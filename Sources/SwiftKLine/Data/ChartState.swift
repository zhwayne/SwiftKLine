import CoreGraphics
import Foundation

struct ChartState {
    var items: [any ChartItem]
    var indicatorSeriesStore: IndicatorSeriesStore
    var contentStyle: ChartType
    var selectedIndex: Int?
    var selectedLocation: CGPoint?
    var lastError: Error?
    var indicatorSelection: IndicatorSelectionState

    var mainIndicators: [BuiltInIndicator] { indicatorSelection.mainIndicators }
    var subIndicators: [BuiltInIndicator] { indicatorSelection.subIndicators }

    init(
        items: [any ChartItem] = [],
        indicatorSeriesStore: IndicatorSeriesStore = IndicatorSeriesStore(),
        contentStyle: ChartType = .candlestick,
        selectedIndex: Int? = nil,
        selectedLocation: CGPoint? = nil,
        lastError: Error? = nil,
        indicatorSelection: IndicatorSelectionState = IndicatorSelectionState(main: [], sub: [])
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
