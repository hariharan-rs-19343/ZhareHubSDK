//
//  APKVectorIconParser.swift
//  ZhareHubSDK
//
//  Ported from ApkAnalyzer POC. Renders Android VectorDrawable / adaptive-icon XML
//  via aapt2 `dump xmltree` + `dump resources` (executed through an injected
//  `ShellExecutorProtocol`) and Core Graphics.
//

import Foundation
import UIKit
import CoreGraphics

// MARK: - Android Path Data Tokenizer & Parser

struct AndroidPathDataParser {

    enum Command {
        case moveTo(CGPoint, Bool)
        case lineTo(CGPoint, Bool)
        case horizontalLineTo(CGFloat, Bool)
        case verticalLineTo(CGFloat, Bool)
        case cubicBezier(CGPoint, CGPoint, CGPoint, Bool)
        case smoothCubic(CGPoint, CGPoint, Bool)
        case quadBezier(CGPoint, CGPoint, Bool)
        case smoothQuad(CGPoint, Bool)
        case arc(CGFloat, CGFloat, CGFloat, Bool, Bool, CGPoint, Bool)
        case close
    }

    static func parse(_ pathData: String) -> [Command] {
        let tokens = tokenize(pathData)
        var commands: [Command] = []
        var i = 0

        while i < tokens.count {
            guard case .letter(let cmd) = tokens[i] else { i += 1; continue }
            let abs = cmd.isUppercase
            let c = cmd.uppercased()
            i += 1

            switch c {
            case "M":
                var first = true
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let p = readPoint(tokens, &i) else { break }
                    if first {
                        commands.append(.moveTo(p, abs)); first = false
                    } else {
                        commands.append(.lineTo(p, abs))
                    }
                }
            case "L":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let p = readPoint(tokens, &i) else { break }
                    commands.append(.lineTo(p, abs))
                }
            case "H":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let v = readNumber(tokens, &i) else { break }
                    commands.append(.horizontalLineTo(v, abs))
                }
            case "V":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let v = readNumber(tokens, &i) else { break }
                    commands.append(.verticalLineTo(v, abs))
                }
            case "C":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let cp1 = readPoint(tokens, &i),
                          let cp2 = readPoint(tokens, &i),
                          let end = readPoint(tokens, &i) else { break }
                    commands.append(.cubicBezier(cp1, cp2, end, abs))
                }
            case "S":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let cp2 = readPoint(tokens, &i),
                          let end = readPoint(tokens, &i) else { break }
                    commands.append(.smoothCubic(cp2, end, abs))
                }
            case "Q":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let cp = readPoint(tokens, &i),
                          let end = readPoint(tokens, &i) else { break }
                    commands.append(.quadBezier(cp, end, abs))
                }
            case "T":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let end = readPoint(tokens, &i) else { break }
                    commands.append(.smoothQuad(end, abs))
                }
            case "A":
                while i < tokens.count, case .number(_) = tokens[i] {
                    guard let rx = readNumber(tokens, &i),
                          let ry = readNumber(tokens, &i),
                          let rot = readNumber(tokens, &i),
                          let lf = readNumber(tokens, &i),
                          let sf = readNumber(tokens, &i),
                          let end = readPoint(tokens, &i) else { break }
                    commands.append(.arc(rx, ry, rot, lf != 0, sf != 0, end, abs))
                }
            case "Z":
                commands.append(.close)
            default:
                break
            }
        }

        return commands
    }

    static func buildPath(from commands: [Command]) -> CGPath {
        let path = CGMutablePath()
        var current = CGPoint.zero
        var lastControl: CGPoint?
        var subpathStart = CGPoint.zero

        for cmd in commands {
            switch cmd {
            case .moveTo(let p, let abs):
                let pt = abs ? p : CGPoint(x: current.x + p.x, y: current.y + p.y)
                path.move(to: pt); current = pt; subpathStart = pt; lastControl = nil
            case .lineTo(let p, let abs):
                let pt = abs ? p : CGPoint(x: current.x + p.x, y: current.y + p.y)
                path.addLine(to: pt); current = pt; lastControl = nil
            case .horizontalLineTo(let x, let abs):
                let pt = CGPoint(x: abs ? x : current.x + x, y: current.y)
                path.addLine(to: pt); current = pt; lastControl = nil
            case .verticalLineTo(let y, let abs):
                let pt = CGPoint(x: current.x, y: abs ? y : current.y + y)
                path.addLine(to: pt); current = pt; lastControl = nil
            case .cubicBezier(let cp1, let cp2, let end, let abs):
                let c1 = abs ? cp1 : CGPoint(x: current.x + cp1.x, y: current.y + cp1.y)
                let c2 = abs ? cp2 : CGPoint(x: current.x + cp2.x, y: current.y + cp2.y)
                let e  = abs ? end  : CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addCurve(to: e, control1: c1, control2: c2)
                lastControl = c2; current = e
            case .smoothCubic(let cp2, let end, let abs):
                let c1: CGPoint
                if let lc = lastControl { c1 = CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y) } else { c1 = current }
                let c2 = abs ? cp2 : CGPoint(x: current.x + cp2.x, y: current.y + cp2.y)
                let e  = abs ? end  : CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addCurve(to: e, control1: c1, control2: c2)
                lastControl = c2; current = e
            case .quadBezier(let cp, let end, let abs):
                let c = abs ? cp  : CGPoint(x: current.x + cp.x, y: current.y + cp.y)
                let e = abs ? end : CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addQuadCurve(to: e, control: c)
                lastControl = c; current = e
            case .smoothQuad(let end, let abs):
                let c: CGPoint
                if let lc = lastControl { c = CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y) } else { c = current }
                let e = abs ? end : CGPoint(x: current.x + end.x, y: current.y + end.y)
                path.addQuadCurve(to: e, control: c)
                lastControl = c; current = e
            case .arc(let rx, let ry, let rotation, let largeArc, let sweep, let end, let abs):
                let e = abs ? end : CGPoint(x: current.x + end.x, y: current.y + end.y)
                addArc(to: path, from: current, to: e, rx: rx, ry: ry,
                       rotation: rotation * .pi / 180, largeArc: largeArc, sweep: sweep)
                current = e; lastControl = nil
            case .close:
                path.closeSubpath()
                current = subpathStart; lastControl = nil
            }
        }

        return path
    }

    private enum Token { case letter(Character); case number(CGFloat) }

    private static func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch.isLetter {
                tokens.append(.letter(ch)); i += 1
            } else if ch == "-" || ch == "+" || ch == "." || ch.isNumber {
                var numStr = ""
                var hasDot = false
                if ch == "-" || ch == "+" { numStr.append(ch); i += 1 }
                while i < chars.count {
                    let c = chars[i]
                    if c == "." {
                        if hasDot { break }
                        hasDot = true; numStr.append(c); i += 1
                    } else if c.isNumber {
                        numStr.append(c); i += 1
                    } else { break }
                }
                if let val = Double(numStr) { tokens.append(.number(CGFloat(val))) }
            } else {
                i += 1
            }
        }
        return tokens
    }

    private static func readNumber(_ tokens: [Token], _ i: inout Int) -> CGFloat? {
        guard i < tokens.count, case .number(let v) = tokens[i] else { return nil }
        i += 1; return v
    }

    private static func readPoint(_ tokens: [Token], _ i: inout Int) -> CGPoint? {
        guard let x = readNumber(tokens, &i), let y = readNumber(tokens, &i) else { return nil }
        return CGPoint(x: x, y: y)
    }

    private static func addArc(to path: CGMutablePath, from p1: CGPoint, to p2: CGPoint,
                               rx: CGFloat, ry: CGFloat, rotation: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        guard rx > 0, ry > 0 else { path.addLine(to: p2); return }
        if p1.x == p2.x && p1.y == p2.y { return }

        var rx = abs(rx), ry = abs(ry)
        let cosAngle = cos(rotation), sinAngle = sin(rotation)
        let dx = (p1.x - p2.x) / 2, dy = (p1.y - p2.y) / 2
        let x1p = cosAngle * dx + sinAngle * dy
        let y1p = -sinAngle * dx + cosAngle * dy

        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda); rx *= s; ry *= s
        }

        let rxSq = rx * rx, rySq = ry * ry
        let x1pSq = x1p * x1p, y1pSq = y1p * y1p
        var sq = max(0, (rxSq * rySq - rxSq * y1pSq - rySq * x1pSq) / (rxSq * y1pSq + rySq * x1pSq))
        sq = sqrt(sq) * (largeArc == sweep ? -1 : 1)

        let cxp = sq * rx * y1p / ry
        let cyp = -sq * ry * x1p / rx
        let cx = cosAngle * cxp - sinAngle * cyp + (p1.x + p2.x) / 2
        let cy = sinAngle * cxp + cosAngle * cyp + (p1.y + p2.y) / 2

        let theta1 = angleBetween(ux: 1, uy: 0, vx: (x1p - cxp) / rx, vy: (y1p - cyp) / ry)
        var dTheta = angleBetween(ux: (x1p - cxp) / rx, uy: (y1p - cyp) / ry,
                                  vx: (-x1p - cxp) / rx, vy: (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        else if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segAngle = dTheta / CGFloat(segments)
        for s in 0..<segments {
            let t1 = theta1 + CGFloat(s) * segAngle
            let t2 = t1 + segAngle
            addArcSegment(to: path, cx: cx, cy: cy, rx: rx, ry: ry, rotation: rotation, t1: t1, t2: t2)
        }
    }

    private static func addArcSegment(to path: CGMutablePath, cx: CGFloat, cy: CGFloat,
                                      rx: CGFloat, ry: CGFloat, rotation: CGFloat,
                                      t1: CGFloat, t2: CGFloat) {
        let alpha = sin(t2 - t1) * (sqrt(4 + 3 * pow(tan((t2 - t1) / 2), 2)) - 1) / 3
        let cosR = cos(rotation), sinR = sin(rotation)

        func ellipsePoint(_ t: CGFloat) -> CGPoint {
            let x = rx * cos(t), y = ry * sin(t)
            return CGPoint(x: cosR * x - sinR * y + cx, y: sinR * x + cosR * y + cy)
        }
        func ellipseDeriv(_ t: CGFloat) -> CGPoint {
            let x = -rx * sin(t), y = ry * cos(t)
            return CGPoint(x: cosR * x - sinR * y, y: sinR * x + cosR * y)
        }

        let ep1 = ellipsePoint(t1), ep2 = ellipsePoint(t2)
        let d1 = ellipseDeriv(t1), d2 = ellipseDeriv(t2)
        let cp1 = CGPoint(x: ep1.x + alpha * d1.x, y: ep1.y + alpha * d1.y)
        let cp2 = CGPoint(x: ep2.x - alpha * d2.x, y: ep2.y - alpha * d2.y)

        path.addCurve(to: ep2, control1: cp1, control2: cp2)
    }

    private static func angleBetween(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        var angle = acos(max(-1, min(1, dot / len)))
        if ux * vy - uy * vx < 0 { angle = -angle }
        return angle
    }
}

