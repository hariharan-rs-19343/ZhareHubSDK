//
//  APKExtractionProtocol.swift
//  ZhareHubSDK
//
//  Strategy contract for Android package extraction. Mirrors the role of
//  `PackageExtractionProtocol` in `iOSPackageHandler/`.
//

import Foundation

public protocol APKExtractionProtocol: Sendable {

    /// Whether this strategy can handle the given URL.
    func canHandle(url: URL) -> Bool

    /// Extracts a fully-populated `APKExtractionModel` for the package at `apkURL`.
    ///
    /// - Parameters:
    ///   - apkURL: Source URL of the APK (already cached / accessible to the process).
    ///   - fileName: Display file name to embed in the resulting model.
    ///   - shell: Consumer-provided shell executor used to invoke `aapt2`.
    ///   - aapt2Path: Absolute path to the bundled `aapt2` binary.
    ///   - parser: Badging output parser.
    ///   - signatureExtractor: Native APK signature extractor.
    ///   - iconExtractor: Multi-strategy icon extractor.
    func extractMetadata(
        from apkURL: URL,
        fileName: String,
        shell: ShellExecutorProtocol,
        aapt2Path: String,
        parser: APKBadgingParserProtocol,
        signatureExtractor: APKSignatureExtractorProtocol,
        iconExtractor: APKIconExtractorProtocol
    ) async throws -> APKExtractionModel
}
