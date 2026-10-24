//
//  BuiltInIndicatorPlugins.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/05/17.
//

import SwiftKLineCore
import Foundation

extension IndicatorConfiguration {
    func periods(for indicator: BuiltInIndicator, matching extractor: (SeriesKey) -> Int?) -> [Int] {
        indicatorKeys(for: indicator).compactMap(extractor)
    }
}

@MainActor
struct BuiltInIndicatorPlugin: ChartPlugin {
    let indicator: BuiltInIndicator
    let configuration: IndicatorConfiguration

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
        let keys = configuration.indicatorKeys(for: indicator)
        guard coordinator.keys != keys else { return }
        coordinator.keys = keys
        for index in 0..<coordinator.calculatorCount { context.removeCalculator(for: "series.\(index)") }
        let calculators = makeCalculators(configuration: configuration)
        coordinator.calculatorCount = calculators.count
        for (index, calculator) in calculators.enumerated() {
            context.setCalculator(calculator, for: "series.\(index)")
        }
        for index in 0..<coordinator.rendererCount { context.removeRenderer(for: "drawing.\(index)") }
        let renderers = makeRenderers(configuration: configuration, calculatorKeys: Set(calculators.map(\.id)))
        coordinator.rendererCount = renderers.count
        for (index, renderer) in renderers.enumerated() {
            context.setRenderer(renderer, for: "drawing.\(index)", panel: indicator.isMain ? .main : .sub)
        }
    }

    func makeCalculators(configuration: IndicatorConfiguration) -> [any IndicatorCalculator] {
        switch indicator {
        case .kdj, .cci, .wr, .dmi, .atr, .obv, .roc, .mfi, .trix:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == indicator.id else { return nil }
                let calculator: (any IndicatorCalculator)?
                switch indicator {
                case .kdj:
                    guard let period = key.parameters["period"].flatMap(Int.init),
                          let k = key.parameters["kPeriod"].flatMap(Int.init),
                          let d = key.parameters["dPeriod"].flatMap(Int.init) else { return nil }
                    calculator = KDJCalculator(period: period, kPeriod: k, dPeriod: d)
                case .dmi:
                    guard let di = key.parameters["diPeriod"].flatMap(Int.init),
                          let adx = key.parameters["adxPeriod"].flatMap(Int.init) else { return nil }
                    calculator = DMICalculator(diPeriod: di, adxPeriod: adx)
                case .obv: calculator = OBVCalculator()
                default:
                    guard let period = key.parameters["period"].flatMap(Int.init) else { return nil }
                    switch indicator {
                    case .cci: calculator = CCICalculator(period: period)
                    case .wr: calculator = WRCalculator(period: period)
                    case .atr: calculator = ATRCalculator(period: period)
                    case .roc: calculator = ROCCalculator(period: period)
                    case .mfi: calculator = MFICalculator(period: period)
                    case .trix: calculator = TRIXCalculator(period: period)
                    default: calculator = nil
                    }
                }
                // Reject noncanonical/malformed keys rather than publishing under a different identity.
                guard let calculator, calculator.id == key else { return nil }
                return calculator
            }
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
        case .bbi:
            // BBI owns its complete period list in one key, so every channel instance stays independently cached.
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .bbi,
                      let rawPeriods = key.parameters["periods"] else { return nil }
                let periods = rawPeriods.split(separator: ",").compactMap { Int($0) }
                guard !periods.isEmpty else { return nil }
                return BBICalculator(periods: periods)
            }
        case .vwma:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .vwma,
                      let period = key.parameters["period"].flatMap(Int.init) else { return nil }
                return period
            }.map { VWMACalculator(period: $0) }
        case .donchian:
            return configuration.periods(for: indicator) { key in
                guard key.indicatorID == .donchian,
                      let period = key.parameters["period"].flatMap(Int.init) else { return nil }
                return period
            }.map { DonchianCalculator(period: $0) }
        case .superTrend:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .superTrend,
                      let period = key.parameters["period"].flatMap(Int.init),
                      let multiplier = key.parameters["multiplier"].flatMap(Double.init) else { return nil }
                return SuperTrendCalculator(period: period, multiplier: multiplier)
            }
        case .ichimoku:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard key.indicatorID == .ichimoku,
                      let tenkan = key.parameters["tenkanPeriod"].flatMap(Int.init),
                      let kijun = key.parameters["kijunPeriod"].flatMap(Int.init),
                      let senkouB = key.parameters["senkouBPeriod"].flatMap(Int.init),
                      let displacement = key.parameters["displacement"].flatMap(Int.init) else { return nil }
                return IchimokuCalculator(
                    tenkanPeriod: tenkan,
                    kijunPeriod: kijun,
                    senkouBPeriod: senkouB,
                    displacement: displacement
                )
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

    /// Convenience for callers that hold only a configuration and not yet-resolved keys.
    ///
    /// The plugin lifecycle uses the keyed overload to avoid rebuilding every calculator twice.
    func makeRenderers(configuration: IndicatorConfiguration) -> [any ChartRenderer] {
        makeRenderers(configuration: configuration,
                      calculatorKeys: Set(makeCalculators(configuration: configuration).map(\.id)))
    }

    /// Builds renderers for the keys the calculators actually resolved.
    ///
    /// The nine generic lower-panel indicators draw from whatever their calculator accepted, so the
    /// resolved keys are passed in instead of rebuilding the calculators a second time. One parse
    /// therefore decides both what is calculated and what is drawn.
    func makeRenderers(configuration: IndicatorConfiguration, calculatorKeys: Set<SeriesKey>) -> [any ChartRenderer] {
        switch indicator {
        case .kdj, .cci, .wr, .dmi, .atr, .obv, .roc, .mfi, .trix:
            return configuration.indicatorKeys(for: indicator).filter { calculatorKeys.contains($0) }
                .enumerated().map { SubIndicatorRenderer.make(key: $0.element, showsLegend: $0.offset == 0) }
        case .ma, .ema, .wma:
            let keys = configuration.indicatorKeys(for: indicator).filter { $0.indicatorID == indicator.id }
            return keys.isEmpty ? [] : [LineIndicatorRenderer(series: keys)]
        case .boll:
            return configuration.indicatorKeys(for: .boll).map { BOLLRenderer(key: $0) }
        case .sar:
            return configuration.indicatorKeys(for: .sar).map { SARRenderer(key: $0) }
        case .bbi, .vwma:
            let keys = configuration.indicatorKeys(for: indicator).filter { $0.indicatorID == indicator.id }
            return keys.isEmpty ? [] : [LineIndicatorRenderer(series: keys)]
        case .donchian:
            return configuration.indicatorKeys(for: indicator)
                .filter { $0.indicatorID == indicator.id }
                .map { BandRenderer(key: $0) }
        case .superTrend:
            return configuration.indicatorKeys(for: indicator)
                .filter { $0.indicatorID == indicator.id }
                .map { SuperTrendRenderer(key: $0) }
        case .ichimoku:
            return configuration.indicatorKeys(for: indicator)
                .filter { $0.indicatorID == indicator.id }
                .map { IchimokuRenderer(key: $0) }
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