// MARK: - Vector Drawable Model

struct VectorDrawable {
    var viewportWidth: CGFloat = 24
    var viewportHeight: CGFloat = 24
    var width: CGFloat = 24
    var height: CGFloat = 24
    var elements: [Element] = []

    enum Element {
        case path(VectorPath)
        case group(VectorGroup)
    }

    struct VectorPath {
        var pathData: String = ""
        var fillColor: UIColor?
        var strokeColor: UIColor?
        var strokeWidth: CGFloat = 0
        var fillAlpha: CGFloat = 1
        var strokeAlpha: CGFloat = 1
        var fillType: CGPathFillRule = .winding
    }

    struct VectorGroup {
        var translateX: CGFloat = 0
        var translateY: CGFloat = 0
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var rotation: CGFloat = 0
        var pivotX: CGFloat = 0
        var pivotY: CGFloat = 0
        var elements: [Element] = []
    }
}

// MARK: - aapt2 xmltree Parser

struct XmlTreeParser {

    struct XmlNode {
        let tag: String
        let depth: Int
        var attributes: [String: String] = [:]
        var children: [XmlNode] = []
    }

    static func parse(_ output: String) -> XmlNode? {
        let lines = output.components(separatedBy: "\n")
        var nodes: [(node: XmlNode, depth: Int)] = []

        for line in lines {
            if let (depth, tag) = parseElementLine(line) {
                nodes.append((XmlNode(tag: tag, depth: depth), depth))
            } else if let (depth, key, value) = parseAttributeLine(line), !nodes.isEmpty {
                for idx in stride(from: nodes.count - 1, through: 0, by: -1) {
                    if nodes[idx].depth < depth {
                        nodes[idx].node.attributes[key] = value
                        break
                    }
                }
            }
        }

        guard !nodes.isEmpty else { return nil }

        var stack: [(node: XmlNode, depth: Int)] = []
        for (node, depth) in nodes {
            while let last = stack.last, last.depth >= depth {
                let child = stack.removeLast()
                if let parentIdx = stack.indices.last {
                    stack[parentIdx].node.children.append(child.node)
                }
            }
            stack.append((node, depth))
        }
        while stack.count > 1 {
            let child = stack.removeLast()
            if let parentIdx = stack.indices.last {
                stack[parentIdx].node.children.append(child.node)
            }
        }

        return stack.first?.node
    }

