//
//  APKDefaultIcon.swift
//  ZhareHubSDK
//
//  Android's stock adaptive launcher icon (the Android Studio template:
//  green grid background + robot foreground), used when an APK declares no
//  icon at all. Built from the template's vector data and rendered with the
//  same `VectorDrawableRenderer` / adaptive-icon compositing as real icons.
//

import CoreGraphics
import SUICore

enum APKDefaultIcon {

    private static let viewport: CGFloat = 108

    @MainActor
    static func render(size: CGSize = CGSize(width: 192, height: 192)) -> PlatformImage? {
        let background = VectorDrawableRenderer.render(makeDrawable(backgroundPaths), size: size)
        let foreground = VectorDrawableRenderer.render(makeDrawable(foregroundPaths), size: size)
        return APKVectorIconParser.composite(background: background, foreground: foreground, size: size)
    }

    private static func makeDrawable(_ paths: [VectorDrawable.VectorPath]) -> VectorDrawable {
        var drawable = VectorDrawable()
        drawable.viewportWidth = viewport
        drawable.viewportHeight = viewport
        drawable.width = viewport
        drawable.height = viewport
        drawable.elements = paths.map(VectorDrawable.Element.path)
        return drawable
    }

    private static func color(_ hex: String) -> VectorPaint? {
        XmlTreeParser.parseColor(hex).map(VectorPaint.color)
    }

    // MARK: - Layers (res/drawable/ic_launcher_background.xml / ic_launcher_foreground.xml)

    private static var backgroundPaths: [VectorDrawable.VectorPath] {
        var paths = [VectorDrawable.VectorPath(pathData: "M0,0h108v108h-108z", fill: color("#3DDC84"))]

        func gridLine(_ pathData: String) -> VectorDrawable.VectorPath {
            VectorDrawable.VectorPath(pathData: pathData, stroke: color("#33FFFFFF"), strokeWidth: 0.8)
        }
        for v in stride(from: 9, through: 99, by: 10) {
            paths.append(gridLine("M\(v),0L\(v),108"))
            paths.append(gridLine("M0,\(v)L108,\(v)"))
        }
        for v in stride(from: 29, through: 79, by: 10) {
            paths.append(gridLine("M19,\(v)L89,\(v)"))
            paths.append(gridLine("M\(v),19L\(v),89"))
        }
        return paths
    }

    private static var foregroundPaths: [VectorDrawable.VectorPath] {
        let shadowStops = [("#44000000", 0.0), ("#00000000", 1.0)].compactMap { hex, offset in
            XmlTreeParser.parseColor(hex).map { VectorPaint.Stop(color: $0, offset: offset) }
        }
        let shadow = VectorDrawable.VectorPath(
            pathData: "M31,63.928c0,0 6.4,-11 12.1,-13.1c7.2,-2.6 26,-1.4 26,-1.4l38.1,38.1L107,108.928l-32,-1L31,63.928z",
            fill: .linearGradient(
                start: CGPoint(x: 42.9492, y: 49.5979),
                end: CGPoint(x: 85.8476, y: 92.4963),
                stops: shadowStops
            )
        )
        let robot = VectorDrawable.VectorPath(
            pathData: "M65.3,45.828l3.8,-6.6c0.2,-0.4 0.1,-0.9 -0.3,-1.1c-0.4,-0.2 -0.9,-0.1 -1.1,0.3l-3.9,6.7c-6.3,-2.8 -13.4,-2.8 -19.7,0l-3.9,-6.7c-0.2,-0.4 -0.7,-0.5 -1.1,-0.3C38.8,38.328 38.7,38.828 38.9,39.228l3.8,6.6C36.2,49.428 31.7,56.028 31,63.928h46C76.3,56.028 71.8,49.428 65.3,45.828zM43.4,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2c-0.3,-0.7 -0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C45.3,56.528 44.5,57.328 43.4,57.328L43.4,57.328zM64.6,57.328c-0.8,0 -1.5,-0.5 -1.8,-1.2s-0.1,-1.5 0.4,-2.1c0.5,-0.5 1.4,-0.7 2.1,-0.4c0.7,0.3 1.2,1 1.2,1.8C66.5,56.528 65.6,57.328 64.6,57.328L64.6,57.328z",
            fill: color("#FFFFFF")
        )
        return [shadow, robot]
    }
}
