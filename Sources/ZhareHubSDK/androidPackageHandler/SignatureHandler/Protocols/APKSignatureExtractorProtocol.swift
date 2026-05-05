//
//  APKSignatureExtractorProtocol.swift
//  ZhareHubSDK
//

import Foundation

public protocol APKSignatureExtractorProtocol: Sendable {
    func extract(from apkPath: URL) -> APKSignatureInfo
}
