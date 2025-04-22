//
//  IndicatorStyle.swift
//  KLine
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

public struct TimelineStyle: IndicatorStyle {
    let textColor: UIColor = UIColor.label.withAlphaComponent(0.7)
    let font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
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
