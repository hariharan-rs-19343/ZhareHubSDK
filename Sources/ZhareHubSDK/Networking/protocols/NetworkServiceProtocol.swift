//
//  NetworkServiceProtocol.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation


public protocol NetworkServiceProtocol {
    func execute<T>(request: NetworkRequestProtocol) async throws -> T where T: Decodable
    func download(request: NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Data
    func download(request: NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
    func upload<T>(request: NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> T where T: Decodable
    func upload(request: NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Any?
}
