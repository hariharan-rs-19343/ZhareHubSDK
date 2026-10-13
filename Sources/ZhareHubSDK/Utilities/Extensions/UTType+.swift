//
//  UTType+.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 16/02/26.
//


import UniformTypeIdentifiers

public extension UTType {
    static var ipa: UTType {
        UTType(filenameExtension: "ipa") ?? UTType(exportedAs: "com.apple.itunes.ipa")
    }

    static var app: UTType {
        let bundleIdentifier = "com.apple.application-file"
        return UTType(bundleIdentifier) ?? .application
    }
}
