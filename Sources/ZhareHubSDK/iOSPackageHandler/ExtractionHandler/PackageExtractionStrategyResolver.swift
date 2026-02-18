//
//  PackageExtractionStrategyResolver.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 19/02/26.
//

import Foundation


public final class PackageExtractionStrategyResolver {
    
    private let strategies: [PackageExtractionProtocol]
    
    public init(strategies: [PackageExtractionProtocol]? = nil) {
        self.strategies = strategies ?? [
            IPAExtractionStrategy(),
            ZipExtractionStrategy(),
            APPExtractionStrategy()
        ]
    }
    
    public func resolve(for url: URL) -> PackageExtractionProtocol? {
        return strategies.first { $0.canHandle(url: url) }
    }
}
