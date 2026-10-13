//
//  BundleProperties.swift
//  ZhareHub
//
//  Created by Hariharan R S on 06/11/24.
//

import Foundation

public struct BundleProperties: Decodable, Identifiable, Hashable {
    public enum APIField {
        public static let deviceFamily = "device_family"
        public static let supportedPlatforms = "supported_platforms"
    }

    public let id: String
    public let bundleName: String?
    public let bundleVersionShort: String?
    public let bundleVersion: String?
    public let bundleIdentifier: String?
    public let minimumOSVersion: String?
    public let requiredDeviceCompability: [String]?
    /// Raw `CFBundleSupportedPlatforms` values, such as `iPhoneOS` or `MacOSX`.
    public let supportedPlatform: [String]?
    /// Raw `UIDeviceFamily` values. `1` is iPhone, `2` is iPad, `6` is Mac, and `7` is Apple Vision.
    public let deviceFamily: [Int]?
    /// Normalized platforms derived from the raw platform list and `deviceFamily`.
    public let supportedPlatforms: [SupportedPlatform]
    public let bundleIcon: String?
    public let redirectURL: String?
    public let appCategory: Bundle.ApplicationCategory

    enum CodingKeys: String, CodingKey {
        case bundleName = "CFBundleName"
        case bundleVersionShort = "CFBundleShortVersionString"
        case bundleVersion = "CFBundleVersion"
        case bundleIdentifier = "CFBundleIdentifier"
        case minimumOSVersion = "MinimumOSVersion"
        case requiredDeviceCompability = "UIRequiredDeviceCapabilities"
        case supportedPlatform = "CFBundleSupportedPlatforms"
        case deviceFamily = "UIDeviceFamily"
        case requiresIPhoneOS = "LSRequiresIPhoneOS"
        case platformName = "DTPlatformName"
        case sdkName = "DTSDKName"
        case bundleIcon = "CFBundleIcons"
        case redirectURL = "CFBundleURLTypes"
        case appCategory = "LSApplicationCategoryType"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleName = try container.decodeIfPresent(String.self, forKey: .bundleName)
        self.bundleVersionShort = try container.decodeIfPresent(String.self, forKey: .bundleVersionShort)
        self.bundleVersion = try container.decodeIfPresent(String.self, forKey: .bundleVersion)
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        self.minimumOSVersion = try container.decodeIfPresent(String.self, forKey: .minimumOSVersion)
        self.requiredDeviceCompability = Self.deviceCapabilities(from: container)
        self.supportedPlatform = try container.decodeIfPresent([String].self, forKey: .supportedPlatform)
        self.deviceFamily = try container.decodeIfPresent([Int].self, forKey: .deviceFamily)
        self.supportedPlatforms = SupportedPlatformResolver.resolve(
            rawPlatforms: supportedPlatform ?? [],
            deviceFamilies: deviceFamily ?? [],
            requiresIPhoneOS: try container.decodeIfPresent(Bool.self, forKey: .requiresIPhoneOS) ?? false,
            platformName: try container.decodeIfPresent(String.self, forKey: .platformName),
            sdkName: try container.decodeIfPresent(String.self, forKey: .sdkName),
            watchAppPresent: false
        )
        self.bundleIcon = try container.decodeIfPresent(BundleIcon.self, forKey: .bundleIcon)?.primaryIcon?.iconFiles?.first

        self.redirectURL = try container.decodeIfPresent([BundleURLTypes].self, forKey: .redirectURL)?.first.flatMap {
            $0.urlIdentifier ?? $0.urlScheme
        }

        if let appCategory: String = try container.decodeIfPresent(String.self, forKey: .appCategory),
           let appCatagoryValue = Bundle.ApplicationCategory(rawValue: appCategory) {
            self.appCategory = appCatagoryValue
        } else {
            self.appCategory = .productivity
        }
        self.id = bundleIdentifier ?? bundleName ?? ""
    }

