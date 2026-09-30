import UIKit
import XCTest

@testable import Runner

/// Guards the tour's copy: Flutter's `_pages` verbatim, except page 3, which
/// names Settings instead of the More tab (D2).
@MainActor
final class OnboardingCopyTests: XCTestCase {
    func testPagesAreFlutterCopyWithSettingsOnPageThree() {
        let pages = OnboardingView.pages
        XCTAssertEqual(pages.map(\.eyebrow), ["WELCOME TO BUDGIE", "START HERE", "EXPLORE WHEN READY"])
        XCTAssertEqual(pages.map(\.title), [
            "Your money, made clearer.", "Track what comes and goes.", "Plan ahead, then look back.",
        ])
        XCTAssertEqual(pages.map(\.body), [
            "Budgie keeps your budget simple and private. Financial data and insights stay on this device unless you choose to export or share a backup.",
            "On Home, use the add button for income or expenses. Your balance and recent activity update as you go.",
            "Worth tracks accounts, Goals keeps savings in view, and Spend, Flow, and Settings (behind the gear on Home) help you understand and manage your budget.",
        ])
        for page in pages {
            XCTAssertNotNil(UIImage(systemName: page.symbol), "\(page.symbol) is not a system symbol")
        }
    }
}
