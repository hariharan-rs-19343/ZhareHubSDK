//
//  PackageUploadHandler.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

final class DefaultPackageParser: PackageParserProtocol {
    
    private let plistHandler: PropertyListHandlerProtocol
    
    init(plistHandler: PropertyListHandlerProtocol = DefaultPropertyListHandler()) {
        self.plistHandler = plistHandler
    }
    
    func extractXMLFromProvision(_ data: Data) -> Result<Data, Error> {
        return plistHandler.extractXMLDataFromMobileProvision(data)
    }
    
    func deserializePlist(_ plistData: Data) -> Result<[String: Any]?, Error> {
        return plistHandler.deserializePlist(plistData)
    }
    
    func loadBundleProperties(with plistDictionary: [String: Any]) -> BundleProperties? {
        return BundleProperties(from: plistDictionary)
    }
    
    func loadMobileProvision(with plist: [String: Any]) -> MobileProvision? {
        return MobileProvision(from: plist)
    }
    
    func generatePropertyList(fileURL: String, bundleId: String, bundleVersion: String, fileName: String) -> Data? {
        let result: Result<URL, Error> = plistHandler.createPlistFile(url: fileURL, bundleIdentifier: bundleId, bundleVersion: bundleVersion, fileName: fileName, content: nil)
        
        return try? Data(contentsOf: result.get())
    }
}
