//
//  ContentView.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import KLine

struct ContentView: View {
    
    @State var period: KLinePeriod = .fiveMinutes
    
    var body: some View {
        ScrollView {
            VStack {
                KLinePeriodPicker(period: $period)
                KLineSwiftUIView(period: period)
            }
        }
        .contentMargins(.vertical, 16)
    }
}

#Preview {
    ContentView()
}
