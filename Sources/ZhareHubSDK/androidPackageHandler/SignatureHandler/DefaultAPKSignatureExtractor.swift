//
//  DefaultAPKSignatureExtractor.swift
//  ZhareHubSDK
//
//  Native (no-tooling) extractor for APK signing schemes v1, v2 and v3.
//  Ported from ApkAnalyzer POC. Uses `Security` framework for cert parsing.
//

import Foundation
import Security

public final class DefaultAPKSignatureExtractor: APKSignatureExtractorProtocol {

    public init() {}

    public func extract(from apkPath: URL) -> APKSignatureInfo {
        var signerDN: String = "N/A"

        // --- v1: META-INF/*.RSA/.DSA/.EC ---
        if let zip = APKZipReader(url: apkPath) {
            let metaEntries = zip.entries.map(\.path).filter { $0.hasPrefix("META-INF/") }
            let hasManifest = metaEntries.contains("META-INF/MANIFEST.MF")
            let hasSF = metaEntries.contains { $0.hasSuffix(".SF") }
            let sigBlockExtensions = [".RSA", ".DSA", ".EC"]
            let sigBlockEntry = metaEntries.first { path in
                sigBlockExtensions.contains { path.uppercased().hasSuffix($0) }
            }
            if hasManifest && hasSF,
               let blockPath = sigBlockEntry,
               let pkcs7Data = zip.extractEntry(path: blockPath) {
                signerDN = extractCertificateDN(from: pkcs7Data)
            }
        }

        // --- v2 / v3: APK Signing Block ---
        if signerDN == "N/A",
           let certData = extractCertFromSigningBlock(at: apkPath),
           let der = certData.certificate,
           let cert = SecCertificateCreateWithData(nil, der as CFData) {
            signerDN = formatCertificateDN(cert)
        }

        return APKSignatureInfo(signer: signerDN)
    }

    // MARK: - APK Signing Block (v2/v3)

    private func extractCertFromSigningBlock(at apkPath: URL) -> (v2: Bool, v3: Bool, certificate: Data?)? {
        guard let handle = try? FileHandle(forReadingFrom: apkPath) else { return nil }
        defer { handle.closeFile() }

        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 22 else { return nil }

        let searchStart = fileSize > 65557 ? fileSize - 65557 : 0
        handle.seek(toFileOffset: searchStart)
        let tailData = handle.readData(ofLength: Int(fileSize - searchStart))
        let tailBytes = [UInt8](tailData)

        var eocdOffset: Int?
        guard tailBytes.count >= 22 else { return nil }
        for i in stride(from: tailBytes.count - 22, through: 0, by: -1) {
            if tailBytes[i] == 0x50 && tailBytes[i+1] == 0x4b &&
               tailBytes[i+2] == 0x05 && tailBytes[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        guard let eocd = eocdOffset, eocd + 21 < tailBytes.count else { return nil }

        let cdOffset = UInt64(tailBytes[eocd+16]) |
                        (UInt64(tailBytes[eocd+17]) << 8) |
                        (UInt64(tailBytes[eocd+18]) << 16) |
                        (UInt64(tailBytes[eocd+19]) << 24)

        guard let magic = "APK Sig Block 42".data(using: .ascii), cdOffset >= 24 else { return nil }

        handle.seek(toFileOffset: cdOffset - 24)
        let trailer = handle.readData(ofLength: 24)
        guard trailer.count == 24, trailer.subdata(in: 8..<24) == magic else { return nil }

        let blockSize = trailer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt64.self) }
        guard blockSize > 24, blockSize <= cdOffset - 8 else { return nil }
        let blockStart = cdOffset - 8 - blockSize

        guard blockStart + 8 < cdOffset - 24 else { return nil }
        let pairsStart = blockStart + 8
        let pairsEnd = cdOffset - 24
        let pairsLen = pairsEnd - pairsStart
        guard pairsLen > 0, pairsLen < 50_000_000 else { return nil }

        handle.seek(toFileOffset: pairsStart)
        let pairsData = handle.readData(ofLength: Int(pairsLen))
        guard pairsData.count == Int(pairsLen) else { return nil }

        return parsePairs(pairsData)
    }