    private static func parseElementLine(_ line: String) -> (Int, String)? {
        let pattern = "^(\\s*)E:\\s+(\\S+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3 else { return nil }
        let indent = (line as NSString).substring(with: match.range(at: 1))
        let tag = (line as NSString).substring(with: match.range(at: 2))
        return (indent.count / 2, tag)
    }

    private static func parseAttributeLine(_ line: String) -> (Int, String, String)? {
        let pattern = "^(\\s*)A:\\s+(?:http://[^:]+:)?(?:android:)?(\\w+)(?:\\([^)]*\\))?=(?:\\(type [^)]*\\))?(.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4 else { return nil }
        let indent = (line as NSString).substring(with: match.range(at: 1))
        let key = (line as NSString).substring(with: match.range(at: 2))
        var value = (line as NSString).substring(with: match.range(at: 3))
        value = value.trimmingCharacters(in: .whitespaces)
        if let rawRange = value.range(of: " (Raw: ") { value = String(value[..<rawRange.lowerBound]) }
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return (indent.count / 2, key, value)
    }

    static func parseVectorDrawable(from root: XmlNode) -> VectorDrawable? {
        guard root.tag == "vector" else { return nil }
        var vd = VectorDrawable()
        vd.viewportWidth = parseDimension(root.attributes["viewportWidth"]) ?? 24
        vd.viewportHeight = parseDimension(root.attributes["viewportHeight"]) ?? 24
        vd.width = parseDimension(root.attributes["width"]) ?? vd.viewportWidth
        vd.height = parseDimension(root.attributes["height"]) ?? vd.viewportHeight
        vd.elements = parseElements(root.children)
        return vd
    }

