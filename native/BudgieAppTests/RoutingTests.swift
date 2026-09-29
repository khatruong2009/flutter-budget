import XCTest

@testable import Runner

@MainActor
final class RoutingTests: XCTestCase {
    func testDeepLinksAndShortcutsMapLikeTheFlutterApp() {
        let model = AppModel()
        for (link, route) in [
            ("budgetapp://add-income", AddRoute.income), ("budgetapp://add_income", .income),
            ("budgetapp://add-expense", .expense), ("budgetapp://add_expense", .expense),
            ("budgetapp://voice-add", .expense), ("budgetapp:///add-income", .income),
        ] {
            model.pendingAdd = nil
            model.open(URL(string: link)!)
            XCTAssertEqual(model.pendingAdd, route, link)
        }
        model.pendingAdd = nil
        model.open(URL(string: "budgetapp://unknown")!)
        XCTAssertNil(model.pendingAdd)
        for (type, route) in [("action_add_expense", AddRoute.expense), ("action_add_income", .income), ("action_voice_add", .expense)] {
            model.pendingAdd = nil
            model.handleShortcut(type)
            XCTAssertEqual(model.pendingAdd, route, type)
        }
    }
}

@MainActor
final class RouteGateTests: XCTestCase {
    /// Before the data is ready (and, in the app, while locked or during
    /// onboarding) a route stays queued instead of opening.
    func testRoutesWaitUntilTheyMayOpen() {
        let model = AppModel()
        XCTAssertFalse(model.canOpenRoutes)
        model.open(URL(string: "budgetapp://add-income")!)
        XCTAssertNil(model.takePendingAdd())
        XCTAssertEqual(model.pendingAdd, .income, "the route is kept for later")
        XCTAssertFalse(model.isLocked, "no data, no lock")
        model.markUnlocked()
        model.relock()
        XCTAssertEqual(model.pendingAdd, .income)
    }
}
