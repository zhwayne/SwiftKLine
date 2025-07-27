//
//  Array++.swift
//  KLineDemo
//
//  Created by iya on 2024/11/1.
//

import Foundation

extension Sequence where Element == any IndicatorCalculator {
    
    func calculate(items: [any KLineItem]) async -> ValueStorage {
        let storageActor = ValueStorageActor(storage: ValueStorage())
        await withTaskGroup(of: Void.self) { group in
            for calc in self {
                group.addTask {
                    let anyCalc = AnyIndicatorCalculator(calc)
                    await anyCalc.dispatchCalculation(items: items, to: storageActor)
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
    
    func update<Key: Hashable, Value>(values: [Value], forKey key: Key) {
        storage.set(value: values, forKey: key)
    }
}


private struct AnyIndicatorCalculator: @unchecked Sendable {
    let id: AnyHashable
    let indicator: Indicator

    private let _calculate: ([any KLineItem]) -> Any
    private let _calculateAndUpdate: ([any KLineItem], ValueStorageActor) async -> Void

    init<C: IndicatorCalculator>(_ base: C) {
        self.id = AnyHashable(base.id)
        self.indicator = base.indicator
        self._calculate = { items in
            base.calculate(for: items)
        }
        self._calculateAndUpdate = { items, actor in
            if let values = base.calculate(for: items, asType: C.Result.self) {
                await actor.update(values: values, forKey: base.id)
            }
        }
    }

    func calculate(for items: [any KLineItem]) -> Any {
        _calculate(items)
    }
    
    func dispatchCalculation(items: [any KLineItem], to actor: ValueStorageActor) async {
        await _calculateAndUpdate(items, actor)
    }
}
