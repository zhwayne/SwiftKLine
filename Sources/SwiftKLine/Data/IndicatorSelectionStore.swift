//
//  IndicatorSelectionStore.swift
//  SwiftKLine
//
//  Created by iya on 2025/11/26.
//

import Foundation

/// 表示主/副图指标的选择状态，可用于做持久化存储。
public struct IndicatorSelectionState: Codable, Equatable, Sendable {
    public var main: [IndicatorID]
    public var sub: [IndicatorID]

    public init(main: [IndicatorID] = [], sub: [IndicatorID] = []) {
        self.main = main
        self.sub = sub
    }

    public init(mainIndicators: [BuiltInIndicator] = [], subIndicators: [BuiltInIndicator] = []) {
        self.main = mainIndicators.map(\.id)
        self.sub = subIndicators.map(\.id)
    }

    public var mainIndicators: [BuiltInIndicator] {
        main.compactMap { BuiltInIndicator(id: $0) }
    }

    public var subIndicators: [BuiltInIndicator] {
        sub.compactMap { BuiltInIndicator(id: $0) }
    }

    var indicatorIDs: [IndicatorID] {
        main + sub
    }
}

/// 抽象指标选择状态的存取行为，便于注入不同的持久化方案。
public protocol IndicatorSelectionStore {
    func load() -> IndicatorSelectionState?
    func save(state: IndicatorSelectionState)
    func reset()
}

public final class UserDefaultsIndicatorSelectionStore: IndicatorSelectionStore {

    public static let defaultKey = "com.swiftkline.indicator.selection"

    private let userDefaults: UserDefaults
    private let key: String
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = UserDefaultsIndicatorSelectionStore.defaultKey
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> IndicatorSelectionState? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(IndicatorSelectionState.self, from: data)
        } catch {
            if let v1 = try? decoder.decode(LegacyV1IndicatorSelectionState.self, from: data) {
                let migrated = IndicatorSelectionState(
                    mainIndicators: v1.mainIndicators,
                    subIndicators: v1.subIndicators
                )
                save(state: migrated)
                return migrated
            }
            if let v2 = try? decoder.decode(LegacyV2IndicatorSelectionState.self, from: data) {
                var mainIDs: [IndicatorID] = []
                var subIDs: [IndicatorID] = []
                for selection in v2.main {
                    switch selection {
                    case let .builtIn(indicator): mainIDs.append(indicator.id)
                    case let .custom(id): mainIDs.append(id)
                    }
                }
                for selection in v2.sub {
                    switch selection {
                    case let .builtIn(indicator): subIDs.append(indicator.id)
                    case let .custom(id): subIDs.append(id)
                    }
                }
                let migrated = IndicatorSelectionState(main: mainIDs, sub: subIDs)
                save(state: migrated)
                return migrated
            }
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }

    public func save(state: IndicatorSelectionState) {
        guard let data = try? encoder.encode(state) else { return }
        userDefaults.set(data, forKey: key)
    }

    public func reset() {
        userDefaults.removeObject(forKey: key)
    }

    private struct LegacyV1IndicatorSelectionState: Codable {
        var mainIndicators: [BuiltInIndicator]
        var subIndicators: [BuiltInIndicator]
    }

    private enum LegacyV2IndicatorSelection: Hashable, Sendable, Codable {
        case builtIn(BuiltInIndicator)
        case custom(IndicatorID)
    }

    private struct LegacyV2IndicatorSelectionState: Codable {
        var main: [LegacyV2IndicatorSelection]
        var sub: [LegacyV2IndicatorSelection]
    }
}