//
//  KLineItemProvider.swift
//  KLine
//
//  Created by iya on 2025/4/13.
//

import Foundation

public protocol KLineItemProvider {
    
    associatedtype Item: KLineItem

    func fetchKLineItems(forPage page: Int) async throws -> [Item]
}
