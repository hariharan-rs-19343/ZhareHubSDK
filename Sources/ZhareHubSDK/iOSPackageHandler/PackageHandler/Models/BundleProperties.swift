//
//  BundleProperties.swift
//  ZhareHub
//
//  Created by Hariharan R S on 06/11/24.
//

import Foundation

struct BundleProperties: Decodable, Identifiable, Hashable {
    var id: String { bundleIdentifier ?? UUID().uuidString }
    let bundleName: String?
    let bundleVersionShort: String?
    let bundleVersion: String?
    let bundleIdentifier: String?
    let minimumOSVersion: String?
    let requiredDeviceCompability: [String]?
    let supportedPlatform: [String]?
    let bundleIcon: String?
    let redirectURL: String?
    let appCategory: Bundle.ApplicationCategory
    
    enum CodingKeys: String, CodingKey {
        case bundleName = "CFBundleName"
        case bundleVersionShort = "CFBundleShortVersionString"
        case bundleVersion = "CFBundleVersion"
        case bundleIdentifier = "CFBundleIdentifier"
        case minimumOSVersion = "MinimumOSVersion"
        case requiredDeviceCompability = "UIRequiredDeviceCapabilities"
        case supportedPlatform = "CFBundleSupportedPlatforms"
        case bundleIcon = "CFBundleIcons"
        case redirectURL = "CFBundleURLTypes"
        case appCategory = "LSApplicationCategoryType"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleName = try container.decodeIfPresent(String.self, forKey: .bundleName)
        self.bundleVersionShort = try container.decodeIfPresent(String.self, forKey: .bundleVersionShort)
        self.bundleVersion = try container.decodeIfPresent(String.self, forKey: .bundleVersion)
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        self.minimumOSVersion = try container.decodeIfPresent(String.self, forKey: .minimumOSVersion)
        self.requiredDeviceCompability = try container.decodeIfPresent([String].self, forKey: .requiredDeviceCompability)
        self.supportedPlatform = try container.decodeIfPresent([String].self, forKey: .supportedPlatform)
        self.bundleIcon = try container.decodeIfPresent(BundleIcon.self, forKey: .bundleIcon)?.primaryIcon?.iconFiles?.first
        
        // Redirect url decode from array
        self.redirectURL = try container.decodeIfPresent([BundleURLTypes].self, forKey: .redirectURL)?.first.flatMap {
            $0.urlIdentifier ?? $0.urlScheme
        }
        
        if let appCategory: String = try container.decodeIfPresent(String.self, forKey: .appCategory),
           let appCatagoryValue = Bundle.ApplicationCategory(rawValue: appCategory)
        {
            self.appCategory = appCatagoryValue
        }else {
            self.appCategory = .productivity
        }
    }
    
    init?(from dictionary: [String: Any]) {
        self.bundleName = dictionary["CFBundleName"] as? String
        self.bundleVersionShort = dictionary["CFBundleShortVersionString"] as? String
        self.bundleVersion = dictionary["CFBundleVersion"] as? String
        self.bundleIdentifier = dictionary["CFBundleIdentifier"] as? String
        self.minimumOSVersion = dictionary["MinimumOSVersion"] as? String
        self.requiredDeviceCompability = dictionary["UIRequiredDeviceCapabilities"] as? [String]
        self.supportedPlatform = dictionary["CFBundleSupportedPlatforms"] as? [String]
        
        // Extract bundle icon
        if let bundleIcons = dictionary["CFBundleIcons"] as? [String: Any],
           let primaryIcon = bundleIcons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
            self.bundleIcon = iconFiles.first
        } else {
            self.bundleIcon = nil
        }
        
        // Extract redirect URL
        if let urlTypes = dictionary["CFBundleURLTypes"] as? [[String: Any]],
           let firstURLType = urlTypes.first {
            self.redirectURL = (firstURLType["CFBundleURLName"] as? String) ??
                               (firstURLType["CFBundleURLSchemes"] as? [String])?.first
        } else {
            self.redirectURL = nil
        }
        
        // Extract app category
        if let categoryString = dictionary["LSApplicationCategoryType"] as? String,
           let category = Bundle.ApplicationCategory(rawValue: categoryString) {
            self.appCategory = category
        } else {
            self.appCategory = .productivity
        }
        
        // Ensure at least one essential property is present
        guard bundleIdentifier != nil || bundleName != nil else {
            return nil
        }
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
        
        let urlSchemes = try container.decode([String].self, forKey: .urlScheme)
        if let urlScheme = urlSchemes.first { self.urlScheme = urlScheme }
        else { self.urlScheme = nil }
    }
}