    private static func parseElements(_ nodes: [XmlNode]) -> [VectorDrawable.Element] {
        var elements: [VectorDrawable.Element] = []
        for node in nodes {
            switch node.tag {
            case "path":
                var vp = VectorDrawable.VectorPath()
                vp.pathData = node.attributes["pathData"] ?? ""
                vp.fillColor = parseColor(node.attributes["fillColor"])
                vp.strokeColor = parseColor(node.attributes["strokeColor"])
                vp.strokeWidth = parseDimension(node.attributes["strokeWidth"]) ?? 0
                vp.fillAlpha = parseDimension(node.attributes["fillAlpha"]) ?? 1
                vp.strokeAlpha = parseDimension(node.attributes["strokeAlpha"]) ?? 1
                if node.attributes["fillType"] == "evenOdd" { vp.fillType = .evenOdd }
                elements.append(.path(vp))
            case "group":
                var vg = VectorDrawable.VectorGroup()
                vg.translateX = parseDimension(node.attributes["translateX"]) ?? 0
                vg.translateY = parseDimension(node.attributes["translateY"]) ?? 0
                vg.scaleX = parseDimension(node.attributes["scaleX"]) ?? 1
                vg.scaleY = parseDimension(node.attributes["scaleY"]) ?? 1
                vg.rotation = parseDimension(node.attributes["rotation"]) ?? 0
                vg.pivotX = parseDimension(node.attributes["pivotX"]) ?? 0
                vg.pivotY = parseDimension(node.attributes["pivotY"]) ?? 0
                vg.elements = parseElements(node.children)
                elements.append(.group(vg))
            default:
                break
            }
        }
        return elements
    }

