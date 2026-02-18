//
//  PackageExtractionModel.swift
//  ZhareHub
//
//  Created by Hariharan R S on 10/12/24.
//

import Foundation

public struct PackageExtractionModel: Hashable {
    public let fileName: String?
    public let appIcon: Data?
    public let app: Data?
    public let mobileProvision: Data?
    public let infoPropertyList: Data?
    public var installationPList: Data?
    
    public var id: Self { return self }
    
    public init(fileName: String?, appIcon: Data?, app: Data?, mobileProvision: Data?, infoPropertyList: Data?, installationPList: Data? = nil) {
        self.fileName = fileName
        self.appIcon = appIcon
        self.app = app
        self.mobileProvision = mobileProvision
        self.infoPropertyList = infoPropertyList
        self.installationPList = installationPList
    }
}

public extension PackageExtractionModel {
    func hash(into hasher: inout Hasher) {
        fileName?.hash(into: &hasher)
    }
    
    func isContentAvailable() -> Bool {
        return (appIcon != nil) && (app != nil) && (mobileProvision != nil) && (infoPropertyList != nil) && (fileName != nil)
    }
}
