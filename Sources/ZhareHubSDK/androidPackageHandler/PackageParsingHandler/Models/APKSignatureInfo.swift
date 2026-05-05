//
//  APKSignatureInfo.swift
//  ZhareHubSDK
//

import Foundation

public struct APKSignatureInfo: Hashable, Sendable {
    public let signer: String
    public let signingSchemes: String

    public init(signer: String, signingSchemes: String) {
        self.signer = signer
        self.signingSchemes = signingSchemes
    }

    public static let unknown = APKSignatureInfo(signer: "N/A", signingSchemes: "None")
}
