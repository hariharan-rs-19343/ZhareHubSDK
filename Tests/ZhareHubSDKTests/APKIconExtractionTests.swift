import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import ZhareHubSDK

// MARK: - Parsing / rendering (no external tools)

@Test func parsesCompiledGradientResource() throws {
    let xml = """
    N: android=http://schemas.android.com/apk/res/android (line=0)
      N: aapt=http://schemas.android.com/aapt (line=0)
        E: gradient (line=14)
          A: http://schemas.android.com/apk/res/android:angle(0x010101a0)=0.000000e+00
          A: http://schemas.android.com/apk/res/android:type(0x010101a1)=0
          A: http://schemas.android.com/apk/res/android:startX(0x01010510)=42.9492
          A: http://schemas.android.com/apk/res/android:startY(0x01010511)=49.5979
          A: http://schemas.android.com/apk/res/android:endX(0x01010512)=85.8476
          A: http://schemas.android.com/apk/res/android:endY(0x01010513)=92.4963
            E: item (line=17)
              A: http://schemas.android.com/apk/res/android:color(0x010101a5)=#44000000
              A: http://schemas.android.com/apk/res/android:offset(0x01010514)=0.000000e+00
            E: item (line=20)
              A: http://schemas.android.com/apk/res/android:color(0x010101a5)=#00000000
              A: http://schemas.android.com/apk/res/android:offset(0x01010514)=1
    """
    let root = try #require(XmlTreeParser.parse(xml))
    let paint = try #require(XmlTreeParser.parseGradient(from: root))
    guard case .linearGradient(let start, let end, let stops) = paint else {
        Issue.record("Expected linear gradient, got \(paint)")
        return
    }
    #expect(start == CGPoint(x: 42.9492, y: 49.5979))
    #expect(end == CGPoint(x: 85.8476, y: 92.4963))
    #expect(stops.map(\.offset) == [0, 1])
}

@Test func parsesResourceFillAndIntegerFillType() throws {
    let xml = """
    N: android=http://schemas.android.com/apk/res/android (line=6)
      E: vector (line=6)
        A: http://schemas.android.com/apk/res/android:viewportWidth(0x01010402)=108
        A: http://schemas.android.com/apk/res/android:viewportHeight(0x01010403)=108
          E: path (line=7)
            A: http://schemas.android.com/apk/res/android:fillColor(0x01010404)=@0x7f040000
            A: http://schemas.android.com/apk/res/android:pathData(0x01010405)="M0,0h10v10z" (Raw: "M0,0h10v10z")
            A: http://schemas.android.com/apk/res/android:fillType(0x0101051e)=1
    """
    let root = try #require(XmlTreeParser.parse(xml))
    let drawable = try #require(XmlTreeParser.parseVectorDrawable(from: root))
    guard case .path(let path) = try #require(drawable.elements.first) else {
        Issue.record("Expected a path element")
        return
    }
    #expect(path.fillRef == "@0x7f040000")
    #expect(path.fill == nil)
    #expect(path.fillType == .evenOdd)
    #expect(path.hasDeclaredPaint)
}

@Test @MainActor func rendersDefaultAndroidIcon() throws {
    let image = try #require(APKDefaultIcon.render())
    let png = try #require(image.pngData())
    let center = try #require(pixel(in: png, atUnit: CGPoint(x: 0.5, y: 0.5)))   // robot head
    let shadow = try #require(pixel(in: png, atUnit: CGPoint(x: 0.79, y: 0.79))) // under the shadow
    #expect(center.r > 0.9 && center.g > 0.9 && center.b > 0.9)
    #expect(shadow.g > 0.6 && shadow.g > shadow.r)
}

