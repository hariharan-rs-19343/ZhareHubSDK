//
//  PackageExtractionProtocol.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import SUICore

/// Each package type implements this protocol with its own extraction logic.
/// Pattern: Strategy pattern
public protocol PackageExtractionProtocol {
    
    /// Whether this strategy can handle this given url
    func canHandle(url: URL) -> Bool
    
    /// Process the package and return the payload directory path
    func processPackage(sourceURL: URL) throws -> URL
   
    /// Read the app icon data from the extracted payload
    func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: PackageParserProtocol, fileName: String?) async throws -> Data?
    
    /// Read the Information property data from the extracted payload
    func extractInfoPlistData(from appDirectory: URL) throws -> Data
    
    /// Read the mobile provision data from the extracted payload
    func extractMobileProvision(from appDirectory: URL) throws -> Data?

    /// Convert the original file to uploadable Data (e.g., .app needs zipping first)
    func prepareAppData(from sourceURL: URL) throws -> Data?
    
}

public extension PackageExtractionProtocol {
    
    func extractInfoPlistData(from appDirectory: URL) throws -> Data {
        let plistURL = appDirectory.appending(component: ZhareHubConstants.INFO_PLIST)
        guard FileURLPath.fileExists(plistURL) else {
            throw FileConversionError.invalidFilePath
        }
        return try Data(contentsOf: plistURL)
    }
    
    func extractMobileProvision(from appDirectory: URL) throws -> Data? {
        let fileNames = [
            ZhareHubConstants.EMBEDDED_MOBILE_PROVISION,
            ZhareHubConstants.EMBEDDED_PROVISION_PROFILE
        ]
        for fileName in fileNames {
            let provisionURL = appDirectory.appending(component: fileName)
            if FileURLPath.fileExists(provisionURL) {
                return try Data(contentsOf: provisionURL)
            }
        }
        return nil
    }
    
    func readAppIconName(from infoPlistData: Data, parser: PackageParserProtocol) throws -> String {
        let result = parser.deserializePlist(infoPlistData)
        guard let dict = try result.get() else {
            throw FileConversionError.deserialiizationError
        }
        guard let props = parser.loadBundleProperties(with: dict) else {
            throw FileConversionError.custom("Failed to load bundle properties")
        }
        return props.bundleIcon ?? ZhareHubConstants.DEFAULT_ICON_NAME
    }
    
    func generateDefaultAppIconData(fileName: String?) async -> Data? {
        let name = fileName ?? ""
        let image = await MainActor.run {
            LetterAvatarView.renderImage(name)
        }
        return image?.pngData()
    }
}
