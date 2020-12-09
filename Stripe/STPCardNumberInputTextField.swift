//
//  STPCardNumberInputTextField.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/22/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPCardNumberInputTextField: STPInputTextField {
    
    public var cardBrand: STPCardBrand {
        return (validator as! STPCardNumberInputTextFieldValidator).cardBrand
    }
    
    public convenience init() {
        self.init(formatter: STPCardNumberInputTextFieldFormatter(), validator: STPCardNumberInputTextFieldValidator())
    }
    
    lazy var brandImageView: UIImageView = {
        return UIImageView()
    }()
    
    lazy var loadingIndicator: STPCardLoadingIndicator = {
        let loadingIndicator = STPCardLoadingIndicator()
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        return loadingIndicator
    }()
    
    required init(formatter: STPInputTextFieldFormatter, validator: STPInputTextFieldValidator) {
        assert(formatter.isKind(of: STPCardNumberInputTextFieldFormatter.self))
        assert(validator.isKind(of: STPCardNumberInputTextFieldValidator.self))
        super.init(formatter: formatter, validator: validator)
        keyboardType = .asciiCapableNumberPad
        textContentType = .creditCardNumber
        rightViewMode = .always
        rightView = brandImageView
        updateRightView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func setupSubviews() {
        super.setupSubviews()
        placeholder = STPLocalizedString("Card Number", "Label for card number entry text field")
    }
    
    func updateRightView() {
        
        // These sould be animated https://jira.corp.stripe.com/browse/MOBILESDK-109
        switch validator.validationState {
        
        case .unknown:
            loadingIndicator.removeFromSuperview()
            brandImageView.image = STPImageLibrary.cardBrandImage(for: .unknown)
        case .valid, .incomplete:
            loadingIndicator.removeFromSuperview()
            brandImageView.image = STPImageLibrary.cardBrandImage(for: cardBrand)
        case .invalid:
            loadingIndicator.removeFromSuperview()
            brandImageView.image = STPImageLibrary.errorImage(for: cardBrand)
        case .processing:
            if loadingIndicator.superview == nil {
                brandImageView.image = STPImageLibrary.unknownCardCardImage()
                rightView = brandImageView
                // delay a bit before showing loading indicator because the response may come quickly
                DispatchQueue.main.asyncAfter(
                    deadline: DispatchTime.now() + Double(
                        Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
                    execute: {
                        if case .processing = self.validator.validationState,
                           self.loadingIndicator.superview == nil
                        {
                            self.brandImageView.addSubview(self.loadingIndicator)
                            NSLayoutConstraint.activate(
                                [
                                    self.loadingIndicator.rightAnchor.constraint(
                                        equalTo: self.brandImageView.rightAnchor),
                                    self.loadingIndicator.topAnchor.constraint(
                                        equalTo: self.brandImageView.topAnchor),
                                ]
                            )
                        }
                    })
            }
        }
    }
    
    override func validationDidUpdate(to state: STPValidatedInputState,from previousState: STPValidatedInputState, for unformattedInput: String?, in input: STPFormInput) {
        super.validationDidUpdate(to: state, from: previousState, for: unformattedInput, in: input)
        updateRightView()
    }
}
