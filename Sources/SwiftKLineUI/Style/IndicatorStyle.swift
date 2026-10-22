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

/// Independent line colors for one complete KDJ output, keyed by all calculation parameters.
public struct KDJStyle: IndicatorStyle {
    public let kColor: UIColor
    public let dColor: UIColor
    public let jColor: UIColor

    public init(kColor: UIColor = .systemOrange, dColor: UIColor = .systemBlue, jColor: UIColor = .systemPurple) {
        self.kColor = kColor
        self.dColor = dColor
        self.jColor = jColor
    }
}

/// Independent +DI, -DI and ADX colors for one complete DMI output.
public struct DMIStyle: IndicatorStyle {
    public let plusDIColor: UIColor
    public let minusDIColor: UIColor
    public let adxColor: UIColor

    public init(plusDIColor: UIColor = .systemGreen, minusDIColor: UIColor = .systemRed, adxColor: UIColor = .systemOrange) {
        self.plusDIColor = plusDIColor
        self.minusDIColor = minusDIColor
        self.adxColor = adxColor
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

/// Internal line, gradient-fill, and border colors for time-series presentation.
struct TimeSeriesStyle: IndicatorStyle {
    let lineColor: UIColor
    /// Color at the top of the price viewport, fading to the same RGB with zero alpha at the bottom.
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

/// Internal colors for the two SuperTrend trend directions.
///
/// Segments drawn while the trend is up use ``upColor``; segments drawn while it is down use ``downColor``.
/// The translucent ``upFillColor`` and ``downFillColor`` shade the area between the active line and price.
struct SuperTrendStyle: IndicatorStyle {
    let upColor: UIColor
    let downColor: UIColor
    let upFillColor: UIColor
    let downFillColor: UIColor

    /// Creates a directional line and ribbon style for the SuperTrend overlay.
    ///
    /// - Parameters:
    ///   - upColor: The color used while the active trailing stop supports price.
    ///   - downColor: The color used while the active trailing stop caps price.
    ///   - upFillColor: The ribbon color between the up-trend line and price; nil derives a translucent
    ///     version of `upColor`.
    ///   - downFillColor: The ribbon color between the down-trend line and price; nil derives a translucent
    ///     version of `downColor`.
    init(
        upColor: UIColor,
        downColor: UIColor,
        upFillColor: UIColor? = nil,
        downFillColor: UIColor? = nil
    ) {
        self.upColor = upColor
        self.downColor = downColor
        self.upFillColor = upFillColor ?? upColor.withAlphaComponent(0.08)
        self.downFillColor = downFillColor ?? downColor.withAlphaComponent(0.08)
    }
}

/// Internal line and cloud colors for the Ichimoku Kinko Hyo overlay.
///
/// Each line has its own color, while the Senkou cloud selects a bullish or bearish fill from the relative
/// order of Senkou Span A and Senkou Span B.
struct IchimokuStyle: IndicatorStyle {
    let tenkanColor: UIColor
    let kijunColor: UIColor
    let spanAColor: UIColor
    let spanBColor: UIColor
    let chikouColor: UIColor
    let bullishCloudColor: UIColor
    let bearishCloudColor: UIColor

    /// Creates a complete Ichimoku style.
    ///
    /// - Parameters:
    ///   - tenkanColor: The Tenkan-sen line color.
    ///   - kijunColor: The Kijun-sen line color.
    ///   - spanAColor: The Senkou Span A line color.
    ///   - spanBColor: The Senkou Span B line color.
    ///   - chikouColor: The Chikou Span line color.
    ///   - bullishCloudColor: The cloud fill when Senkou Span A is at or above Senkou Span B.
    ///   - bearishCloudColor: The cloud fill when Senkou Span A is below Senkou Span B.
    init(
        tenkanColor: UIColor,
        kijunColor: UIColor,
        spanAColor: UIColor,
        spanBColor: UIColor,
        chikouColor: UIColor,
        bullishCloudColor: UIColor,
        bearishCloudColor: UIColor
    ) {
        self.tenkanColor = tenkanColor
        self.kijunColor = kijunColor
        self.spanAColor = spanAColor
        self.spanBColor = spanBColor
        self.chikouColor = chikouColor
        self.bullishCloudColor = bullishCloudColor
        self.bearishCloudColor = bearishCloudColor
    }
}
