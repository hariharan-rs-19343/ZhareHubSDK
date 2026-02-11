//
//  PackageExtractionHandler.swift
//  ZhareHub
//
//  Created by Hariharan R S on 15/11/24.
//

import SwiftUI
import SUICore

final class PackageExtractionHandler: PackageExtractionProtocol {
    
    // Dependencies
    private let appPackageProcessor: PackageProcessorProtocol
    private let packageParseHandler: PackageParserProtocol
    
    // State
    private var sourceURL: URL!
    private var fileName: String!
    private var fileTypeWithDataMapper: [SupportedFileTypes: Data] = [:]
    
    // FileManager
    private let fileManager = FileManager.default
    private let appCacheDirectory: URL = ZFFileManager.shared.appCacheDirectory
    
    init(
        appPackageProcessor: PackageProcessorProtocol = AppPackageProcessor(),
        parser packageParseHandler: PackageParserProtocol = DefaultPackageParser()
    ) {
        self.appPackageProcessor = appPackageProcessor
        self.packageParseHandler = packageParseHandler
    }
    
    func initiateAppExtraction(from url: URL, fileName: String) -> Result<PackageExtractionModel, Error> {
        self.sourceURL = url
        self.fileName = fileName
        
        // Check if the URL is a security-scoped resource
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Process the package contents for extraction
        do {
            // Convert package file into data
            fileTypeWithDataMapper[.app] = try fileToData(from: url)
            
            let payloadPath = try appPackageProcessor.processPackage(of: url)
            
            let packageModel: PackageExtractionModel = try processAppBundle(path: payloadPath)
            
            return .success(packageModel)
        }catch {
            fileTypeWithDataMapper.removeAll()
            return .failure(error)
        }
    }
    
    // MARK: - PRIVATE HELPER METHODS
    private func processAppBundle(path payLoadPath: URL) throws -> PackageExtractionModel {
        
        guard doesPayloadPathExist(at: payLoadPath) else {
            throw writeLogsAndThrow(error: .custom("App bundle does not exist at path"))
        }
        
        guard let appPathDirectory: URL = getAppDirectoryPath(from: payLoadPath) else {
            throw writeLogsAndThrow(error: .custom("App directory does not exist at path"))
        }

        ZOSLogs.shared.warning("APP PATH DIRECTORY: \(appPathDirectory)")
        
        // Info.plist
        try convertInfoPlistFileAsData(at: getSourcePath(of: .infoPlist, from: appPathDirectory))
        
        // embedded.plist
        try convertMobileProvisionFileAsData(at: getSourcePath(of: .mobileprovision, from: appPathDirectory))
        
        // Read app icon name from Info.plist
        let appIconFileName = try readAppIconFileNameFromInfoPlist()
        
        // AppIcon
        try createAppIconAsData(at: appPathDirectory, iconName: appIconFileName)
        
        return getPackageExtractionModel()
    }
    
    private func doesPayloadPathExist(at path: URL) -> Bool {
        return fileManager.fileExists(atPath: path.path())
    }
    
