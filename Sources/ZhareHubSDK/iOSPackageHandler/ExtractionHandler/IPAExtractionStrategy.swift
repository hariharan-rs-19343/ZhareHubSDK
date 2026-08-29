//
//  IPAExtractionStrategy.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 18/02/26.
//

import Foundation
import SUICore
import UniformTypeIdentifiers

public final class IPAExtractionStrategy: PackageExtractionProtocol {
    private let archiveOperations: ArchiveOperationsProtocol
    private let packageConversion: PackageConversionProtocol
    private let fileManager = FileManager.default
    
    private var appCacheDirectory: URL {
        ZFFileManager.shared.appCacheDirectory
    }
    
    init(archiveOperations: ArchiveOperationsProtocol = DefaultArchiveOperations(),
         packageConversion: PackageConversionProtocol = DefaultPackageConversion()) {
        self.archiveOperations = archiveOperations
        self.packageConversion = packageConversion
    }
    
    public func canHandle(url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension) == .ipa
    }
    
    public func processPackage(sourceURL: URL) throws -> URL {
        try ZFFileManager.shared.clearCache()
        let zipLocation = try packageConversion.prepareArchiveFormat(of: sourceURL)
        try archiveOperations.extractArchive(file: zipLocation, to: appCacheDirectory, overwrite: true, password: nil)
        return appCacheDirectory.appending(path: ZHConstants.PAYLOAD)
    }
    
    public func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: any PackageParserProtocol, fileName: String?) throws -> Data? {
        let iconName = try readAppIconName(from: infoPlistData, parser: parser)
        return try readAppIconData(from: appDirectory, iconName: iconName, fileName: fileName)
    }
    
    public func readAppIconData(from appDirectory: URL, iconName: String, fileName: String?) throws -> Data? {
        let dirPath = appDirectory.path().removingPercentEncoding ?? appDirectory.path()
        
        guard let iconSubPath = try? FileManager.default.contentsOfDirectory(atPath: dirPath)
            .first(where: { $0.contains(iconName) })
        else {
            return generateDefaultAppIconData(fileName: fileName)
        }
        
        let iconFullPath = appDirectory.appending(component: iconSubPath).path()
        let cleanPath = iconFullPath.removingPercentEncoding ?? iconFullPath
        
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            return generateDefaultAppIconData(fileName: fileName)
        }
        
        return try Data(contentsOf: URL(filePath: cleanPath))
    }
    
    public func prepareAppData(from sourceURL: URL) throws -> Data? {
        return try Data(contentsOf: sourceURL)
    }
}
