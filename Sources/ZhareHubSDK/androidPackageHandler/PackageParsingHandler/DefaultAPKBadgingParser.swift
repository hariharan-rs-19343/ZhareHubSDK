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
        let pattern = "application-label:'([^']*)'"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "N/A" }
        let nsOutput = output as NSString
        guard let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: nsOutput.length)),
              match.numberOfRanges >= 2 else { return "N/A" }
        return nsOutput.substring(with: match.range(at: 1))
    }

    public func parseSingleValue(from output: String, key: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let patterns = ["\(escaped)='([^']*)'", "\(escaped):'([^']*)'"]

        let nsOutput = output as NSString
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: nsOutput.length)),
               match.numberOfRanges >= 2 {
                return nsOutput.substring(with: match.range(at: 1))
            }
        }
        return "N/A"
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
        return APKBundleProperties(
            appName: parseAppLabel(from: output),
            packageName: parseAppLabel(from: output),
            packageIdentifier: parseSingleValue(from: output, key: "package: name"),
            versionName: parseSingleValue(from: output, key: "versionName"),
            versionCode: parseSingleValue(from: output, key: "versionCode"),
            minSDK: parseSingleValue(from: output, key: "minSdkVersion"),
            targetSDK: parseSingleValue(from: output, key: "targetSdkVersion"),
            deviceCompatibility: parseDeviceCompatibility(from: output),
            permissions: parsePermissions(from: output),
            usesFeatures: parseFeatures(from: output)
        )
    }
}
