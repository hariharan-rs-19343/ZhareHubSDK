//
//  ShellExecutorProtocol.swift
//  ZhareHubSDK
//
//  Consumer-injected abstraction for executing external binaries (e.g., aapt2).
//
//  ZhareHubSDK does not bundle aapt2 or a Process-bridging .bundle. The host
//  application is responsible for shipping the binary and providing a concrete
//  `ShellExecutorProtocol` implementation (typically backed by Foundation.Process
//  through a macOS helper bundle, since Process is not available directly on
//  Mac Catalyst).
//

import Foundation

public protocol ShellExecutorProtocol: Sendable {

    /// Whether shell execution is available at runtime on the current platform.
    /// Should return `false` on iOS device builds.
    var isAvailable: Bool { get }

    /// Runs an executable at `executablePath` with the given arguments.
    ///
    /// - Parameters:
    ///   - executablePath: Absolute path to the executable.
    ///   - arguments: Arguments passed to the executable (no shell interpolation).
    ///   - environment: Optional additional environment variables.
    ///   - workingDirectory: Optional working directory.
    ///   - timeout: Timeout in seconds. `nil` (or 0) means no timeout.
    /// - Returns: A `ShellResult` containing stdout, stderr, and exit code.
    /// - Throws: `ShellExecutorError`.
    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        timeout: TimeInterval?
    ) async throws -> ShellResult
}

public extension ShellExecutorProtocol {
    func run(executablePath: String, arguments: [String]) async throws -> ShellResult {
        try await run(executablePath: executablePath,
                      arguments: arguments,
                      environment: nil,
                      workingDirectory: nil,
                      timeout: 30)
    }

    func run(executablePath: String, arguments: [String], timeout: TimeInterval?) async throws -> ShellResult {
        try await run(executablePath: executablePath,
                      arguments: arguments,
                      environment: nil,
                      workingDirectory: nil,
                      timeout: timeout)
    }
}
