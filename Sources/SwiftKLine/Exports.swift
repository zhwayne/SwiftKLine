//
//  Exports.swift
//  SwiftKLine
//
//  Created by zhwayne on 2026/10/21.
//

// Preserve the single-import API while allowing calculation-only clients to use SwiftKLineCore.
@_exported import SwiftKLineCore
#if canImport(UIKit)
@_exported import SwiftKLineUI
@_exported import SwiftKLineSwiftUI
#endif
