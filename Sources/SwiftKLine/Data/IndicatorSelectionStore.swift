//
//  IndicatorSelectionStore.swift
//  SwiftKLine
//
//  Created by iya on 2025/11/26.
//

import Foundation

/// 表示主/副图指标的选择状态，可用于做持久化存储。
public struct IndicatorSelectionState: Codable, Equatable {
    public var mainIndicators: [Indicator]
    public var subIndicators: [Indicator]
    
    public init(mainIndicators: [Indicator] = [], subIndicators: [Indicator] = []) {
        self.mainIndicators = mainIndicators
        self.subIndicators = subIndicators
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
            // 数据损坏时清理，避免反复失败
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
}
