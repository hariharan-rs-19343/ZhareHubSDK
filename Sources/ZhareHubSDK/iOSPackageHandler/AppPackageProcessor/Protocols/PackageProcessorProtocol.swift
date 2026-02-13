//
//  PackageProcessor.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

public protocol PackageProcessorProtocol {
    func processPackage(of sourceURL: URL) throws -> URL
}
