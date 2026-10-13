//
//  AppPackageProcessor.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import UniformTypeIdentifiers

public final class AppPackageProcessor: PackageProcessorProtocol {
    
    private let archiveOperations: ArchiveOperationsProtocol
    
    public init(archiveOperations: ArchiveOperationsProtocol = DefaultArchiveOperations(),
         packageConversion: PackageConversionProtocol = DefaultPackageConversion())
    {
        self.archiveOperations = archiveOperations
        _ = packageConversion
    }
    
    public func processPackage(of sourceURL: URL) throws -> URL {
        guard let fileExtension = getPackageExtension(at: sourceURL) else {
            throw FileConversionError.unsupportedFile
        }

        switch fileExtension {
        case .ipa:
            let workspace = try ExtractionWorkspace.make()
            let archiveName = ExtractionWorkspace.singlePathComponent(sourceURL.deletingPathExtension().lastPathComponent) ?? "package"
            let zipLocation = workspace.appending(component: archiveName).appendingPathExtension("zip")
            try FileManager.default.copyItem(at: sourceURL, to: zipLocation)
            try archiveOperations.extractArchive(file: zipLocation, to: workspace, overwrite: true, password: nil)
            return workspace.appending(component: ZhareHubConstants.PAYLOAD)
        case .zip:
            let workspace = try ExtractionWorkspace.make()
            try archiveOperations.extractArchive(file: sourceURL, to: workspace, overwrite: true, password: nil)
            return workspace
        case .app:
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
