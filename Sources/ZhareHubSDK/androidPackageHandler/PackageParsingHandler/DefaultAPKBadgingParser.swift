//
//  DefaultAPKBadgingParser.swift
//  ZhareHubSDK
//
//  Ports BadgingParser + parseAllIconEntries from the ApkAnalyzer POC.
//  Pure regex-based parsing, no side effects.
//

import Foundation

public struct DefaultAPKBadgingParser: APKBadgingParserProtocol {

    public init() {}

    public func parseAppLabel(from output: String) -> String {
        quotedValue(in: output, key: "application-label") ?? APKConstants.notAvailable
    }

    public func parseSingleValue(from output: String, key: String) -> String {
        quotedValue(in: output, key: key) ?? APKConstants.notAvailable
    }

    public func parseDeviceCompatibility(from output: String) -> [String] {
        var devices: [String] = []
        let nsOutput = output as NSString

        if let regex = try? NSRegularExpression(pattern: "native-code: (.*)"),
           let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: nsOutput.length)) {
            let line = nsOutput.substring(with: match.range(at: 1))
            if let archRegex = try? NSRegularExpression(pattern: "'([^']*)'") {
                let archMatches = archRegex.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length))
                for m in archMatches {
                    devices.append((line as NSString).substring(with: m.range(at: 1)))
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: "supports-screens: (.*)"),
           let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: nsOutput.length)) {
            let line = nsOutput.substring(with: match.range(at: 1))
            let screens = line.components(separatedBy: " ")
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "'", with: "") }
                .filter { !$0.isEmpty }
            devices.append(contentsOf: screens)
        }

        return devices
    }

    public func parseFeatures(from output: String) -> [String] {
        var required: [String] = []

        for line in output.components(separatedBy: "\n") {
            guard line.contains("uses-feature:") || line.contains("uses-implied-feature:") else { continue }
            // Skip features explicitly marked optional.
            if line.contains("required='false'") { continue }

            guard let regex = try? NSRegularExpression(pattern: "name='([^']*)'"),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
                  match.numberOfRanges >= 2 else { continue }

            let name = (line as NSString).substring(with: match.range(at: 1))
            required.append(name)
        }

        return required
    }

    /// `uses-feature` names marked `required='false'` (e.g. optional leanback
    /// on a phone app that also supports TV).
    public func parseOptionalFeatures(from output: String) -> [String] {
        var optional: [String] = []

        for line in output.components(separatedBy: "\n") {
            guard line.contains("uses-feature:"), line.contains("required='false'") else { continue }

            guard let regex = try? NSRegularExpression(pattern: "name='([^']*)'"),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
                  match.numberOfRanges >= 2 else { continue }

            optional.append((line as NSString).substring(with: match.range(at: 1)))
        }

        return optional
    }

    public func parsePermissions(from output: String) -> [String] {
        let pattern = "uses-permission.*name='([^']*)'"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsOutput = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsOutput.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            return nsOutput.substring(with: match.range(at: 1))
        }
    }

    public func parseAllIconEntries(from output: String) -> [APKIconEntry] {
        let pattern = "application-icon-(\\d+):'([^']*)'"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsOutput = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsOutput.length))
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let densityStr = nsOutput.substring(with: match.range(at: 1))
            let path = nsOutput.substring(with: match.range(at: 2))
            guard let density = Int(densityStr), !path.isEmpty else { return nil }
            return APKIconEntry(density: density, path: path)
        }
    }

    public func loadProperties(from output: String) -> APKBundleProperties {
        loadProperties(from: output, fileName: "")
    }

    public func loadProperties(from output: String, fileName: String) -> APKBundleProperties {
        let requiredFeatures = parseFeatures(from: output)
        return APKBundleProperties(
            appName: fileName,
            packageName: parseAppLabel(from: output),
            packageIdentifier: parseSingleValue(from: output, key: "package: name"),
            versionName: parseSingleValue(from: output, key: "versionName"),
            versionCode: parseSingleValue(from: output, key: "versionCode"),
            // aapt2 prints `minSdkVersion:'..'`; legacy aapt prints `sdkVersion:'..'`.
            minSDK: quotedValue(in: output, key: "minSdkVersion")
                ?? parseSingleValue(from: output, key: "sdkVersion"),
            targetSDK: parseSingleValue(from: output, key: "targetSdkVersion"),
            deviceCompatibility: parseDeviceCompatibility(from: output),
            permissions: parsePermissions(from: output),
            usesFeatures: requiredFeatures,
            supportedPlatforms: APKSupportedPlatformResolver.resolve(
                required: requiredFeatures,
                optional: parseOptionalFeatures(from: output)
            )
        )
    }

    private func quotedValue(in text: String, key: String) -> String? {
        guard let keyRange = rangeOfKey(key, in: text) else { return nil }
        var remainder = text[keyRange.upperBound...]
        while let first = remainder.first, first == " " || first == ":" || first == "=" {
            remainder.removeFirst()
        }
        guard remainder.first == "'" else { return nil }
        remainder.removeFirst()

        var value = ""
        var isEscaped = false
        for character in remainder {
            if isEscaped {
                value.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == "'" {
                return value
            }
            value.append(character)
        }
        return nil
    }

    private func rangeOfKey(_ key: String, in text: String) -> Range<String.Index>? {
        var search = text.startIndex
        while let found = text.range(of: key, range: search..<text.endIndex) {
            let hasBoundary: Bool
            if found.lowerBound == text.startIndex {
                hasBoundary = true
            } else {
                let previous = text[text.index(before: found.lowerBound)]
                hasBoundary = !previous.isLetter && previous != "_"
            }
            if hasBoundary {
                return found
            }
            search = found.upperBound
        }
        return nil
    }
}
