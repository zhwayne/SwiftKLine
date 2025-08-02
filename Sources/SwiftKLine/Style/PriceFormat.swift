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

struct PriceFormatter: NumberFormatting {
    
    var maximumSignificantDigits = 4
    var minimumFractionDigits = 2
    
    func format(_ number: NSNumber) -> String {
        var integer = number.intValue
        var digits = 0
        while integer != 0 {
            digits += 1
            integer /= 10
        }
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = max(maximumSignificantDigits, digits + minimumFractionDigits)
        formatter.numberStyle = .decimal
        return formatter.string(from: number)!
    }
}

struct VolumeFormatter: NumberFormatting {
    
    func format(_ number: NSNumber) -> String {
        var units = ["K", "M", "B", "T"]
        var unit = ""
        var value = number.doubleValue
        while value >= 1000, units.count > 0 {
            value /= 1000
            unit = units.removeFirst()
        }
        let formatter = PriceFormatter()
        return formatter.format(number) + unit
    }
}
