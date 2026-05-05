//
//  ShellResult.swift
//  ZhareHubSDK
//
//  Result of a shell command executed via `ShellExecutorProtocol`.
//

import Foundation

public struct ShellResult: Sendable {
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32

    public var isSuccess: Bool { exitCode == 0 }

    public init(output: String, errorOutput: String, exitCode: Int32) {
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
    }
}
