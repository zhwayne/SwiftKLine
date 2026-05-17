import UIKit

public struct LayoutMetrics: Equatable {
    public let mainChartHeight: CGFloat
    public let timelineHeight: CGFloat
    public let indicatorHeight: CGFloat
    public let indicatorSelectorHeight: CGFloat

    public init(
        mainChartHeight: CGFloat = 320,
        timelineHeight: CGFloat = 16,
        indicatorHeight: CGFloat = 64,
        indicatorSelectorHeight: CGFloat = 32
    ) {
        self.mainChartHeight = mainChartHeight
        self.timelineHeight = timelineHeight
        self.indicatorHeight = indicatorHeight
        self.indicatorSelectorHeight = indicatorSelectorHeight
    }
}