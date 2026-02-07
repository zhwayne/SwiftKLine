//
//  IndicatorCatalog.swift
//  SwiftKLine
//
//  Created by iya on 2026/2/7.
//

import Foundation

/// 指标元数据注册表（单一真相源）。
///
/// 新增指标时优先在这里挂载 spec，避免在计算、渲染、映射多处重复修改。
@MainActor
enum IndicatorCatalog {
    /// 所有内置指标 spec。
    static let allSpecs: [any IndicatorSpec] = [
        MASpec(),
        EMASpec(),
        WMASpec(),
        BOLLSpec(),
        SARSpec(),
        VOLSpec(),
        RSISpec(),
        MACDSpec(),
    ]

    private static let specsByIndicator: [Indicator: any IndicatorSpec] = {
        Dictionary(uniqueKeysWithValues: allSpecs.map { ($0.indicator, $0) })
    }()

    /// 按指标类型查找 spec。
    static func spec(for indicator: Indicator) -> (any IndicatorSpec)? {
        specsByIndicator[indicator]
    }
}

private extension KLineConfiguration {
    /// 从配置里的 `indicatorKeys` 提取周期参数。
    /// 抽到统一 helper，避免各 spec 重复 `compactMap` 模板代码。
    func periods(for indicator: Indicator, matching extractor: (Indicator.Key) -> Int?) -> [Int] {
        indicatorKeys(for: indicator).compactMap(extractor)
    }
}

/// MA 指标定义。
@MainActor
private struct MASpec: IndicatorSpec {
    let indicator: Indicator = .ma
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.periods(for: indicator) { key in
            guard case let .ma(period) = key else { return nil }
            return period
        }
        .map { MACalculator(period: $0) }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        let periods = configuration.periods(for: indicator) { key in
            guard case let .ma(period) = key else { return nil }
            return period
        }
        guard !periods.isEmpty else { return nil }
        return MARenderer(peroids: periods)
    }
}

/// EMA 指标定义。
@MainActor
private struct EMASpec: IndicatorSpec {
    let indicator: Indicator = .ema
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.periods(for: indicator) { key in
            guard case let .ema(period) = key else { return nil }
            return period
        }
        .map { EMACalculator(period: $0) }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        let periods = configuration.periods(for: indicator) { key in
            guard case let .ema(period) = key else { return nil }
            return period
        }
        guard !periods.isEmpty else { return nil }
        return EMARenderer(peroids: periods)
    }
}

/// WMA 指标定义。
@MainActor
private struct WMASpec: IndicatorSpec {
    let indicator: Indicator = .wma
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.periods(for: indicator) { key in
            guard case let .wma(period) = key else { return nil }
            return period
        }
        .map { WMACalculator(period: $0) }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        let periods = configuration.periods(for: indicator) { key in
            guard case let .wma(period) = key else { return nil }
            return period
        }
        guard !periods.isEmpty else { return nil }
        return WMARenderer(periods: periods)
    }
}

/// BOLL 指标定义。
@MainActor
private struct BOLLSpec: IndicatorSpec {
    let indicator: Indicator = .boll
    let valueFamily: IndicatorValueFamily = .boll

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.indicatorKeys(for: indicator).compactMap { key in
            guard case .boll = key else { return nil }
            return BOLLCalculator()
        }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        BOLLRenderer()
    }
}

/// SAR 指标定义。
@MainActor
private struct SARSpec: IndicatorSpec {
    let indicator: Indicator = .sar
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.indicatorKeys(for: indicator).compactMap { key in
            guard case .sar = key else { return nil }
            return SARCalculator()
        }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        SARRenderer()
    }
}

/// VOL 指标定义。
@MainActor
private struct VOLSpec: IndicatorSpec {
    let indicator: Indicator = .vol
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.indicatorKeys(for: indicator).compactMap { key in
            guard case .vol = key else { return nil }
            return VOLCalculator()
        }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        VOLRenderer()
    }
}

/// RSI 指标定义。
@MainActor
private struct RSISpec: IndicatorSpec {
    let indicator: Indicator = .rsi
    let valueFamily: IndicatorValueFamily = .scalar

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.periods(for: indicator) { key in
            guard case let .rsi(period) = key else { return nil }
            return period
        }
        .map { RSICalculator(period: $0) }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        let periods = configuration.periods(for: indicator) { key in
            guard case let .rsi(period) = key else { return nil }
            return period
        }
        guard !periods.isEmpty else { return nil }
        return RSIRenderer(peroids: periods)
    }
}

/// MACD 指标定义。
@MainActor
private struct MACDSpec: IndicatorSpec {
    let indicator: Indicator = .macd
    let valueFamily: IndicatorValueFamily = .macd

    func makeCalculators(configuration: KLineConfiguration) -> [any IndicatorCalculator] {
        configuration.indicatorKeys(for: indicator).compactMap { key in
            guard case .macd = key else { return nil }
            return MACDCalculator()
        }
    }

    func makeRenderer(configuration: KLineConfiguration) -> (any Renderer)? {
        MACDRenderer()
    }
}
