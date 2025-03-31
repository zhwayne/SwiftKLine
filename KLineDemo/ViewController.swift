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

        // 解析 plist
        let filePath = Bundle.main.path(forResource: "kline", ofType: "plist")!
        let data = NSDictionary(contentsOfFile: filePath)!
        let json = JSON(data)
        let datas = json["data"].arrayValue
        
        let items = datas.map { json -> KLineItem in
            KLineItem(
                opening: json.arrayValue[0].doubleValue,
                closing: json.arrayValue[1].doubleValue,
                highest: json.arrayValue[2].doubleValue,
                lowest: json.arrayValue[3].doubleValue,
                volume: json.arrayValue[4].intValue,
                value: Double.random(in: 10000...10000000),
                timestamp: json.arrayValue[5].intValue
            )
        }
        
        chartView.draw(items: items.reversed(), scrollPosition: .right)
    }
}

import SwiftUI

@available(iOS 17.0, *)
#Preview {
    ViewController()
}
