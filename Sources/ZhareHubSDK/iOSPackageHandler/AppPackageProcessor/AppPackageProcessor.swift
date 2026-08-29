//
//  AppPackageProcessor.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import SUICore
import UniformTypeIdentifiers

public final class AppPackageProcessor: PackageProcessorProtocol {
    
    private let archiveOperations: ArchiveOperationsProtocol
    private let packageConversion: PackageConversionProtocol
    
    private var appCacheDirectory: URL {
        ZFFileManager.shared.appCacheDirectory
    }
    
    public init(archiveOperations: ArchiveOperationsProtocol = DefaultArchiveOperations(),
         packageConversion: PackageConversionProtocol = DefaultPackageConversion())
    {
        self.archiveOperations = archiveOperations
        self.packageConversion = packageConversion
    }
    
    public func processPackage(of sourceURL: URL) throws -> URL {
        /// Clear existing cache
        try ZFFileManager.shared.clearCache()
        
        guard let fileExtension = getPackageExtension(at: sourceURL) else {
            throw FileConversionError.unsupportedFile
        }
        
        switch fileExtension {
        case .ipa:
            let zipLocation = try packageConversion.prepareArchiveFormat(of: sourceURL) // Convert ipa file to zip file, then extract
            try archiveOperations.extractArchive(file: zipLocation, to: appCacheDirectory, overwrite: true, password: nil)
            return appCacheDirectory.appending(path: ZhareHubConstants.PAYLOAD) // Append Payload path in app cache directory
        case .zip:
            try archiveOperations.extractArchive(file: sourceURL, to: appCacheDirectory, overwrite: true, password: nil) // Extract zip file directly in app cache directory
            return appCacheDirectory
            
        case .app:
            /// .app bundle — copy into a Payload directory in cache
            return sourceURL
        default:
            throw FileConversionError.unsupportedFile
        }
    }
    
    private func getPackageExtension(at url: URL) -> UTType? {
        // Using the file extension
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }
        
        // Fallback: Using resource values
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = resourceValues.contentType {
            return type
        }
        
        return nil
    }
}
