//
//  PackageExtractionHandler.swift
//  ZhareHub
//
//  Created by Hariharan R S on 15/11/24.
//

import SwiftUI
import SUICore

public final class PackageExtractionHandler {

    // Dependencies
    private let strategyResolver: PackageExtractionStrategyResolver
    private let packageParseHandler: PackageParserProtocol
    private let logger: ZHLoggerProtocol

    // State
    private var sourceURL: URL!
    private var fileName: String!

    // FileManager
    private let fileManager = FileManager.default

    public init(
        resolver: PackageExtractionStrategyResolver = PackageExtractionStrategyResolver(),
        parser packageParseHandler: PackageParserProtocol = DefaultPackageParser(),
        logger: ZHLoggerProtocol = ZHDefaultLogger(subsystem: "com.zharehub.sdk")
    ) {
        self.strategyResolver = resolver
        self.packageParseHandler = packageParseHandler
        self.logger = logger
    }

    public func initiateAppExtraction(from url: URL, fileName: String) -> Result<PackageExtractionModel, Error> {
        self.sourceURL = url
        self.fileName = fileName

        logger.log(level: .info, category: .custom("iosParsing"), message: "Starting package extraction", metadata: ["fileName": fileName])
        let clock = ContinuousClock()
        let start = clock.now

        // Check if the URL is a security-scoped resource
        let needsScopedAccess = url.startAccessingSecurityScopedResource()

        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Process the package contents for extraction
        do {
            guard let strategy = strategyResolver.resolve(for: url) else {
                throw FileConversionError.unsupportedFile
            }
            logger.log(level: .debug, category: .custom("iosParsing"), message: "Resolved strategy \(type(of: strategy))")

            // 1. Process the package (extract/prepare payload directory)
            let payloadPath = try strategy.processPackage(sourceURL: url)

            // 2. Find the .app directory
            guard let appDirectory = try resolveAppDirectory(from: payloadPath) else {
                throw FileConversionError.custom("Failed to find the .app directory.")
            }

            // 3. Read Info.plist
            let infoPlistData = try strategy.extractInfoPlistData(from: appDirectory)

            // 4. Extract mobile provision (strategy-specific)
            let mobileProvision = try strategy.extractMobileProvision(from: appDirectory)

            // 5. Extract app icon (strategy-specific)
            let appIcon = try strategy.extractAppIcon(
                from: appDirectory,
                infoPlistData: infoPlistData,
                parser: packageParseHandler,
                fileName: fileName
            )

            // 6. Prepare app data for upload (strategy-specific, e.g., .app zips first)
            let appData = try strategy.prepareAppData(from: url)

            let model = PackageExtractionModel(
                fileName: fileName,
                appIcon: appIcon,
                app: appData,
                mobileProvision: mobileProvision,
                infoPropertyList: infoPlistData
            )

            let duration = (clock.now - start).secondsString
            logger.log(
                level: .info,
                category: .custom("iosParsing"),
                message: "Package extraction succeeded",
                metadata: ["fileName": fileName, "durationSeconds": duration]
            )
            return .success(model)
        } catch {
            let duration = (clock.now - start).secondsString
            return .failure(writeLogsAndThrow(error: error, durationSeconds: duration))
        }
    }
    
    // MARK: - PRIVATE HELPER METHODS
    private func resolveAppDirectory(from payloadPath: URL) throws -> URL? {
        // Check if payloadPath itself is an .app bundle
        if payloadPath.pathExtension.caseInsensitiveCompare(ZhareHubConstants.APP_FILE_EXTENSION) == .orderedSame {
            // macCatalyst .app bundles have Contents/ subdirectory
            let contentsDir = payloadPath.appending(component: "Contents")
            if fileManager.fileExists(atPath: contentsDir.path()) {
                return contentsDir
            }
            return payloadPath
        }
        
        // Search for .app directory inside payload
        guard fileManager.fileExists(atPath: payloadPath.path(percentEncoded: false)) else {
            throw FileConversionError.custom("Payload path does not exist")
        }
        
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey]
        guard let enumerator = fileManager.enumerator(
            at: payloadPath,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            throw FileConversionError.custom("Cannot enumerate payload directory")
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.caseInsensitiveCompare(ZhareHubConstants.APP_FILE_EXTENSION) == .orderedSame {
                enumerator.skipDescendants()
                return fileURL
            }
        }
        
        throw FileConversionError.custom("No .app bundle found in payload")
    }
    
    /// Checks whether the given URL is an `.app` bundle and returns it if so.
    /// If the URL is a package, the enumerator skips its descendants.
    private func matchAppBundle(_ fileURL: URL) -> URL? {
        guard fileURL.pathExtension.caseInsensitiveCompare(ZhareHubConstants.APP_FILE_EXTENSION) == .orderedSame else {
            return nil
        }
        
        if let values = try? fileURL.resourceValues(forKeys: [.isPackageKey, .isApplicationKey]), (values.isPackage == true || values.isApplication == true) {
            return fileURL
        }
        
        return nil
    }
    
    private func writeLogsAndThrow(error: Error, durationSeconds: String) -> Error {
        logger.log(
            level: .error,
            category: .custom("iosParsing"),
            message: "Package extraction failed",
            metadata: ["fileName": fileName ?? "", "error": error.localizedDescription, "durationSeconds": durationSeconds]
        )
        return error
    }
}
