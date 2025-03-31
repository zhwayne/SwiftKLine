//
//  PriceFormat.swift
//  KLine
//
//  Created by iya on 2025/3/26.
//

import Foundation

// TODO: 格式化功能从 StyleManager 中分离出去
extension StyleManager {
    
    func format(value: Double) -> String {
        let dvalue = Decimal(floatLiteral: value)
        return format(value: dvalue, priceFractionDigits: priceFractionDigits)
    }
    
    func format(value: Int) -> String {
        let ivalue = Decimal(integerLiteral: value)
        return format(value: ivalue, priceFractionDigits: 0)
    }
    
    private func format(value: Decimal, priceFractionDigits: Int) -> String {
        var number = NSDecimalNumber(decimal: value)
        // 避免科学计数法
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.roundingMode = .halfEven
        formatter.minimumFractionDigits = priceFractionDigits
        if value >= 1 && value < 100_000 {
            formatter.maximumFractionDigits = 2  // 设置最大小数位数
            return formatter.string(from: number) ?? ""
        }
        if value >= 100_000 && value < 1_000_000 {
            number = NSDecimalNumber(decimal: value / 1000)
            formatter.maximumFractionDigits = 2  // 设置最大小数位数
            return formatter.string(from: number)?.appending("K") ?? ""
        }
        if value >= 1_000_000 && value < 1_000_000_000 {
            number = NSDecimalNumber(decimal: value / 1_000_000)
            formatter.maximumFractionDigits = 2  // 设置最大小数位数
            return formatter.string(from: number)?.appending("M") ?? ""
        }
        if value >= 1_000_000_000 {
            number = NSDecimalNumber(decimal: value / 1_000_000_000)
            formatter.maximumFractionDigits = 2  // 设置最大小数位数
            return formatter.string(from: number)?.appending("B") ?? ""
        }
        
        // 最后处理小数
        formatter.maximumFractionDigits = priceFractionDigits  // 设置最大小数位数
        return formatter.string(from: number) ?? ""
    }
}

