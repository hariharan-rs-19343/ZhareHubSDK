//
//  DefaultPackageConversion.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import SUICore

public final class DefaultPackageConversion: PackageConversionProtocol {
    
    public init() {}
    
    private var appCacheDirector: URL {
        ZFFileManager.shared.appCacheDirectory
    }
    
    public func prepareArchiveFormat(of sourceURL: URL) throws -> URL {
        let destinationURL = replaceExtensionNameWithZip(of: sourceURL)
        try ZFFileManager.shared.copyFile(from: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    // MARK: - HELPER METHODS
    private func replaceExtensionNameWithZip(of url: URL) -> URL {
        let fileName = url.deletingPathExtension().lastPathComponent
        return appCacheDirector.appendingPathComponent(fileName, conformingTo: .zip)
    }
}
