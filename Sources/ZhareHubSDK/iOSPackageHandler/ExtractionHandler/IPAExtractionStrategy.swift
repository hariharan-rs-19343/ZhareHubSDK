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

    init(archiveOperations: ArchiveOperationsProtocol = DefaultArchiveOperations()) {
        self.archiveOperations = archiveOperations
    }

    public func canHandle(url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension) == .ipa
    }

    public func processPackage(sourceURL: URL) throws -> URL {
        let workspace = try ExtractionWorkspace.make()
        let archiveName = ExtractionWorkspace.singlePathComponent(sourceURL.deletingPathExtension().lastPathComponent) ?? "package"
        let zipLocation = workspace.appending(component: archiveName).appendingPathExtension("zip")
        try FileManager.default.copyItem(at: sourceURL, to: zipLocation)
        try archiveOperations.extractArchive(file: zipLocation, to: workspace, overwrite: true, password: nil)
        return workspace.appending(component: ZhareHubConstants.PAYLOAD)
    }

    public func extractAppIcon(from appDirectory: URL, infoPlistData: Data, parser: any PackageParserProtocol, fileName: String?) async throws -> Data? {
        let iconName = try readAppIconName(from: infoPlistData, parser: parser)
        return try await readAppIconData(from: appDirectory, iconName: iconName, fileName: fileName)
    }

    public func readAppIconData(from appDirectory: URL, iconName: String, fileName: String?) async throws -> Data? {
        guard let iconSubPath = try? FileManager.default.contentsOfDirectory(atPath: FileURLPath.decoded(appDirectory))
            .first(where: { $0.contains(iconName) })
        else {
            return await generateDefaultAppIconData(fileName: fileName)
        }

        let iconURL = appDirectory.appending(component: iconSubPath)
        guard FileURLPath.fileExists(iconURL) else {
            return await generateDefaultAppIconData(fileName: fileName)
        }
        return try Data(contentsOf: iconURL)
    }

    public func prepareAppData(from sourceURL: URL) throws -> Data? {
        try ExtractionWorkspace.readBounded(contentsOf: sourceURL)
    }
}
