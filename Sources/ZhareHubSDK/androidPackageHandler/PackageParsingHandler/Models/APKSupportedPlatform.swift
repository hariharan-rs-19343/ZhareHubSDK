//
//  APKSupportedPlatform.swift
//  ZhareHubSDK
//
//  Android counterpart of `SupportedPlatform` — form factors an APK targets,
//  derived from its manifest `uses-feature` entries.
//

import Foundation

public enum APKSupportedPlatform: String, Codable, Hashable, Sendable, CaseIterable {
    case phoneAndTablet
    case wearOS
    case tv
    case automotive
    case chromeOS

    /// Uploaded as `supported_platform`, whose server regex (`^[A-Za-z0-9 ,._-]{0,100}$`)
    /// rejects `&` and `/`, so names stick to letters, digits and spaces.
    public var displayName: String {
        switch self {
        case .phoneAndTablet: "Phone and Tablet"
        case .wearOS: "Wear OS"
        // Google TV runs on Android TV OS; the APK can't tell them apart.
        case .tv: "Android TV and Google TV"
        case .automotive: "Android Automotive"
        case .chromeOS: "ChromeOS"
        }
    }
}

enum APKSupportedPlatformResolver {
    private enum Feature {
        static let watch = "android.hardware.type.watch"
        static let leanback = "android.software.leanback"
        static let television = "android.hardware.type.television"
        static let automotive = "android.hardware.type.automotive"
        static let pc = "android.hardware.type.pc"
    }

    /// A feature counts whether required or optional. A *required* watch, TV or
    /// automotive feature means the APK runs only there, so phone & tablet is
    /// included only when none of those is required.
    static func resolve(required: [String], optional: [String]) -> [APKSupportedPlatform] {
        let requiredSet = Set(required)
        let all = requiredSet.union(optional)

        var resolved = Set<APKSupportedPlatform>()
        if all.contains(Feature.watch) { resolved.insert(.wearOS) }
        if all.contains(Feature.leanback) || all.contains(Feature.television) { resolved.insert(.tv) }
        if all.contains(Feature.automotive) { resolved.insert(.automotive) }
        if all.contains(Feature.pc) { resolved.insert(.chromeOS) }

        let formFactorRequired = [Feature.watch, Feature.leanback, Feature.television, Feature.automotive]
            .contains(where: requiredSet.contains)
        if !formFactorRequired { resolved.insert(.phoneAndTablet) }

        return APKSupportedPlatform.allCases.filter { resolved.contains($0) }
    }
}
