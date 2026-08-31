//
//  APKExtractionHandler.swift
//  ZhareHubSDK
//
//  High-level entry point for Android APK extraction. Sibling of
//  `PackageExtractionHandler` (iOS side) — does not share its protocol family.
//
//  The host application is responsible for:
//   - shipping `aapt2` (macOS binary) inside the app bundle
//   - providing a concrete `ShellExecutorProtocol` that bridges Process calls
//     (typically via a macOS helper bundle loaded from `Bundle.main/PlugIns/`)
//

import Foundation
import SUICore

public final class APKExtractionHandler {

    // Dependencies
    private let strategyResolver: APKExtractionStrategyResolver
    private let parser: APKBadgingParserProtocol
    private let signatureExtractor: APKSignatureExtractorProtocol
    private let iconExtractor: APKIconExtractorProtocol
    private let shell: ShellExecutorProtocol
    private let aapt2Path: String
    private let logger: ZHLoggerProtocol

    public init(
        resolver: APKExtractionStrategyResolver = APKExtractionStrategyResolver(),
        parser: APKBadgingParserProtocol = DefaultAPKBadgingParser(),
        signatureExtractor: APKSignatureExtractorProtocol = DefaultAPKSignatureExtractor(),
        iconExtractor: APKIconExtractorProtocol = DefaultAPKIconExtractor(),
        shell: ShellExecutorProtocol,
        aapt2Path: String,
        logger: ZHLoggerProtocol = ZHDefaultLogger(subsystem: "com.zharehub.sdk")
    ) {
        self.strategyResolver = resolver
        self.parser = parser
        self.signatureExtractor = signatureExtractor
        self.iconExtractor = iconExtractor
        self.shell = shell
        self.aapt2Path = aapt2Path
        self.logger = logger
    }

    /// Extracts a fully populated `APKExtractionModel` from the APK at `url`.
    ///
    /// Returns `.failure(FileConversionError.unsupportedPlatform)` if the injected
    /// `ShellExecutorProtocol` is unavailable on the current platform.
    public func initiateAPKExtraction(from url: URL, fileName: String) async -> Result<APKExtractionModel, Error> {
        logger.log(level: .info, category: .custom("androidParsing"), message: "Starting APK extraction", metadata: ["fileName": fileName])
        let clock = ContinuousClock()
        let start = clock.now

        guard shell.isAvailable else {
            logger.log(level: .error, category: .custom("androidParsing"), message: "Shell executor unavailable on this platform")
            return .failure(FileConversionError.unsupportedPlatform)
        }

        // Security-scoped resource access (e.g., document picker URLs)
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.isExecutableFile(atPath: aapt2Path) else {
            let err = FileConversionError.custom("aapt2 binary not executable at path: \(aapt2Path)")
            logger.log(level: .error, category: .custom("androidParsing"), message: err.localizedDescription)
            return .failure(err)
        }

        do {
            guard let strategy = strategyResolver.resolve(for: url) else {
                throw FileConversionError.unsupportedFile
            }
            logger.log(level: .debug, category: .custom("androidParsing"), message: "Resolved strategy \(type(of: strategy))")

            let model = try await strategy.extractMetadata(
                from: url,
                fileName: fileName,
                shell: shell,
                aapt2Path: aapt2Path,
                parser: parser,
                signatureExtractor: signatureExtractor,
                iconExtractor: iconExtractor
            )

            let duration = (clock.now - start).secondsString
            logger.log(
                level: .info,
                category: .custom("androidParsing"),
                message: "APK extraction succeeded",
                metadata: [
                    "fileName": fileName,
                    "packageIdentifier": model.properties?.packageIdentifier ?? "",
                    "versionName": model.properties?.versionName ?? "",
                    "durationSeconds": duration
                ]
            )
            return .success(model)
        } catch {
            let duration = (clock.now - start).secondsString
            logger.log(
                level: .error,
                category: .custom("androidParsing"),
                message: "APK extraction failed",
                metadata: ["fileName": fileName, "error": error.localizedDescription, "durationSeconds": duration]
            )
            return .failure(error)
        }
    }
}
