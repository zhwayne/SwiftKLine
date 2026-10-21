//
//  PriceFormat.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/26.
//

import SwiftKLineCore
import Foundation

/// The internal formatting interface shared by legends, price markers, and candle details.
protocol NumberFormatting {
    
    func format(_ number: NSNumber) -> String
}

/// Formats prices with magnitude-aware significant digits; non-finite input is displayed as "--".
final class PriceFormatter: NumberFormatting {
    
    private let maximumSignificantDigits: Int
    private let minimumFractionDigits: Int
    private let formatter: NumberFormatter
    
    init(maximumSignificantDigits: Int = 4, minimumFractionDigits: Int = 2) {
        self.maximumSignificantDigits = maximumSignificantDigits
        self.minimumFractionDigits = minimumFractionDigits
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
    }
    
    func format(_ number: NSNumber) -> String {
        let value = number.doubleValue
        guard value.isFinite else { return "--" }
        let absoluteValue = abs(value)
        let digits: Int
        if absoluteValue >= 1 {
            digits = Int(floor(log10(absoluteValue))) + 1
        } else {
            digits = 1
        }
        formatter.maximumSignificantDigits = max(maximumSignificantDigits, digits + minimumFractionDigits)
        return formatter.string(from: number) ?? "\(number)"
    }
}

/// Abbreviates positive quantities using K/M/B/T suffixes and delegates numeric formatting to PriceFormatter.
final class VolumeFormatter: NumberFormatting {
    private let priceFormatter = PriceFormatter()
    
    func format(_ number: NSNumber) -> String {
        var units = ["K", "M", "B", "T"]
        var unit = ""
        var value = number.doubleValue
        while value >= 1000, !units.isEmpty {
            value /= 1000
            unit = units.removeFirst()
        }
        return priceFormatter.format(NSNumber(value: value)) + unit
    }
}
