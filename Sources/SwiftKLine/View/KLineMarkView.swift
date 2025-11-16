//
//  KLineMarkView.swift
//  SwiftKLine
//
//  Created by iya on 2025/3/29.
//

import UIKit

class KLineMarkView: UIView {
    
    private class ItemLabel: UIView {
        
        let titleLabel = UILabel()
        let detailLabel = UILabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            titleLabel.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
            titleLabel.font = .systemFont(ofSize: 10)
            titleLabel.textColor = UIColor.label.withAlphaComponent(0.8)
            detailLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            detailLabel.textColor = UIColor.label.withAlphaComponent(0.8)
            detailLabel.textAlignment = .right
            
            let stackView = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
            stackView.spacing = 8
            stackView.distribution = .fill
            addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    var item: (any KLineItem)? {
        didSet { update() }
    }
    
    private let stackView = UIStackView()
    private let dateLabel = ItemLabel()
    private let openingLabel = ItemLabel()
    private let highestLabel = ItemLabel()
    private let lowestLabel = ItemLabel()
    private let closingLabel = ItemLabel()
    private let volumeLabel = ItemLabel()
    private let valueLabel = ItemLabel()
    private let changeAmountLabel = ItemLabel()
    private let changeRateLabel = ItemLabel()
    private let amplitudeLabel = ItemLabel()
    private let dateFormatter = DateFormatter()
    private let volumeFormatter = VolumeFormatter()
    private let priceFormatter = PriceFormatter()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // TODO: 根据周期改变format
        dateFormatter.dateFormat = "MM/dd HH:mm"
        
        layer.cornerRadius = 6
        layer.masksToBounds = true
        
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        visualEffectView.isUserInteractionEnabled = false
        addSubview(visualEffectView)
        visualEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .fill
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        }
        
        stackView.addArrangedSubview(dateLabel)
        stackView.addArrangedSubview(openingLabel)
        stackView.addArrangedSubview(highestLabel)
        stackView.addArrangedSubview(lowestLabel)
        stackView.addArrangedSubview(closingLabel)
        stackView.addArrangedSubview(changeAmountLabel)
        stackView.addArrangedSubview(changeRateLabel)
        stackView.addArrangedSubview(amplitudeLabel)
        stackView.addArrangedSubview(volumeLabel)
        stackView.addArrangedSubview(valueLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update() {
        guard let item else { return }
        let klineConfig = KLineConfiguration.default
        // 时间
        dateLabel.titleLabel.text = "时间"
        let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
        dateLabel.detailLabel.text = dateFormatter.string(from: date)
        // 开盘
        openingLabel.titleLabel.text = "开盘"
        openingLabel.detailLabel.text = priceFormatter.format(item.opening as NSNumber)
        // 最高价
        highestLabel.titleLabel.text = "最高"
        highestLabel.detailLabel.text = priceFormatter.format(item.highest as NSNumber)
        // 最低价
        lowestLabel.titleLabel.text = "最低"
        lowestLabel.detailLabel.text = priceFormatter.format(item.lowest as NSNumber)
        // 收盘
        closingLabel.titleLabel.text = "收盘"
        closingLabel.detailLabel.text = priceFormatter.format(item.closing as NSNumber)
        // 涨跌额
        let changeAmount = item.closing - item.opening
        changeAmountLabel.titleLabel.text = "涨跌额"
        changeAmountLabel.detailLabel.text = priceFormatter.format(changeAmount as NSNumber)
        // 涨跌幅
        let changeRate = (changeAmount / item.opening) * 100
        changeRateLabel.titleLabel.text = "涨跌幅"
        let changeRateString = priceFormatter.format(changeRate as NSNumber)
        var prefix = changeRateString.hasPrefix("-") ? "" : "+"
        changeRateLabel.detailLabel.text =  prefix + changeRateString + "%"
        changeRateLabel.detailLabel.textColor = item.trend == .rising
        ? klineConfig.candleStyle.risingColor
        : klineConfig.candleStyle.fallingColor
        // 振幅
        let amplitude = ((item.highest - item.lowest) / item.lowest) * 100
        amplitudeLabel.titleLabel.text = "振幅"
        let amplitudeString = priceFormatter.format(amplitude as NSNumber)
        prefix = amplitudeString.hasPrefix("-") ? "" : "+"
        amplitudeLabel.detailLabel.text =  prefix + amplitudeString + "%"
        amplitudeLabel.detailLabel.textColor = item.trend == .rising
        ? klineConfig.candleStyle.risingColor
        : klineConfig.candleStyle.fallingColor
        // 成交量
        volumeLabel.titleLabel.text = "成交量"
        volumeLabel.detailLabel.text = volumeFormatter.format(item.volume as NSNumber)
        // 成交额
        valueLabel.titleLabel.text = "成交额"
        valueLabel.detailLabel.text = volumeFormatter.format(item.volume as NSNumber)
    }
}
