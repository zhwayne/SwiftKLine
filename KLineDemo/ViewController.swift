//
//  ViewController.swift
//  KLineDemo
//
//  Created by iya on 2024/10/31.
//

import UIKit
import SwiftyJSON
import SnapKit
import KLine

class ViewController: UIViewController {
    
    private let chartView = KLineView()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.addSubview(chartView)

        chartView.snp.makeConstraints { make in
            make.left.right.equalTo(view.safeAreaLayoutGuide)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(64)
        }
        
        let provider = BinanceDataProvider(period: .fiveMinutes)
        chartView.setProvider(provider)
    }
}

import SwiftUI

@available(iOS 17.0, *)
#Preview {
    ViewController()
}
