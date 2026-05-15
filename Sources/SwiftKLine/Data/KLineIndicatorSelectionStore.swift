//
//  IndicatorSelectionStore.swift
//  SwiftKLine
//
//  Created by iya on 2025/11/26.
//

import Foundation

/// 表示主/副图指标的选择状态，可用于做持久化存储。
public struct IndicatorSelectionState: Codable, Equatable {
    public var main: [IndicatorSelection]
    public var sub: [IndicatorSelection]

    public var mainIndicators: [KLineIndicator] {
        get { main.compactMap(\.builtInIndicator) }
        set { main = newValue.map { .builtIn($0) } }
    }

    public var subIndicators: [KLineIndicator] {
        get { sub.compactMap(\.builtInIndicator) }
        set { sub = newValue.map { .builtIn($0) } }
    }

    public init(
        main: [IndicatorSelection],
        sub: [IndicatorSelection]
    ) {
        self.main = main
        self.sub = sub
    }
    
    public init(mainIndicators: [KLineIndicator] = [], subIndicators: [KLineIndicator] = []) {
        self.main = mainIndicators.map { .builtIn($0) }
        self.sub = subIndicators.map { .builtIn($0) }
    }
}

public extension IndicatorSelection {
    var id: IndicatorID {
        switch self {
        case let .builtIn(indicator):
            return indicator.kLineID
        case let .custom(id):
            return id
        }
    }

    var builtInIndicator: KLineIndicator? {
        if case let .builtIn(indicator) = self {
            return indicator
        }
        return nil
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
            if let legacy = try? decoder.decode(LegacyIndicatorSelectionState.self, from: data) {
                let migrated = IndicatorSelectionState(
                    mainIndicators: legacy.mainIndicators,
                    subIndicators: legacy.subIndicators
                )
                save(state: migrated)
                return migrated
            }
            // 无法迁移的数据清理掉，避免反复失败
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

    private struct LegacyIndicatorSelectionState: Codable {
        var mainIndicators: [KLineIndicator]
        var subIndicators: [KLineIndicator]
    }
}
