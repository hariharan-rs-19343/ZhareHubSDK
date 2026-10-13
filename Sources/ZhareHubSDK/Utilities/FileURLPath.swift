//
//  FileURLPath.swift
//  ZhareHubSDK
//

import Foundation

enum FileURLPath {
    static func decoded(_ url: URL) -> String {
        url.path(percentEncoded: false)
    }

    static func fileExists(_ url: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: decoded(url))
    }
}
