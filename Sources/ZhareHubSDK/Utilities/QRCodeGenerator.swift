//
//  QRCodeGenerator.swift
//  ZhareHubSDK
//
//  Created by Hariharan R S on 27/05/26.
//

import Foundation
import CoreImage.CIFilterBuiltins
import UIKit

/// A thread-safe utility for generating QR code images from string content.
///
/// ## Usage
///
/// ```swift
/// // Basic usage with default settings
/// let pngData = try QRCodeGenerator.generate(from: "https://example.com")
///
/// // Custom scale and correction level
/// let pngData = try QRCodeGenerator.generate(
///     from: "https://example.com",
///     scaleFactor: .extraLarge,
///     correctionLevel: .high
/// )
///
/// // Convert to UIImage
/// if let image = UIImage(data: pngData) {
///     imageView.image = image
/// }
/// ```
public enum QRCodeGenerator: Sendable {

    // MARK: - Public Types

    /// Error correction level for QR code generation.
    ///
    /// Higher levels allow more of the QR code to be damaged while still remaining scannable,
    /// at the cost of increased data density.
    public enum CorrectionLevel: String, Sendable {
        /// Recovers up to 7% of data loss.
        case low = "L"
        /// Recovers up to 15% of data loss.
        case medium = "M"
        /// Recovers up to 25% of data loss.
        case quartile = "Q"
        /// Recovers up to 30% of data loss.
        case high = "H"
    }

    /// Scale factor applied to the generated QR code image.
    ///
    /// The raw QR code output from Core Image is very small (typically ~21×21 to ~177×177 points
    /// depending on content length). The scale factor multiplies these dimensions to produce
    /// a usable image resolution.
    public enum ScaleFactor: CGFloat, Sendable {
        /// 2.5x scale — suitable for thumbnails.
        case small = 2.5
        /// 5x scale — suitable for standard display.
        case medium = 5.0
        /// 7.5x scale — suitable for high-resolution display.
        case large = 7.5
        /// 10x scale — suitable for print or large display.
        case extraLarge = 10.0
    }

    /// Errors that can occur during QR code generation.
    public enum GenerationError: ErrorProtocol, Sendable {
        /// The input string could not be encoded to UTF-8 data.
        case encodingFailed
        /// Core Image failed to produce a QR code output.
        case filterOutputFailed
        /// The rendered image could not be converted to PNG data.
        case pngConversionFailed

        public var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "The input string could not be encoded to UTF-8."
            case .filterOutputFailed:
                return "QR code generation failed. The Core Image filter produced no output."
            case .pngConversionFailed:
                return "Failed to convert the QR code image to PNG data."
            }
        }
    }

    // MARK: - Public API

    /// Generates a QR code as PNG data from the given string.
    ///
    /// - Parameters:
    ///   - string: The content to encode in the QR code.
    ///   - scaleFactor: The scale multiplier for the output image (default: `.large`).
    ///   - correctionLevel: The error correction level (default: `.medium`).
    ///   - isOpaque: Whether to render with a white background (`true`) or transparent background (`false`). Default is `false`.
    /// - Returns: PNG-encoded image data of the generated QR code.
    /// - Throws: ``GenerationError`` if encoding, filter output, or PNG conversion fails.
    public static func generate(
        from string: String,
        scaleFactor: ScaleFactor = .large,
        correctionLevel: CorrectionLevel = .medium,
        isOpaque: Bool = false
    ) throws(GenerationError) -> Data {
        guard let messageData = string.data(using: .utf8) else {
            throw .encodingFailed
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(messageData, forKey: "inputMessage")
        filter.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else {
            throw .filterOutputFailed
        }

        let finalImage: CIImage

        if isOpaque {
            finalImage = ciImage
        } else {
            // Make white background transparent using a color matrix:
            // RGB output = 0 (black), Alpha = 1 - R (black pixels opaque, white pixels transparent)
            let colorMatrixFilter = CIFilter(name: "CIColorMatrix")!
            colorMatrixFilter.setValue(ciImage, forKey: kCIInputImageKey)
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
            colorMatrixFilter.setValue(CIVector(x: -1, y: 0, z: 0, w: 0), forKey: "inputAVector")
            colorMatrixFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBiasVector")

            guard let transparentImage = colorMatrixFilter.outputImage else {
                throw .filterOutputFailed
            }
            finalImage = transparentImage
        }

        let scale = scaleFactor.rawValue
        let scaledImage = finalImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(
            scaledImage,
            from: scaledImage.extent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        ) else {
            throw .pngConversionFailed
        }

        guard let pngData = UIImage(cgImage: cgImage).pngData() else {
            throw .pngConversionFailed
        }

        return pngData
    }
}
