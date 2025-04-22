//
//  KLineItemLoader.swift
//  KLine
//
//  Created by iya on 2025/4/13.
//

import UIKit

final class KLineItemLoader: @unchecked Sendable {
    
    private var page = 0
    private var isLoading = false
    private var fetchTask: Task<Void, Never>?
    let provider: any KLineItemProvider
    
    typealias KLineItemsHandler = (Int, [any KLineItem]) async -> Void
    
    let klineItemsHandler: KLineItemsHandler
    
    init(provider: some KLineItemProvider, klineItemsHandler: @escaping KLineItemsHandler) {
        self.provider = provider
        self.klineItemsHandler = klineItemsHandler
    }
    
    deinit {
        fetchTask?.cancel()
    }

    @MainActor
    func scrollViewDidScroll(scrollView: UIScrollView) {
        guard !isLoading else {
            return
        }
        let offsetX = scrollView.contentOffset.x
        let width = scrollView.bounds.width
        guard offsetX < width * 2 else { return }
        loadMore()
    }
    
    func loadMore() {
        isLoading = true
        fetchTask?.cancel()
        fetchTask = Task {
            defer { isLoading = false }
            do {
                let items = try await provider.fetchKLineItems(forPage: page)
                try Task.checkCancellation()
                if items.isEmpty { return }
                await klineItemsHandler(page, items)
                try Task.checkCancellation()
                page += 1
            } catch {
                print(error)
            }
        }
    }
}
