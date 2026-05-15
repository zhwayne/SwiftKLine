import Foundation

extension Sequence where Element == AnyIndicatorCalculator {

    /// 并发计算所有开放指标，并将各 calculator 的局部 store 归并成最终结果。
    func calculate(items: [any KLineItem]) async -> IndicatorSeriesStore {
        await withTaskGroup(of: IndicatorSeriesStore.self) { group in
            for calculator in self {
                group.addTask {
                    calculator.calculateStore(items: items)
                }
            }

            var store = IndicatorSeriesStore()
            for await partialStore in group {
                store.merge(partialStore)
            }
            return store
        }
    }
}