    private func getAppDirectoryPath(from payloadPath: URL) -> URL? {
        guard let subPaths = try? fileManager.contentsOfDirectory(
            at: payloadPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        let appDirectory: URL? = try? subPaths.filter { url in
            let resourceValue = try url.resourceValues(forKeys: [.isDirectoryKey])
            return resourceValue.isDirectory == true && url.pathExtension == "app"
        }.first
        
        return appDirectory
    }
    
    private func convertInfoPlistFileAsData(at path: String) throws {
        // Check file exist in path and convert file into data
        guard fileManager.fileExists(atPath: path) else {
            throw writeLogsAndThrow(error: .infoPlistNotFoundInPayload)
        }
        
        fileTypeWithDataMapper[.infoPlist] = try fileToData(from: URL(fileURLWithPath: path))
    }
    
    private func readAppIconFileNameFromInfoPlist() throws -> String {
        guard let infoPlistData = fileTypeWithDataMapper[.infoPlist] else {
            throw writeLogsAndThrow(error: .infoPlistNotFoundInPayload)
        }
        
        let decodedInfoPlistResult = packageParseHandler.deserializePlist(infoPlistData)
        
        guard let deocdedInfoPlistDic = try decodedInfoPlistResult.get() else {
            throw writeLogsAndThrow(error: .deserialiizationError)
        }
        
        guard let bundleProperties: BundleProperties = packageParseHandler.loadBundleProperties(with: deocdedInfoPlistDic) else {
            throw writeLogsAndThrow(error: .custom("JSON Parsing error while loading bundle properties"))
        }
        
        return bundleProperties.bundleIcon ?? "AppIcon"
    }
    
    private func convertMobileProvisionFileAsData(at path: String) throws {
        // Check file exist in path and convert file into data
        guard fileManager.fileExists(atPath: path) else {
            throw writeLogsAndThrow(error: .provisioningProfileNotFoundInPayload)
        }
        
        // Read the file content
        fileTypeWithDataMapper[.mobileprovision] = try fileToData(from: URL(fileURLWithPath: path))
    }
    
    private func createAppIconAsData(at payloadPath: URL, iconName appIconFileName: String) throws {
        // Get subpath of the appIcon file
        let filePath: String = payloadPath.path().removingPercentEncoding ?? payloadPath.path()
        guard let appIconSubPath = try fileManager.contentsOfDirectory(atPath: filePath)
            .first(where: { $0.contains(appIconFileName) })
        else {
            fileTypeWithDataMapper[.icon] = generateDefaultAppIconData()
            return
        }
        
        // Read App Icon
        let appIconPath = getSourcePath(of: .icon, from: payloadPath, appIconName: appIconSubPath)
        
        // Check file exist in path and convert file into data
        guard fileManager.fileExists(atPath: appIconPath) else {
            ZOSLogs.shared.warning(FileConversionError.appIconNotFoundInPayload.localizedDescription)
            fileTypeWithDataMapper[.icon] = generateDefaultAppIconData()
            return
        }
        
        fileTypeWithDataMapper[.icon] = try fileToData(from: URL(filePath: appIconPath))
    }
    
    private func generateDefaultAppIconData() -> Data? {
        let name = fileName ?? ""
        let uiImage: UIImage? = MainActor.assumeIsolated {
            LetterAvatar(name: name).image
        }
        return uiImage?.pngData()
    }
    
    private func getSourcePath(of fileType: SupportedFileTypes, from payloadPath: URL, appIconName: String = "") -> String {
        switch fileType {
            case .mobileprovision:
                let provisionPath = payloadPath.appending(component: ZHConstants.EMBEDDED_PROVISION).path()
                return provisionPath.removingPercentEncoding ?? provisionPath
            case .infoPlist:
                let plistPath = payloadPath.appending(component: ZHConstants.INFO_PLIST).path()
                return plistPath.removingPercentEncoding ?? plistPath
            case .icon:
                let iconPath = payloadPath.appending(component: appIconName).path()
                return iconPath.removingPercentEncoding ?? iconPath
            default:
                return ""
        }
    }
    
    // MARK: - Convert source as data
    private func fileToData(from url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    private func getPackageExtractionModel() -> PackageExtractionModel {
        PackageExtractionModel(fileName: fileName,
                               appIcon: fileTypeWithDataMapper[.icon],
                               app: fileTypeWithDataMapper[.app],
                               mobileProvision: fileTypeWithDataMapper[.mobileprovision],
                               infoPropertyList: fileTypeWithDataMapper[.infoPlist],
                               installationPList: fileTypeWithDataMapper[.installationPlist])
    }
    
    private func writeLogsAndThrow(error: FileConversionError) -> FileConversionError {
        ZOSLogs.shared.error(error.localizedDescription)
        return error
    }
}
