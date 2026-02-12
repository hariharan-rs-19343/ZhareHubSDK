//
//  RequestBuilder.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation
import Alamofire

public class RequestBuilder {
    private var path: String
    private var method: HTTPMethod = .get
    private var headers: HTTPHeaders?
    private var queryParameters: Parameters?
    private var encoding: ParameterEncoding = URLEncoding.default
    private var body: Data?
    private var timeoutInterval: TimeInterval = 30
    private var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    
    public init(path: String) {
        self.path = path
    }
    
    public func set(method: HTTPMethod) -> RequestBuilder {
        self.method = method
        return self
    }
    
    public func set(headers: HTTPHeaders?) -> RequestBuilder {
        self.headers = headers
        return self
    }
    
    public func set<T: Encodable>(body: T, encoder: JSONEncoder = JSONEncoder()) throws -> RequestBuilder {
        self.body = try encoder.encode(body)
        return self
    }
    
    public func set(binary data: Data) -> RequestBuilder {
        self.body = data
        return self
    }
    
    public func set(queryParameters: Parameters) -> RequestBuilder {
        self.queryParameters = queryParameters
        return self
    }
    
    public func set(timeoutInterval: TimeInterval) -> RequestBuilder {
        self.timeoutInterval = timeoutInterval
        return self
    }
    
    public func set(cachePolicy: URLRequest.CachePolicy) -> RequestBuilder {
        self.cachePolicy = cachePolicy
        return self
    }
    
    public func set(encoding: Alamofire.ParameterEncoding) -> RequestBuilder {
        self.encoding = encoding
        return self
    }
    
    public func build() -> NetworkRequest {
        return NetworkRequest(path: path,
                              method: method,
                              headers: headers,
                              queryParameters: queryParameters,
                              encoding: encoding,
                              body: body,
                              timeoutInterval: timeoutInterval,
                              cachePolicy: cachePolicy)
    }
}