    static func parseDimension(_ value: String?) -> CGFloat? {
        guard var str = value?.trimmingCharacters(in: .whitespaces), !str.isEmpty else { return nil }
        for suffix in ["dip", "dp", "sp", "px"] {
            if str.hasSuffix(suffix) { str = String(str.dropLast(suffix.count)); break }
        }
        return Double(str).map { CGFloat($0) }
    }

    static func parseColor(_ value: String?) -> UIColor? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), value.hasPrefix("#") else { return nil }
        let hex = String(value.dropFirst())
        var rgba: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgba) else { return nil }
        let r, g, b, a: CGFloat
        switch hex.count {
        case 8:
            a = CGFloat((rgba >> 24) & 0xFF) / 255
            r = CGFloat((rgba >> 16) & 0xFF) / 255
            g = CGFloat((rgba >> 8) & 0xFF) / 255
            b = CGFloat(rgba & 0xFF) / 255
        case 6:
            a = 1
            r = CGFloat((rgba >> 16) & 0xFF) / 255
            g = CGFloat((rgba >> 8) & 0xFF) / 255
            b = CGFloat(rgba & 0xFF) / 255
        case 4:
            a = CGFloat((rgba >> 12) & 0xF) / 15
            r = CGFloat((rgba >> 8) & 0xF) / 15
            g = CGFloat((rgba >> 4) & 0xF) / 15
            b = CGFloat(rgba & 0xF) / 15
        case 3:
            a = 1
            r = CGFloat((rgba >> 8) & 0xF) / 15
            g = CGFloat((rgba >> 4) & 0xF) / 15
            b = CGFloat(rgba & 0xF) / 15
        default:
            return nil
        }
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Vector Drawable Renderer

struct VectorDrawableRenderer {

    @MainActor
    static func render(_ drawable: VectorDrawable, size: CGSize? = nil) -> UIImage? {
        let outputSize = size ?? CGSize(width: drawable.width, height: drawable.height)
        guard outputSize.width > 0, outputSize.height > 0 else { return nil }

        let renderSize = CGSize(
            width: max(outputSize.width, 192),
            height: max(outputSize.height, 192)
        )

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let scaleX = renderSize.width / drawable.viewportWidth
            let scaleY = renderSize.height / drawable.viewportHeight
            cgCtx.scaleBy(x: scaleX, y: scaleY)
            renderElements(drawable.elements, in: cgCtx)
        }
    }

    private static func renderElements(_ elements: [VectorDrawable.Element], in ctx: CGContext) {
        for element in elements {
            switch element {
            case .path(let p): renderPath(p, in: ctx)
            case .group(let g): renderGroup(g, in: ctx)
            }
        }
    }

    private static func renderPath(_ vPath: VectorDrawable.VectorPath, in ctx: CGContext) {
        guard !vPath.pathData.isEmpty else { return }
        let commands = AndroidPathDataParser.parse(vPath.pathData)
        let cgPath = AndroidPathDataParser.buildPath(from: commands)

        ctx.saveGState()
        if let fillColor = vPath.fillColor {
            ctx.setFillColor(fillColor.withAlphaComponent(vPath.fillAlpha).cgColor)
            ctx.addPath(cgPath)
            ctx.fillPath(using: vPath.fillType)
        }
        if let strokeColor = vPath.strokeColor, vPath.strokeWidth > 0 {
            ctx.setStrokeColor(strokeColor.withAlphaComponent(vPath.strokeAlpha).cgColor)
            ctx.setLineWidth(vPath.strokeWidth)
            ctx.addPath(cgPath)
            ctx.strokePath()
        }
        if vPath.fillColor == nil && (vPath.strokeColor == nil || vPath.strokeWidth <= 0) {
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.addPath(cgPath)
            ctx.fillPath(using: vPath.fillType)
        }
        ctx.restoreGState()
    }

    private static func renderGroup(_ vGroup: VectorDrawable.VectorGroup, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: vGroup.pivotX + vGroup.translateX, y: vGroup.pivotY + vGroup.translateY)
        ctx.rotate(by: vGroup.rotation * .pi / 180)
        ctx.scaleBy(x: vGroup.scaleX, y: vGroup.scaleY)
        ctx.translateBy(x: -vGroup.pivotX, y: -vGroup.pivotY)
        renderElements(vGroup.elements, in: ctx)
        ctx.restoreGState()
    }
}

