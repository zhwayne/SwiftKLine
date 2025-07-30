//
//  File.swift
//  KLine
//
//  Created by iya on 2025/3/28.
//

import UIKit

extension CALayer {
    
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
