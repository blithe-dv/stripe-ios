//
//  PaymentSheet.swift
//  Stripe
//
//  Created by Yuki Tokuhiro on 9/3/20.
//  Copyright © 2020 Stripe, Inc. All rights reserved.
//

import Foundation
import UIKit
import PassKit

/// The result of an attempt to confirm a PaymentIntent
/// You may use this to notify the customer of the status of their payment attempt in your app
@frozen public enum PaymentResult {
    /// The payment attempt successfully completed.
    ///
    /// Some types of payment methods take time to transfer money. You should inspect the PaymentIntent status:
    ///  - If it's `.succeeded`, money successfully moved; you may e.g. show a receipt view to the customer.
    ///  - If it's `.processing`, the PaymentMethod is asynchronous and money has not yet moved. You may e.g. inform the customer their order is pending.
    ///
    /// To notify your backend of the payment and e.g. fulfill the order, see https://stripe.com/docs/payments/handling-payment-events
    /// - Parameter paymentIntent: The underlying PaymentIntent.
    case completed(paymentIntent: STPPaymentIntent)

    /// The customer canceled the payment.
    /// - Parameter lastError: The last error encountered by the customer, if any.
    /// - Parameter paymentIntent: The underlying PaymentIntent, if one exists.
    case canceled(lastError: Error?, paymentIntent: STPPaymentIntent?)

    /// The payment attempt failed.
    /// - Parameter error: The error encountered by the customer. You can display its `localizedDescription` to the customer.
    /// - Parameter paymentIntent: The underlying PaymentIntent, if one exists.
    case failed(error: Error, paymentIntent: STPPaymentIntent?)
}

/// A drop-in class that presents a sheet for a customer to complete their payment
public class PaymentSheet {
    /// The client secret of the Stripe PaymentIntent object
    /// See https://stripe.com/docs/api/payment_intents/object#payment_intent_object-client_secret
    /// Note: This can be used to complete a payment - don't log it, store it, or expose it to anyone other than the customer.
    public let paymentIntentClientSecret: String

    // MARK: - Configuration

    /// Billing address collection modes for PaymentSheet
    public enum BillingAddressCollectionLevel {
        /// (Default) PaymentSheet will only collect the necessary billing address information
        case automatic

        /// PaymentSheet will always collect full billing address details
        case required
    }
    
    /// Style options for colors in PaymentSheet
    @available(iOS 13.0, *)
    public enum SheetStyle: Int {
        
        /// (default) PaymentSheet will automatically switch between standard and dark mode compatible colors based on device settings
        case automatic = 0
        
        /// PaymentSheet will always use colors appropriate for standard, i.e. non-dark mode UI
        case alwaysLight
        
        /// PaymentSheet will always use colors appropriate for dark mode UI
        case alwaysDark
        
        func configure(_ viewController: UIViewController) {
            switch self {
            case .automatic:
                break // no-op
            
            case .alwaysLight:
                viewController.overrideUserInterfaceStyle = .light
                
            case .alwaysDark:
                viewController.overrideUserInterfaceStyle = .dark
            }
        }
    }
    
    /// Configuration for PaymentSheet
    public struct Configuration {
        /// The APIClient instance used to make requests to Stripe
        public var apiClient: STPAPIClient = STPAPIClient.shared

        /// Configuration related to the Stripe Customer making a payment.
        /// If set, PaymentSheet displays Apple Pay as a payment option
        public var applePay: ApplePayConfiguration? = nil

        /// The amount of billing address details to collect
        /// @see BillingAddressCollection
        public var billingAddressCollection: BillingAddressCollectionLevel = .automatic
        
        private var styleRawValue: Int = 0 // SheetStyle.automatic.rawValue
        /// The color styling to use for PaymentSheet UI
        /// Default value is SheetStyle.automatic
        /// @see SheetStyle
        @available(iOS 13.0, *)
        public var style: SheetStyle { // stored properties can't be marked @available which is why this uses the styleRawValue private var
            get {
                return SheetStyle(rawValue: styleRawValue)!
            }
            set {
                styleRawValue = newValue.rawValue
            }
        }

        /// Configuration related to Apple Pay
        /// If set, the customer can select a previously saved payment method within PaymentSheet
        public var customer: CustomerConfiguration? = nil

        /// Your customer-facing business name.
        /// This is used to display a "Pay \(merchantDisplayName)" line item in the Apple Pay sheet
        /// The default value is the name of your app, using CFBundleDisplayName or CFBundleName
        public var merchantDisplayName: String = Bundle.displayName ?? ""

        /// Initializes a Configuration with default values
        public init() {}
    }

