//
//  STPStackViewWithSeparator.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/22/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPStackViewWithSeparator: UIStackView {
    var separatorColor: UIColor = .clear {
        didSet {
            separatorLayer.strokeColor = separatorColor.cgColor
            layer.borderColor = separatorColor.cgColor
        }
    }
    
    private let separatorLayer = CAShapeLayer()
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if separatorLayer.superlayer == nil {
            layer.addSublayer(separatorLayer)
        }
        separatorLayer.strokeColor = separatorColor.cgColor
        
        let path = UIBezierPath()
        path.lineWidth = spacing
        
        if spacing > 0 {
            // inter-view separators
            let nonHiddenArrangedSubviews = arrangedSubviews.filter({ !$0.isHidden })

            for view in nonHiddenArrangedSubviews {
                
                if axis == .vertical {
                    if view == nonHiddenArrangedSubviews.last {
                        continue
                    }
                    path.move(to: CGPoint(x: view.frame.origin.x, y: view.frame.maxY + 0.5*spacing))
                    path.addLine(to: CGPoint(x: view.frame.maxX, y: view.frame.maxY +  0.5*spacing))
                } else { // .horizontal
                    if view == nonHiddenArrangedSubviews.first {
                        continue
                    }
                    path.move(to: CGPoint(x: view.frame.origin.x - 0.5*spacing, y: view.frame.origin.y))
                    path.addLine(to: CGPoint(x: view.frame.origin.x - 0.5*spacing, y: view.frame.maxY))
                }
                
            }
        }
        
        separatorLayer.path = path.cgPath
    }
}
