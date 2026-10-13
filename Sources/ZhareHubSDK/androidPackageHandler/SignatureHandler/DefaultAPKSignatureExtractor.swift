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
        let signingBlock = extractCertFromSigningBlock(at: apkPath)
        var schemes: [String] = []
        if signingBlock?.v3 == true { schemes.append("v3") }
        if signingBlock?.v2 == true { schemes.append("v2") }

        if let der = signingBlock?.certificate,
           let cert = SecCertificateCreateWithData(nil, der as CFData) {
            if let v1 = v1Certificate(at: apkPath) {
                schemes.append("v1")
                _ = v1
            }
            return APKSignatureInfo(signer: formatCertificateDN(cert), signingSchemes: schemeList(schemes))
        }

        if let v1 = v1Certificate(at: apkPath) {
            schemes.append("v1")
            return APKSignatureInfo(signer: formatCertificateDN(v1), signingSchemes: schemeList(schemes))
        }

        return APKSignatureInfo(signer: APKConstants.notAvailable, signingSchemes: schemeList(schemes))
    }

    private func schemeList(_ schemes: [String]) -> String {
        schemes.isEmpty ? APKConstants.notAvailable : schemes.joined(separator: ", ")
    }

    private func v1Certificate(at apkPath: URL) -> SecCertificate? {
        guard let zip = APKZipReader(url: apkPath) else { return nil }
        let metaEntries = zip.entries.map(\.path).filter { $0.hasPrefix("META-INF/") }
        guard metaEntries.contains("META-INF/MANIFEST.MF") else { return nil }
        let signatureFiles = metaEntries.filter { $0.uppercased().hasSuffix(".SF") }
        let signatureStems = Set(signatureFiles.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent.uppercased() })
        let blockExtensions = [".RSA", ".DSA", ".EC"]
        let blockPath = metaEntries.first { path in
            let uppercased = path.uppercased()
            guard blockExtensions.contains(where: { uppercased.hasSuffix($0) }) else { return false }
            let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.uppercased()
            return signatureStems.contains(stem)
        }
        guard let blockPath, let pkcs7Data = zip.extractEntry(path: blockPath) else { return nil }
        if let cert = SecCertificateCreateWithData(nil, pkcs7Data as CFData) {
            return cert
        }
        return certificateFromPKCS7Scan(pkcs7Data)
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
                let commentLength = Int(tailBytes[i+20]) | (Int(tailBytes[i+21]) << 8)
                if commentLength == tailBytes.count - (i + 22) {
                    eocdOffset = i
                    break
                }
            }
        }
        guard let eocd = eocdOffset, eocd + 21 < tailBytes.count else { return nil }

        var cdOffset = UInt64(tailBytes[eocd+16]) |
                        (UInt64(tailBytes[eocd+17]) << 8) |
                        (UInt64(tailBytes[eocd+18]) << 16) |
                        (UInt64(tailBytes[eocd+19]) << 24)
        let cdSize = UInt64(tailBytes[eocd+12]) |
                        (UInt64(tailBytes[eocd+13]) << 8) |
                        (UInt64(tailBytes[eocd+14]) << 16) |
                        (UInt64(tailBytes[eocd+15]) << 24)
        if cdOffset == UInt64(UInt32.max) || cdSize == UInt64(UInt32.max),
           let zip64Offset = zip64CentralDirectoryOffset(tailBytes: tailBytes, eocd: eocd, searchStart: searchStart, handle: handle) {
            cdOffset = zip64Offset
        }

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
        var v2Cert: Data?
        var v3Cert: Data?

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
                if v2Cert == nil {
                    v2Cert = extractCertFromSignerBlock(pairsData.subdata(in: dataStart..<(dataStart + dataLen)))
                }
            } else if pairID == v3ID {
                foundV3 = true
                if v3Cert == nil {
                    v3Cert = extractCertFromSignerBlock(pairsData.subdata(in: dataStart..<(dataStart + dataLen)))
                }
            }

            let nextOffset = offset + 8 + Int(pairSize)
            guard nextOffset > offset else { break }
            offset = nextOffset
        }

        guard foundV2 || foundV3 else { return nil }
        return (foundV2, foundV3, v3Cert ?? v2Cert)
    }

    private func zip64CentralDirectoryOffset(tailBytes: [UInt8], eocd: Int, searchStart: UInt64, handle: FileHandle) -> UInt64? {
        guard eocd >= 20 else { return nil }
        let locator = eocd - 20
        guard tailBytes[locator] == 0x50, tailBytes[locator + 1] == 0x4b,
              tailBytes[locator + 2] == 0x06, tailBytes[locator + 3] == 0x07 else { return nil }
        let relativeOffset = tailBytes[locator..<locator + 20].withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 8, as: UInt64.self)
        }
        guard relativeOffset >= searchStart else { return nil }
        handle.seek(toFileOffset: relativeOffset)
        let record = handle.readData(ofLength: 56)
        guard record.count == 56 else { return nil }
        let signature = record.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        guard signature == 0x06064b50 else { return nil }
        return record.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 48, as: UInt64.self) }
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

    private func certificateFromPKCS7Scan(_ data: Data) -> SecCertificate? {
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

            if let candidate = certData, let cert = SecCertificateCreateWithData(nil, candidate as CFData) {
                return cert
            }
        }

        return nil
    }

    private func formatCertificateDN(_ cert: SecCertificate) -> String {
        let subjectKey = kSecOIDX509V1SubjectName as String
        if let values = SecCertificateCopyValues(cert, [kSecOIDX509V1SubjectName] as CFArray, nil) as? [String: Any],
           let subject = values[subjectKey] as? [String: Any],
           let items = subject[kSecPropertyKeyValue as String] as? [[String: Any]] {
            var fields: [String: String] = [:]
            for item in items {
                guard let label = item[kSecPropertyKeyLabel as String] as? String else { continue }
                let value = (item[kSecPropertyKeyValue as String] as? String) ?? ""
                let normalized = Self.normalizedDNLabel(label)
                if fields[normalized] == nil, !value.isEmpty {
                    fields[normalized] = value
                }
            }
            if let formatted = Self.formattedDN(fields) {
                return formatted
            }
        }

        if let summary = SecCertificateCopySubjectSummary(cert) as String?, !summary.isEmpty {
            return summary
        }
        return APKConstants.notAvailable
    }

    private static func normalizedDNLabel(_ label: String) -> String {
        switch label {
        case "2.5.4.3", "CN", "Common Name":
            return "CN"
        case "2.5.4.10", "O", "Organization":
            return "O"
        case "2.5.4.11", "OU", "Organizational Unit":
            return "OU"
        default:
            return label
        }
    }

    private static func formattedDN(_ fields: [String: String]) -> String? {
        let organization = fields["O"]
        let commonName = fields["CN"]
        let unit = fields["OU"]
        if let organization, !organization.isEmpty {
            if let commonName, !commonName.isEmpty, commonName.lowercased() != organization.lowercased() {
                return "\(organization) (\(commonName))"
            }
            return organization
        }
        if let commonName, !commonName.isEmpty { return commonName }
        if let unit, !unit.isEmpty { return unit }
        return nil
    }
}
