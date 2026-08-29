//
//  APKIconExtractorProtocol.swift
//  ZhareHubSDK
//

import Foundation
import SUICore

public enum APKIconExtractionStrategyKind: String, Sendable {
    case directPath
    case vectorRendered
    case densityFallback
    case anyPNG
}

public struct APKIconResult: Sendable {
    public let image: PlatformImage
    public let strategy: APKIconExtractionStrategyKind
    public let sourcePath: String?

    public init(image: PlatformImage, strategy: APKIconExtractionStrategyKind, sourcePath: String?) {
        self.image = image
        self.strategy = strategy
        self.sourcePath = sourcePath
    }
}

public protocol APKIconExtractorProtocol: Sendable {
    func extractIcon(
        from apkURL: URL,
        badgingOutput: String,
        parser: APKBadgingParserProtocol,
        shell: ShellExecutorProtocol,
        aapt2Path: String
    ) async -> APKIconResult?
}
