//
//  BuiltInIndicatorPlugins.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

extension ChartAppearance {
    func periods(for indicator: BuiltInIndicator, matching extractor: (SeriesKey) -> Int?) -> [Int] {
        indicatorKeys(for: indicator).compactMap(extractor)
    }
}

@MainActor
struct BuiltInIndicatorPlugin: ChartPlugin {
    let indicator: BuiltInIndicator
    let appearance: ChartAppearance

    var id: String {
        indicator.id.rawValue
    }

    var title: String {
        indicator.rawValue
    }

    var defaultSeriesKeys: [SeriesKey] {
        indicator.defaultSeriesKeys
    }


    @MainActor final class Coordinator {
        var keys: [SeriesKey]?
        var calculatorCount = 0
        var rendererCount = 0
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func update(coordinator: Coordinator, context: ChartPluginContext) {
        let keys = appearance.indicatorKeys(for: indicator)
        guard coordinator.keys != keys else { return }
        coordinator.keys = keys
        for index in 0..<coordinator.calculatorCount { context.removeCalculator(for: "series.\(index)") }
        let calculators = makeCalculators(configuration: appearance)
        coordinator.calculatorCount = calculators.count
        for (index, calculator) in calculators.enumerated() {
            context.setCalculator(calculator, for: "series.\(index)")
        }
        for index in 0..<coordinator.rendererCount { context.removeRenderer(for: "drawing.\(index)") }
        let renderers = makeRenderers(configuration: appearance)
        coordinator.rendererCount = renderers.count
        for (index, renderer) in renderers.enumerated() {
            context.setRenderer(renderer, for: "drawing.\(index)", panel: indicator.isMain ? .main : .sub)
        }
    }

    func makeCalculators(configuration: ChartAppearance) -> [any IndicatorCalculator] {
        switch indicator {
        case .ma:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .ma, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }.map { MACalculator(period: $0) }
        case .ema:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .ema, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }.map { EMACalculator(period: $0) }
        case .wma:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .wma, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }.map { WMACalculator(period: $0) }
        case .boll:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .boll,
                      let periodStr = key.parameters["period"],
                      let period = Int(periodStr),
                      let kStr = key.parameters["k"],
                      let k = Double(kStr) else { return nil }
                return BOLLCalculator(period: period, k: k)
            }
        case .sar:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .sar else { return nil }
                if key.parameters.isEmpty { return SARCalculator() }
                guard let start = key.parameters["afStart"].flatMap(Double.init),
                      let step = key.parameters["afStep"].flatMap(Double.init),
                      let max = key.parameters["afMax"].flatMap(Double.init) else { return nil }
                return SARCalculator(afStart: start, afStep: step, afMax: max)
            }
        case .vol:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .vol else { return nil }
                return VOLCalculator()
            }
        case .rsi:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .rsi, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }.map { RSICalculator(period: $0) }
        case .macd:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .macd,
                      let shortStr = key.parameters["shortPeriod"],
                      let longStr = key.parameters["longPeriod"],
                      let signalStr = key.parameters["signalPeriod"],
                      let short = Int(shortStr),
                      let long = Int(longStr),
                      let signal = Int(signalStr) else { return nil }
                return MACDCalculator(shortPeriod: short, longPeriod: long, signalPeriod: signal)
            }
        }
    }

    func makeRenderers(configuration: ChartAppearance) -> [any ChartRenderer] {
        switch indicator {
        case .ma, .ema, .wma:
            let keys = configuration.indicatorKeys(for: indicator).filter { $0.indicatorID == indicator.id }
            return keys.isEmpty ? [] : [LineIndicatorRenderer(series: keys)]
        case .boll:
            return configuration.indicatorKeys(for: .boll).map { BOLLRenderer(key: $0) }
        case .sar:
            return configuration.indicatorKeys(for: .sar).map { SARRenderer(key: $0) }
        case .vol:
            return [VOLRenderer()]
        case .rsi:
            let periods = configuration.periods(for: indicator) { key in
                guard key.indicatorID == .rsi, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [RSIRenderer(periods: periods)]
        case .macd:
            return configuration.indicatorKeys(for: .macd).map { MACDRenderer(key: $0) }
        }
    }
}