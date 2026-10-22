//
//  RangeDataProvider.swift
//  SwiftKLineCore
//
//  Created by zhwayne on 2026/10/21.
//

import Foundation

/// A page belonging to an unchanged half-open time query; nil ends that query.
public struct RangePage<Item: Sendable, Cursor: Hashable & Sendable>: Sendable {
    /// Items returned by this page, including an empty page with a continuation cursor.
    public let items: [Item]
    /// The next cursor for this exact query, or nil when the query is complete.
    public let nextCursor: Cursor?
    /// Creates a page without coupling its cursor to candle pagination.
    public init(items: [Item], nextCursor: Cursor?) { self.items = items; self.nextCursor = nextCursor }
}

/// An independent, cursor-paged source of time-addressed values.
public protocol RangeDataProvider: Sendable {
    /// The immutable value produced by this independent source.
    associatedtype Item: Sendable
    /// An opaque cursor; hashability allows the loader to reject cursor loops.
    associatedtype Cursor: Hashable & Sendable
    /// Cursors belong to this exact [lowerBound, upperBound) query and ordering.
    func fetch(in range: Range<Date>, cursor: Cursor?) async throws -> RangePage<Item, Cursor>
}

/// A recoverable failure local to one range-loading session.
public enum RangeLoadingError: Error, Sendable, Equatable {
    /// The backend returned a cursor already visited by this query.
    case repeatedCursor
    /// The visible demand alone exceeds the configured hard item limit.
    case cacheCapacityExceeded
}

/// An immutable cache publication; empty completed ranges are represented explicitly.
public struct RangeSnapshot<Item: Sendable>: Sendable {
    /// Cached values in timestamp order, with stable ordering for equal timestamps.
    public let items: [Item]
    /// Fully queried intervals, including those with no items.
    public let completedRanges: [Range<Date>]
    /// Whether an active page or continuation remains to be fetched.
    public let isLoading: Bool
    /// The current query error; nil after a successful retry or replacement demand.
    public let error: (any Error)?
}
