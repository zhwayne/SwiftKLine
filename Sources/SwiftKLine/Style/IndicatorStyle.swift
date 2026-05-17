//
//  IndicatorStyle.swift
//  SwiftKLine
//
//  Created by zhwayne on 2025/4/14.
//

import UIKit

public protocol IndicatorStyle { }

public struct LineStyle: IndicatorStyle {
    public let strokeColor: UIColor
    
    public init(strokeColor: UIColor) {
        self.strokeColor = strokeColor
    }
}

struct PriceIndicatorStyle: IndicatorStyle {
    let textColor: UIColor = UIColor.label.withAlphaComponent(0.7)
    let font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
}

struct TimeAxisStyle: IndicatorStyle {
    let textColor: UIColor
    let font: UIFont

    init(
        textColor: UIColor = UIColor.label.withAlphaComponent(0.7),
        font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    ) {
        self.textColor = textColor
        self.font = font
    }
}

struct TimeSeriesStyle: IndicatorStyle {
    let lineColor: UIColor
    let fillColor: UIColor
    let borderColor: UIColor

    init(
        lineColor: UIColor = .systemBlue,
        fillColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.15),
        borderColor: UIColor = .systemGray3
    ) {
        self.lineColor = lineColor
        self.fillColor = fillColor
        self.borderColor = borderColor
    }
}

struct MACDStyle: IndicatorStyle {
    let macdColor: UIColor
    let difColor: UIColor
    let deaColor: UIColor

    init(macdColor: UIColor, difColor: UIColor, deaColor: UIColor) {
        self.macdColor = macdColor
        self.difColor = difColor
        self.deaColor = deaColor
    }
}
