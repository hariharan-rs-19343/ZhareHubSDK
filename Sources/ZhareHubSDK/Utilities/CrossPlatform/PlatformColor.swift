//
//  PlatformColor.swift
//  ZhareHubSDK
//
//  Cross-platform color alias, mirroring SUICore's `PlatformImage` convention.
//  `canImport(UIKit)` covers iOS, Mac Catalyst, tvOS, visionOS, and watchOS.
//

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformColor = NSColor
#endif
