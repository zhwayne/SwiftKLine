import CoreGraphics
import Foundation

struct ChartState {
    var items: [any KLineItem]
    var indicatorSeriesStore: IndicatorSeriesStore
    var contentStyle: KLineChartContentStyle
    var selectedIndex: Int?
    var selectedLocation: CGPoint?
    var lastError: Error?
    var indicatorSelection: KLineIndicatorSelectionState

    var mainIndicators: [KLineIndicator] { indicatorSelection.mainIndicators }
    var subIndicators: [KLineIndicator] { indicatorSelection.subIndicators }

    init(
        items: [any KLineItem] = [],
        indicatorSeriesStore: IndicatorSeriesStore = IndicatorSeriesStore(),
        contentStyle: KLineChartContentStyle = .candlestick,
        selectedIndex: Int? = nil,
        selectedLocation: CGPoint? = nil,
        lastError: Error? = nil,
        indicatorSelection: KLineIndicatorSelectionState = KLineIndicatorSelectionState()
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
