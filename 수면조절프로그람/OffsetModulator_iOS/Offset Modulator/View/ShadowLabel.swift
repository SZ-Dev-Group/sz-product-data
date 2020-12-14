//
//  ShadowLabel.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/14.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import MarqueeLabel

class ShadowLabel: MarqueeLabel {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    override init(frame: CGRect, rate: CGFloat, fadeLength fade: CGFloat) {
        super.init(frame: frame, rate: rate, fadeLength: fade)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func activateShadow() {
        self.layer.masksToBounds = false
        self.layer.shadowOffset = CGSize(width: 3, height: 3)
        self.layer.rasterizationScale = UIScreen.main.scale
        self.layer.shadowRadius = 3.0
        self.layer.shadowOpacity = 1.0
        self.trailingBuffer = 30
        self.animationDelay = 2
        
        let strokeTextAttributes = [
            NSAttributedString.Key.strokeColor : UIColor.gray,
            NSAttributedString.Key.strokeWidth : -0.5,
            ] as [NSAttributedString.Key : Any]

        self.attributedText = NSAttributedString(string: self.text ?? "", attributes: strokeTextAttributes)
    }
}
