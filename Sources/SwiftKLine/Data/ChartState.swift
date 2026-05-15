import CoreGraphics
import Foundation

struct ChartState {
    var items: [any KLineItem]
    var indicatorSeriesStore: IndicatorSeriesStore
    var contentStyle: ChartType
    var selectedIndex: Int?
    var selectedLocation: CGPoint?
    var lastError: Error?
    var indicatorSelection: IndicatorSelectionState

    var mainIndicators: [KLineIndicator] { indicatorSelection.mainIndicators }
    var subIndicators: [KLineIndicator] { indicatorSelection.subIndicators }

    init(
        items: [any KLineItem] = [],
        indicatorSeriesStore: IndicatorSeriesStore = IndicatorSeriesStore(),
        contentStyle: ChartType = .candlestick,
        selectedIndex: Int? = nil,
        selectedLocation: CGPoint? = nil,
        lastError: Error? = nil,
        indicatorSelection: IndicatorSelectionState = IndicatorSelectionState()
    ) {
        self.items = items
        self.indicatorSeriesStore = indicatorSeriesStore
        self.contentStyle = contentStyle
        self.selectedIndex = selectedIndex
        self.selectedLocation = selectedLocation
        self.lastError = lastError
        self.indicatorSelection = indicatorSelection
    }
}
