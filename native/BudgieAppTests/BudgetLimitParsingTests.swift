import BudgieCore
import XCTest

@testable import Runner

/// The budget limit sheet's locale-aware parse (D6): Flutter strips
/// `[^0-9.]`, which reads "1.500,00" as 1.5.
final class BudgetLimitParsingTests: XCTestCase {
    private let english = MoneyFormatter(currencyCode: "USD")
    private let german = MoneyFormatter(currencyCode: "EUR", locale: "de_DE")
    private let french = MoneyFormatter(currencyCode: "EUR", locale: "fr_FR")

    private func parse(_ text: String, _ formatter: MoneyFormatter) -> Double? {
        BudgetLimitSheet.parseLimit(text, formatter: formatter)
    }

    func testGroupedAmountsInTheirOwnLocale() {
        XCTAssertEqual(parse("1,500.00", english), 1500)
        XCTAssertEqual(parse("1.500,00", german), 1500)
        XCTAssertEqual(parse("1\u{202F}500,00", french), 1500)
        XCTAssertEqual(parse("1,234,567.89", english), 1_234_567.89)
        XCTAssertEqual(parse("100", english), 100)
        XCTAssertEqual(parse("5.", english), 5)
        XCTAssertEqual(parse(".5", english), 0.5)
        XCTAssertEqual(parse(" 42.50 ", english), 42.5)
    }

    /// The prefill round-trips through the parse.
    func testPrefillRoundTrips() {
        for formatter in [english, german, french] {
            XCTAssertEqual(parse(formatter.formatNumber(1500, decimalDigits: 2), formatter), 1500)
            XCTAssertEqual(parse(formatter.formatNumber(0.25, decimalDigits: 2), formatter), 0.25)
        }
    }

    /// A keyboard from another locale types the other decimal key.
    func testLoneGroupingSeparatorIsADecimalUnlessThreeDigitsFollow() {
        XCTAssertEqual(parse("12,5", english), 12.5)
        XCTAssertEqual(parse("1,500", english), 1500)
        XCTAssertEqual(parse("12.5", german), 12.5)
        XCTAssertEqual(parse("1.500", german), 1500)
        XCTAssertEqual(parse("12.5", french), 12.5)
        XCTAssertNil(parse("1,5,0", english))
    }

    func testRejectsEmptyZeroNegativeAndNonNumericText() {
        XCTAssertNil(parse("", english))
        XCTAssertNil(parse(".", english))
        XCTAssertNil(parse("0", english))
        XCTAssertNil(parse("0.00", english))
        XCTAssertNil(parse("-5", english))
        XCTAssertNil(parse("abc", english))
        XCTAssertNil(parse("1.2.3", english))
        XCTAssertNil(parse("1.2.3", german))
    }

    /// Dart `tryParse` accepts exponents and "Infinity"; the field does not
    /// (Flutter's strip turned "1e3" into 13).
    func testRejectsExponentsAndNonFiniteValues() {
        XCTAssertNil(parse("1e3", english))
        XCTAssertNil(parse("Infinity", english))
        XCTAssertNil(parse("NaN", english))
        XCTAssertNil(parse(String(repeating: "9", count: 400), english))
    }

    func testSeparatorsAndCurrencySymbolFollowTheFormat() {
        XCTAssertTrue(BudgetLimitSheet.separators(english) == (",", "."))
        XCTAssertTrue(BudgetLimitSheet.separators(german) == (".", ","))
        XCTAssertEqual(BudgetLimitSheet.currencySymbol(english), "$")
        XCTAssertEqual(BudgetLimitSheet.currencySymbol(german), "\u{20AC}")
        XCTAssertEqual(BudgetLimitSheet.currencySymbol(MoneyFormatter(currencyCode: "BRL")), "R$")
        XCTAssertEqual(
            BudgetLimitSheet.currencySymbol(MoneyFormatter(currencyCode: "GBP", hideBalances: true)), "\u{00A3}")
    }
}
