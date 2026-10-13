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

    private let registry = RequestRegistry()
    private let session: Session
    private let logger: ZHLoggerProtocol

    private static var invalidRequestMessage: String { "Invalid Request" }

    public init(logger: ZHLoggerProtocol = ZHDefaultLogger(subsystem: "com.zharehub.sdk")) {
        self.logger = logger
        let configuration = URLSessionConfiguration.ephemeral
        self.session = Session(configuration: configuration, eventMonitors: [ZHNetworkEventMonitor(logger: logger)])
    }

    deinit {
        logger.info(category: .networking, message: "NetworkService Deinit")
        registry.cancelAll()
    }

    open func execute<T: Sendable>(request: NetworkRequestProtocol) async throws -> ZHNetworkResponse<T> where T : Decodable {
        let urlRequest = try makeURLRequest(from: request)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let dataRequest = session.request(urlRequest)
                    .validate(statusCode: 200..<300)
                registry.track(requestID, dataRequest)
                dataRequest.responseDecodable(of: T.self) { [weak self] response in
                    self?.registry.remove(requestID)
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: ZHNetworkResponse(value: value, response: response.response, data: response.data))
                    case .failure:
                        continuation.resume(throwing: self?.failureError(from: response.response, data: response.data, error: response.error) ?? NetworkError.unknown)
                    }
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func upload<T: Sendable>(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> T where T : Decodable {
        guard let body = request.body else {
            throw NetworkError.custom(Self.invalidRequestMessage, nil)
        }
        let urlRequest = try makeURLRequest(from: request, forcePostWhenGet: true)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let uploadRequest = session.upload(body, with: urlRequest)
                    .validate(statusCode: 200..<300)
                    .uploadProgress { progressValue in
                        DispatchQueue.main.async {
                            progress(progressValue.fractionCompleted)
                        }
                    }
                registry.track(requestID, uploadRequest)
                uploadRequest.responseDecodable(of: T.self) { [weak self] response in
                    self?.registry.remove(requestID)
                    switch response.result {
                    case .success(let value):
                        continuation.resume(returning: value)
                    case .failure:
                        continuation.resume(throwing: self?.failureError(from: response.response, data: response.data, error: response.error) ?? NetworkError.unknown)
                    }
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func execute(request: NetworkRequestProtocol) async throws -> ZHNetworkResponse<Void> {
        let urlRequest = try makeURLRequest(from: request)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let dataRequest = session.request(urlRequest)
                    .validate(statusCode: 200..<300)
                registry.track(requestID, dataRequest)
                dataRequest.response { [weak self] response in
                    self?.registry.remove(requestID)
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    if let error = response.error {
                        continuation.resume(throwing: self.failureError(from: response.response, data: response.data, error: error))
                        return
                    }
                    continuation.resume(returning: ZHNetworkResponse(value: (), response: response.response, data: response.data))
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func upload(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Any? {
        guard let body = request.body else {
            throw NetworkError.custom(Self.invalidRequestMessage, nil)
        }
        let urlRequest = try makeURLRequest(from: request, forcePostWhenGet: true)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let uploadRequest = session.upload(body, with: urlRequest)
                    .validate(statusCode: 200..<300)
                    .uploadProgress { progressValue in
                        DispatchQueue.main.async {
                            progress(progressValue.fractionCompleted)
                        }
                    }
                registry.track(requestID, uploadRequest)
                uploadRequest.response { [weak self] response in
                    self?.registry.remove(requestID)
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    if let error = response.error {
                        continuation.resume(throwing: self.failureError(from: response.response, data: response.data, error: error))
                        return
                    }
                    continuation.resume(returning: response.data)
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func download(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let urlRequest = try makeURLRequest(from: request)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let destination: DownloadRequest.Destination = { _, _ in
                    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
                }
                let downloadRequest = session.download(urlRequest, to: destination)
                    .validate(statusCode: 200..<300)
                    .downloadProgress { progressValue in
                        progress(progressValue.fractionCompleted)
                    }
                registry.track(requestID, downloadRequest)
                downloadRequest.response { [weak self] response in
                    self?.registry.remove(requestID)
                    guard let self else {
                        continuation.resume(throwing: NetworkError.unknown)
                        return
                    }
                    if let error = response.error {
                        if let fileURL = response.fileURL {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        continuation.resume(throwing: self.failureError(from: response.response, data: response.resumeData, error: error))
                        return
                    }
                    if let fileURL = response.fileURL {
                        continuation.resume(returning: fileURL)
                    } else {
                        continuation.resume(throwing: NetworkError.noDataAvailable)
                    }
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func download(request: any NetworkRequestProtocol, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        let urlRequest = try makeURLRequest(from: request)
        let requestID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let downloadRequest = session.download(urlRequest)
                    .validate(statusCode: 200..<300)
                    .downloadProgress { progressValue in
                        progress(progressValue.fractionCompleted)
                    }
                registry.track(requestID, downloadRequest)
                downloadRequest.responseData { [weak self] response in
                    self?.registry.remove(requestID)
                    switch response.result {
                    case .success(let downloadedData):
                        continuation.resume(returning: downloadedData)
                    case .failure:
                        if let fileURL = response.fileURL {
                            try? FileManager.default.removeItem(at: fileURL)
                        }
                        continuation.resume(throwing: self?.failureError(from: response.response, data: response.resumeData, error: response.error) ?? NetworkError.unknown)
                    }
                }
            }
        } onCancel: { [registry] in
            registry.cancel(requestID)
        }
    }

    open func cancelUploads() {
        registry.cancelAll()
    }

    open func cancelDownloads() {
        registry.cancelAll()
    }

    open func cancelAllRequests() {
        registry.cancelAll()
    }

    open func validateHTTPResponse(_ httpResponse: HTTPURLResponse?, error afError: AFError?) throws {
        if let mapped = transportError(afError) {
            throw mapped
        }
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
            throw NetworkError.serviceUnavailable
        default:
            throw NetworkError.unknown
        }
    }

    private func makeURLRequest(from request: NetworkRequestProtocol, forcePostWhenGet: Bool = false) throws -> URLRequest {
        try Self.ensureNetworkAvailable()
        guard var components = URLComponents(string: request.path) else {
            throw NetworkError.invalidResponse
        }
        if let queryParameters = request.queryParameters, !queryParameters.isEmpty {
            var items = components.queryItems ?? []
            for key in queryParameters.keys.sorted() {
                guard let value = queryParameters[key] else { continue }
                items.append(URLQueryItem(name: key, value: String(describing: value)))
            }
            components.queryItems = items
        }
        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        var urlRequest = URLRequest(url: url, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
        var method = request.method
        if forcePostWhenGet && method == .get {
            method = .post
        }
        urlRequest.method = method
        urlRequest.httpBody = request.body
        if let headers = request.headers {
            urlRequest.headers = headers
        }
        if let contentType = request.contentType, urlRequest.headers["Content-Type"] == nil {
            urlRequest.headers.add(.contentType(contentType))
        }
        return urlRequest
    }

    private static func ensureNetworkAvailable() throws {
        guard ConnectionStatus.shared.isNetworkAvailable else {
            throw NetworkError.noNetworkAvailable
        }
    }

    private func failureError(from response: HTTPURLResponse?, data: Data?, error: AFError?) -> Error {
        if let transportError = transportError(error) {
            return transportError
        }
        if let statusCode = response?.statusCode, !(200..<300).contains(statusCode) {
            if let serverError = decodeErrorBody(from: data) {
                return serverError
            }
        }
        if let statusCode = response?.statusCode, (200..<300).contains(statusCode) {
            return NetworkError.serializationFailed
        }
        if let response {
            do {
                try validateHTTPResponse(response, error: nil)
            } catch {
                return error
            }
        }
        return NetworkError.invalidResponse
    }

    private func transportError(_ error: AFError?) -> NetworkError? {
        guard let error else { return nil }
        if error.isExplicitlyCancelledError || error.isSessionDeinitializedError {
            return .isExplicitlyCancelled
        }
        let urlError = error.underlyingError as? URLError ?? (error as Error as? URLError)
        switch urlError?.code {
        case .timedOut:
            return .timeout
        case .cancelled:
            return .isExplicitlyCancelled
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .noNetworkAvailable
        default:
            return nil
        }
    }

    private func decodeErrorBody(from data: Data?) -> Error? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(E.self, from: data)
    }
}

private final class RequestRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [UUID: Request] = [:]

    func track(_ id: UUID, _ request: Request) {
        lock.lock()
        requests[id] = request
        lock.unlock()
    }

    func remove(_ id: UUID) {
        lock.lock()
        requests.removeValue(forKey: id)
        lock.unlock()
    }

    func cancel(_ id: UUID) {
        lock.lock()
        let request = requests.removeValue(forKey: id)
        lock.unlock()
        request?.cancel()
    }

    func cancelAll() {
        lock.lock()
        let active = Array(requests.values)
        requests.removeAll()
        lock.unlock()
        active.forEach { $0.cancel() }
    }
}
