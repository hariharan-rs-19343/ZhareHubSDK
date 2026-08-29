//
//  FileConversionError.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 11/02/26.
//

import Foundation

public enum FileConversionError: ErrorProtocol {
        case invalidFilePath
        case packageToZipConversionError
        case fileToDataConversionError
        case fileReadFailed
        case unsupportedFile
        case infoPlistNotFoundInPayload
        case appIconNotFoundInPayload
        case provisioningProfileNotFoundInPayload
        case deserialiizationError
        case unsupportedPlatform
        case custom(String)
        
        public var errorDescription: String? {
            switch self {
            case .packageToZipConversionError:
                return NSLocalizedString("Unable to convert package to zip.", comment: "Displayed when the content of the specified file cannot be converted into a zip.")
            case .fileToDataConversionError:
                return NSLocalizedString("Unable to convert file to data.", comment: "Displayed when the content of the specified file cannot be converted into data.")
            case .invalidFilePath:
                return NSLocalizedString("The specified file path is invalid or does not exist.", comment: "Displayed when the provided file URL is invalid or the file is missing.")
            case .fileReadFailed:
                return NSLocalizedString("Failed to read the file at the specified path.", comment: "Displayed when the file cannot be read, either due to an invalid path or a missing file.")
            case .unsupportedFile:
                return NSLocalizedString("The specified file format is not supported.", comment: "Displayed when the file type is unsupported by the application.")
            case .appIconNotFoundInPayload:
                return NSLocalizedString("App icon not found in the payload", comment: "Displayed when the app icon is not found in the provided payload")
            case .infoPlistNotFoundInPayload:
                return NSLocalizedString("Info.plist not found in the payload", comment: "Displayed when the Info.plist is not found in the provided payload")
            case .provisioningProfileNotFoundInPayload:
                return NSLocalizedString("Provisioning profile not found in the payload", comment: "Displayed when the provisioning profile is not found in the provided payload")
            case .deserialiizationError:
                return NSLocalizedString("Failed to deserialize the property list.", comment: "Displayed when the property list data cannot be parsed into a valid JSON object.")
            case .unsupportedPlatform:
                return NSLocalizedString("This operation is not supported on the current platform. Mac Catalyst is required.", comment: "Displayed when an operation requires Mac Catalyst (e.g., APK analysis) but is invoked on iOS.")
            case .custom(let errorMessage):
                return NSLocalizedString(errorMessage, comment: "")
            }
        }
    }
