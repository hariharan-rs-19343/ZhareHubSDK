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

    /// Extracts a single entry by path. Returns the decompressed file data, or `nil` if absent / empty.
    public func extractEntry(path: String) -> Data? {
        guard let zipEntry = archive[path] else { return nil }
        var result = Data()
        _ = try? archive.extract(zipEntry) { chunk in
            result.append(chunk)
        }
        return result.isEmpty ? nil : result
    }
}
