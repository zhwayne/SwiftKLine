//
//  IndicatorSelectionNormalizer.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import Foundation

struct IndicatorSelectionNormalizer {
    private let availableMain: Set<Indicator>
    private let availableSub: Set<Indicator>

    init(availableMain: [Indicator], availableSub: [Indicator]) {
        self.availableMain = Set(availableMain)
        self.availableSub = Set(availableSub)
    }

    func normalize(_ state: IndicatorSelectionState?) -> IndicatorSelectionState {
        let main = deduplicatedIndicators(state?.mainIndicators ?? [], validSet: availableMain)
        let sub = deduplicatedIndicators(state?.subIndicators ?? [], validSet: availableSub)
        return IndicatorSelectionState(mainIndicators: main, subIndicators: sub)
    }

    private func deduplicatedIndicators(_ indicators: [Indicator], validSet: Set<Indicator>) -> [Indicator] {
        var seen = Set<Indicator>()
        var result: [Indicator] = []
        for indicator in indicators where validSet.contains(indicator) && !seen.contains(indicator) {
            result.append(indicator)
            seen.insert(indicator)
        }
        return result
    }
}
