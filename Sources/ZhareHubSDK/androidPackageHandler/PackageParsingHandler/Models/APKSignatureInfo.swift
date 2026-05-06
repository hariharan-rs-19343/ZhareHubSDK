//
//  APKSignatureInfo.swift
//  ZhareHubSDK
//

import Foundation

public struct APKSignatureInfo: Hashable, Sendable {
    /// Distinguished Name of the certificate that signed the APK
    /// (typically the team / organization name).
    public let signer: String

    public init(signer: String) {
        self.signer = signer
    }

    public static let unknown = APKSignatureInfo(signer: "N/A")
}
