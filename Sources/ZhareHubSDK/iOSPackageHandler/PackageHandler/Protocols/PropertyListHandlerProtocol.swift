//
//  PropertyListHandlerProtocol.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

protocol PropertyListHandlerProtocol {
    func extractXMLDataFromMobileProvision(_ data: Data) -> Result<Data, Error>
    func deserializePlist(_ plistData: Data) -> Result<[String: Any]?, Error>
    func createPlistFile(url ipaURL: String, bundleIdentifier: String?, bundleVersion: String?, fileName: String?, content: [String: Any]?) -> Result<URL, Error>
    func createPlistDictionary(ipaURL: String, fileName: String, bundleIdentifier: String, bundleVersion: String) -> [String: Any]
}
