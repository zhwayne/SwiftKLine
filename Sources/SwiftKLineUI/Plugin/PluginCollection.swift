//
//  PluginCollection.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import SwiftKLineCore
import Foundation

/// Private type erasure at the declarative assembly boundary, confined to the main actor.
@MainActor
private struct PluginDefinition {
    let id: String
    let type: ObjectIdentifier
    let make: () -> Any
    let update: (Any, ChartPluginContext) -> Void
    let dismantle: (Any) -> Void
    init<P: ChartPlugin>(_ plugin: P) {
        id = plugin.id; type = ObjectIdentifier(P.self)
        make = { plugin.makeCoordinator() }
        update = { plugin.update(coordinator: $0 as! P.Coordinator, context: $1) }
        dismantle = { P.dismantleCoordinator($0 as! P.Coordinator) }
    }
}

/// Owns one chart's plugin coordinators and preserves explicit declaration order.
@MainActor
final class PluginCollection {
    private struct Entry {
        var definition: PluginDefinition
        let coordinator: Any
        let context: ChartPluginContext
    }
    private var entries: [Entry] = []
    /// Built-in declarations only reconcile configuration; application plugins also observe input changes.
    private(set) var needsInputUpdates = false
    var onChange: ((String, Bool, Bool) -> Void)?
    var onError: ((String, Error) -> Void)?
    var contexts: [ChartPluginContext] { entries.map(\.context) }

    func apply(_ plugins: [any ChartPlugin], input: ChartPluginInput) {
        var old = Dictionary(uniqueKeysWithValues: entries.map { ($0.definition.id, $0) })
        var next: [Entry] = []
        for plugin in plugins {
            let definition = erase(plugin)
            var entry: Entry
            if let previous = old.removeValue(forKey: definition.id) {
                if previous.definition.type == definition.type {
                    entry = previous; entry.definition = definition
                } else {
                    dispose(previous)
                    entry = make(definition, input: input)
                }
            } else { entry = make(definition, input: input) }
            next.append(entry)
        }
        for removed in old.values { dispose(removed) }
        entries = next
        needsInputUpdates = plugins.contains { !($0 is BuiltInIndicatorPlugin) }
        update(input)
    }

    func update(_ input: ChartPluginInput) {
        for entry in entries {
            entry.context.input = input
            entry.definition.update(entry.coordinator, entry.context)
        }
    }

    func removeAll() {
        for entry in entries { dispose(entry) }
        entries.removeAll()
        needsInputUpdates = false
    }

    private func make(_ definition: PluginDefinition, input: ChartPluginInput) -> Entry {
        let context = ChartPluginContext(id: definition.id, input: input)
        context.onChange = { [weak self] calculate, structure in
            self?.onChange?(definition.id, calculate, structure)
        }
        context.onError = { [weak self] error in self?.onError?(definition.id, error) }
        return Entry(definition: definition, coordinator: definition.make(), context: context)
    }

    private func dispose(_ entry: Entry) {
        let hadCalculators = !entry.context.calculators.isEmpty
        entry.context.revoke()
        entry.definition.dismantle(entry.coordinator)
        onChange?(entry.definition.id, hadCalculators, true)
    }

    private func erase(_ plugin: any ChartPlugin) -> PluginDefinition { PluginDefinition(plugin) }
}
