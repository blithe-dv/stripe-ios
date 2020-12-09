//
//  STPInputTextField.swift
//  StripeiOS
//
//  Created by Cameron Sabol on 10/12/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import UIKit

class STPInputTextField:  STPFloatingPlaceholderTextField, STPFormInputValidationObserver {
    let formatter: STPInputTextFieldFormatter
    
    let validator: STPInputTextFieldValidator
    
    weak var formContainer: STPFormContainer? = nil
    
    var wantsAutoFocus: Bool {
        return true
    }
    
    required init(formatter: STPInputTextFieldFormatter, validator: STPInputTextFieldValidator) {
        self.formatter = formatter
        self.validator = validator
        super.init(frame: .zero)
        delegate = formatter
        validator.textField = self
        validator.addObserver(self)
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    override var text : String? {
      didSet {
        textDidChange()
      }
    }
  
    @objc
    func textDidChange() {
        let text = self.text ?? ""
        let formatted = formatter.formattedText(from: text, with: defaultTextAttributes)
        if formatted != attributedText {
            var updatedCursorPosition: UITextPosition? = nil
            if let selection = selectedTextRange {
                let cursorPosition = offset(from: beginningOfDocument, to: selection.start)
                updatedCursorPosition =  position(from: beginningOfDocument, offset: cursorPosition - (text.count - formatted.length))

            }
            attributedText = formatted
            sendActions(for: .valueChanged)
            if let updatedCursorPosition = updatedCursorPosition {
                selectedTextRange = textRange(from: updatedCursorPosition, to: updatedCursorPosition)
            }
        }
        validator.inputValue = formatted.string
    }
    
    @objc
    override public func becomeFirstResponder() -> Bool {
        let ret = super.becomeFirstResponder()
        if ret {
          self.formContainer?.inputTextFieldDidBecomeFirstResponder(self)
        }
        updateTextColor()
        return ret
    }
    
    @objc
    override public func resignFirstResponder() -> Bool {
        let ret = super.resignFirstResponder()
        updateTextColor()
        return ret
    }
    
    func updateTextColor() {
        switch validator.validationState {

        case .unknown:
            textColor = STPInputFormColors.textColor
        case .incomplete:
            if isEditing {
                textColor = STPInputFormColors.textColor
            } else {
                textColor = STPInputFormColors.errorColor
            }
        case .invalid:
            textColor = STPInputFormColors.errorColor
        case .valid:
            textColor = STPInputFormColors.textColor
        case .processing:
            textColor = STPInputFormColors.textColor
        }
    }
    
    @objc
    public override func deleteBackward() {
        let deletingOnEmpty = (text?.count ?? 0) == 0
        super.deleteBackward()
        if deletingOnEmpty {
            formContainer?.inputTextFieldDidBackspaceOnEmpty(self)
        }
    }
    
    // Fixes a weird issue related to our custom override of deleteBackwards. This only affects the simulator and iPads with custom keyboards.
    // copied from STPFormTextField
    @objc
    public override var keyCommands: [UIKeyCommand]? {
      return [
        UIKeyCommand(
          input: "\u{08}", modifierFlags: .command, action: #selector(commandDeleteBackwards))
      ]
    }

    @objc
    func commandDeleteBackwards() {
      text = ""
    }
    
    // MARK: - STPInputTextFieldValidationObserver
    func validationDidUpdate(to state: STPValidatedInputState,from previousState: STPValidatedInputState, for unformattedInput: String?, in input: STPFormInput) {
        
        guard input == self,
              unformattedInput == text else {
            return
        }
        updateTextColor()
    }
}

/// :nodoc:
extension STPInputTextField: STPFormInput {
    
    var validationState: STPValidatedInputState {
        return validator.validationState
    }
    
    var inputValue: String? {
        return validator.inputValue
    }
    
    func addObserver(_ validationObserver: STPFormInputValidationObserver) {
        validator.addObserver(validationObserver)
    }
    
    func removeObserver(_ validationObserver: STPFormInputValidationObserver) {
        validator.removeObserver(validationObserver)
    }
    
    
}
