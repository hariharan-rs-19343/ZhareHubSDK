//
//  APKBadgingParserProtocol.swift
//  ZhareHubSDK
//

import Foundation

/// Pure parsing of `aapt2 dump badging` output into structured data.
public protocol APKBadgingParserProtocol: Sendable {
    func parseAppLabel(from output: String) -> String
    func parseSingleValue(from output: String, key: String) -> String
    func parseDeviceCompatibility(from output: String) -> [String]
    func parseFeatures(from output: String) -> [String]
    func parsePermissions(from output: String) -> [String]
    func parseAllIconEntries(from output: String) -> [APKIconEntry]
    func loadProperties(from output: String) -> APKBundleProperties
}

/// A single icon entry from `aapt2 dump badging`. Used by both the parser and the icon extractor.
public struct APKIconEntry: Hashable, Sendable {
    public let density: Int
    public let path: String

    public var isPNG: Bool { path.hasSuffix(".png") }
    public var isWebP: Bool { path.hasSuffix(".webp") }
    public var isXML: Bool { path.hasSuffix(".xml") }
    public var isRasterImage: Bool { isPNG || isWebP }

    public init(density: Int, path: String) {
        self.density = density
        self.path = path
    }
}
