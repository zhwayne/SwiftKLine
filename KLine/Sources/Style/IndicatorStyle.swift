//
//  IndicatorStyle.swift
//  KLine
//
//  Created by W on 2025/4/14.
//

import UIKit

public protocol IndicatorStyle {
    
}

public struct TrackStyle: IndicatorStyle {
    
    public let strokeColor: UIColor
    
    public init(strokeColor: UIColor) {
        self.strokeColor = strokeColor
    }
}

public struct MACDStyle: IndicatorStyle {
    
    public let macdColor: UIColor
    public let difColor: UIColor
    public let deaColor: UIColor
    
    public init(macdColor: UIColor, difColor: UIColor, deaColor: UIColor) {
        self.macdColor = macdColor
        self.difColor = difColor
        self.deaColor = deaColor
    }
}
