//
//  IndicatorSelectionStore.swift
//  SwiftKLine
//
//  Created by iya on 2025/11/26.
//

import Foundation

/// 表示主/副图指标的选择状态，可用于做持久化存储。
public struct IndicatorSelectionState: Codable, Equatable, Sendable {
    public var mainIndicatorIDs: [IndicatorID]
    public var subIndicatorIDs: [IndicatorID]

    public init(mainIndicatorIDs: [IndicatorID] = [], subIndicatorIDs: [IndicatorID] = []) {
        self.mainIndicatorIDs = mainIndicatorIDs
        self.subIndicatorIDs = subIndicatorIDs
    }

    @available(*, deprecated, renamed: "init(mainIndicatorIDs:subIndicatorIDs:)")
    public init(main: [IndicatorID] = [], sub: [IndicatorID] = []) {
        self.init(mainIndicatorIDs: main, subIndicatorIDs: sub)
    }

    public init(mainIndicators: [BuiltInIndicator] = [], subIndicators: [BuiltInIndicator] = []) {
        self.mainIndicatorIDs = mainIndicators.map(\.id)
        self.subIndicatorIDs = subIndicators.map(\.id)
    }

    @available(*, deprecated, renamed: "mainIndicatorIDs")
    public var main: [IndicatorID] {
        get { mainIndicatorIDs }
        set { mainIndicatorIDs = newValue }
    }

    @available(*, deprecated, renamed: "subIndicatorIDs")
    public var sub: [IndicatorID] {
        get { subIndicatorIDs }
        set { subIndicatorIDs = newValue }
    }

    public var mainIndicators: [BuiltInIndicator] {
        mainIndicatorIDs.compactMap { BuiltInIndicator(id: $0) }
    }

    public var subIndicators: [BuiltInIndicator] {
        subIndicatorIDs.compactMap { BuiltInIndicator(id: $0) }
    }

    var indicatorIDs: [IndicatorID] {
        mainIndicatorIDs + subIndicatorIDs
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainIndicatorIDs, forKey: .main)
        try container.encode(subIndicatorIDs, forKey: .sub)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mainIndicatorIDs = try container.decode([IndicatorID].self, forKey: .main)
        self.subIndicatorIDs = try container.decode([IndicatorID].self, forKey: .sub)
    }

    private enum CodingKeys: String, CodingKey {
        case main, sub
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
        return try? decoder.decode(IndicatorSelectionState.self, from: data)
    }

    public func save(state: IndicatorSelectionState) {
        guard let data = try? encoder.encode(state) else { return }
        userDefaults.set(data, forKey: key)
    }

    public func reset() {
        userDefaults.removeObject(forKey: key)
    }
}
