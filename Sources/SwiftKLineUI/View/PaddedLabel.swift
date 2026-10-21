//
//  PaddedLabel.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/29.
//

import SwiftKLineCore
import UIKit

/// A label that adds configured edge insets to text drawing and intrinsic measurement.
class PaddedLabel: UILabel {
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
