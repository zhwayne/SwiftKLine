//
//  PriceFormat.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/26.
//

import Foundation

protocol NumberFormatting {
    
    func format(_ number: NSNumber) -> String
}

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
