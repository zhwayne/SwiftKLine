//
//  IndicatorSelectionNormalizer.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import Foundation

/// Filters unavailable or misplaced indicator IDs while preserving the first occurrence and declared order.
///
/// Built-in availability comes from chart configuration; custom availability and placement come from the registry.
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

    /// Normalizes main and lower-panel IDs independently; nil input produces an empty selection.
    func normalize(_ state: IndicatorSelectionState?) -> IndicatorSelectionState {
        let main = deduplicatedIDs(state?.mainIndicatorIDs ?? [], placement: .main)
        let sub = deduplicatedIDs(state?.subIndicatorIDs ?? [], placement: .sub)
        return IndicatorSelectionState(mainIndicatorIDs: main, subIndicatorIDs: sub)
    }

    /// Returns the same built-in availability rules with a replacement instance registry.
    func using(pluginRegistry: PluginRegistry) -> IndicatorSelectionNormalizer {
        IndicatorSelectionNormalizer(
            availableMain: Array(availableMain),
            availableSub: Array(availableSub),
            pluginRegistry: pluginRegistry
        )
    }

    /// Keeps only the first valid occurrence without sorting the user’s selection.
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

    /// Accepts configured built-ins or registered custom plugins; main selection also accepts overlay placement.
    private func isValid(_ id: IndicatorID, placement: IndicatorPlacement) -> Bool {
        if let builtIn = BuiltInIndicator(id: id) {
            let validSet = placement == .sub ? availableSub : availableMain
            return validSet.contains(builtIn)
        }
        guard let plugin = pluginRegistry.plugin(for: id) else { return false }
        return plugin.placement == placement || (plugin.placement == .overlay && placement == .main)
    }
}