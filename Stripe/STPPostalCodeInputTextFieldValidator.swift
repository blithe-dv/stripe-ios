//
//  STPPostalCodeInputTextFieldValidator.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/30/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPPostalCodeInputTextFieldValidator: STPInputTextFieldValidator {
    
    var countryCode: String? = Locale.autoupdatingCurrent.regionCode

    override public var inputValue: String? {
        didSet {
            guard let inputValue = inputValue,
                  !inputValue.isEmpty else {
                validationState = .incomplete
                return
            }
            
            switch STPPostalCodeValidator.validationState(forPostalCode: inputValue, countryCode: countryCode) {
            case .valid:
                validationState = .valid(message: nil)
            case .invalid:
                validationState = .invalid(errorMessage: nil)
            case .incomplete:
                validationState = .incomplete
            }
        }
    }
}