    public init?(from dictionary: [String: Any], watchAppPresent: Bool = false) {
        self.bundleName = dictionary[CodingKeys.bundleName.rawValue] as? String
        self.bundleVersionShort = dictionary[CodingKeys.bundleVersionShort.rawValue] as? String
        self.bundleVersion = dictionary[CodingKeys.bundleVersion.rawValue] as? String
        self.bundleIdentifier = dictionary[CodingKeys.bundleIdentifier.rawValue] as? String
        self.minimumOSVersion = dictionary[CodingKeys.minimumOSVersion.rawValue] as? String
        self.requiredDeviceCompability = Self.deviceCapabilities(from: dictionary[CodingKeys.requiredDeviceCompability.rawValue])
        self.supportedPlatform = dictionary[CodingKeys.supportedPlatform.rawValue] as? [String]
        self.deviceFamily = SupportedPlatformResolver.deviceFamilies(from: dictionary[CodingKeys.deviceFamily.rawValue])
        self.supportedPlatforms = SupportedPlatformResolver.resolve(
            rawPlatforms: supportedPlatform ?? [],
            deviceFamilies: deviceFamily ?? [],
            requiresIPhoneOS: dictionary[CodingKeys.requiresIPhoneOS.rawValue] as? Bool ?? false,
            platformName: dictionary[CodingKeys.platformName.rawValue] as? String,
            sdkName: dictionary[CodingKeys.sdkName.rawValue] as? String,
            watchAppPresent: watchAppPresent
        )

        if let bundleIcons = dictionary[CodingKeys.bundleIcon.rawValue] as? [String: Any],
           let primaryIcon = bundleIcons[BundleIcon.CodingKeys.primaryIcon.rawValue] as? [String: Any],
           let iconFiles = primaryIcon[BundleIcon.PrimaryIcon.CodingKeys.iconFiles.rawValue] as? [String] {
            self.bundleIcon = iconFiles.first
        } else {
            self.bundleIcon = nil
        }

        if let urlTypes = dictionary[CodingKeys.redirectURL.rawValue] as? [[String: Any]],
           let firstURLType = urlTypes.first {
            self.redirectURL = (firstURLType[BundleURLTypes.CodingKeys.urlIdentifier.rawValue] as? String) ??
                               (firstURLType[BundleURLTypes.CodingKeys.urlScheme.rawValue] as? [String])?.first
        } else {
            self.redirectURL = nil
        }

        if let categoryString = dictionary[CodingKeys.appCategory.rawValue] as? String,
           let category = Bundle.ApplicationCategory(rawValue: categoryString) {
            self.appCategory = category
        } else {
            self.appCategory = .productivity
        }

        guard bundleIdentifier != nil || bundleName != nil else {
            return nil
        }
        self.id = bundleIdentifier ?? bundleName ?? ""
    }

    private static func deviceCapabilities(from container: KeyedDecodingContainer<CodingKeys>) -> [String]? {
        if let capabilities = try? container.decodeIfPresent([String].self, forKey: .requiredDeviceCompability) {
            return capabilities
        }
        if let capabilities = try? container.decodeIfPresent([String: Bool].self, forKey: .requiredDeviceCompability) {
            return capabilities.compactMap { key, isRequired in isRequired ? key : nil }.sorted()
        }
        return nil
    }

    private static func deviceCapabilities(from value: Any?) -> [String]? {
        if let capabilities = value as? [String] {
            return capabilities
        }
        if let capabilities = value as? [String: Bool] {
            return capabilities.compactMap { key, isRequired in isRequired ? key : nil }.sorted()
        }
        return nil
    }
}

fileprivate struct BundleIcon: Decodable {
    let primaryIcon: PrimaryIcon?

    enum CodingKeys: String, CodingKey {
        case primaryIcon = "CFBundlePrimaryIcon"
    }

    struct PrimaryIcon: Decodable {
        let iconFiles: [String]?

        enum CodingKeys: String, CodingKey {
            case iconFiles = "CFBundleIconFiles"
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.iconFiles = try container.decodeIfPresent([String].self, forKey: .iconFiles)
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryIcon = try container.decodeIfPresent(PrimaryIcon.self, forKey: .primaryIcon)
    }
}

fileprivate struct BundleURLTypes: Decodable {
    let urlIdentifier: String?
    let urlScheme: String?

    enum CodingKeys: String, CodingKey {
        case urlIdentifier = "CFBundleURLName"
        case urlScheme = "CFBundleURLSchemes"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.urlIdentifier = try container.decodeIfPresent(String.self, forKey: .urlIdentifier)
        let urlSchemes = try container.decodeIfPresent([String].self, forKey: .urlScheme)
        self.urlScheme = urlSchemes?.first
    }
}
