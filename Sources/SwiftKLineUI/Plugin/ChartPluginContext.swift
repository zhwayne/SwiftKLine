//
//  ChartPluginContext.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/10/21.
//

import SwiftKLineCore
import UIKit

/// Revocable, plugin-scoped access to calculation and drawing resources.
///
/// Callbacks retain the host weakly. Retaining this capability cannot keep a chart alive.
@MainActor
public final class ChartPluginContext {
    /// Current published data and viewport demand, refreshed before each update.
    public internal(set) var input: ChartPluginInput
    let id: String
    private(set) var isValid = true
    private(set) var calculators: [(String, AnyIndicatorCalculator)] = []
    private(set) var renderers: [(String, PluginPanel, any ChartRenderer)] = []
    var onChange: ((Bool, Bool) -> Void)?
    var onError: ((Error) -> Void)?

    init(id: String, input: ChartPluginInput) { self.id = id; self.input = input }

    /// Replaces a local calculator and invalidates its output, even if its series key is unchanged.
    public func setCalculator(_ calculator: any IndicatorCalculator, for id: String) {
        guard isValid else { return }
        let erased = calculator.eraseToAnyIndicatorCalculator()
        guard !calculators.contains(where: { $0.0 != id && $0.1.id == erased.id }) else {
            report(ChartPluginError.duplicateSeries(erased.id)); return
        }
        if let index = calculators.firstIndex(where: { $0.0 == id }) { calculators[index].1 = erased }
        else { calculators.append((id, erased)) }
        onChange?(true, false)
    }

    /// Removes a local calculator and invalidates its obsolete output.
    public func removeCalculator(for id: String) {
        guard isValid, let index = calculators.firstIndex(where: { $0.0 == id }) else { return }
        calculators.remove(at: index)
        onChange?(true, false)
    }

    /// Replaces the actual object; semantic renderer IDs never discard a new renderer.
    public func setRenderer(_ renderer: any ChartRenderer, for id: String, panel: PluginPanel) {
        guard isValid else { return }
        if let index = renderers.firstIndex(where: { $0.0 == id }) {
            let old = renderers[index]
            guard old.2 !== renderer || old.1 != panel else { return }
            renderers[index] = (id, panel, renderer)
        } else { renderers.append((id, panel, renderer)) }
        onChange?(false, true)
    }

    /// Detaches one local renderer without disturbing other plugins.
    public func removeRenderer(for id: String) {
        guard isValid, let index = renderers.firstIndex(where: { $0.0 == id }) else { return }
        renderers.remove(at: index)
        onChange?(false, true)
    }

    /// Invalidates drawing and legends without restarting calculations or providers.
    public func requestRedraw() { if isValid { onChange?(false, false) } }
    /// Reports an error tagged with this plugin identity; revoked contexts ignore it.
    public func report(_ error: any Error) { if isValid { onError?(error) } }

    func revoke() {
        isValid = false
        onChange = nil; onError = nil
        calculators.removeAll(); renderers.removeAll()
    }
}
