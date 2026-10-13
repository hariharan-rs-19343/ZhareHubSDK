//
//  ExtractionWorkspace.swift
//  ZhareHubSDK
//

import Foundation
import SUICore

enum ExtractionWorkspace {
    static let maximumPayloadBytes: Int64 = 2 * 1_024 * 1_024 * 1_024

    static func make() throws -> URL {
        let workspace = ZFFileManager.shared.appCacheDirectory
            .appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        return workspace
    }

    static func readBounded(contentsOf url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
        guard size <= maximumPayloadBytes else {
            throw FileConversionError.custom("Package exceeds the 2 GB size limit.")
        }
        return try Data(contentsOf: url)
    }

    static func singlePathComponent(_ fileName: String) -> String? {
        let name = URL(fileURLWithPath: fileName).lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\") else {
            return nil
        }
        return name
    }
}
