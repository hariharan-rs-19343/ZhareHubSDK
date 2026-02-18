//
//  PackageExtractionHandler.swift
//  ZhareHub
//
//  Created by Hariharan R S on 15/11/24.
//

import SwiftUI
import SUICore

public final class PackageExtractionHandler: PackageExtractionProtocol {
    
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
    
    public init(
        appPackageProcessor: PackageProcessorProtocol = AppPackageProcessor(),
        parser packageParseHandler: PackageParserProtocol = DefaultPackageParser()
    ) {
        self.appPackageProcessor = appPackageProcessor
        self.packageParseHandler = packageParseHandler
    }
    
    public func initiateAppExtraction(from url: URL, fileName: String) -> Result<PackageExtractionModel, Error> {
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
            
            let payloadPath: URL = try appPackageProcessor.processPackage(of: url)
            
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

        ZOSLogs.shared.info("APP PATH DIRECTORY: \(appPathDirectory)")
        
        // Info.plist
        fileTypeWithDataMapper[.infoPlist] = try convertFileAsData(at: getSourcePath(of: .infoPlist, from: appPathDirectory), type: .infoPlist)
        
        // embedded.plist
        if let mobileProvision = try? convertFileAsData(at: getSourcePath(of: .mobileprovision, from: appPathDirectory), type: .mobileprovision) {
            fileTypeWithDataMapper[.mobileprovision] = mobileProvision
        }
        if let provisionalProfile = try? convertFileAsData(at: getSourcePath(of: .provisionProfile, from: appPathDirectory), type: .provisionProfile) {
            fileTypeWithDataMapper[.mobileprovision] = provisionalProfile
        }
        
        // Read app icon name from Info.plist
        let appIconFileName = try readAppIconFileNameFromInfoPlist()
        
        // AppIcon
        try createAppIconAsData(at: appPathDirectory, iconName: appIconFileName)
        
        return getPackageExtractionModel()
    }
    
    private func doesPayloadPathExist(at path: URL) -> Bool {
        return fileManager.fileExists(atPath: path.path(percentEncoded: false))
    }
    
    private func getAppDirectoryPath(from payloadPath: URL) -> URL? {
        // Safe check: current payload path is .app url
        if let appURL = matchAppBundle(payloadPath) {
            return appURL.appending(component: "Contents")
        }
        
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey]
        guard let subPaths = try? fileManager.enumerator(
            at: payloadPath,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        for case let fileURL as URL in subPaths {
            if let appURL = matchAppBundle(fileURL) {
                subPaths.skipDescendants()
                return appURL
            }
        }
        
        return nil
    }
    
    /// Checks whether the given URL is an `.app` bundle and returns it if so.
    /// If the URL is a package, the enumerator skips its descendants.
    private func matchAppBundle(_ fileURL: URL) -> URL? {
        guard fileURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
            return nil
        }
        
        if let values = try? fileURL.resourceValues(forKeys: [.isPackageKey, .isApplicationKey]), (values.isPackage == true || values.isApplication == true) {
            return fileURL
        }
        
        return nil
    }
    
    private func convertFileAsData(at path: String, type: SupportedFileTypes) throws -> Data {
        // Check file exist in path and convert file into data
        guard fileManager.fileExists(atPath: path) else {
            throw writeLogsAndThrow(error: type.getError)
        }
        
        return try fileToData(from: URL(filePath: path))
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
                let provisionPath = payloadPath.appending(component: ZHConstants.EMBEDDED_MOBILE_PROVISION).path()
                return provisionPath.removingPercentEncoding ?? provisionPath
            case .infoPlist:
                let plistPath = payloadPath.appending(component: ZHConstants.INFO_PLIST).path()
                return plistPath.removingPercentEncoding ?? plistPath
            case .icon:
                let iconPath = payloadPath.appending(component: appIconName).path()
                return iconPath.removingPercentEncoding ?? iconPath
            case .provisionProfile:
                let provisionPath = payloadPath.appending(component: ZHConstants.EMBEDDED_PROVISION_PROFILE).path()
                return provisionPath.removingPercentEncoding ?? provisionPath
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
