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
        
        // 获取数据
        let url = URL(string: "https://data-api.binance.vision/api/v3/klines?interval=1h&symbol=BTCUSDT")!
        /*
         [
         [
         1499040000000,      // 开盘时间
         "0.01634790",       // 开盘价
         "0.80000000",       // 最高价
         "0.01575800",       // 最低价
         "0.01577100",       // 收盘价(当前K线未结束的即为最新价)
         "148976.11427815",  // 成交量
         1499644799999,      // 收盘时间
         "2434.19055334",    // 成交额
         308,                // 成交笔数
         "1756.87402397",    // 主动买入成交量
         "28.46694368",      // 主动买入成交额
         "17928899.62484339" // 请忽略该参数
         ]
         ]
         */
        Task {
            do {
                let session = URLSession(configuration: URLSessionConfiguration.default)
                let (data, _) = try await session.data(from: url)
                let json = try JSON(data: data)
                let items = json.arrayValue.map { json in
                    let array = json.arrayValue
                    return KLineItem(
                        opening: array[1].doubleValue,
                        closing: array[4].doubleValue,
                        highest: array[2].doubleValue,
                        lowest: array[3].doubleValue,
                        volume: array[5].doubleValue,
                        value: array[7].doubleValue,
                        timestamp: array[0].intValue / 1000
                    )
                }
                chartView.draw(items: items, scrollPosition: .right)
            } catch {
                print(error)
            }
        }
    }
}

import SwiftUI

@available(iOS 17.0, *)
#Preview {
    ViewController()
}
