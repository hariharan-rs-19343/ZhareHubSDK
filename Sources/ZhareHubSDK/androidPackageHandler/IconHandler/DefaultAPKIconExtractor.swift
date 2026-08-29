//
//  DefaultAPKIconExtractor.swift
//  ZhareHubSDK
//
//  Multi-strategy APK icon resolver. Ports `APKIconExtractor` from the POC.
//
//  Strategy order:
//   1. Direct extraction of the highest-density raster icon advertised in
//      `aapt2 dump badging`.
//   2. Vector / adaptive-icon XML rendered via `APKVectorIconParser`.
//   2.5. Direct adaptive-icon foreground PNG resolution via `aapt2 dump xmltree`
//        / `dump resources` (handles obfuscated APKs).
//   3. Density scan: any `ic_launcher*.png` / `.webp` under `res/mipmap-*/`
//      or `res/drawable-*/`.
//   4. Best square PNG fallback for obfuscated APKs.
//

import Foundation
import SUICore

public final class DefaultAPKIconExtractor: APKIconExtractorProtocol {

    public init() {}

    public func extractIcon(
        from apkURL: URL,
        badgingOutput: String,
        parser: APKBadgingParserProtocol,
        shell: ShellExecutorProtocol,
        aapt2Path: String
    ) async -> APKIconResult? {
        let entries = parser.parseAllIconEntries(from: badgingOutput)
        let iconPath = bestIconPath(entries: entries)

        guard let zip = APKZipReader(url: apkURL) else { return nil }

        // 1. Direct raster
        if let relPath = iconPath, !relPath.hasSuffix(".xml"),
           let data = zip.extractEntry(path: relPath),
           let image = PlatformImage(data: data) {
            return APKIconResult(image: image, strategy: .directPath, sourcePath: relPath)
        }

        // 2. Vector / adaptive-icon
        let vectorParser = APKVectorIconParser(aapt2Path: aapt2Path, shell: shell)

        if let xmlPath = iconPath, xmlPath.hasSuffix(".xml") {
            if let image = await vectorParser.renderIcon(from: apkURL, iconXmlPath: xmlPath) {
                return APKIconResult(image: image, strategy: .vectorRendered, sourcePath: xmlPath)
            }

            // 2.5 Adaptive-icon foreground PNG resolution
            if let result = await extractAdaptiveIconPNGs(
                from: apkURL, iconXml: xmlPath,
                shell: shell, aapt2Path: aapt2Path, zip: zip
            ) {
                return APKIconResult(image: result.0, strategy: .densityFallback, sourcePath: result.1)
            }
        }

        // 3. Density scan
        if let result = extractByDensityScan(from: zip) {
            return APKIconResult(image: result.0, strategy: .densityFallback, sourcePath: result.1)
        }

        // 4. Best square PNG
        if let result = extractBestSquarePNG(from: zip) {
            return APKIconResult(image: result.0, strategy: .anyPNG, sourcePath: result.1)
        }

        return nil
    }

    // MARK: - Selection

    private func bestIconPath(entries: [APKIconEntry]) -> String? {
        guard !entries.isEmpty else { return nil }
        if let png = entries.filter(\.isPNG).max(by: { $0.density < $1.density }) { return png.path }
        if let webp = entries.filter(\.isWebP).max(by: { $0.density < $1.density }) { return webp.path }
        return entries.max(by: { $0.density < $1.density })?.path
    }

    // MARK: - Strategy 2.5

