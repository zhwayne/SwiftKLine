//
//  KLinePeriod.swift
//  KLine
//
//  Created by iya on 2025/4/13.
//

import Foundation

public struct KLinePeriod: Sendable {
    
    public let seconds: Int
    public let identifier: String
    
    init(seconds: Int, identifier: String) {
        self.seconds = seconds
        self.identifier = identifier
    }
    
    // Common periods
    public static let oneMinute = KLinePeriod(seconds: 60, identifier: "1m")        // 1m
    public static let threeMinutes = KLinePeriod(seconds: 180, identifier: "3m")    // 3m
    public static let fiveMinutes = KLinePeriod(seconds: 300, identifier: "5m")     // 5m
    public static let fifteenMinutes = KLinePeriod(seconds: 900, identifier: "15m") // 15m
    public static let thirtyMinutes = KLinePeriod(seconds: 1800, identifier: "30m") // 30m
    public static let oneHour = KLinePeriod(seconds: 3600, identifier: "1h")        // 1h
    public static let twoHours = KLinePeriod(seconds: 7200, identifier: "2h")       // 2h
    public static let fourHours = KLinePeriod(seconds: 14400, identifier: "4h")     // 4h
    public static let sixHours = KLinePeriod(seconds: 21600, identifier: "6h")      // 6h
    public static let eightHours = KLinePeriod(seconds: 28800, identifier: "8h")    // 8h
    public static let twelveHours = KLinePeriod(seconds: 43200, identifier: "12h")  // 12h
    public static let oneDay = KLinePeriod(seconds: 86400, identifier: "1d")        // 1d
    public static let threeDays = KLinePeriod(seconds: 259200, identifier: "3d")    // 3d
    public static let oneWeek = KLinePeriod(seconds: 604800, identifier: "1w")      // 1w
    public static let oneMonth = KLinePeriod(seconds: 2592000, identifier: "1M")    // 1M (approximation)
}
