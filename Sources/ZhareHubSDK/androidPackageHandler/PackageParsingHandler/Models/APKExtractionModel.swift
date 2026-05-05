//
//  APKExtractionModel.swift
//  ZhareHubSDK
//
//  Aggregated APK extraction output. Mirrors the shape of `PackageExtractionModel`
//  while exposing Android-native concepts (signature info, parsed manifest).
//

import Foundation

public struct APKExtractionModel: Hashable, Sendable {
    public let fileName: String?
    public let appIcon: Data?
    public let app: Data?
    public let iconSourcePath: String?
    public let properties: APKBundleProperties?
    public let signature: APKSignatureInfo?

    public var id: Self { self }

    public init(
        fileName: String?,
        appIcon: Data?,
        app: Data?,
        iconSourcePath: String? = nil,
        properties: APKBundleProperties?,
        signature: APKSignatureInfo?
    ) {
        self.fileName = fileName
        self.appIcon = appIcon
        self.app = app
        self.iconSourcePath = iconSourcePath
        self.properties = properties
        self.signature = signature
    }
}

public extension APKExtractionModel {
    func hash(into hasher: inout Hasher) {
        fileName?.hash(into: &hasher)
        properties?.packageIdentifier.hash(into: &hasher)
    }

    func isContentAvailable() -> Bool {
        return fileName != nil
            && appIcon != nil
            && app != nil
            && properties != nil
            && signature != nil
    }
}
