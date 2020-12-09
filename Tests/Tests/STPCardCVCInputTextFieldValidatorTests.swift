//
//  STPCardCVCInputTextFieldValidatorTests.swift
//  StripeiOS Tests
//
//  Created by Cameron Sabol on 10/28/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import XCTest
@testable import Stripe

class STPCardCVCInputTextFieldValidatorTests: XCTestCase {

    func testValidation() {
        let validator = STPCardCVCInputTextFieldValidator()
        validator.cardBrand = .visa
        
        validator.inputValue = "123"
        if case .valid = validator.validationState {
            XCTAssertTrue(true)
        } else {
            XCTAssertTrue(false, "123 should be valid for Visa")
        }
        
        validator.inputValue = "1"
        if case .incomplete = validator.validationState {
            XCTAssertTrue(true)
        } else {
            XCTAssertTrue(false, "1 should be incomplete for Visa")
        }
        
        validator.inputValue = "1234"
        if case .invalid = validator.validationState {
            XCTAssertTrue(true)
        } else {
            XCTAssertTrue(false, "1234 should be invalid for Visa")
        }
        
        validator.cardBrand = .amex
        // don't update inputValue so we know validationState is recalculated on cardBrand change
        if case .valid = validator.validationState {
            XCTAssertTrue(true)
        } else {
            XCTAssertTrue(false, "1234 should be valid for Amex")
        }
    }

}
