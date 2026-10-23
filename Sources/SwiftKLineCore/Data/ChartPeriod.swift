//
//  ChartPeriod.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2025/04/13.
//

import Foundation

/// A transport-facing period identifier and its nominal duration.
///
/// Fixed durations can define Unix-time buckets. Calendar periods require exact candle-open timestamps;
/// the nominal duration alone does not encode exchange time zones or trading calendars.
public struct ChartPeriod: Hashable, Codable, Sendable {
    
    /// The nominal duration in seconds. Fixed-bucket matching only uses positive durations.
    public let seconds: Int
    /// The provider's period identifier, such as "1m"; the chart matches available periods without imposing exchange semantics.
    public let identifier: String
    
    /// Creates a period without imposing an exchange-specific naming or calendar convention.
    ///
    /// - Parameters:
    ///   - seconds: Nominal duration in seconds.
    ///   - identifier: Identifier understood by the application’s provider.
    public init(seconds: Int, identifier: String) {
        self.seconds = seconds
        self.identifier = identifier
    }
    
    // Common periods
    /// A one-minute period ("1m").
    public static let oneMinute = ChartPeriod(seconds: 60, identifier: "1m")
    /// A three-minute period ("3m").
    public static let threeMinutes = ChartPeriod(seconds: 180, identifier: "3m")
    /// A five-minute period ("5m").
    public static let fiveMinutes = ChartPeriod(seconds: 300, identifier: "5m")
    /// A fifteen-minute period ("15m").
    public static let fifteenMinutes = ChartPeriod(seconds: 900, identifier: "15m")
    /// A thirty-minute period ("30m").
    public static let thirtyMinutes = ChartPeriod(seconds: 1800, identifier: "30m")
    /// A one-hour period ("1h").
    public static let oneHour = ChartPeriod(seconds: 3600, identifier: "1h")
    /// A two-hour period ("2h").
    public static let twoHours = ChartPeriod(seconds: 7200, identifier: "2h")
    /// A four-hour period ("4h").
    public static let fourHours = ChartPeriod(seconds: 14400, identifier: "4h")
    /// A six-hour period ("6h").
    public static let sixHours = ChartPeriod(seconds: 21600, identifier: "6h")
    /// An eight-hour period ("8h").
    public static let eightHours = ChartPeriod(seconds: 28800, identifier: "8h")
    /// A twelve-hour period ("12h").
    public static let twelveHours = ChartPeriod(seconds: 43200, identifier: "12h")
    /// A nominal 24-hour period ("1d").
    public static let oneDay = ChartPeriod(seconds: 86400, identifier: "1d")
    /// A nominal three-day period ("3d").
    public static let threeDays = ChartPeriod(seconds: 259200, identifier: "3d")
    /// A nominal seven-day period ("1w"); no exchange week-start rule is encoded.
    public static let oneWeek = ChartPeriod(seconds: 604800, identifier: "1w")
    /// A calendar-month identifier ("1M") with a nominal 30-day duration; do not use it to infer month boundaries.
    public static let oneMonth = ChartPeriod(seconds: 2592000, identifier: "1M")
}
