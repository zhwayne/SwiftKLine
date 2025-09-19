//
//  IndicatorStyle.swift
//  SwiftKLine
//
//  Created by W on 2025/4/14.
//

import UIKit

public protocol IndicatorStyle { }

public struct LineStyle: IndicatorStyle {
    public let strokeColor: UIColor
    
    public init(strokeColor: UIColor) {
        self.strokeColor = strokeColor
    }
}

public struct PriceIndicatorStyle: IndicatorStyle {
    let textColor: UIColor = UIColor.label.withAlphaComponent(0.7)
    let font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
}

public struct TimeAxisStyle: IndicatorStyle {
    let textColor: UIColor
    let font: UIFont
    
    public init(
        textColor: UIColor = UIColor.label.withAlphaComponent(0.7),
        font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    ) {
        self.textColor = textColor
        self.font = font
    }
}

public struct TimeSeriesStyle: IndicatorStyle {
    let lineColor: UIColor
    let fillColor: UIColor
    let borderColor: UIColor
    
    public init(
        lineColor: UIColor = .systemBlue,
        fillColor: UIColor = UIColor.systemBlue.withAlphaComponent(0.15),
        borderColor: UIColor = .systemGray3
    ) {
        self.lineColor = lineColor
        self.fillColor = fillColor
        self.borderColor = borderColor
    }
}

public struct MACDStyle: IndicatorStyle {
    
    public let macdColor: UIColor
    public let difColor: UIColor
    public let deaColor: UIColor
    
    public init(macdColor: UIColor, difColor: UIColor, deaColor: UIColor) {
        self.macdColor = macdColor
        self.difColor = difColor
        self.deaColor = deaColor
    }
}
