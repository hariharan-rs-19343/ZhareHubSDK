//
//  APKBundleProperties.swift
//  ZhareHubSDK
//
//  Android counterpart of `BundleProperties` — parsed metadata from
//  `aapt2 dump badging` output.
//

import Foundation

public struct APKBundleProperties: Hashable, Sendable {
    /// Source filename of the APK (e.g. `"MyApp_security_fix.apk"`). Not the package name. Can be localized.
    public let appName: String
    /// Human-readable application label from `application-label` (e.g. `"MyApp"`). May be localized.
    public let packageName: String
    /// Reverse-DNS package identifier from `package: name` (e.g. `"com.example.myapp"`). Globally unique.
    public let packageIdentifier: String
    public let versionName: String
    public let versionCode: String
    public let minSDK: String
    public let targetSDK: String
    public let deviceCompatibility: [String]
    public let permissions: [String]
    public let usesFeatures: [String]

    public init(
        appName: String,
        packageName: String,
        packageIdentifier: String,
        versionName: String,
        versionCode: String,
        minSDK: String,
        targetSDK: String,
        deviceCompatibility: [String],
        permissions: [String],
        usesFeatures: [String]
    ) {
        self.appName = appName
        self.packageName = packageName
        self.packageIdentifier = packageIdentifier
        self.versionName = versionName
        self.versionCode = versionCode
        self.minSDK = minSDK
        self.targetSDK = targetSDK
        self.deviceCompatibility = deviceCompatibility
        self.permissions = permissions
        self.usesFeatures = usesFeatures
    }
}
