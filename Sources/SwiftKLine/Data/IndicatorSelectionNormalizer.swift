//
//  IndicatorSelectionNormalizer.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

@MainActor
struct IndicatorSelectionNormalizer {
    private let availableMain: Set<BuiltInIndicator>
    private let availableSub: Set<BuiltInIndicator>
    private let pluginRegistry: PluginRegistry

    init(
        availableMain: [BuiltInIndicator],
        availableSub: [BuiltInIndicator],
        pluginRegistry: PluginRegistry = .default
    ) {
        self.availableMain = Set(availableMain)
        self.availableSub = Set(availableSub)
        self.pluginRegistry = pluginRegistry
    }

    func normalize(_ state: IndicatorSelectionState?) -> IndicatorSelectionState {
        let main = deduplicatedIDs(state?.main ?? [], placement: .main)
        let sub = deduplicatedIDs(state?.sub ?? [], placement: .sub)
        return IndicatorSelectionState(main: main, sub: sub)
    }

    func using(pluginRegistry: PluginRegistry) -> IndicatorSelectionNormalizer {
        IndicatorSelectionNormalizer(
            availableMain: Array(availableMain),
            availableSub: Array(availableSub),
            pluginRegistry: pluginRegistry
        )
    }

    private func deduplicatedIDs(
        _ ids: [IndicatorID],
        placement: IndicatorPlacement
    ) -> [IndicatorID] {
        var seen = Set<IndicatorID>()
        var result: [IndicatorID] = []
        for id in ids {
            guard isValid(id, placement: placement), !seen.contains(id) else { continue }
            result.append(id)
            seen.insert(id)
        }
        return result
    }

    private func isValid(_ id: IndicatorID, placement: IndicatorPlacement) -> Bool {
        if let builtIn = BuiltInIndicator(id: id) {
            let validSet = placement == .sub ? availableSub : availableMain
            return validSet.contains(builtIn)
        }
        guard let plugin = pluginRegistry.plugin(for: id) else { return false }
        return plugin.placement == placement || (plugin.placement == .overlay && placement == .main)
    }
}