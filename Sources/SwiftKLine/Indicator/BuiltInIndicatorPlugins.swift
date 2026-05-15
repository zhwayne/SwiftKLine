import Foundation

extension KLineConfiguration {
    func periods(for indicator: KLineIndicator, matching extractor: (KLineIndicator.Key) -> Int?) -> [Int] {
        indicatorKeys(for: indicator).compactMap(extractor)
    }
}

@MainActor
struct BuiltInIndicatorPlugin: KLineIndicatorPlugin {
    let indicator: KLineIndicator

    var id: KLineIndicatorID {
        indicator.kLineID
    }

    var title: String {
        indicator.rawValue
    }

    var placement: KLineIndicatorPlacement {
        indicator.isMain ? .main : .sub
    }

    var defaultSeriesKeys: [KLineSeriesKey] {
        indicator.defaultKeys.map(\.kLineSeriesKey)
    }

    func makeCalculators(configuration: KLineConfiguration) -> [any KLineIndicatorCalculator] {
        switch indicator {
        case .ma:
            return configuration.periods(for: indicator) { key in
                guard case let .ma(period) = key else { return nil }
                return period
            }.map { MACalculator(period: $0) }
        case .ema:
            return configuration.periods(for: indicator) { key in
                guard case let .ema(period) = key else { return nil }
                return period
            }.map { EMACalculator(period: $0) }
        case .wma:
            return configuration.periods(for: indicator) { key in
                guard case let .wma(period) = key else { return nil }
                return period
            }.map { WMACalculator(period: $0) }
        case .boll:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard case let .boll(period, k) = key else { return nil }
                return BOLLCalculator(period: period, k: k)
            }
        case .sar:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard case .sar = key else { return nil }
                return SARCalculator()
            }
        case .vol:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard case .vol = key else { return nil }
                return VOLCalculator()
            }
        case .rsi:
            return configuration.periods(for: indicator) { key in
                guard case let .rsi(period) = key else { return nil }
                return period
            }.map { RSICalculator(period: $0) }
        case .macd:
            return configuration.indicatorKeys(for: indicator).compactMap { key in
                guard case let .macd(short, long, signal) = key else { return nil }
                return MACDCalculator(shortPeriod: short, longPeriod: long, signalPeriod: signal)
            }
        }
    }

    func makeRenderers(configuration: KLineConfiguration) -> [any KLineRenderer] {
        switch indicator {
        case .ma:
            let periods = configuration.periods(for: indicator) { key in
                guard case let .ma(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [MARenderer(periods: periods)]
        case .ema:
            let periods = configuration.periods(for: indicator) { key in
                guard case let .ema(period) = key else { return nil }
                return period
            }
            guard !periods.isEmpty else { return [] }
            return [EMARenderer(periods: periods)]
        case .wma:
            let periods = configuration.periods(for: indicator) { key in
                guard case let .wma(period) = key else { return nil }
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
                guard case let .rsi(period) = key else { return nil }
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