// MARK: - Real APKs (opt-in)
//
// Set ZH_AAPT2_PATH plus ZH_ADAPTIVE_ICON_APK and/or ZH_NO_ICON_APK to run, e.g.
//   ZH_AAPT2_PATH=~/Android/Sdk/build-tools/36.0.0/aapt2 \
//   ZH_ADAPTIVE_ICON_APK=haptic-feedback-demos.apk ZH_NO_ICON_APK=com.memobile.adaptive_1.0.apk
// Optionally set ZH_ICON_OUTPUT_DIR to dump the extracted PNGs for inspection.

#if os(macOS)
private let env = ProcessInfo.processInfo.environment

@Test(.enabled(if: env["ZH_AAPT2_PATH"] != nil && env["ZH_ADAPTIVE_ICON_APK"] != nil))
func extractsAdaptiveIconWithGradientShadow() async throws {
    let result = try await extractIcon(apkPath: env["ZH_ADAPTIVE_ICON_APK"]!)
    #expect(result.strategy == .vectorRendered)
    let png = try #require(await MainActor.run { result.image.pngData() })
    try dump(png, as: "adaptive-icon.png")
    // Previously filled solid black because the gradient fill reference was unresolved.
    let shadow = try #require(pixel(in: png, atUnit: CGPoint(x: 0.79, y: 0.79)))
    #expect(shadow.g > 0.6 && shadow.g > shadow.r)
}

@Test(.enabled(if: env["ZH_AAPT2_PATH"] != nil && env["ZH_NO_ICON_APK"] != nil))
func fallsBackToDefaultIconWhenAPKHasNone() async throws {
    let url = URL(filePath: env["ZH_NO_ICON_APK"]!)
    let handler = APKExtractionHandler(shell: ProcessShellExecutor(), aapt2Path: env["ZH_AAPT2_PATH"]!)
    let model = try await handler.initiateAPKExtraction(from: url, fileName: url.lastPathComponent).get()
    #expect(model.isContentAvailable())

    let result = try await extractIcon(apkPath: url.path)
    #expect(result.strategy == .defaultIcon)
    try dump(try #require(model.appIcon), as: "default-icon.png")
}

private func extractIcon(apkPath: String) async throws -> APKIconResult {
    let aapt2 = env["ZH_AAPT2_PATH"]!
    let shell = ProcessShellExecutor()
    let badging = try await shell.run(executablePath: aapt2, arguments: ["dump", "badging", apkPath])
    return try #require(await DefaultAPKIconExtractor().extractIcon(
        from: URL(filePath: apkPath),
        badgingOutput: badging.output,
        parser: DefaultAPKBadgingParser(),
        shell: shell,
        aapt2Path: aapt2
    ))
}

private func dump(_ png: Data, as name: String) throws {
    guard let dir = env["ZH_ICON_OUTPUT_DIR"] else { return }
    try png.write(to: URL(filePath: dir).appending(component: name))
}

private struct ProcessShellExecutor: ShellExecutorProtocol {
    var isAvailable: Bool { true }

    func run(executablePath: String, arguments: [String], environment: [String: String]?,
             workingDirectory: String?, timeout: TimeInterval?) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(filePath: executablePath)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ShellResult(output: String(decoding: outData, as: UTF8.self),
                           errorOutput: String(decoding: errData, as: UTF8.self),
                           exitCode: process.terminationStatus)
    }
}
#endif

// MARK: - Helpers

/// Samples the RGBA color at a unit-space point (0...1, top-left origin) of a PNG.
private func pixel(in png: Data, atUnit point: CGPoint) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    var bytes = [UInt8](repeating: 0, count: 4)
    guard let ctx = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    let x = CGFloat(image.width) * point.x
    let y = CGFloat(image.height) * (1 - point.y) // CG origin is bottom-left
    ctx.draw(image, in: CGRect(x: -x, y: -y, width: CGFloat(image.width), height: CGFloat(image.height)))
    return (CGFloat(bytes[0]) / 255, CGFloat(bytes[1]) / 255, CGFloat(bytes[2]) / 255, CGFloat(bytes[3]) / 255)
}
