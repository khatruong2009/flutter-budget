import XCTest

@testable import Runner

@MainActor
final class FontTests: XCTestCase {
    func testEveryBundledFontIsRegistered() {
        XCTAssertEqual(BudgieFont.missing, [], "UIAppFonts or the bundled TTFs are out of sync")
    }

    func testLicenceTextsShipWithTheFonts() {
        for name in ["OFL-Gabarito", "OFL-SplineSansMono"] {
            XCTAssertTrue(LicencesView.text(name).contains("SIL OPEN FONT LICENSE Version 1.1"), name)
        }
    }
}
