import Foundation

// 计算结果在 task group 之间以不可变快照传递，内部 Any 只承载值类型序列。
struct AnyIndicatorSeries: @unchecked Sendable {
    let key: KLineSeriesKey
    private let valuesStorage: Any

    init<Value>(key: KLineSeriesKey, values: ContiguousArray<Value?>) {
        self.key = key
        valuesStorage = values
    }

    func values<Value>(as type: Value.Type) -> ContiguousArray<Value?>? {
        valuesStorage as? ContiguousArray<Value?>
    }
}

/// 指标序列的统一存储。
///
/// 内部以开放的 `KLineSeriesKey` 索引，无旧兼容层。
struct IndicatorSeriesStore: @unchecked Sendable {
    private var series: [KLineSeriesKey: AnyIndicatorSeries] = [:]

    mutating func setSeries(_ value: AnyIndicatorSeries, for key: KLineSeriesKey) {
        series[key] = value
    }

    mutating func setValues<Value>(_ values: ContiguousArray<Value?>, for key: KLineSeriesKey) {
        series[key] = AnyIndicatorSeries(key: key, values: values)
    }

    func values<Value>(for key: KLineSeriesKey, as type: Value.Type) -> ContiguousArray<Value?>? {
        series[key]?.values(as: type)
    }

    /// 将另一个局部存储合并到当前存储。
    ///
    /// 语义为“同 key 覆盖”，适用于并发计算后归并结果。
    mutating func merge(_ other: IndicatorSeriesStore) {
        series.merge(other.series) { _, new in new }
    }
}
