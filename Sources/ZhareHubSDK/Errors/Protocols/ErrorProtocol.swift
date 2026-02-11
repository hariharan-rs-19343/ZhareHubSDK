//
//  ErrorTypeProtocol.swift
//  MEAdmin
//
//  Created by Hariharan R S on 07/02/25.
//

import Foundation

public protocol ErrorProtocol: Error, LocalizedError {
    override var errorDescription: String? { get }
}

