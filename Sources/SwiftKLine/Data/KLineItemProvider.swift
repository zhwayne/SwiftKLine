//
//  KLineItemProvider.swift
//  SwiftKLine
//
//  Created by iya on 2025/4/13.
//

import Foundation
 
// 依赖 WebSocketMessage 作为直播解码输入
// 位于同一模块内（Sources/SwiftKLine/Websocket）

public protocol KLineItemProvider {
    
    associatedtype Item: KLineItem

    func fetchKLineItems(forPage page: Int) async throws -> [Item]

    /// 可选：返回最新一根 K 线的直播流；默认不支持（返回空流）
    func liveStream() -> AsyncStream<Item>
}

public extension KLineItemProvider {
    func liveStream() -> AsyncStream<Item> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
