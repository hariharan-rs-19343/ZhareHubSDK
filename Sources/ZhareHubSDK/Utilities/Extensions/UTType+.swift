//
//  UTType+.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 16/02/26.
//


import UniformTypeIdentifiers

public extension UTType {
    static var ipa: UTType {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        return UTType(bundleIdentifier!) ?? UTType(filenameExtension: "ipa")!
    }

    static var app: UTType {
        let bundleIdentifier = "com.apple.application-file"
        return UTType(bundleIdentifier) ?? .application
    }
}
