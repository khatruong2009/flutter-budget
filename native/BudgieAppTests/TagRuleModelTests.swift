import BudgieCore
import XCTest

@testable import Runner

@MainActor
final class TagRuleModelTests: XCTestCase {
    /// Before the store is loaded nothing can change and nothing is written.
    func testEditsBeforeLoadDoNothing() async {
        let model = AppModel()
        let tag = await model.addTag(name: "Work")
        XCTAssertEqual(tag, .unchanged)
        let deletedTag = await model.deleteTag(id: "t1")
        XCTAssertEqual(deletedTag, .unchanged)
        let rule = await model.addRule(RuleDraft(merchantPattern: "Whole Foods", transactionType: .expense, category: "Groceries"))
        XCTAssertEqual(rule, .unchanged)
        let deletedRule = await model.deleteRule(id: "r1")
        XCTAssertEqual(deletedRule, .unchanged)
        XCTAssertEqual(model.tags, [])
        XCTAssertEqual(model.rules, [])
        XCTAssertNil(model.validateTagName(""))
        XCTAssertNil(model.suggestion(type: .expense, description: "whole foods", amount: 1))
        XCTAssertFalse(model.hasUnsavedChanges)
    }

    /// The outcome carries Flutter's copy for the caller's message.
    func testRejectedOutcomeCarriesFlutterCopy() {
        let outcome = AppModel.TagRuleOutcome.rejected(.duplicateTagName)
        guard case .rejected(let error) = outcome else { return XCTFail() }
        XCTAssertEqual(error.message, "A tag with this name already exists")
        XCTAssertEqual(CategorizationEditError.tagNameRequired.message, "Tag name is required")
    }
}
