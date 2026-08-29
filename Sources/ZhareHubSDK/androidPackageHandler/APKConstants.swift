//
//  APKConstants.swift
//  ZhareHubSDK
//
//  Shared string constants for aapt2-based APK extraction, covering values
//  that are either duplicated across files or fail silently at runtime
//  (not at compile time) if mistyped.
//

enum APKConstants {
    static let notAvailable = "N/A"
    static let resourcePrefix = "res/"

    enum AAPT2 {
        static let dumpVerb = "dump"
        static let fileFlag = "--file"

        enum Command: String {
            case badging
            case xmltree
            case resources
        }
    }
}
