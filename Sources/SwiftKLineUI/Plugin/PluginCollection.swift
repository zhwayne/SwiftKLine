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
    let builtInKeys: [SeriesKey]?
    let make: () -> Any
    let update: (Any, ChartPluginContext) -> Void
    let dismantle: (Any) -> Void
    init<P: ChartPlugin>(_ plugin: P) {
        id = plugin.id; type = ObjectIdentifier(P.self)
        if let builtin = plugin as? BuiltInIndicatorPlugin {
            builtInKeys = builtin.configuration.indicatorKeys(for: builtin.indicator)
        } else { builtInKeys = nil }
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
    private var generation: UInt64 = 0
    /// Built-in declarations only reconcile configuration; application plugins also observe input changes.
    private(set) var needsInputUpdates = false
    var onChange: ((String, Bool, Bool) -> Void)?
    var onError: ((String, Error) -> Void)?
    var contexts: [ChartPluginContext] { entries.map(\.context) }

    func apply(_ plugins: [any ChartPlugin], input: ChartPluginInput) {
        // Only built-ins have a complete, comparable declaration. Custom plugins always receive updates.
        if plugins.count == entries.count, zip(plugins, entries).allSatisfy({ plugin, entry in
            guard let builtin = plugin as? BuiltInIndicatorPlugin else { return false }
            return entry.definition.id == builtin.id
                && entry.definition.type == ObjectIdentifier(BuiltInIndicatorPlugin.self)
                && entry.definition.builtInKeys == builtin.configuration.indicatorKeys(for: builtin.indicator)
        }) { return }
        generation &+= 1
        let transaction = generation
        var old = Dictionary(uniqueKeysWithValues: entries.map { ($0.definition.id, $0) })
        entries.removeAll()
        needsInputUpdates = false
        var next: [Entry] = []
        // Unpublished entries remain owned here; a reentrant removal cannot dismantle them twice.
        defer {
            for entry in old.values { dispose(entry) }
            for entry in next { dispose(entry) }
        }
        for plugin in plugins {
            guard generation == transaction else { return }
            let definition = erase(plugin)
            var entry: Entry
            if let previous = old.removeValue(forKey: definition.id) {
                if previous.definition.type == definition.type {
                    entry = previous; entry.definition = definition
                } else {
                    dispose(previous)
                    guard generation == transaction else { return }
                    entry = make(definition, input: input)
                }
            } else { entry = make(definition, input: input) }
            next.append(entry)
        }
        let removed = Array(old.values)
        old.removeAll()
        for entry in removed { dispose(entry) }
        guard generation == transaction else { return }
        entries = next
        next.removeAll()
        needsInputUpdates = plugins.contains { !($0 is BuiltInIndicatorPlugin) }
        update(input, includeBuiltIns: true)
    }

    func update(_ input: ChartPluginInput, includeBuiltIns: Bool = false) {
        for entry in entries {
            guard entry.context.isValid else { continue }
            entry.context.input = input
            if includeBuiltIns || entry.definition.builtInKeys == nil {
                entry.definition.update(entry.coordinator, entry.context)
            }
        }
    }

    func removeAll() {
        generation &+= 1
        let removed = entries
        entries.removeAll()
        needsInputUpdates = false
        for entry in removed { dispose(entry) }
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
        guard entry.context.isValid else { return }
        let hadCalculators = !entry.context.calculators.isEmpty
        entry.context.revoke()
        entry.definition.dismantle(entry.coordinator)
        onChange?(entry.definition.id, hadCalculators, true)
    }

    private func erase(_ plugin: any ChartPlugin) -> PluginDefinition { PluginDefinition(plugin) }
}
