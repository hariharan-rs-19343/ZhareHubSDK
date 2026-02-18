//
//  UTType+.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 16/02/26.
//


import UniformTypeIdentifiers

public extension UTType {
    public static var ipa: UTType {
        let bundleIdentifier = Bundle.main.bundleIdentifier
        return UTType(bundleIdentifier!) ?? UTType(filenameExtension: "ipa")!
    }
    
    public static var app: UTType {
        let bundleIdentifier = "com.apple.application-file"
        return UTType(bundleIdentifier) ?? .application
    }
}
