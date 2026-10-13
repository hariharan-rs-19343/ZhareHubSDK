//
//  MobileProvision.swift
//  ZhareHub
//
//  Created by Hariharan R S on 26/11/24.
//

import Foundation

public struct MobileProvision: Hashable {
    public let name: String
    public let teamIdentifier: [String]
    public let creationDate: Date
    public let expirationDate: Date
    public let teamName: String
    public var isExpired: Bool {
        expirationDate < Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case teamIdentifier = "TeamIdentifier"
        case creationDate = "CreationDate"
        case expirationDate = "ExpirationDate"
        case teamName = "TeamName"
    }
    
    public init?(from dictionary: [String: Any]) {
        guard let name = dictionary[CodingKeys.name.rawValue] as? String,
              let teamIdentifier = dictionary[CodingKeys.teamIdentifier.rawValue] as? [String],
              let creationDate = dictionary[CodingKeys.creationDate.rawValue] as? Date,
              let expirationDate = dictionary[CodingKeys.expirationDate.rawValue] as? Date,
              let teamName = dictionary[CodingKeys.teamName.rawValue] as? String
        else {
            return nil
        }
        
        self.name = name
        self.teamIdentifier = teamIdentifier
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.teamName = teamName
    }
}

public struct Entitlements: Codable {
    public let teamIdentifier: [String]?
    public let getTaskAllow: Bool?
    public let applicationIdentifier: String?
    public let apsEnvironment: String?
    public let keychainAccessGroups: [String]?
    
    enum CodingKeys: String, CodingKey {
        case teamIdentifier = "com.apple.developer.team-identifier"
        case getTaskAllow = "get-task-allow"
        case applicationIdentifier = "application-identifier"
        case apsEnvironment = "aps-environment"
        case keychainAccessGroups = "keychain-access-groups"
    }
}
