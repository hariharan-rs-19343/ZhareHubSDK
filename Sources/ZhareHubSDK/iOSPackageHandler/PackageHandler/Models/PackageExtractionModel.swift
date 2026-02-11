//
//  PackageExtractionModel.swift
//  ZhareHub
//
//  Created by Hariharan R S on 10/12/24.
//

import Foundation

struct PackageExtractionModel: Hashable {
    let fileName: String?
    let appIcon: Data?
    let app: Data?
    let mobileProvision: Data?
    let infoPropertyList: Data?
    var installationPList: Data?
    
    var id: Self { return self }
}

extension PackageExtractionModel {
    func hash(into hasher: inout Hasher) {
        fileName?.hash(into: &hasher)
    }
    
    func isContentAvailable() -> Bool {
        return (appIcon != nil) && (app != nil) && (mobileProvision != nil) && (infoPropertyList != nil) && (fileName != nil)
    }
}
