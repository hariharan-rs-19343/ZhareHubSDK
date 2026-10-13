//
//  APKSignatureInfo.swift
//  ZhareHubSDK
//

import Foundation

public struct APKSignatureInfo: Hashable, Sendable {
    /// Distinguished Name of the certificate that signed the APK
    /// (typically the team / organization name).
    public let signer: String
    /// Signing schemes that were present, such as `"v2, v3"`.
    public let signingSchemes: String

    public init(signer: String, signingSchemes: String = "N/A") {
        self.signer = signer
        self.signingSchemes = signingSchemes
    }

    public static let unknown = APKSignatureInfo(signer: "N/A")
}
