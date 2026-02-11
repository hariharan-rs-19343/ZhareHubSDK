//
//  AppPackageProcessor.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import SUICore

final class AppPackageProcessor: PackageProcessorProtocol {
    
    private let archiveOperations: ArchiveOperationsProtocol
    private let packageConversion: PackageConversionProtocol
    
    private var appCacheDirectory: URL {
        ZFFileManager.shared.appCacheDirectory
    }
    
    init(archiveOperations: ArchiveOperationsProtocol = DefaultArchiveOperations(),
         packageConversion: PackageConversionProtocol = DefaultPackageConversion())
    {
        self.archiveOperations = archiveOperations
        self.packageConversion = packageConversion
    }
    
    func processPackage(of sourceURL: URL) throws -> URL {
        // Clear existing cache
        try ZFFileManager.shared.clearCache()
        
        // Convert ipa file to zip file
        let zipLocation = try packageConversion.prepareArchiveFormat(of: sourceURL)
        
        // Extract zip file in app cache directory
        try archiveOperations.extractArchive(file: zipLocation, to: appCacheDirectory, overwrite: true, password: nil)
        
        // append payload in appcache directory
        return appCacheDirectory.appending(path: ZHConstants.PAYLOAD)
    }
}
