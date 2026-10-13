//
//  APPExtractionStrategy.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 18/02/26.
//

import Foundation
import UniformTypeIdentifiers
internal import ZIPFoundation

public final class APPExtractionStrategy: PackageExtractionProtocol {
    private let fileManager = FileManager.default

    public init() {}

    public func canHandle(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type == .app || type == .application
    }

    public func processPackage(sourceURL: URL) throws -> URL {
        sourceURL
    }

    public func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: any PackageParserProtocol, fileName: String?) async throws -> Data? {
        if let iconData = try? await standardIconExtraction(from: appDirectory, infoPlistData: infoPlistData, parser: parser) {
            return iconData
        }

        let resourcesDir = appDirectory.appending(component: "Resources")
        if FileURLPath.fileExists(resourcesDir, fileManager: fileManager) {
            let resourceContents = try fileManager.contentsOfDirectory(atPath: FileURLPath.decoded(resourcesDir))
            if let icnsFile = resourceContents.first(where: { $0.hasSuffix(".icns") }) {
                return try Data(contentsOf: resourcesDir.appending(component: icnsFile))
            }
        }

        return await generateDefaultAppIconData(fileName: fileName)
    }

    public func extractMobileProvision(from appDirectory: URL) throws -> Data? {
        try PackageExtractionFallback.mobileProvision(in: appDirectory)
    }

    public func prepareAppData(from sourceURL: URL) throws -> Data? {
        let workspace = try ExtractionWorkspace.make()
        let archiveName = ExtractionWorkspace.singlePathComponent(sourceURL.deletingPathExtension().lastPathComponent) ?? "application"
        let zipDestination = workspace.appending(component: archiveName).appendingPathExtension("zip")
        try Self.zipBundle(at: sourceURL, to: zipDestination)
        return try ExtractionWorkspace.readBounded(contentsOf: zipDestination)
    }

    private static func zipBundle(at sourceURL: URL, to destination: URL) throws {
        let root = sourceURL.standardizedFileURL
        let archive = try Archive(url: destination, accessMode: .create)
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw FileConversionError.fileReadFailed
        }

        let rootPath = FileURLPath.decoded(root)
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            let standardized = fileURL.standardizedFileURL
            let standardizedPath = FileURLPath.decoded(standardized)
            guard standardizedPath == rootPath || standardizedPath.hasPrefix(rootPath + "/") else {
                enumerator.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }
            let relativePath = String(standardizedPath.dropFirst(rootPath.count + 1))
            try archive.addEntry(with: relativePath, fileURL: standardized)
        }
    }
}

private enum PackageExtractionFallback {
    static func mobileProvision(in appDirectory: URL) throws -> Data? {
        let fileNames = [
            ZhareHubConstants.EMBEDDED_MOBILE_PROVISION,
            ZhareHubConstants.EMBEDDED_PROVISION_PROFILE
        ]
        for fileName in fileNames {
            let provisionURL = appDirectory.appending(component: fileName)
            if FileURLPath.fileExists(provisionURL) {
                return try Data(contentsOf: provisionURL)
            }
        }
        return nil
    }
}

extension APPExtractionStrategy {
    private func standardIconExtraction(from appDirectory: URL, infoPlistData: Data, parser: PackageParserProtocol) async throws -> Data? {
        let result = parser.deserializePlist(infoPlistData)
        guard let dict = try result.get(),
              let props = parser.loadBundleProperties(with: dict, in: appDirectory),
              let iconName = props.bundleIcon
        else {
            return nil
        }

        guard let iconSubPath = try fileManager.contentsOfDirectory(atPath: FileURLPath.decoded(appDirectory))
            .first(where: { $0.contains(iconName) })
        else {
            return nil
        }

        let iconURL = appDirectory.appending(component: iconSubPath)
        guard FileURLPath.fileExists(iconURL, fileManager: fileManager) else { return nil }
        return try Data(contentsOf: iconURL)
    }
}
