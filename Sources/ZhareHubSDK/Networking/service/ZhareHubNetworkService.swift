//
//  ZhareHubNetworkService.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation
import Alamofire
import SUICore

public typealias ZhareHubDefaultNetworkService = ZhareHubNetworkService<ZHRequestErrorBody>

open class ZhareHubNetworkService<E: ZHErrorBody>: @unchecked Sendable, NetworkServiceProtocol {
    
    private var activeUploads: [UUID: UploadRequest] = [:]
    
    private var activeDownloads: [UUID: DownloadRequest] = [:]
    
    public init() {}
    
    deinit {
        ZOSLogs.shared.info("NetworkService Deinit")
        cancelAllRequests()
    }

    open func execute<T: Sendable>(request: NetworkRequestProtocol) async throws -> ZHNetworkResponse<T> where T : Decodable {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(request.path, method: request.method, parameters: request.queryParameters, encoding: request.encoding, headers: request.headers)
                .validate()
                .responseDecodable(of: T.self) {[weak self] response in
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: ZHNetworkResponse(value: value, response: response.response, data: response.data))
                    case .failure:
                        if let serverError = self?.decodeErrorBody(from: response.data) {
                            continuation.resume(throwing: serverError)
                        } else {
                            guard let self else {
                                continuation.resume(throwing: NetworkError.unknown)
                                return
                            }
                            do {
                                try self.validateHTTPResponse(response.response, error: response.error)
                                continuation.resume(throwing: NetworkError.unknown)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
        }
    }
    
    open func upload<T: Sendable>(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> T where T : Decodable {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        guard let body = request.body else {
            throw NetworkError.custom("Invalid Request", nil)
        }
        
        let uploadId: UUID = UUID()
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadRequest = AF.upload(body, to: request.path, method: request.method, headers: request.headers)
                .uploadProgress { progressValue in
                    DispatchQueue.main.async {
                        progress(progressValue.fractionCompleted)
                    }
                }
                .responseDecodable(of: T.self) {[weak self] response in
                    self?.activeUploads.removeValue(forKey: uploadId)
                    
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure:
                        if let serverError = self?.decodeErrorBody(from: response.data) {
                            continuation.resume(throwing: serverError)
                        } else {
                            guard let self else {
                                continuation.resume(throwing: NetworkError.unknown)
                                return
                            }
                            do {
                                try self.validateHTTPResponse(response.response, error: response.error)
                                continuation.resume(throwing: NetworkError.unknown)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            
            activeUploads[uploadId] = uploadRequest
        }
    }
    
    open func execute(request: NetworkRequestProtocol) async throws -> ZHNetworkResponse<Void> {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            AF.request(request.path, method: request.method, parameters: request.queryParameters, encoding: request.encoding, headers: request.headers)
                .validate()
                .response { [weak self] response in
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    do {
                        try self.validateHTTPResponse(response.response, error: response.error)
                        continuation.resume(returning: ZHNetworkResponse(value: (), response: response.response, data: response.data))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    open func upload(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Any? {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        guard let body = request.body else {
            throw NetworkError.custom("Invalid Request", nil)
        }
        
        let uploadId = UUID()
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadRequest = AF.upload(body, to: request.path, method: request.method, headers: request.headers)
                .uploadProgress { progressValue in
                    DispatchQueue.main.async {
                        progress(progressValue.fractionCompleted)
                    }
                }
                .validate()
                .response {[weak self] response in
                    self?.activeUploads.removeValue(forKey: uploadId)
                    
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    do {
                        try self.validateHTTPResponse(response.response, error: response.error)
                        let result = try response.result.get()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            
            activeUploads[uploadId] = uploadRequest
        }
    }
    
    open func download(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let destination: DownloadRequest.Destination = { _, _ in
                let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentURL.appendingPathComponent(UUID().uuidString)
                return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
            }
            
            let downloadId = UUID()
            
            let downloadRequest = AF.download(request.path,
                        method: request.method,
                        parameters: request.queryParameters,
                        encoding: request.encoding,
                        headers: request.headers,
                        to: destination)
                .downloadProgress { progressValue in
                    progress(progressValue.fractionCompleted)
                }
                .response { [weak self] response in
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    do {
                        try self.validateHTTPResponse(response.response, error: response.error)
                        if let fileURL = response.fileURL {
                            continuation.resume(returning: fileURL)
                        } else {
                            continuation.resume(throwing: NetworkError.noDataAvailable)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                
            activeDownloads[downloadId] = downloadRequest
        }
    }
    
    open func download(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        let downloadId = UUID()
        
        return try await withCheckedThrowingContinuation { continuation in
            let downloadRequest = AF.download(request.path,
                        method: request.method,
                        parameters: request.queryParameters,
                        encoding: request.encoding,
                        headers: request.headers)
                .downloadProgress { progressValue in
                    progress(progressValue.fractionCompleted)
                }
                .responseData(completionHandler: { [weak self] response in
                    switch response.result {
                    case .success(let downloadedData):
                        continuation.resume(returning: downloadedData)
                    case .failure:
                        guard let self else {
                            continuation.resume(throwing: NetworkError.unknown)
                            return
                        }
                        do {
                            try self.validateHTTPResponse(response.response, error: response.error)
                            continuation.resume(throwing: NetworkError.unknown)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                })
            
            activeDownloads[downloadId] = downloadRequest
        }
    }
    
    /// Cancel all active upload requests
    open func cancelUploads() {
        activeUploads.forEach { _, request in
            request.cancel()
        }
        
        activeUploads.removeAll()
    }
    
    /// Cancel all active download requests
    open func cancelDownloads() {
        activeDownloads.forEach { _, request in
            request.cancel()
        }
        activeDownloads.removeAll()
    }
    
    /// Cancel all active requests (uploads, downloads, and data requests)
    open func cancelAllRequests() {
       cancelUploads()
       cancelDownloads()
    }
    
    open func validateHTTPResponse(_ httpResponse: HTTPURLResponse?, error afError: AFError?) throws {
        if let afError = afError, afError.isExplicitlyCancelledError { throw NetworkError.isExplicitlyCancelled }
        guard let httpResponse else { throw NetworkError.invalidResponse }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.badRequest
        case 401:
            throw NetworkError.userAuthenticationRequired
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 408:
            throw NetworkError.timeout
        case 409:
            throw NetworkError.conflict
        case 429:
            throw NetworkError.tooManyRequests
        case 500:
            throw NetworkError.internalServerError
        case 502:
            throw NetworkError.badGateWay
        case 503:
            throw NetworkError.badServerResponse
        default:
            throw NetworkError.unknown
        }
    }
    
    private func decodeErrorBody(from data: Data?) -> Error? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(E.self, from: data)
    }
}
