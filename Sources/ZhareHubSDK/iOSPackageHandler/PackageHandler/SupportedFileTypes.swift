//
//  SupportedFileTypes.swift
//  ZhareHub
//
//  Created by Hariharan R S on 13/03/25.
//

import Foundation

enum SupportedFileTypes {
    case icon, app, mobileprovision, installationPlist, infoPlist, provisionProfile
    
    var getError: FileConversionError {
        switch self {
        case .icon:
            return .appIconNotFoundInPayload
        case .mobileprovision:
            return .provisioningProfileNotFoundInPayload
        case .infoPlist:
            return .infoPlistNotFoundInPayload
        case .provisionProfile:
            return .provisioningProfileNotFoundInPayload
        default:
            return .fileToDataConversionError
        }
    }
}
