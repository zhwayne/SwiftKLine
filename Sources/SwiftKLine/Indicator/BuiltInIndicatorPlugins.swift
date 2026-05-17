import Foundation

extension ChartConfiguration {
    func periods(for indicator: BuiltInIndicator, matching extractor: (SeriesKey) -> Int?) -> [Int] {
        indicatorKeys(for: indicator).compactMap(extractor)
    }
}

@MainActor
struct BuiltInIndicatorPlugin: IndicatorPlugin {
    let indicator: BuiltInIndicator

    var id: IndicatorID {
        indicator.id
    }

    var title: String {
        indicator.rawValue
    }

    var placement: IndicatorPlacement {
        indicator.isMain ? .main : .sub
    }

    var defaultSeriesKeys: [SeriesKey] {
        indicator.defaultSeriesKeys
    }

    func makeCalculators(configuration: ChartConfiguration) -> [any IndicatorCalculator] {
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
                return SARCalculator()
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

    func makeRenderers(configuration: ChartConfiguration) -> [any ChartRenderer] {
        switch indicator {
        case .ma:
            let periods = configuration.periods(for: indicator) { key in
                guard key.indicatorID == .ma, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [MARenderer(periods: periods)]
        case .ema:
            let periods = configuration.periods(for: indicator) { key in
                guard key.indicatorID == .ema, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [EMARenderer(periods: periods)]
        case .wma:
            let periods = configuration.periods(for: indicator) { key in
                guard key.indicatorID == .wma, let periodStr = key.parameters["period"], let period = Int(periodStr) else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [WMARenderer(periods: periods)]
        case .boll:
            guard let key = configuration.indicatorKeys(for: .boll).first else { return [] }
            return [BOLLRenderer(key: key)]
        case .sar:
            return [SARRenderer()]
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
            guard let key = configuration.indicatorKeys(for: .macd).first else { return [] }
            return [MACDRenderer(key: key)]
        }
    }
}