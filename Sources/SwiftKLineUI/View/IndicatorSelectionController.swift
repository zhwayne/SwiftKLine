//
//  IndicatorSelectionController.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import SwiftKLineCore
import Foundation

/// Adapts the existing selector and persistence to the independent plugin pipeline.
@MainActor
final class IndicatorSelectionController {
    private var configuration: ChartConfiguration
    private let store: (any IndicatorSelectionStore)?
    private(set) var selection: IndicatorSelectionState

    init(configuration: ChartConfiguration, store: (any IndicatorSelectionStore)?) {
        self.configuration = configuration
        self.store = store
        let saved = configuration.features.contains(.indicatorPersistence) ? store?.load() : nil
        if let saved, !saved.mainIndicatorIDs.isEmpty || !saved.subIndicatorIDs.isEmpty {
            selection = saved
        } else {
            selection = configuration.indicators ?? IndicatorSelectionState(
                mainIndicators: configuration.appearance.defaultMainIndicators,
                subIndicators: configuration.appearance.defaultSubIndicators)
        }
        selection = normalized(selection)
        persist()
    }

    func apply(_ configuration: ChartConfiguration) {
        let old = self.configuration
        self.configuration = configuration
        if old.indicators != configuration.indicators {
            selection = configuration.indicators ?? defaults()
        }
        selection = normalized(selection)
    }

    func set(_ selection: IndicatorSelectionState) {
        self.selection = normalized(selection)
        persist()
    }

    func reset() {
        if configuration.features.contains(.indicatorPersistence) { store?.reset() }
        selection = normalized(defaults())
        persist()
    }

    func configuredChart() -> ChartConfiguration {
        let chosen = (selection.mainIndicators + selection.subIndicators).map {
            BuiltInIndicatorPlugin(indicator: $0, appearance: configuration.appearance) as any ChartPlugin
        }
        return configuration.includingSelectedIndicators(chosen)
    }

    private func defaults() -> IndicatorSelectionState {
        IndicatorSelectionState(mainIndicators: configuration.appearance.defaultMainIndicators,
                                subIndicators: configuration.appearance.defaultSubIndicators)
    }
    private func normalized(_ state: IndicatorSelectionState) -> IndicatorSelectionState {
        let available = Set(configuration.appearance.indicators)
        func filter(_ ids: [IndicatorID], main: Bool) -> [IndicatorID] {
            var seen = Set<IndicatorID>()
            return ids.filter { id in
                guard let indicator = BuiltInIndicator(id: id), available.contains(indicator), indicator.isMain == main else { return false }
                return seen.insert(id).inserted
            }
        }
        return IndicatorSelectionState(mainIndicatorIDs: filter(state.mainIndicatorIDs, main: true),
                                       subIndicatorIDs: filter(state.subIndicatorIDs, main: false))
    }
    private func persist() {
        if configuration.features.contains(.indicatorPersistence) { store?.save(state: selection) }
    }
}
