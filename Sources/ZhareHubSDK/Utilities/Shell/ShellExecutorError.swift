//
//  ShellExecutorError.swift
//  ZhareHubSDK
//

import Foundation

public enum ShellExecutorError: ErrorProtocol {
    case notSupportedOnPlatform
    case executionFailed(String)
    case timeout
    case invalidExecutable(String)

    public var errorDescription: String? {
        switch self {
        case .notSupportedOnPlatform:
            return NSLocalizedString("Shell execution is not supported on this platform.",
                                     comment: "Process-based execution is unavailable (e.g., on iOS device).")
        case .executionFailed(let reason):
            return NSLocalizedString("Shell execution failed: \(reason)", comment: "")
        case .timeout:
            return NSLocalizedString("The shell command timed out.", comment: "")
        case .invalidExecutable(let path):
            return NSLocalizedString("Executable not found or not executable at path: \(path)", comment: "")
        }
    }
}
