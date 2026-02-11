//
//  ArchiveOperations.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

protocol ArchiveOperationsProtocol {
    func extractArchive(file: URL, to destination: URL, overwrite: Bool, password: String?) throws
}
