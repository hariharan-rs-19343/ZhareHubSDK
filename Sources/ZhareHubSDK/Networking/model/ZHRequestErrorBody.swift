//
//  ZHError.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 12/08/26.
//

import Foundation

public struct ZHRequestErrorBody: ZHErrorBody, LocalizedError {
    public private(set) var statusCode: String
    public private(set) var resourceName: String
    public private(set) var error: ErrorBody?
    
    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case resourceName = "resource_name"
        case error
    }
    
    public var errorDescription: String? {
        error?.message
    }
    
    public struct ErrorBody: Decodable {
        public private(set) var code: String
        public private(set) var message: String
        
        enum CodingKeys: String, CodingKey {
            case code
            case message
        }
    }
}