    /// Configuration related to the Stripe Customer making a payment.
    public struct CustomerConfiguration {
        /// The identifier of the Stripe Customer object.
        /// See https://stripe.com/docs/api/customers/object#customer_object-id
        public let id: String

        /// A short-lived token that allows the SDK to access a Customer's payment methods
        public let ephemeralKeySecret: String

        /// Initializes a CustomerConfiguration
        public init(id: String, ephemeralKeySecret: String) {
            self.id = id
            self.ephemeralKeySecret = ephemeralKeySecret
        }
    }

    /// Configuration related to Apple Pay
    public struct ApplePayConfiguration {
        /// The Apple Merchant Identifier to use during Apple Pay transactions.
        /// To obtain one, see https://stripe.com/docs/apple-pay#native
        public let merchantId: String

        /// The two-letter ISO 3166 code of the country of your business, e.g. "US"
        /// See your account's country value here https://dashboard.stripe.com/settings/account
        public let merchantCountryCode: String

        /// Initializes a ApplePayConfiguration
        public init(merchantId: String, merchantCountryCode: String) {
            self.merchantId = merchantId
            self.merchantCountryCode = merchantCountryCode
        }
    }

    /// This contains all configurable properties of PaymentSheet
    public let configuration: Configuration

    /// Initializes a PaymentSheet
    /// - Parameter paymentIntentClientSecret: The client secret of the Stripe PaymentIntent object
    ///     See https://stripe.com/docs/api/payment_intents/object#payment_intent_object-client_secret
    ///     Note: This can be used to complete a payment - don't log it, store it, or expose it to anyone other than the customer.
    /// - Parameter configuration: Configuration for the PaymentSheet. e.g. your business name, Customer details, etc.
    public init(paymentIntentClientSecret: String, configuration: Configuration) {
        self.paymentIntentClientSecret = paymentIntentClientSecret
        self.configuration = configuration
    }

    /// Presents a sheet for a customer to complete their payment
    /// - Parameter presentingViewController: The view controller to present a payment sheet
    /// - Parameter completion: Called with the result of the payment after the payment sheet is dismissed
    @available(iOSApplicationExtension, unavailable)
    public func present(from presentingViewController: UIViewController, completion: @escaping (PaymentResult) -> ()) {
        // Overwrite completion closure to retain self until called
        let completion: (PaymentResult) -> () = { status in
            completion(status)
            self.completion = nil
        }
        self.completion = completion

        // Guard against basic user error
        guard presentingViewController.presentedViewController == nil else {
            assertionFailure("presentingViewController is already presenting a view controller")
            let error = PaymentSheetError.unknown(debugDescription: "presentingViewController is already presenting a view controller")
            completion(.failed(error: error, paymentIntent: nil))
            return
        }

        // Configure the Payment Sheet VC after loading the PI, Customer, etc.
        PaymentSheet.load(apiClient: configuration.apiClient,
                          clientSecret: paymentIntentClientSecret,
                          ephemeralKey: configuration.customer?.ephemeralKeySecret,
                          customerID: configuration.customer?.id) { result in
            switch result {
            case .success((let paymentIntent, let paymentMethods)):
                // Set the PaymentSheetViewController as the content of our bottom sheet
                let isApplePayEnabled = StripeAPI.deviceSupportsApplePay() && self.configuration.applePay != nil
                let paymentSheetVC = PaymentSheetViewController(paymentIntent: paymentIntent,
                                                                savedPaymentMethods: paymentMethods,
                                                                configuration: self.configuration,
                                                                isApplePayEnabled: isApplePayEnabled,
                                                                delegate: self)
                if #available(iOS 13.0, *) {
                    self.configuration.style.configure(paymentSheetVC)
                }
                self.bottomSheetViewController.contentViewController = paymentSheetVC
            case .failure(let error):
                // Dismiss if necessary
                if self.bottomSheetViewController.presentingViewController != nil {
                    self.bottomSheetViewController.dismiss(animated: true) {
                        self.completion?(.failed(error: error, paymentIntent: nil))
                    }
                } else {
                    self.completion?(.failed(error: error, paymentIntent: nil))
                }
            }
        }

