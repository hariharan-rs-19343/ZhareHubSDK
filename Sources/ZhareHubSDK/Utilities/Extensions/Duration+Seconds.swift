//
//  Duration+Seconds.swift
//  ZhareHubSDK
//

import Foundation

extension Duration {
    /// Elapsed time formatted as seconds with millisecond precision, e.g. `"1.234"`.
    var secondsString: String {
        let seconds = Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
        return String(format: "%.3f", seconds)
    }
}
