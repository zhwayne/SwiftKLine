//
//  SwiftKLineExampleApp.swift
//  SwiftKLineExample
//
//  Created by zhwayne on 2025/04/13.
//

import SwiftUI
import SwiftKLine

/// The SwiftUI entry point for the standalone chart example.
@main
struct SwiftKLineExampleApp: App {
    
    @State private var chartState = ChartScreenState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(state: chartState)
        }
    }
}