    private func extractAdaptiveIconPNGs(
        from apkPath: URL,
        iconXml: String,
        shell: ShellExecutorProtocol,
        aapt2Path: String,
        zip: APKZipReader
    ) async -> (PlatformImage, String)? {
        guard let xmlOut = try? await shell.run(
            executablePath: aapt2Path,
            arguments: [APKConstants.AAPT2.dumpVerb, APKConstants.AAPT2.Command.xmltree.rawValue, apkPath.path, APKConstants.AAPT2.fileFlag, iconXml],
            environment: nil, workingDirectory: nil, timeout: 30
        ), !xmlOut.output.isEmpty else { return nil }

        let refPattern = "foreground[\\s\\S]*?drawable.*?=(@0x[0-9a-fA-F]+)"
        guard let refRegex = try? NSRegularExpression(pattern: refPattern),
              let refMatch = refRegex.firstMatch(in: xmlOut.output,
                                                 range: NSRange(xmlOut.output.startIndex..., in: xmlOut.output)),
              refMatch.numberOfRanges >= 2 else { return nil }
        let foregroundRef = (xmlOut.output as NSString).substring(with: refMatch.range(at: 1))
        let cleanRef = foregroundRef.replacingOccurrences(of: "@", with: "")

        guard let resOut = try? await shell.run(
            executablePath: aapt2Path,
            arguments: [APKConstants.AAPT2.dumpVerb, APKConstants.AAPT2.Command.resources.rawValue, apkPath.path],
            environment: nil, workingDirectory: nil, timeout: 15
        ), !resOut.output.isEmpty else { return nil }

        var foundResource = false
        var pngPaths: [String] = []
        for line in resOut.output.components(separatedBy: "\n") {
            if line.contains(cleanRef) { foundResource = true; continue }
            if foundResource {
                if line.contains("resource ") { break }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let resRange = trimmed.range(of: APKConstants.resourcePrefix) {
                    var path = String(trimmed[resRange.lowerBound...])
                    if let typeRange = path.range(of: " type=") {
                        path = String(path[..<typeRange.lowerBound])
                    }
                    if path.hasSuffix(".png") || path.hasSuffix(".webp") {
                        pngPaths.append(path)
                    }
                }
            }
        }

        for path in pngPaths.reversed() {
            if let data = zip.extractEntry(path: path), let image = PlatformImage(data: data) {
                return (image, path)
            }
        }
        return nil
    }

    // MARK: - Strategy 3

    private func extractByDensityScan(from zip: APKZipReader) -> (PlatformImage, String)? {
        let candidates = zip.entries.filter { entry in
            let p = entry.path.lowercased()
            return (p.hasPrefix("res/mipmap-") || p.hasPrefix("res/drawable-")) &&
                   (p.hasSuffix(".png") || p.hasSuffix(".webp")) &&
                   p.contains("ic_launcher")
        }.sorted { $0.uncompressedSize > $1.uncompressedSize }

        for entry in candidates {
            if let data = zip.extractEntry(path: entry.path),
               let image = PlatformImage(data: data) {
                return (image, entry.path)
            }
        }
        return nil
    }

    // MARK: - Strategy 4

    private func extractBestSquarePNG(from zip: APKZipReader) -> (PlatformImage, String)? {
        let candidates = zip.entries.filter { entry in
            let p = entry.path.lowercased()
            return p.hasPrefix(APKConstants.resourcePrefix) &&
                   (p.hasSuffix(".png") || p.hasSuffix(".webp")) &&
                   !p.contains(".9.") &&
                   entry.uncompressedSize >= 1000 && entry.uncompressedSize <= 30000
        }.sorted { $0.uncompressedSize > $1.uncompressedSize }

        var bestImage: PlatformImage?
        var bestPixels = 0
        var bestPath: String?

        for entry in candidates.prefix(30) {
            guard let data = zip.extractEntry(path: entry.path),
                  let img = PlatformImage(data: data) else { continue }
            let w = Int(img.pixelSize.width)
            let h = Int(img.pixelSize.height)
            guard w > 0, h > 0 else { continue }

            let ratio = CGFloat(max(w, h)) / CGFloat(min(w, h))
            guard ratio <= 1.05, max(w, h) <= 512 else { continue }

            let pixels = w * h
            let isStdSize = Self.iconSizes.contains(w) || Self.iconSizes.contains(h)
            let curIsStd = bestImage != nil && Self.iconSizes.contains(Int(sqrt(Double(bestPixels))))

            if bestImage == nil ||
               (isStdSize && !curIsStd) ||
               (isStdSize == curIsStd && pixels > bestPixels) {
                bestImage = img
                bestPixels = pixels
                bestPath = entry.path
            }
        }

        if let image = bestImage {
            return (image, bestPath ?? "unknown")
        }
        return nil
    }

    private static let iconSizes: Set<Int> = [48, 72, 96, 108, 128, 144, 162, 192, 216, 256, 324, 432, 512]
}
