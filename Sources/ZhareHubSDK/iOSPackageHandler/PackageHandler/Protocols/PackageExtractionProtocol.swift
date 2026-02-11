//
//  PackageExtractionProtocol.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

protocol PackageExtractionProtocol {
    func initiateAppExtraction(from url: URL, fileName: String) -> Result<PackageExtractionModel, Error>
}
