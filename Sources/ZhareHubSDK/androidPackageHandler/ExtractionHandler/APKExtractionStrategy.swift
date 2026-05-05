//
//  APKExtractionStrategy.swift
//  ZhareHubSDK
//
//  Default strategy for `.apk` files. Pipeline:
//   1. Validate URL
//   2. Run `aapt2 dump badging`
//   3. Parse badging into APKBundleProperties
//   4. Concurrently extract icon (uses aapt2) + signature (native, no shell)
//   5. Read raw APK bytes for upload-ready payload
//   6. Assemble APKExtractionModel
//

import Foundation
import SUICore

public final class APKExtractionStrategy: APKExtractionProtocol {

    public init() {}

    public func canHandle(url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare(ZHConstants.APK_FILE_EXTENSION) == .orderedSame
    }

    public func extractMetadata(
        from apkURL: URL,
        fileName: String,
        shell: ShellExecutorProtocol,
        aapt2Path: String,
        parser: APKBadgingParserProtocol,
        signatureExtractor: APKSignatureExtractorProtocol,
        iconExtractor: APKIconExtractorProtocol
    ) async throws -> APKExtractionModel {

        guard FileManager.default.fileExists(atPath: apkURL.path(percentEncoded: false)) else {
            throw FileConversionError.invalidFilePath
        }

        // 1. aapt2 dump badging
        let badgingResult = try await shell.run(
            executablePath: aapt2Path,
            arguments: ["dump", "badging", apkURL.path],
            environment: nil,
            workingDirectory: nil,
            timeout: 30
        )

        guard badgingResult.isSuccess else {
            let reason = badgingResult.errorOutput.isEmpty
                ? "aapt2 exited with code \(badgingResult.exitCode)"
                : badgingResult.errorOutput
            throw FileConversionError.custom("aapt2 dump badging failed: \(reason)")
        }

        let badging = badgingResult.output

        // 2. Parse badging
        let properties = parser.loadProperties(from: badging)

        // 3. Parallel icon + signature extraction
        async let iconTask: APKIconResult? = iconExtractor.extractIcon(
            from: apkURL,
            badgingOutput: badging,
            parser: parser,
            shell: shell,
            aapt2Path: aapt2Path
        )

        async let signatureTask: APKSignatureInfo = Task.detached(priority: .userInitiated) {
            signatureExtractor.extract(from: apkURL)
        }.value

        let iconResult = await iconTask
        let signature = await signatureTask

        // 4. Raw APK data (best-effort)
        let appData = try? Data(contentsOf: apkURL)

        // 5. Icon Data (PNG) for parity with iOS PackageExtractionModel
        let iconData = await Task.detached { () -> Data? in
            await MainActor.run { iconResult?.image.pngData() }
        }.value

        return APKExtractionModel(
            fileName: fileName,
            appIcon: iconData,
            app: appData,
            iconSourcePath: iconResult?.sourcePath,
            properties: properties,
            signature: signature
        )
    }
}
