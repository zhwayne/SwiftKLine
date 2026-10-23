//
//  IndicatorSelectorView.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2026/10/22.
//

import SwiftUI
import SwiftKLine

/// An application-owned indicator selector demonstrating how to drive the chart through a binding.
struct IndicatorSelectorView: View {
    private let mainIndicators: [BuiltInIndicator]
    private let subIndicators: [BuiltInIndicator]
    @Binding private var selection: IndicatorSelection

    init(indicators: [BuiltInIndicator], selection: Binding<IndicatorSelection>) {
        mainIndicators = indicators.filter(\.isMain)
        subIndicators = indicators.filter { !$0.isMain }
        _selection = selection
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                IndicatorSelectorGroup(indicators: mainIndicators, selection: $selection, accessibilityLabel: "主图指标")
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 11)
                    .padding(.horizontal, 8)
                    .accessibilityHidden(true)
                IndicatorSelectorGroup(indicators: subIndicators, selection: $selection, accessibilityLabel: "副图指标")
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 8)
        .frame(height: 36)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("技术指标")
    }
}

private struct IndicatorSelectorGroup: View {
    let indicators: [BuiltInIndicator]
    @Binding var selection: IndicatorSelection
    let accessibilityLabel: String

    var body: some View {
        ForEach(indicators, id: \.id) { indicator in
            IndicatorSelectorButton(indicator: indicator, selection: $selection)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct IndicatorSelectorButton: View {
    let indicator: BuiltInIndicator
    @Binding var selection: IndicatorSelection

    private var isSelected: Bool {
        let ids = indicator.isMain ? selection.mainIndicatorIDs : selection.subIndicatorIDs
        return ids.contains(indicator.id)
    }

    var body: some View {
        Button { toggleSelection() } label: {
            Text(indicator.rawValue)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color(.label).opacity(0.8) : Color(.systemGray2))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private func toggleSelection() {
        if indicator.isMain {
            toggle(indicator.id, in: &selection.mainIndicatorIDs)
        } else {
            toggle(indicator.id, in: &selection.subIndicatorIDs)
        }
    }

    private func toggle(_ id: IndicatorID, in ids: inout [IndicatorID]) {
        if let index = ids.firstIndex(of: id) { ids.remove(at: index) }
        else { ids.append(id) }
    }
}
