//
//  RendererReconciler.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2026/04/27.
//

import SwiftKLineCore
import Foundation

/// Reuses compatible renderer instances across structural changes and reports the required install/uninstall transition.
@MainActor
struct RendererReconciler {
    struct Transition {
        let added: [AnyRenderer]
        let removed: [AnyRenderer]
    }

    /// Matches each new renderer by semantic ID and zIndex, consuming old instances once and preserving unmatched additions/removals.
    func reconcile(
        from oldDescriptor: ChartDescriptor,
        to newDescriptor: inout ChartDescriptor
    ) -> Transition {
        struct RendererReuseKey: Hashable {
            let id: AnyHashable
            let zIndex: Int
        }

        var available = Dictionary(grouping: oldDescriptor.renderers) { renderer in
            RendererReuseKey(id: AnyHashable(renderer.id), zIndex: renderer.zIndex)
        }
        var additions = [AnyRenderer]()
        var reused = Set<ObjectIdentifier>()

        for groupIndex in newDescriptor.groups.indices {
            var renderers = newDescriptor.groups[groupIndex].renderers
            for rendererIndex in renderers.indices {
                let renderer = renderers[rendererIndex]
                let key = RendererReuseKey(id: AnyHashable(renderer.id), zIndex: renderer.zIndex)
                if var bucket = available[key], let reusedRenderer = bucket.popLast() {
                    renderers[rendererIndex] = reusedRenderer
                    reused.insert(ObjectIdentifier(reusedRenderer))
                    available[key] = bucket.isEmpty ? nil : bucket
                } else {
                    additions.append(renderer)
                }
            }
            newDescriptor.groups[groupIndex].renderers = renderers
        }

        let removals = oldDescriptor.renderers.filter { renderer in
            !reused.contains(ObjectIdentifier(renderer))
        }
        return Transition(added: additions, removed: removals)
    }
}
