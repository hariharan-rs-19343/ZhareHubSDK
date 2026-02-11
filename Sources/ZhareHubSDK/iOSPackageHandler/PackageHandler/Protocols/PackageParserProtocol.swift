//
//  PackageUploadProtocol.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation


protocol PackageParserProtocol {
    func extractXMLFromProvision(_ data: Data) -> Result<Data, Error>
    func deserializePlist(_ plistData: Data) -> Result<[String: Any]?, Error>
    func loadBundleProperties(with plistDictionary: [String: Any]) -> BundleProperties?
    func loadMobileProvision(with plist: [String: Any]) -> MobileProvision?
    func generatePropertyList(fileURL: String, bundleId: String, bundleVersion: String, fileName: String) -> Data?
}
