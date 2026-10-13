//
//  SupportedPlatform.swift
//  ZhareHubSDK
//

import Foundation

public enum SupportedPlatform: String, Codable, Hashable, Sendable, CaseIterable {
    case iOS
    case iPadOS
    case macOS
    case macCatalyst
    case watchOS
    case visionOS
}

public enum DeviceFamilyCode {
    public static let iPhone = 1
    public static let iPad = 2
    public static let mac = 6
    public static let appleVision = 7
}

enum SupportedPlatformResolver {
    static func resolve(
        rawPlatforms: [String],
        deviceFamilies: [Int],
        requiresIPhoneOS: Bool,
        platformName: String?,
        sdkName: String?,
        watchAppPresent: Bool
    ) -> [SupportedPlatform] {
        let raw = Set(rawPlatforms.map { $0.lowercased() })
        let families = Set(deviceFamilies)
        let platform = platformName?.lowercased() ?? ""
        let sdk = sdkName?.lowercased() ?? ""

        let iphoneOS = raw.contains("iphoneos") || platform == "iphoneos" || sdk.contains("iphoneos")
        let watchOS = raw.contains("watchos") || platform == "watchos" || sdk.contains("watchos") || watchAppPresent
        let visionOS = raw.contains("xros") || platform == "xros" || sdk.contains("xros") || families.contains(DeviceFamilyCode.appleVision)
        let macDeclared = raw.contains("macosx") || platform == "macosx" || sdk.contains("macosx")
        let catalystMarker = requiresIPhoneOS
            || families.contains(DeviceFamilyCode.mac)
            || platform.contains("maccatalyst")
            || sdk.contains("maccatalyst")

        var resolved = Set<SupportedPlatform>()
        if iphoneOS {
            if families.contains(DeviceFamilyCode.iPhone) {
                resolved.insert(.iOS)
            }
            if families.contains(DeviceFamilyCode.iPad) {
                resolved.insert(.iPadOS)
            }
        }
        if macDeclared || families.contains(DeviceFamilyCode.mac) {
            if catalystMarker {
                resolved.insert(.macCatalyst)
            } else if macDeclared {
                resolved.insert(.macOS)
            }
        }
        if watchOS {
            resolved.insert(.watchOS)
        }
        if visionOS {
            resolved.insert(.visionOS)
        }

        return SupportedPlatform.allCases.filter { resolved.contains($0) }
    }

    static func deviceFamilies(from value: Any?) -> [Int]? {
        if let families = value as? [Int] {
            return families
        }
        if let numbers = value as? [NSNumber] {
            return numbers.map(\.intValue)
        }
        return nil
    }

    static func watchAppExists(in appDirectory: URL) -> Bool {
        let watchDirectory = appDirectory.appending(component: "Watch")
        guard FileURLPath.fileExists(watchDirectory) else { return false }
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: FileURLPath.decoded(watchDirectory)) else {
            return false
        }
        return contents.contains { $0.lowercased().hasSuffix(".app") }
    }
}
