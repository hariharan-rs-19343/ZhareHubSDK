//
//  NetworkRequestProtocol.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation
import Alamofire

public protocol NetworkRequestProtocol {
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: HTTPHeaders? { get }
    var queryParameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
    var body: Data? { get }
    var timeoutInterval: TimeInterval { get }
    var cachePolicy: URLRequest.CachePolicy { get }
}
