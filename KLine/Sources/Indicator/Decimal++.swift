//
//  Decimal++.swift
//  KLine
//
//  Created by iya on 2025/3/26.
//

import Foundation

extension Decimal {
    
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
