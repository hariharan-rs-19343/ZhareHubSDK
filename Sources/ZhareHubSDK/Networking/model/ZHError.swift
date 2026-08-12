//
//  ZHError.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 12/08/26.
//

import Foundation

public struct ZHError: ZHErrorBody, LocalizedError {
    public private(set) var statusCode: Int
    public private(set) var resourceName: String
    public private(set) var message: String
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case resourceName = "resource_name"
        case message
    }
    
    public var errorDescription: String? {
        message
    }
}
