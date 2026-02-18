//
//  PackageExtractionProtocol.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import UIKit
import SUICore

/// Each package type implements this protocol with its own extraction logic.
/// Pattern: Strategy pattern
public protocol PackageExtractionProtocol {
    
    /// Whether this strategy can handle this given url
    func canHandle(url: URL) -> Bool
    
    /// Process the package and return the payload directory path
    func processPackage(sourceURL: URL) throws -> URL
   
    /// Read the app icon data from the extracted payload
    func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: PackageParserProtocol, fileName: String?) throws -> Data?
    
    /// Read the Information property data from the extracted payload
    func extractInfoPlistData(from appDirectory: URL) throws -> Data
    
    /// Read the mobile provision data from the extracted payload
    func extractMobileProvision(from appDirectory: URL) throws -> Data?

    /// Convert the original file to uploadable Data (e.g., .app needs zipping first)
    func prepareAppData(from sourceURL: URL) throws -> Data?
    
}

public extension PackageExtractionProtocol {
    
    func extractInfoPlistData(from appDirectory: URL) throws -> Data {
        let plistPath = appDirectory.appending(component: ZHConstants.INFO_PLIST).path()
        let cleanPath = plistPath.removingPercentEncoding ?? plistPath
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            throw FileConversionError.invalidFilePath
        }
        return try Data(contentsOf: URL(filePath: cleanPath))
    }
    
    func extractMobileProvision(from appDirectory: URL) throws -> Data? {
        let provisionPath = appDirectory.appending(component: ZHConstants.EMBEDDED_MOBILE_PROVISION).path()
        let cleanPath = provisionPath.removingPercentEncoding ?? provisionPath
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            return nil
        }
        return try Data(contentsOf: URL(filePath: cleanPath))
    }
    
    func readAppIconName(from infoPlistData: Data, parser: PackageParserProtocol) throws -> String {
        let result = parser.deserializePlist(infoPlistData)
        guard let dict = try result.get() else {
            throw FileConversionError.deserialiizationError
        }
        guard let props = parser.loadBundleProperties(with: dict) else {
            throw FileConversionError.custom("Failed to load bundle properties")
        }
        return props.bundleIcon ?? "AppIcon"
    }
    
    func generateDefaultAppIconData(fileName: String?) -> Data? {
        let name = fileName ?? ""
        let uiImage: UIImage? = MainActor.assumeIsolated {
            LetterAvatar(name: name).image
        }
        return uiImage?.pngData()
    }
}
