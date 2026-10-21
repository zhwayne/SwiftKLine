//
//  MarkView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/29.
//

import SwiftKLineCore
import UIKit

/// Displays the selected candle’s prices, volume, traded amount, and safely computed change percentages.
class MarkView: UIView {
    
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
            stackView.pinEdges(to: self)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    var item: (any ChartItem)? {
        didSet { update() }
    }
    
    private let configuration: ChartConfiguration
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
    
    init(configuration: ChartConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        // TODO: Adapt date formatting to the selected candle period.
        dateFormatter.dateFormat = "MM/dd HH:mm"
        
        layer.cornerRadius = 6
        layer.masksToBounds = true
        
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        visualEffectView.isUserInteractionEnabled = false
        addSubview(visualEffectView)
        visualEffectView.pinEdges(to: self)
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .fill
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.pinEdges(to: self, insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        
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
    
    override convenience init(frame: CGRect) {
        self.init(configuration: ChartConfiguration())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update() {
        guard let item else { return }
        let configuration = configuration
        // Time
        dateLabel.titleLabel.text = "时间"
        let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
        dateLabel.detailLabel.text = dateFormatter.string(from: date)
        // Open
        openingLabel.titleLabel.text = "开盘"
        openingLabel.detailLabel.text = priceFormatter.format(item.open as NSNumber)
        // Highest price
        highestLabel.titleLabel.text = "最高"
        highestLabel.detailLabel.text = priceFormatter.format(item.high as NSNumber)
        // Lowest price
        lowestLabel.titleLabel.text = "最低"
        lowestLabel.detailLabel.text = priceFormatter.format(item.low as NSNumber)
        // Close
        closingLabel.titleLabel.text = "收盘"
        closingLabel.detailLabel.text = priceFormatter.format(item.close as NSNumber)
        // Price change
        let changeAmount = item.close - item.open
        changeAmountLabel.titleLabel.text = "涨跌额"
        changeAmountLabel.detailLabel.text = priceFormatter.format(changeAmount as NSNumber)
        // Percentage change
        changeRateLabel.titleLabel.text = "涨跌幅"
        if item.open != 0 {
            let changeRate = (changeAmount / item.open) * 100
            let changeRateString = priceFormatter.format(changeRate as NSNumber)
            let prefix = changeRateString.hasPrefix("-") ? "" : "+"
            changeRateLabel.detailLabel.text = prefix + changeRateString + "%"
            changeRateLabel.detailLabel.textColor = item.trend == .rising
            ? configuration.candleStyle.risingColor
            : configuration.candleStyle.fallingColor
        } else {
            changeRateLabel.detailLabel.text = "--"
            changeRateLabel.detailLabel.textColor = .secondaryLabel
        }
        // Price amplitude
        amplitudeLabel.titleLabel.text = "振幅"
        if item.low != 0 {
            let amplitude = ((item.high - item.low) / item.low) * 100
            let amplitudeString = priceFormatter.format(amplitude as NSNumber)
            let prefix = amplitudeString.hasPrefix("-") ? "" : "+"
            amplitudeLabel.detailLabel.text = prefix + amplitudeString + "%"
            amplitudeLabel.detailLabel.textColor = item.trend == .rising
            ? configuration.candleStyle.risingColor
            : configuration.candleStyle.fallingColor
        } else {
            amplitudeLabel.detailLabel.text = "--"
            amplitudeLabel.detailLabel.textColor = .secondaryLabel
        }
        // Traded quantity
        volumeLabel.titleLabel.text = "成交量"
        volumeLabel.detailLabel.text = volumeFormatter.format(item.volume as NSNumber)
        // Traded amount
        valueLabel.titleLabel.text = "成交额"
        valueLabel.detailLabel.text = volumeFormatter.format(item.value as NSNumber)
    }
}
