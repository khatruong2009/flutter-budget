import XCTest

@testable import Runner

/// The Worth editor's balance field: typing goes through Flutter's
/// `_CurrencyInputFormatter`; the text a month pick assigns (the stored
/// balance, which may be negative) is kept as set.
final class AccountEditorInputTests: XCTestCase {
    func testTypingIsSanitized() {
        XCTAssertEqual(AccountEditorDialog.sanitizedAmount(old: "123", new: "1234", prefill: ""), "1,234")
        XCTAssertEqual(AccountEditorDialog.sanitizedAmount(old: "12", new: "12-", prefill: ""), "12")
        XCTAssertEqual(AccountEditorDialog.sanitizedAmount(old: "1.55", new: "1.555", prefill: ""), "1.55")
        XCTAssertNil(AccountEditorDialog.sanitizedAmount(old: "1,234", new: "12,345", prefill: ""))
    }

    /// A month pick with a negative stored balance: the formatter would
    /// restore the previous month's text while Save compares against the
    /// new prefill, saving the old month's amount into the new month.
    func testMonthPickPrefillIsKeptEvenWhereTheFormatterWouldRejectIt() {
        XCTAssertNil(AccountEditorDialog.sanitizedAmount(old: "250,000", new: "-1,234.5", prefill: "-1,234.5"))
        XCTAssertNil(AccountEditorDialog.sanitizedAmount(old: "250,000", new: "", prefill: ""))
        // Typing away from the prefill is sanitized again.
        XCTAssertEqual(AccountEditorDialog.sanitizedAmount(old: "-1,234.5", new: "-1,234.5x", prefill: "-1,234.5"), "-1,234.5")
    }
}
