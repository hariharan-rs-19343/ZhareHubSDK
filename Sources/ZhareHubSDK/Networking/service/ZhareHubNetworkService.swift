//
//  ZhareHubNetworkService.swift
//  MEAdmin
//
//  Created by Hariharan R S on 10/03/25.
//

import Foundation
import Alamofire
import SUICore

open class ZhareHubNetworkService: @unchecked Sendable, NetworkServiceProtocol {
    
    // Dictionary to store active upload requests with their identifiers
    private var activeUploads: [UUID: UploadRequest] = [:]
    
    // Dictionary to store active download requests with their identifiers
    private var activeDownloads: [UUID: DownloadRequest] = [:]
    
    public init() {}
    
    deinit {
        ZOSLogs.shared.info("NetworkService Deinit")
        cancelAllRequests()
    }

    open func execute<T: Sendable>(request: NetworkRequestProtocol) async throws -> T where T : Decodable {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.request(request.path, method: request.method, parameters: request.queryParameters, encoding: request.encoding, headers: request.headers)
                .validate()
                .responseDecodable(of: T.self) {[weak self] response in
                    do {
                        try self?.validateHTTPResponse(response.response, error: response.error)
                        let result = try response.result.get()
                        continuation.resume(returning: result)
                    }catch {
                        continuation.resume(throwing: error)
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
                    
                    do {
                        try self?.validateHTTPResponse(response.response, error: response.error)
                        let result = try response.result.get()
                        continuation.resume(returning: result)
                    }catch {
                        continuation.resume(throwing: error)
                    }
                }
            
            activeUploads[uploadId] = uploadRequest
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
                    
                    do {
                        try self?.validateHTTPResponse(response.response, error: response.error)
                        let result = try response.result.get()
                        continuation.resume(returning: result)
                    }catch {
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
                .response { response in
                    if let error = response.error {
                        return continuation.resume(throwing: error)
                    }
                    
                    if let fileURL = response.fileURL {
                        continuation.resume(returning: fileURL)
                    }else {
                        continuation.resume(throwing: NetworkError.noDataAvailable)
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
                .responseData(completionHandler: { response in
                    switch response.result {
                    case .success(let downloadedData):
                        continuation.resume(returning: downloadedData)
                    case .failure(let error):
                        continuation.resume(throwing: error)
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
        if let afError = afError, afError.isExplicitlyCancelledError {
            throw NetworkError.isExplicitlyCancelled
        }
        
        guard let httpRequest = httpResponse else {
            throw NetworkError.invalidResponse
        }
        
        let statusCode = httpRequest.statusCode
        
        switch statusCode {
        case 200...299:
            return
        case 400:
            throw NetworkError.badRequest
        case 401:
            throw NetworkError.userAuthenticationRequired
        case 403:
            throw NetworkError.noPermissionToReadFile
        case 404:
            throw NetworkError.fileDoesNotExist
        case 408:
            throw NetworkError.timeout
        case 500:
            throw NetworkError.badServerResponse
        default:
            throw URLError(.unknown)
        }
    }
}
