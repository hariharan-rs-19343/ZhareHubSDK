//
//  PackageConversion.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

protocol PackageConversionProtocol {
    
    /// Converts a package file to ZIP format and returns the location of the converted file
    /// - Returns: URL to the converted ZIP file if successful
    /// - Throws: Conversion errors that might occur during the process
    func prepareArchiveFormat(of sourceURL: URL) throws -> URL
}
