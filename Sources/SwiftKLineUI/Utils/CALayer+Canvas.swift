//
//  CALayer+Canvas.swift
//  SwiftKLineUI
//
//  Created by zhwayne on 2025/03/28.
//

import SwiftKLineCore
import UIKit

extension CALayer {
    
    /// Finds the UIView that owns a canvas by walking the layer’s delegate and superlayer chain.
    var owningView: UIView? {
        if let view = delegate as? UIView {
            return view
        }
        for layer in sequence(first: superlayer, next: { $0?.superlayer }) {
            if let view = layer?.delegate as? UIView {
                return view
            }
        }
        return nil
    }
}