    private func parsePairs(_ pairsData: Data) -> (v2: Bool, v3: Bool, certificate: Data?)? {
        let v2ID: UInt32 = 0x7109871a
        let v3ID: UInt32 = 0xf05368c0
        var foundV2 = false
        var foundV3 = false
        var firstCert: Data?

        var offset = 0
        while offset + 12 <= pairsData.count {
            let pairSize = pairsData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }
            guard pairSize >= 4, pairSize <= UInt64(pairsData.count - offset - 8) else { break }

            let pairID = pairsData.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset + 8, as: UInt32.self) }
            let dataStart = offset + 12
            let dataLen = Int(pairSize) - 4

            guard dataStart + dataLen <= pairsData.count else { break }

            if pairID == v2ID {
                foundV2 = true
                if firstCert == nil {
                    firstCert = extractCertFromSignerBlock(pairsData.subdata(in: dataStart..<(dataStart + dataLen)))
                }
            } else if pairID == v3ID {
                foundV3 = true
                if firstCert == nil {
                    firstCert = extractCertFromSignerBlock(pairsData.subdata(in: dataStart..<(dataStart + dataLen)))
                }
            }

            let nextOffset = offset + 8 + Int(pairSize)
            guard nextOffset > offset else { break }
            offset = nextOffset
        }

        guard foundV2 || foundV3 else { return nil }
        return (foundV2, foundV3, firstCert)
    }

    private func extractCertFromSignerBlock(_ data: Data) -> Data? {
        guard data.count > 20 else { return nil }

        return data.withUnsafeBytes { bytes -> Data? in
            func readU32(_ offset: Int) -> Int? {
                guard offset >= 0, offset + 4 <= data.count else { return nil }
                return Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }

            guard let signersSeqLen = readU32(0), signersSeqLen > 0 else { return nil }
            guard let signerLen = readU32(4), signerLen > 0 else { return nil }
            guard let signedDataLen = readU32(8), signedDataLen > 0,
                  12 + signedDataLen <= data.count else { return nil }
            let signedDataStart = 12

            guard let digestsSeqLen = readU32(signedDataStart), digestsSeqLen >= 0 else { return nil }
            let certsSeqOffset = signedDataStart + 4 + digestsSeqLen
            guard certsSeqOffset >= signedDataStart + 4, certsSeqOffset < data.count else { return nil }

            guard let certsSeqLen = readU32(certsSeqOffset), certsSeqLen > 0 else { return nil }
            let firstCertOffset = certsSeqOffset + 4
            guard firstCertOffset > certsSeqOffset, firstCertOffset < data.count else { return nil }

            guard let certLen = readU32(firstCertOffset), certLen > 0,
                  firstCertOffset + 4 + certLen <= data.count else { return nil }

            return data.subdata(in: (firstCertOffset + 4)..<(firstCertOffset + 4 + certLen))
        }
    }

    // MARK: - PKCS#7 / DN

    private func extractCertificateDN(from pkcs7Data: Data) -> String {
        if let cert = SecCertificateCreateWithData(nil, pkcs7Data as CFData) {
            return formatCertificateDN(cert)
        }
        if let dn = extractDNFromPKCS7(pkcs7Data) {
            return dn
        }
        return "N/A"
    }

    private func extractDNFromPKCS7(_ data: Data) -> String? {
        let bytes = [UInt8](data)
        guard bytes.count > 4 else { return nil }

        for i in 0..<(bytes.count - 4) {
            guard bytes[i] == 0x30 else { continue }

            let certData: Data?
            let totalLen: Int

            if bytes[i + 1] == 0x82 && i + 4 < bytes.count {
                let len = (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
                totalLen = 4 + len
                guard i + totalLen <= bytes.count, totalLen > 100 else { continue }
                certData = Data(bytes[i..<(i + totalLen)])
            } else if bytes[i + 1] == 0x83 && i + 5 < bytes.count {
                let len = (Int(bytes[i + 2]) << 16) | (Int(bytes[i + 3]) << 8) | Int(bytes[i + 4])
                totalLen = 5 + len
                guard i + totalLen <= bytes.count, totalLen > 100 else { continue }
                certData = Data(bytes[i..<(i + totalLen)])
            } else {
                continue
            }

            guard let candidate = certData,
                  let cert = SecCertificateCreateWithData(nil, candidate as CFData) else {
                continue
            }
            return formatCertificateDN(cert)
        }

        return nil
    }

    private func formatCertificateDN(_ cert: SecCertificate) -> String {
        let derData = SecCertificateCopyData(cert) as Data

        if let fields = parseSubjectDNFields(derData) {
            let cn = fields["CN"]
            let org = fields["O"]
            let ou = fields["OU"]

            if let org, !org.isEmpty {
                if let cn, !cn.isEmpty, cn.lowercased() != org.lowercased() {
                    return "\(org) (\(cn))"
                }
                return org
            }
            if let cn, !cn.isEmpty { return cn }
            if let ou, !ou.isEmpty { return ou }
        }

        if let summary = SecCertificateCopySubjectSummary(cert) as String?, !summary.isEmpty {
            return summary
        }

        return "N/A"
    }

    private func parseSubjectDNFields(_ data: Data) -> [String: String]? {
        let bytes = [UInt8](data)
        guard bytes.count > 8 else { return nil }

        let oidLabels: [[UInt8]: String] = [
            [0x55, 0x04, 0x03]: "CN",
            [0x55, 0x04, 0x06]: "C",
            [0x55, 0x04, 0x07]: "L",
            [0x55, 0x04, 0x08]: "ST",
            [0x55, 0x04, 0x0A]: "O",
            [0x55, 0x04, 0x0B]: "OU",
        ]

        var fields: [String: String] = [:]

        for i in 0..<(bytes.count - 7) {
            guard bytes[i] == 0x06, bytes[i + 1] == 0x03,
                  bytes[i + 2] == 0x55, bytes[i + 3] == 0x04 else { continue }

            let oid = Array(bytes[(i + 2)...(i + 4)])
            guard let label = oidLabels[oid] else { continue }

            let valueStart = i + 5
            guard valueStart + 2 < bytes.count else { continue }
            let tag = bytes[valueStart]
            guard tag == 0x0C || tag == 0x13 || tag == 0x16 || tag == 0x1E else { continue }
            let len = Int(bytes[valueStart + 1])
            guard valueStart + 2 + len <= bytes.count else { continue }

            let valueBytes = Data(bytes[(valueStart + 2)..<(valueStart + 2 + len)])
            if let str = String(data: valueBytes, encoding: .utf8), fields[label] == nil {
                fields[label] = str
            }
        }

        return fields.isEmpty ? nil : fields
    }
}
