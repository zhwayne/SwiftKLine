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
    private let pluginRegistry: KLinePluginRegistry

    init(
        availableMain: [KLineIndicator],
        availableSub: [KLineIndicator],
        pluginRegistry: KLinePluginRegistry = .default
    ) {
        self.availableMain = Set(availableMain)
        self.availableSub = Set(availableSub)
        self.pluginRegistry = pluginRegistry
    }

    func normalize(_ state: KLineIndicatorSelectionState?) -> KLineIndicatorSelectionState {
        let main = deduplicatedSelections(state?.main ?? [], placement: .main)
        let sub = deduplicatedSelections(state?.sub ?? [], placement: .sub)
        return KLineIndicatorSelectionState(main: main, sub: sub)
    }

    func using(pluginRegistry: KLinePluginRegistry) -> IndicatorSelectionNormalizer {
        IndicatorSelectionNormalizer(
            availableMain: Array(availableMain),
            availableSub: Array(availableSub),
            pluginRegistry: pluginRegistry
        )
    }

    private func deduplicatedSelections(
        _ selections: [KLineIndicatorSelection],
        placement: KLineIndicatorPlacement
    ) -> [KLineIndicatorSelection] {
        var seen = Set<KLineIndicatorID>()
        var result: [KLineIndicatorSelection] = []
        for selection in selections {
            guard isValid(selection, placement: placement), !seen.contains(selection.id) else { continue }
            result.append(selection)
            seen.insert(selection.id)
        }
        return result
    }

    private func isValid(_ selection: KLineIndicatorSelection, placement: KLineIndicatorPlacement) -> Bool {
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
