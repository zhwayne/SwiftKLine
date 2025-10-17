//
//  KLineItemProvider.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import Foundation
 
// 依赖 WebSocketMessage 作为直播解码输入
// 位于同一模块内（Sources/SwiftKLine/Websocket）

public protocol KLineItemProvider: AnyObject {
    /// 按页获取历史 K 线数据。page=0 表示最近一页，page 递增向过去扩展。
    func fetchKLineItems(forPage page: Int) async throws -> [any KLineItem]

    /// 获取处于指定时间区间内的 K 线数据，常用于补齐缺失区段。
    /// - Parameters:
    ///   - start: 区间起始时间（包含）。
    ///   - end: 区间结束时间（包含）。
    func fetchKLineItems(from start: Date, to end: Date) async throws -> [any KLineItem]

    /// 返回最新 K 线的实时流；默认实现返回空流。
    func liveStream() -> AsyncStream<any KLineItem>
}

public extension KLineItemProvider {
    func liveStream() -> AsyncStream<any KLineItem> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