// MARK: - Vector Icon Parser (top-level)

/// Resolves Android vector / adaptive-icon XML inside an APK to a `UIImage`,
/// using `aapt2 dump xmltree` and `aapt2 dump resources` via an injected shell.
///
/// Marked `@unchecked Sendable` because instances are only used sequentially
/// inside a single async extraction Task; the internal `resourceDumpCache`
/// is never accessed concurrently.
final class APKVectorIconParser: @unchecked Sendable {

    private let aapt2Path: String
    private let shell: ShellExecutorProtocol
    private var resourceDumpCache: [String: String?] = [:]

    init(aapt2Path: String, shell: ShellExecutorProtocol) {
        self.aapt2Path = aapt2Path
        self.shell = shell
    }

    func renderIcon(from apkPath: URL,
                    iconXmlPath: String,
                    outputSize: CGSize = CGSize(width: 192, height: 192)) async -> UIImage? {
        guard let xmlOutput = await dumpXmlTree(apkPath: apkPath, filePath: iconXmlPath),
              let root = XmlTreeParser.parse(xmlOutput) else {
            return nil
        }

        switch root.tag {
        case "adaptive-icon":
            return await renderAdaptiveIcon(root, apkPath: apkPath, outputSize: outputSize)
        case "vector":
            return await renderVector(root, outputSize: outputSize)
        default:
            return nil
        }
    }

    // MARK: - Adaptive

    private func renderAdaptiveIcon(_ root: XmlTreeParser.XmlNode,
                                    apkPath: URL,
                                    outputSize: CGSize) async -> UIImage? {
        var backgroundImage: UIImage?
        var foregroundImage: UIImage?

        for child in root.children {
            switch child.tag {
            case "background":
                backgroundImage = await resolveLayer(child, apkPath: apkPath, outputSize: outputSize)
            case "foreground":
                foregroundImage = await resolveLayer(child, apkPath: apkPath, outputSize: outputSize)
            default:
                break
            }
        }

        return await composite(background: backgroundImage, foreground: foregroundImage, size: outputSize)
    }

    private func resolveLayer(_ node: XmlTreeParser.XmlNode,
                              apkPath: URL,
                              outputSize: CGSize) async -> UIImage? {
        if let colorStr = node.attributes["drawable"], colorStr.hasPrefix("#"),
           let color = XmlTreeParser.parseColor(colorStr) {
            return await solidColorImage(color: color, size: outputSize)
        }
        if let drawableRef = node.attributes["drawable"],
           let image = await resolveDrawableReference(drawableRef, apkPath: apkPath, outputSize: outputSize) {
            return image
        }
        for child in node.children {
            if child.tag == "vector" {
                return await renderVector(child, outputSize: outputSize)
            } else if child.tag == "inset" {
                return await resolveLayer(child, apkPath: apkPath, outputSize: outputSize)
            } else if child.tag == "color" || child.tag == "drawable" {
                if let colorStr = child.attributes["color"] ?? child.attributes["drawable"],
                   let color = XmlTreeParser.parseColor(colorStr) {
                    return await solidColorImage(color: color, size: outputSize)
                }
            }
        }
        return nil
    }