        presentingViewController.presentPanModal(bottomSheetViewController)
    }

    // MARK: - Internal Properties

    var completion: ((PaymentResult) -> ())?

    lazy var bottomSheetViewController: BottomSheetViewController = {
        let vc = BottomSheetViewController(contentViewController: LoadingViewController(delegate: self))
        if #available(iOS 13.0, *) {
            configuration.style.configure(vc)
        }
        return vc
    }()

    // MARK: Internal Methods

    static func load(apiClient: STPAPIClient,
                     clientSecret: String,
                     ephemeralKey: String? = nil,
                     customerID: String? = nil,
                     completion: @escaping ((Result<(STPPaymentIntent, [STPPaymentMethod]), Error>) -> ())) {
        let paymentIntentPromise = Promise<STPPaymentIntent>()
        let paymentMethodsPromise = Promise<[STPPaymentMethod]>()
        paymentIntentPromise.observe { result in
            switch result {
            case .success(let paymentIntent):
                paymentMethodsPromise.observe { result in
                    switch result {
                    case .success(let paymentMethods):
                        let savedPaymentMethods = paymentMethods.filter {
                            // Filter out payment methods that the PaymentIntent or PaymentSheet doesn't support
                            paymentIntent.paymentMethodTypesSet.contains($0.type) || Set([STPPaymentMethodType.card]).contains($0.type)
                        }

                        completion(.success((paymentIntent, savedPaymentMethods)))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }

        // Get the PaymentIntent
        apiClient.retrievePaymentIntent(withClientSecret: clientSecret) { paymentIntent, error in
            guard let paymentIntent = paymentIntent, error == nil else {
                let error = error ?? PaymentSheetError.unknown(debugDescription: "Failed to retrieve PaymentIntent")
                paymentIntentPromise.reject(with: error)
                return
            }
            paymentIntentPromise.resolve(with: paymentIntent)
        }

        // List the Customer's saved PaymentMethods
        if let customerID = customerID, let ephemeralKey = ephemeralKey {
            apiClient.listPaymentMethods(forCustomer: customerID, using: ephemeralKey) { paymentMethods, error in
                guard let paymentMethods = paymentMethods, error == nil else {
                    let error = error ?? PaymentSheetError.unknown(debugDescription: "Failed to retrieve PaymentMethods for the customer")
                    paymentMethodsPromise.reject(with: error)
                    return
                }
                paymentMethodsPromise.resolve(with: paymentMethods)
            }
        } else {
            paymentMethodsPromise.resolve(with: [])
        }
    }
}

@available(iOSApplicationExtension, unavailable)
extension PaymentSheet: PaymentSheetViewControllerDelegate {
    func paymentSheetViewControllerShouldConfirm(_ paymentSheetViewController: PaymentSheetViewController,
                                                 with paymentOption: PaymentOption,
                                                 completion: @escaping STPPaymentHandlerActionPaymentIntentCompletionBlock) {
        let paymentIntent = paymentSheetViewController.paymentIntent
        switch paymentOption {
        case .applePay:
            guard
                let applePayConfiguration = configuration.applePay,
                let presentingViewController = paymentSheetViewController.presentingViewController,
                let applePayContext = STPApplePayContext.create(
                    paymentIntent: paymentIntent,
                    merchantName: configuration.merchantDisplayName,
                    configuration: applePayConfiguration,
                    completion: { status, paymentIntent, error in
                        if status != .succeeded {
                            // We dismissed the Payment Sheet to show the Apple Pay sheet
                            // Bring it back if it didn't succeed
                            presentingViewController.presentPanModal(self.bottomSheetViewController)
                        }
                        completion(status, paymentIntent, error)
                    })
            else {
                assertionFailure()
                completion(.failed, paymentIntent, nil)
                return
            }
            // Don't present the Apple Pay sheet on top of the Payment Sheet
            paymentSheetViewController.dismiss(animated: true) {
                applePayContext.presentApplePay(on: presentingViewController)
            }
        case let .new(paymentMethodParams, shouldSave):
            let paymentIntentParams = STPPaymentIntentParams(clientSecret: paymentIntent.clientSecret)
            paymentIntentParams.paymentMethodParams = paymentMethodParams
            if shouldSave {
                paymentIntentParams.setupFutureUsage = STPPaymentIntentSetupFutureUsage.offSession
            }
            STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: bottomSheetViewController, completion: completion)

        case let .saved(paymentMethod):
            let paymentIntentParams = STPPaymentIntentParams(clientSecret: paymentIntent.clientSecret)
            paymentIntentParams.paymentMethodId = paymentMethod.stripeId
            STPPaymentHandler.shared().confirmPayment(paymentIntentParams, with: bottomSheetViewController, completion: completion)
        }
    }

    func paymentSheetViewControllerDidFinish(_ paymentSheetViewController: PaymentSheetViewController, result: PaymentResult) {
        paymentSheetViewController.dismiss(animated: true) {
            self.completion?(result)
        }
    }
}

extension PaymentSheet: LoadingViewControllerDelegate {
    func shouldDismiss(_ loadingViewController: LoadingViewController) {
        loadingViewController.dismiss(animated: true) {
            self.completion?(.canceled(lastError: nil, paymentIntent: nil))
        }
    }
}
