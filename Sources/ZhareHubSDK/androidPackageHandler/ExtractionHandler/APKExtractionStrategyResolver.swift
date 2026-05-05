//
//  APKExtractionStrategyResolver.swift
//  ZhareHubSDK
//
//  Mirrors `PackageExtractionStrategyResolver` for the Android side.
//

import Foundation

public final class APKExtractionStrategyResolver {

    private let strategies: [APKExtractionProtocol]

    public init(strategies: [APKExtractionProtocol]? = nil) {
        self.strategies = strategies ?? [APKExtractionStrategy()]
    }

    public func resolve(for url: URL) -> APKExtractionProtocol? {
        return strategies.first { $0.canHandle(url: url) }
    }
}
