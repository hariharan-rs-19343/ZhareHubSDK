//
//  APPExtractionStrategy.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 18/02/26.
//

import Foundation
import SUICore
import UniformTypeIdentifiers
internal import Zip

public final class APPExtractionStrategy: PackageExtractionProtocol {
    private let fileManager = FileManager.default
    
    private var appCacheDirectory: URL {
        ZFFileManager.shared.appCacheDirectory
    }
    
    public init() {}
    
    public func canHandle(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type == .app || type == .application
    }
    
    public func processPackage(sourceURL: URL) throws -> URL {
        try ZFFileManager.shared.clearCache()
        return sourceURL // .app bundle — return the URL directly, no extraction needed
    }
    
    public func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: any PackageParserProtocol, fileName: String?) throws -> Data? {
        // .app bundles may store icons differently (e.g., in Assets.car or as .icns on macOS)
        // First try the standard approach
        if let iconData = try? standardIconExtraction(from: appDirectory, infoPlistData: infoPlistData, parser: parser, fileName: fileName) {
            return iconData
        }
        
        // Fallback: look for .icns files (macCatalyst / macOS .app bundles)
        let resourcesDir = appDirectory.appending(component: "Resources")
        if fileManager.fileExists(atPath: resourcesDir.path()) {
            let resourceContents = try fileManager.contentsOfDirectory(atPath: resourcesDir.path())
            if let icnsFile = resourceContents.first(where: { $0.hasSuffix(".icns") }) {
                let icnsPath = resourcesDir.appending(component: icnsFile)
                return try Data(contentsOf: icnsPath)
            }
        }
       
        // Final fallback: generate default
        return generateDefaultAppIconData(fileName: fileName)
    }
    
    public func extractMobileProvision(from appDirectory: URL) throws -> Data? {
        // .app bundles on macOS use embedded.provisionprofile (not .mobileprovision)
        let provisionProfilePath = appDirectory.appending(component: ZHConstants.EMBEDDED_PROVISION_PROFILE).path()
        let cleanPath = provisionProfilePath.removingPercentEncoding ?? provisionProfilePath
        if fileManager.fileExists(atPath: cleanPath) {
            return try Data(contentsOf: URL(filePath: cleanPath))
        }
        
        return nil
    }
    
    public func prepareAppData(from sourceURL: URL) throws -> Data? {
        // .app needs to be zipped first before it can be uploaded as data
        let zipDestination = appCacheDirectory
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(for: .zip)
        
        try Zip.zipFiles(paths: [sourceURL], zipFilePath: zipDestination, password: nil, progress: nil)
        return try Data(contentsOf: zipDestination)
    }
}

// MARK: - Private Helpers
extension APPExtractionStrategy {
    
    private func standardIconExtraction(from appDirectory: URL, infoPlistData: Data, parser: PackageParserProtocol, fileName: String?) throws -> Data? {
        let result = parser.deserializePlist(infoPlistData)
        guard let dict = try result.get(),
              let props = parser.loadBundleProperties(with: dict),
              let iconName = props.bundleIcon
        else {
            return nil
        }
        
        let dirPath = appDirectory.path().removingPercentEncoding ?? appDirectory.path()
        guard let iconSubPath = try fileManager.contentsOfDirectory(atPath: dirPath)
            .first(where: { $0.contains(iconName) })
        else {
            return nil
        }
        
        let iconPath = appDirectory.appending(component: iconSubPath).path()
        let cleanPath = iconPath.removingPercentEncoding ?? iconPath
        guard fileManager.fileExists(atPath: cleanPath) else { return nil }
        return try Data(contentsOf: URL(filePath: cleanPath))
    }
}
