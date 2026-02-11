//
//  NetworkError.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 11/02/26.
//

import Foundation

public enum NetworkError: ErrorProtocol, Hashable {
        case tokenRetrievalFailed
        case badRequest
        case badServerResponse
        case userAuthenticationRequired
        case noDataAvailable
        case accessRestricted
        case noNetworkAvailable
        case conflict
        case tooManyRequests
        case serializationFailed
        case timeout
        case unknown
        case downloadFailed
        case forbidden
        case notFound
        case internalServerError
        case badGateWay
        case invalidResponse
        case noPermissionToReadFile
        case fileDoesNotExist
        case isExplicitlyCancelled
        case custom(String, String?)

        public var errorDescription: String? {
            switch self {
            case .tokenRetrievalFailed:
                return NSLocalizedString("Failed to retrieve authentication token.",
                              comment: "Occurs when retrieving an authentication token fails.")
                
            case .badRequest:
                return NSLocalizedString("Bad Request",
                              comment: "Occurs when the request is invalid or improperly formatted.")

            case .badServerResponse:
                return NSLocalizedString("Unexpected server response.",
                              comment: "Occurs when the server returns an invalid or unexpected response.")

            case .userAuthenticationRequired:
                return NSLocalizedString("User authentication required.",
                              comment: "Occurs when authentication is required but missing or invalid.")

            case .noDataAvailable:
                return NSLocalizedString("No data available.",
                              comment: "Occurs when the expected data is missing from the response.")

            case .accessRestricted:
                return NSLocalizedString("Access restricted.",
                              comment: "Occurs when the user does not have permission to access the requested resource.")

            case .noNetworkAvailable:
                return NSLocalizedString("No network connection.",
                              comment: "Occurs when there is no internet connection available.")

            case .conflict:
                return NSLocalizedString("Request conflict.",
                              comment: "Occurs when a network request results in a conflict, such as duplicate data updates.")

            case .tooManyRequests:
                return NSLocalizedString("Too many requests.",
                              comment: "Occurs when the server limits the number of requests within a timeframe (rate limiting).")

            case .serializationFailed:
                return NSLocalizedString("Data serialization error.",
                              comment: "Occurs when the response data cannot be parsed or encoded properly.")

            case .timeout:
                return NSLocalizedString("Request timed out.",
                              comment: "Occurs when the request exceeds the allowed time limit without a response.")

            case .unknown:
                return NSLocalizedString("An unexpected error occurred.",
                              comment: "Occurs when an unhandled or unknown network error is encountered.")

            case .downloadFailed:
                return NSLocalizedString("File download failed.",
                              comment: "Occurs when a file download is interrupted or fails due to network issues.")

            case .forbidden:
                return NSLocalizedString("Access forbidden.",
                              comment: "Occurs when the request is denied due to insufficient permissions.")

            case .notFound:
                return NSLocalizedString("Resource not found.",
                              comment: "Occurs when the requested resource does not exist on the server.")

            case .internalServerError:
                return NSLocalizedString("Internal server error.",
                              comment: "Occurs when the server encounters an unexpected condition preventing it from fulfilling the request.")

            case .badGateWay:
                return NSLocalizedString("Bad gateway.",
                              comment: "Occurs when an invalid response is received from an upstream server.")
                
            case .invalidResponse:
                return NSLocalizedString("Invalid or missing HTTP response",
                              comment: "Displayed when the HTTP response is invalid or missing")
                
            case .noPermissionToReadFile:
                        return NSLocalizedString("No permission to read the file.",
                                      comment: "Occurs when the user does not have permission to access the file.")

            case .fileDoesNotExist:
                return NSLocalizedString("File does not exist.",
                              comment: "Occurs when the requested file is missing or has been deleted.")
                
            case .isExplicitlyCancelled:
                return NSLocalizedString("Request was explicitly cancelled.",
                                         comment: "Occurs when the user cancels a network request")
                
            case .custom(let description, let comment):
                return NSLocalizedString(description, comment: comment ?? "")
            }
        }
    }
