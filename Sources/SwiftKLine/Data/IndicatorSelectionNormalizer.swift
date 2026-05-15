//
//  IndicatorSelectionNormalizer.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

@MainActor
struct IndicatorSelectionNormalizer {
    private let availableMain: Set<KLineIndicator>
    private let availableSub: Set<KLineIndicator>
    private let pluginRegistry: PluginRegistry

    init(
        availableMain: [KLineIndicator],
        availableSub: [KLineIndicator],
        pluginRegistry: PluginRegistry = .default
    ) {
        self.availableMain = Set(availableMain)
        self.availableSub = Set(availableSub)
        self.pluginRegistry = pluginRegistry
    }

    func normalize(_ state: IndicatorSelectionState?) -> IndicatorSelectionState {
        let main = deduplicatedSelections(state?.main ?? [], placement: .main)
        let sub = deduplicatedSelections(state?.sub ?? [], placement: .sub)
        return IndicatorSelectionState(main: main, sub: sub)
    }

    func using(pluginRegistry: PluginRegistry) -> IndicatorSelectionNormalizer {
        IndicatorSelectionNormalizer(
            availableMain: Array(availableMain),
            availableSub: Array(availableSub),
            pluginRegistry: pluginRegistry
        )
    }

    private func deduplicatedSelections(
        _ selections: [IndicatorSelection],
        placement: IndicatorPlacement
    ) -> [IndicatorSelection] {
        var seen = Set<IndicatorID>()
        var result: [IndicatorSelection] = []
        for selection in selections {
            guard isValid(selection, placement: placement), !seen.contains(selection.id) else { continue }
            result.append(selection)
            seen.insert(selection.id)
        }
        return result
    }

    private func isValid(_ selection: IndicatorSelection, placement: IndicatorPlacement) -> Bool {
        switch selection {
        case let .builtIn(indicator):
            let validSet = placement == .sub ? availableSub : availableMain
            return validSet.contains(indicator)
        case let .custom(id):
            guard let plugin = pluginRegistry.plugin(for: id) else { return false }
            return plugin.placement == placement || (plugin.placement == .overlay && placement == .main)
        }
    }
}
