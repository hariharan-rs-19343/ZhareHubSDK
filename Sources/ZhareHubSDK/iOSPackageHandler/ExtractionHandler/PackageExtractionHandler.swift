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

    public func initiateAppExtraction(from url: URL, fileName: String) async -> Result<PackageExtractionModel, Error> {
        logger.info(category: .custom("iosParsing"), message: "Starting package extraction", metadata: ["fileName": fileName])
        let clock = ContinuousClock()
        let start = clock.now

        let needsScopedAccess = url.startAccessingSecurityScopedResource()

        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            guard let strategy = strategyResolver.resolve(for: url) else {
                throw FileConversionError.unsupportedFile
            }
            logger.debug(category: .custom("iosParsing"), message: "Resolved strategy \(type(of: strategy))")

            let payloadPath = try strategy.processPackage(sourceURL: url)
            let appDirectory = try resolveAppDirectory(from: payloadPath)
            let infoPlistData = try strategy.extractInfoPlistData(from: appDirectory)
            let mobileProvision = try strategy.extractMobileProvision(from: appDirectory)
            let appIcon: Data?
            do {
                appIcon = try await strategy.extractAppIcon(
                    from: appDirectory,
                    infoPlistData: infoPlistData,
                    parser: packageParseHandler,
                    fileName: fileName
                )
            } catch {
                appIcon = await strategy.generateDefaultAppIconData(fileName: fileName)
            }
            let appData = try strategy.prepareAppData(from: url)

            let model = PackageExtractionModel(
                fileName: fileName,
                appIcon: appIcon,
                app: appData,
                mobileProvision: mobileProvision,
                infoPropertyList: infoPlistData
            )

            let duration = (clock.now - start).secondsString
            logger.info(
                category: .custom("iosParsing"),
                message: "Package extraction succeeded",
                metadata: ["fileName": fileName, "durationSeconds": duration]
            )
            return .success(model)
        } catch {
            let duration = (clock.now - start).secondsString
            return .failure(writeLogsAndThrow(error: error, fileName: fileName, durationSeconds: duration))
        }
    }
    
    // MARK: - PRIVATE HELPER METHODS
    private func resolveAppDirectory(from payloadPath: URL) throws -> URL {
        if payloadPath.pathExtension.caseInsensitiveCompare(ZhareHubConstants.APP_FILE_EXTENSION) == .orderedSame {
            let contentsDir = payloadPath.appending(component: "Contents")
            if FileURLPath.fileExists(contentsDir, fileManager: fileManager) {
                return contentsDir
            }
            return payloadPath
        }

        guard FileURLPath.fileExists(payloadPath, fileManager: fileManager) else {
            throw FileConversionError.custom("Payload path does not exist")
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .isApplicationKey]
        let children = try fileManager.contentsOfDirectory(at: payloadPath, includingPropertiesForKeys: keys)
        if let appBundle = children.compactMap(matchAppBundle).first {
            return appBundle
        }

        guard let enumerator = fileManager.enumerator(
            at: payloadPath,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            throw FileConversionError.custom("Cannot enumerate payload directory")
        }

        for case let fileURL as URL in enumerator {
            if let appBundle = matchAppBundle(fileURL) {
                enumerator.skipDescendants()
                return appBundle
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
    
    private func writeLogsAndThrow(error: Error, fileName: String, durationSeconds: String) -> Error {
        logger.error(
            category: .custom("iosParsing"),
            message: "Package extraction failed",
            metadata: ["fileName": fileName, "error": error.localizedDescription, "durationSeconds": durationSeconds]
        )
        return error
    }
}
