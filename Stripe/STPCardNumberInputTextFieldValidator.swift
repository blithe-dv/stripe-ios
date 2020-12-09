//
//  STPCardNumberInputTextFieldValidator.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/22/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPCardNumberInputTextFieldValidator: STPInputTextFieldValidator {
    
    var cardBrand: STPCardBrand {
        guard let inputValue = inputValue,
              STPBINRange.hasBINRanges(forPrefix: inputValue) else {
            return .unknown
        }
        
        return STPCardValidator.brand(forNumber: inputValue)
    }
    
    override public var inputValue: String? {
        didSet {
            guard let inputValue = inputValue else {
                validationState = .incomplete
                return
            }
            if STPBINRange.hasBINRanges(forPrefix: inputValue) {
                switch STPCardValidator.validationState(forNumber: inputValue, validatingCardBrand: true) {
                
                case .valid:
                    validationState = .valid(message: nil)
                case .invalid:
                    validationState = .invalid(errorMessage: STPLocalizedString("Invalid card number", "Error message for card form when card number is invalid"))
                case .incomplete:
                    validationState = .incomplete
                }
            } else {
                STPBINRange.retrieveBINRanges(forPrefix: inputValue) { (binRanges, error) in
                    
                    // Needs better error handling and analytics https://jira.corp.stripe.com/browse/MOBILESDK-110
                    switch STPCardValidator.validationState(forNumber: inputValue, validatingCardBrand: true) {
                    
                    case .valid:
                        self.validationState = .valid(message: nil)
                    case .invalid:
                        self.validationState = .invalid(errorMessage: STPLocalizedString("Invalid card number", "Error message for card form when card number is invalid"))
                    case .incomplete:
                        self.validationState = .incomplete
                    }
                }
                if STPBINRange.isLoadingCardMetadata(forPrefix: inputValue) {
                    validationState = .processing
                }
            }
        }
    }
}
