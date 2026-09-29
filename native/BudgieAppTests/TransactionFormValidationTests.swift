import XCTest

@testable import Runner

/// The form's amount validation (`validateForm`, transaction_form.dart:152-165):
/// Dart `double.tryParse`, then `<= 0`; non-finite values are rejected (D6).
@MainActor
final class TransactionFormValidationTests: XCTestCase {
    private let enUS = Locale(identifier: "en_US")

    private func validate(_ text: String, _ locale: Locale? = nil) -> Result<Double, TransactionFormView.AmountError> {
        TransactionFormView.validateAmount(text, locale: locale ?? enUS)
    }

    func testMessages() {
        XCTAssertEqual(TransactionFormView.AmountError.required.message, "Amount is required")
        XCTAssertEqual(TransactionFormView.AmountError.invalid.message, "Please enter a valid number")
        XCTAssertEqual(TransactionFormView.AmountError.notPositive.message, "Amount must be greater than 0")
    }

    func testRejected() {
        XCTAssertEqual(validate(""), .failure(.required))
        XCTAssertEqual(validate("abc"), .failure(.invalid))
        XCTAssertEqual(validate("0"), .failure(.notPositive))
        XCTAssertEqual(validate("-5"), .failure(.notPositive))
        XCTAssertEqual(validate("NaN"), .failure(.invalid))
        XCTAssertEqual(validate("Infinity"), .failure(.invalid))
        XCTAssertEqual(validate("1e400"), .failure(.invalid))
        XCTAssertEqual(validate("1,5"), .failure(.invalid), "no comma decimal in en_US")
        XCTAssertEqual(validate("   "), .failure(.invalid), "whitespace is not empty (Dart checks isEmpty)")
    }

    func testAcceptedDartForms() {
        XCTAssertEqual(validate("12.34"), .success(12.34))
        XCTAssertEqual(validate(" 5 "), .success(5))
        XCTAssertEqual(validate(".5"), .success(0.5))
        XCTAssertEqual(validate("5."), .success(5))
        XCTAssertEqual(validate("1e3"), .success(1000))
        XCTAssertEqual(validate("+5"), .success(5))
        XCTAssertEqual(validate("12.345"), .success(12.345), "nothing rounds on add")
    }

    func testLocaleDecimalSeparator() {
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(validate("12,5", german), .success(12.5))
        XCTAssertEqual(validate("12.5", german), .success(12.5))
    }
}
