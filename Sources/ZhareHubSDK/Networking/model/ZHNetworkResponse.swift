//
//  ZHNetworkResponse.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 27/08/26.
//

import Foundation

public struct ZHNetworkResponse<T> {
    private let value: T
    private let httpResponse: HTTPURLResponse?
    private let rawData: Data?

    init(value: T, response: HTTPURLResponse?, data: Data?) {
        self.value = value
        self.httpResponse = response
        self.rawData = data
    }

    public func get() -> T { value }
    public func getStatusCode() -> Int? { httpResponse?.statusCode }
    public func getAllHeaders() -> [AnyHashable: Any]? { httpResponse?.allHeaderFields }
    public func getData() -> Data? { rawData }
    public func getResponse() -> HTTPURLResponse? { httpResponse }
}

extension ZHNetworkResponse: Sendable where T: Sendable {}
