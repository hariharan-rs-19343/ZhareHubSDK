//
//  DefaultArchiveOperations.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
internal import ZIPFoundation

public final class DefaultArchiveOperations: ArchiveOperationsProtocol {

    public init() {}

    public func extractArchive(file: URL, to destination: URL, overwrite: Bool = true, password: String? = nil) throws {
        if password != nil {
            throw FileConversionError.custom("Password-protected archives are not supported.")
        }

        let fileManager = FileManager.default
        if !FileURLPath.fileExists(destination, fileManager: fileManager) {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        do {
            try fileManager.unzipItem(
                at: file,
                to: destination,
                skipCRC32: false,
                allowUncontainedSymlinks: false
            )
        } catch {
            throw FileConversionError.custom("Archive extraction failed: \(error.localizedDescription)")
        }
    }
}
