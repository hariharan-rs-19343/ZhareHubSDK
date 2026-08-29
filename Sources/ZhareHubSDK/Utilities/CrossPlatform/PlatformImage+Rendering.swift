//
//  PlatformImage+Rendering.swift
//  ZhareHubSDK
//
//  Cross-platform bitmap rendering helpers built on SUICore's `PlatformImage`
//  typealias (`UIImage` on UIKit platforms, `NSImage` on macOS).
//

import CoreGraphics
import SUICore

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension PlatformImage {

    /// Renders a bitmap image by drawing into a `CGContext`, using a top-left-origin,
    /// y-down coordinate system on every platform (matching `UIGraphicsImageRenderer`).
    static func rendered(size: CGSize, _ draw: @escaping (CGContext) -> Void) -> PlatformImage {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in draw(ctx.cgContext) }
        #else
        NSImage(size: size, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(ctx)
            return true
        }
        #endif
    }

    /// The image's size in actual pixels, accounting for display scale on UIKit
    /// platforms and bitmap representation size on macOS.
    var pixelSize: CGSize {
        #if canImport(UIKit)
        CGSize(width: size.width * scale, height: size.height * scale)
        #else
        guard let rep = representations.first else { return size }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        #endif
    }
}

#if !canImport(UIKit)
public extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
