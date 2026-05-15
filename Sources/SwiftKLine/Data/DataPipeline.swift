import Foundation

struct DataPipeline {
    private var dataMerger = DataMerger()

    mutating func reset() {
        dataMerger.reset()
    }

    @discardableResult
    mutating func apply(
        _ event: KLineItemLoaderEvent,
        to state: inout ChartState
    ) -> LiveTickMergeResult? {
        switch event {
        case let .page(index, items):
            if index == 0 {
                dataMerger.prepareBucketsIfNeeded(with: items)
                state.items = items
            } else {
                state.items = dataMerger.merge(current: state.items, patch: items)
            }
        case let .recovery(items):
            state.items = dataMerger.merge(current: state.items, patch: items)
        case let .liveTick(tick):
            return dataMerger.applyLiveTick(tick, to: &state.items)
        case let .failed(error):
            state.lastError = error
        }
        return nil
    }
}
