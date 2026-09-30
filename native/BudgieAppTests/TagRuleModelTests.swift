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

    /// The rule dialog's category: the pick while the list has it (UTF-16
    /// equality), else the list's first.
    func testResolvedCategory() {
        let expense = ["Gift", "Groceries", "General"]
        XCTAssertEqual(NewRuleDialog.resolvedCategory(nil, in: expense), "Gift")
        XCTAssertEqual(NewRuleDialog.resolvedCategory("Groceries", in: expense), "Groceries")
        XCTAssertEqual(NewRuleDialog.resolvedCategory("groceries", in: expense), "Gift", "case-sensitive")
        // Precomposed vs decomposed e-acute: different UTF-16, so not kept.
        XCTAssertEqual(NewRuleDialog.resolvedCategory("Caf\u{00E9}", in: ["Cafe\u{0301}", "Other"]), "Cafe\u{0301}")
        XCTAssertEqual(NewRuleDialog.resolvedCategory("Gift", in: []), "")
    }

    /// Flutter's type switch: the shown category survives when the new type
    /// has it, including the untouched default (Flutter starts at the first
    /// expense category, not at "nothing picked").
    func testCategoryAfterTypeChange() {
        let expense = ["Gift", "Groceries"]
        let income = ["Salary", "Gift"]
        XCTAssertEqual(NewRuleDialog.categoryAfterTypeChange(nil, from: expense, to: income), "Gift")
        XCTAssertEqual(NewRuleDialog.categoryAfterTypeChange("Groceries", from: expense, to: income), "Salary")
        XCTAssertEqual(NewRuleDialog.categoryAfterTypeChange(nil, from: ["General"], to: income), "Salary")
        XCTAssertEqual(NewRuleDialog.categoryAfterTypeChange("Gift", from: income, to: expense), "Gift")
    }

    /// Flutter's exact rule subtitle: raw match type, category, and
    /// " · n tags" (never singular) when it has tags.
    func testRuleSubtitle() {
        func rule(_ match: MerchantMatchType, _ category: String, _ tags: [String]) -> CategorizationRuleRecord {
            .make(id: "r", RuleDraft(
                merchantPattern: "Whole Foods", matchType: match, transactionType: .expense, category: category, tagIds: tags))
        }
        XCTAssertEqual(TagsRulesView.ruleSubtitle(rule(.contains, "Groceries", [])), "contains \u{00B7} Groceries")
        XCTAssertEqual(TagsRulesView.ruleSubtitle(rule(.contains, "Groceries", ["t1"])), "contains \u{00B7} Groceries \u{00B7} 1 tags")
        XCTAssertEqual(TagsRulesView.ruleSubtitle(rule(.startsWith, "Salary", ["t1", "t2"])), "startsWith \u{00B7} Salary \u{00B7} 2 tags")
        XCTAssertEqual(TagsRulesView.ruleSubtitle(rule(.exact, "Housing", [])), "exact \u{00B7} Housing")
    }
}
