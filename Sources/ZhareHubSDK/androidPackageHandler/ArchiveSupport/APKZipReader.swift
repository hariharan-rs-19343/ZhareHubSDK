//
//  APKZipReader.swift
//  ZhareHubSDK
//
//  Single-entry ZIP reader for APK files, backed by ZIPFoundation.
//  ZIPFoundation is `internal import` so it never leaks into public API.
//

import Foundation
internal import ZIPFoundation

public final class APKZipReader {

    public struct Entry: Hashable, Sendable {
        public let path: String
        public let uncompressedSize: UInt64

        public init(path: String, uncompressedSize: UInt64) {
            self.path = path
            self.uncompressedSize = uncompressedSize
        }
    }

    private let archive: Archive
    public let entries: [Entry]

    public init?(url: URL) {
        guard let archive = try? Archive(url: url, accessMode: .read, pathEncoding: .utf8) else {
            return nil
        }
        self.archive = archive
        self.entries = archive.compactMap { zipEntry -> Entry? in
            guard zipEntry.type == .file else { return nil }
            return Entry(path: zipEntry.path, uncompressedSize: zipEntry.uncompressedSize)
        }
    }

    /// Extracts a single entry by path. Returns the decompressed file data, or `nil` if absent, corrupt, or over the size limit.
    public func extractEntry(path: String, maximumBytes: UInt64 = 32 * 1_024 * 1_024) -> Data? {
        guard let zipEntry = archive[path] else { return nil }
        guard zipEntry.uncompressedSize <= maximumBytes else { return nil }
        var result = Data()
        do {
            _ = try archive.extract(zipEntry) { chunk in
                result.append(chunk)
                if UInt64(result.count) > maximumBytes {
                    throw FileConversionError.fileReadFailed
                }
            }
        } catch {
            return nil
        }
        guard UInt64(result.count) == zipEntry.uncompressedSize else { return nil }
        return result.isEmpty ? nil : result
    }
}
