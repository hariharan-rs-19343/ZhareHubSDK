//
//  ZHNetworkEventMonitor.swift
//  ZhareHubSDK
//
//  Alamofire `EventMonitor` that routes every request/response through an
//  injected `ZHLoggerProtocol`, without touching each of `ZhareHubNetworkService`'s
//  execute/upload/download methods individually.
//
//  Never logs raw header values, query parameter values, or body content —
//  only names, keys, and sizes — since any of those could carry tokens/PII
//  that shouldn't land in the (host-configurable) log sink.
//

import Foundation
import Alamofire
import SUICore

final class ZHNetworkEventMonitor: EventMonitor {
    let queue = DispatchQueue(label: "com.zharehub.sdk.network-logging")

    private let logger: ZHLoggerProtocol

    init(logger: ZHLoggerProtocol) {
        self.logger = logger
    }

    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        let headerNames = (urlRequest.allHTTPHeaderFields ?? [:]).keys.sorted().joined(separator: ",")
        let queryKeys = urlRequest.url
            .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }?
            .map(\.name).joined(separator: ",") ?? ""
        let bodyBytes = urlRequest.httpBody?.count ?? 0

        logger.log(
            level: .info,
            category: .networking,
            message: "→ \(urlRequest.httpMethod ?? "?") \(urlRequest.url?.absoluteString ?? "?")",
            metadata: ["headerNames": headerNames, "queryKeys": queryKeys, "bodyBytes": "\(bodyBytes)"]
        )
    }

    func request(_ request: Request, didGatherMetrics metrics: URLSessionTaskMetrics) {
        let duration = String(format: "%.3f", metrics.taskInterval.duration)
        logger.log(
            level: .debug,
            category: .networking,
            message: "\(request.request?.httpMethod ?? "?") \(request.request?.url?.absoluteString ?? "?") took \(duration)s",
            metadata: ["durationSeconds": duration]
        )
    }

    func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        logResponse(request, statusCode: response.response?.statusCode, size: response.data?.count, error: response.error)
    }

    func request<Value: Sendable>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        logResponse(request, statusCode: response.response?.statusCode, size: response.data?.count, error: response.error)
    }

    func request(_ request: DownloadRequest, didParseResponse response: DownloadResponse<URL?, AFError>) {
        logResponse(request, statusCode: response.response?.statusCode, size: nil, error: response.error)
    }

    func request<Value: Sendable>(_ request: DownloadRequest, didParseResponse response: DownloadResponse<Value, AFError>) {
        logResponse(request, statusCode: response.response?.statusCode, size: nil, error: response.error)
    }

    private func logResponse(_ request: Request, statusCode: Int?, size: Int?, error: AFError?) {
        var metadata: [String: String] = [:]
        if let statusCode { metadata["statusCode"] = "\(statusCode)" }
        if let size { metadata["responseBytes"] = "\(size)" }
        if let error { metadata["error"] = error.localizedDescription }

        logger.log(
            level: error == nil ? .info : .error,
            category: .networking,
            message: "← \(request.request?.httpMethod ?? "?") \(request.request?.url?.absoluteString ?? "?")",
            metadata: metadata
        )
    }
}
