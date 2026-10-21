//
//  PriceMarkView.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/29.
//

import SwiftKLineCore
import UIKit

/// An interactive latest-price marker whose notification is scoped to the chart that owns this control.
final class PriceMarkView: UIControl {
    
    let label = UILabel()
    
    private let arrowView = UIImageView(image: UIImage(systemName: "chevron.right"))
    var showArrow: Bool {
        get { !arrowView.isHidden }
        set { arrowView.isHidden = !newValue }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textColor = UIColor.label.withAlphaComponent(0.8)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        label.textAlignment = .center
        label.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        
        arrowView.tintColor = UIColor.label.withAlphaComponent(0.8)
        
        layer.cornerRadius = 4
        layer.masksToBounds = true
        
        let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        visualEffectView.isUserInteractionEnabled = false
        addSubview(visualEffectView)
        visualEffectView.pinEdges(to: self)
        
        let stackView = UIStackView(arrangedSubviews: [label, arrowView])
        stackView.isUserInteractionEnabled = false
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 2
        addSubview(stackView)
        stackView.pinEdges(to: self, insets: UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4))
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arrowView.widthAnchor.constraint(equalToConstant: 5),
            arrowView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        addTarget(self, action: #selector(Self.onClick), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func onClick() {
        NotificationCenter.default.post(name: .scrollToTop, object: self)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = UIColor.label.withAlphaComponent(0.8).cgColor
    }
}