    private func resolveResourceId(_ ref: String,
                                   apkPath: URL,
                                   outputSize: CGSize) async -> UIImage? {
        let cleanRef = ref.replacingOccurrences(of: "@", with: "")
        guard let dump = await dumpResources(apkPath: apkPath) else { return nil }

        let lines = dump.components(separatedBy: "\n")
        var foundResource = false
        var candidatePaths: [String] = []
        var colorValue: String?

        for line in lines {
            if line.contains(cleanRef) { foundResource = true; continue }
            if foundResource {
                if line.contains("resource ") { break }
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if let resRange = trimmed.range(of: "res/") {
                    var path = String(trimmed[resRange.lowerBound...])
                    if let typeRange = path.range(of: " type=") {
                        path = String(path[..<typeRange.lowerBound])
                    }
                    candidatePaths.append(path)
                } else if trimmed.contains("#") {
                    if let hashIdx = trimmed.firstIndex(of: "#") {
                        colorValue = String(trimmed[hashIdx...])
                    }
                }
            }
        }

        if candidatePaths.isEmpty, let colorStr = colorValue,
           let color = XmlTreeParser.parseColor(colorStr) {
            return await solidColorImage(color: color, size: outputSize)
        }

        for path in candidatePaths.reversed() where path.hasSuffix(".xml") {
            if let image = await renderIcon(from: apkPath, iconXmlPath: path) {
                return image
            }
        }

        if let zip = APKZipReader(url: apkPath) {
            for path in candidatePaths.reversed() where !path.hasSuffix(".xml") {
                if let data = zip.extractEntry(path: path), let image = UIImage(data: data) {
                    return image
                }
            }
        }

        return nil
    }

    private func resolveDrawableReference(_ ref: String,
                                          apkPath: URL,
                                          outputSize: CGSize) async -> UIImage? {
        if ref.hasPrefix("@") {
            return await resolveResourceId(ref, apkPath: apkPath, outputSize: outputSize)
        }
        if ref.hasPrefix("res/") {
            if ref.hasSuffix(".xml") {
                return await renderIcon(from: apkPath, iconXmlPath: ref)
            }
            if let zip = APKZipReader(url: apkPath),
               let data = zip.extractEntry(path: ref) {
                return UIImage(data: data)
            }
        }
        return nil
    }

    // MARK: - Vector

    private func renderVector(_ root: XmlTreeParser.XmlNode, outputSize: CGSize) async -> UIImage? {
        guard let drawable = XmlTreeParser.parseVectorDrawable(from: root) else { return nil }
        return await MainActor.run {
            VectorDrawableRenderer.render(drawable, size: outputSize)
        }
    }

    // MARK: - Compositing

    @MainActor
    private func composite(background: UIImage?, foreground: UIImage?, size: CGSize) -> UIImage? {
        guard background != nil || foreground != nil else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cgCtx = ctx.cgContext

            cgCtx.addPath(adaptiveIconMask(in: rect))
            cgCtx.clip()

            background?.draw(in: rect)
            foreground?.draw(in: rect)
        }
    }

    private func adaptiveIconMask(in rect: CGRect) -> CGPath {
        let w = rect.width, h = rect.height
        let cx = rect.midX, cy = rect.midY
        let path = CGMutablePath()
        let r = min(w, h) / 2
        let n: CGFloat = 4.0
        let steps = 360
        for i in 0...steps {
            let angle = CGFloat(i) * (2 * .pi / CGFloat(steps))
            let cosA = cos(angle), sinA = sin(angle)
            let exp = 2.0 / n
            let x = cx + r * copysign(pow(abs(cosA), exp), cosA)
            let y = cy + r * copysign(pow(abs(sinA), exp), sinA)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    @MainActor
    private func solidColorImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - aapt2 calls

    private func dumpXmlTree(apkPath: URL, filePath: String) async -> String? {
        let result = try? await shell.run(
            executablePath: aapt2Path,
            arguments: ["dump", "xmltree", apkPath.path, "--file", filePath],
            environment: nil,
            workingDirectory: nil,
            timeout: 30
        )
        guard let output = result?.output, !output.isEmpty else { return nil }
        return output
    }

    private func dumpResources(apkPath: URL) async -> String? {
        let key = apkPath.path
        if let cached = resourceDumpCache[key] { return cached }
        let result = try? await shell.run(
            executablePath: aapt2Path,
            arguments: ["dump", "resources", apkPath.path],
            environment: nil,
            workingDirectory: nil,
            timeout: 15
        )
        let output = (result?.output.isEmpty == false) ? result?.output : nil
        resourceDumpCache[key] = output
        return output
    }
}
