//
//  LegendCache.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/4/27.
//

import UIKit

struct LegendCache<Key: Hashable> {
    struct Value {
        let text: NSAttributedString
        let size: CGSize
    }

    private let capacity: Int
    private var storage: [Key: Value] = [:]
    private(set) var lastMainKey: Key?

    init(capacity: Int = 256) {
        self.capacity = capacity
    }

    subscript(key: Key) -> Value? {
        storage[key]
    }

    mutating func clear() {
        storage.removeAll(keepingCapacity: true)
        lastMainKey = nil
    }

    mutating func resetLastMainKey() {
        lastMainKey = nil
    }

    mutating func markMainKey(_ key: Key) {
        lastMainKey = key
    }

    mutating func store(_ value: Value, for key: Key) {
        if storage.count >= capacity {
            clear()
        }
        storage[key] = value
    }

    @MainActor
    static func makeLegendText(
        for renderers: [AnyRenderer],
        context: KLineRendererContext<any KLineItem>
    ) -> NSMutableAttributedString {
        let legendText = NSMutableAttributedString()
        for renderer in renderers {
            guard let string = renderer.legend(context: context) else { continue }
            if !legendText.string.isEmpty {
                legendText.append(NSAttributedString(string: "\n"))
            }
            legendText.append(string)
        }
        return legendText
    }

    @MainActor
    static func rendererIDsHash(_ renderers: [AnyRenderer]) -> Int {
        var hasher = Hasher()
        for renderer in renderers {
            hasher.combine(AnyHashable(renderer.id))
            hasher.combine(renderer.zIndex)
        }
        return hasher.finalize()
    }
}
