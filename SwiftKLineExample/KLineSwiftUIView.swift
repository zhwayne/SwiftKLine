//
//  KLineSwiftUIView.swift
//  SwiftKLineExample
//
//  Created by iya on 2025/4/13.
//

import SwiftUI
import SwiftKLine

struct KLineSwiftUIView: View {
    
    let period: KLinePeriod
    
    var body: some View {
        KLineRepresentable(period: period)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KLineRepresentable: UIViewRepresentable {
    
    let period: KLinePeriod
    
    typealias UIViewType = KLineView
    
    func makeUIView(context: Context) -> KLineView {
        let view = KLineView()
        return view
    }
    
    func updateUIView(_ uiView: KLineView, context: Context) {
        let provider = BinanceDataProvider(period: period)
        uiView.setProvider(provider)
        uiView.invalidateIntrinsicContentSize()
    }
}

#Preview {
    KLineSwiftUIView(period: .fiveMinutes)
}
