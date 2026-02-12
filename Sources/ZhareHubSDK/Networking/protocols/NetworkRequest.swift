//
//  NetworkRequest.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation
import Alamofire

public struct NetworkRequest: NetworkRequestProtocol {
    public var path: String
    public var method: Alamofire.HTTPMethod
    public var headers: Alamofire.HTTPHeaders?
    public var encoding: Alamofire.ParameterEncoding
    public var queryParameters: Parameters?
    public var body: Data?
    public var timeoutInterval: TimeInterval
    public var cachePolicy: URLRequest.CachePolicy
    
    
    init(path: String,
         method: Alamofire.HTTPMethod,
         headers: Alamofire.HTTPHeaders?,
         queryParameters: Parameters? = nil,
         encoding: ParameterEncoding = URLEncoding.default,
         body: Data? = nil,
         timeoutInterval: TimeInterval,
         cachePolicy: URLRequest.CachePolicy)
    {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryParameters = queryParameters
        self.encoding = encoding
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cachePolicy = cachePolicy
    }
}
