//
//  EdgeInsetLabel.swift
//  KLine
//
//  Created by iya on 2025/3/29.
//

import UIKit

class EdgeInsetLabel: UILabel {
    var edgeInsets = UIEdgeInsets.zero
    
    override func textRect(
        forBounds bounds: CGRect,
        limitedToNumberOfLines numberOfLines: Int
    ) -> CGRect {
        guard text != nil else {
            return super.textRect(
                forBounds: bounds,
                limitedToNumberOfLines: numberOfLines
            )
        }
        
        let insetRect = bounds.inset(by: edgeInsets)
        let textRect = super.textRect(
            forBounds: insetRect,
            limitedToNumberOfLines: numberOfLines
        )
        let invertedInsets = UIEdgeInsets(
            top: -edgeInsets.top,
            left: -edgeInsets.left,
            bottom: -edgeInsets.bottom,
            right: -edgeInsets.right
        )
        return textRect.inset(by: invertedInsets)
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: edgeInsets))
    }
}
