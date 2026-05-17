//
//  ChartItemProvider.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import Foundation

public protocol ChartItemProvider: AnyObject, Sendable {
    /// 按页获取历史 K 线数据。page=0 表示最近一页，page 递增向过去扩展。
    func fetchChartItems(forPage page: Int) async throws -> [any ChartItem]

    /// 获取处于指定时间区间内的 K 线数据，常用于补齐缺失区段。
    /// - Parameters:
    ///   - start: 区间起始时间（包含）。
    ///   - end: 区间结束时间（包含）。
    func fetchChartItems(from start: Date, to end: Date) async throws -> [any ChartItem]

    /// 返回最新 K 线的实时流；默认实现返回空流。
    func liveStream() -> AsyncStream<any ChartItem>
}

public extension ChartItemProvider {
    func liveStream() -> AsyncStream<any ChartItem> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
