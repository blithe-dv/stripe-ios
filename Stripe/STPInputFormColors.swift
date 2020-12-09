//
//  STPInputFormColors.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/23/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPInputFormColors: NSObject {
    
    static var textColor: UIColor {
        return CompatibleColor.label
    }
    
    static var errorColor: UIColor {
        return .systemRed
    }
    
    static var outlineColor: UIColor {
        return UIColor(red: 120.0/255.0, green: 120.0/255.0, blue: 128.0/255.0, alpha: 0.2)
    }
    
}
