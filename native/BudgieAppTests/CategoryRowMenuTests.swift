import BudgieCore
import XCTest

@testable import Runner

/// The Categories page's row menu and subtitle (category_settings_page.dart
/// :104-139) and the neutral toast style.
@MainActor
final class CategoryRowMenuTests: XCTestCase {
    private func titles(index: Int, count: Int, archived: Bool) -> [String] {
        CategoryRowAction.menu(index: index, count: count, isArchived: archived).map(\.title)
    }

    func testMenuItemsFollowThePositionShown() {
        XCTAssertEqual(titles(index: 0, count: 3, archived: false), ["Edit", "Move down", "Archive"])
        XCTAssertEqual(titles(index: 1, count: 3, archived: false), ["Edit", "Move up", "Move down", "Archive"])
        XCTAssertEqual(titles(index: 2, count: 3, archived: false), ["Edit", "Move up", "Archive"])
        XCTAssertEqual(titles(index: 0, count: 1, archived: false), ["Edit", "Archive"])
        XCTAssertEqual(titles(index: 1, count: 3, archived: true), ["Edit", "Restore"])
    }

    func testSubtitleJoinsBuiltInAndArchived() {
        func info(builtIn: Bool, archived: Bool) -> CategoryInfo {
            CategoryInfo.make(
                id: "expense-x", type: .expense, name: "X", iconIdentifier: "cart", colorToken: "green", sortOrder: 0,
                isArchived: archived, isBuiltIn: builtIn)
        }
        XCTAssertEqual(CategoryRowAction.subtitle(for: info(builtIn: true, archived: false)), "Built in")
        XCTAssertEqual(CategoryRowAction.subtitle(for: info(builtIn: false, archived: true)), "Archived")
        XCTAssertEqual(CategoryRowAction.subtitle(for: info(builtIn: true, archived: true)), "Built in \u{00B7} Archived")
        XCTAssertEqual(CategoryRowAction.subtitle(for: info(builtIn: false, archived: false)), "")
    }

    func testNeutralToastStyle() {
        let toast = Toast(message: "No rows", style: .neutral)
        XCTAssertEqual(toast.style, .neutral)
        XCTAssertEqual(toast.duration, 4)
    }
}
