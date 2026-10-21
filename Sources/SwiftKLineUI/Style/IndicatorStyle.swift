//
//  IndicatorStyle.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/04/14.
//

import SwiftKLineCore
import UIKit

/// Marker protocol for series-keyed visual settings; renderers request the concrete type they understand.
public protocol IndicatorStyle { }

/// The visual style shared by scalar line indicators and bands that consume a line color.
public struct LineStyle: IndicatorStyle {
    /// The stroke color, resolved when the renderer draws.
    public let strokeColor: UIColor
    
    /// Creates a scalar line style using the supplied color.
    public init(strokeColor: UIColor) {
        self.strokeColor = strokeColor
    }
}

/// Internal text appearance for latest-price and visible-extreme annotations.
struct PriceIndicatorStyle: IndicatorStyle {
    let textColor: UIColor = UIColor.label.withAlphaComponent(0.7)
    let font: UIFont = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
}

/// Internal font and text color for time-axis labels.
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

/// Internal line, area-fill, and border colors for time-series presentation.
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

/// Internal colors for the MACD histogram and its DIF and DEA lines.
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
