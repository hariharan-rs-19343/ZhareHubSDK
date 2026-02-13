//
//  DefaultArchiveOperations.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation
import Zip

public final class DefaultArchiveOperations: ArchiveOperationsProtocol {
    
    public init() {}
    
    public func extractArchive(file: URL, to destination: URL, overwrite: Bool = true, password: String? = nil) throws {
        try Zip.unzipFile(file, destination: destination, overwrite: overwrite, password: password)
    }
}
