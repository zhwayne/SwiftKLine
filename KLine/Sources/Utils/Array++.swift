//
//  Array++.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

extension Collection where Element == AnyRenderer {

    func calculateIndicators(items: [any KLineItem]) async -> ValueStorage {
        let storageActor = ValueStorageActor(storage: ValueStorage())
        await withTaskGroup(of: Void.self) { group in
            for renderer in self where renderer.calculator != nil {
                group.addTask {
                    let calculator = renderer.calculator!
                    let values = calculator.calculate(for: items)
                    let key = calculator.identifier
                    await storageActor.update(key: key, values: values)
                }
            }
            await group.waitForAll()
        }
        return await storageActor.storage
    }
}

private actor ValueStorageActor {
    var storage: ValueStorage
    
    init(storage: ValueStorage) {
        self.storage = storage
    }
    
    func update<Key: Hashable>(key: Key, values: Any) {
        storage[key] = values
    }
}
