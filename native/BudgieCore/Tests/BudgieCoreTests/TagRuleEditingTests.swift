import Foundation
import Testing

@testable import BudgieCore

private let calendar = DartCalendar(timeZone: TimeZone(identifier: "America/New_York")!)
private let now = calendar.date(2026, 9, 28, 9, 15, 30, 250, 125)

/// Loads sections given as JSON text.
private func data(_ json: String) throws -> FinancialData {
    FinancialData.load(
        FinancialSnapshot(revision: 1, sections: try JSONParser.parse(json).objectValue!), preferences: InMemoryPreferences([:]),
        calendar: calendar, now: { now }, newID: { "new-id" }
    ).data
}

private func text(_ value: JSONValue) -> String { DartJSON.encodeString(value) }

private let twoTags = #"{"transactionTags":[{"id":"t1","name":"Work","colorToken":"accent"},{"id":"t2","name":"Café","colorToken":"cyan"}]}"#

@Suite("Tags and rules: add and delete as CategorizationProvider does")
struct TagRuleEditingTests {
    @Test("addTag: Dart trim, empty before duplicate, UTF-16 case-insensitive duplicates, toJson shape")
    func addTag() throws {
        var d = try data(twoTags)
        for name in ["", "   ", "\u{FEFF}", "\u{85}\u{A0}\u{3000}"] {
            #expect(throws: CategorizationEditError.tagNameRequired) { try d.addTag(name: name, id: "x") }
        }
        for name in ["work", " WORK ", "\u{FEFF}Work", "CAFÉ"] {
            #expect(throws: CategorizationEditError.duplicateTagName) { try d.addTag(name: name, id: "x") }
        }
        #expect(CategorizationEditError.tagNameRequired.message == "Tag name is required")
        #expect(CategorizationEditError.duplicateTagName.message == "A tag with this name already exists")
        #expect(d.tags.count == 2)

        // NFD differs from the stored NFC "Café" as UTF-16, as in Dart.
        try d.addTag(name: " Cafe\u{301} ", id: "t3")
        // Dart lowercases U+0130 to plain "i".
        try d.addTag(name: "İstanbul", id: "t4")
        #expect(throws: CategorizationEditError.duplicateTagName) { try d.addTag(name: "istanbul", id: "x") }
        // Georgian Mtavruli is not in Dart's case tables: no duplicate.
        try d.addTag(name: "\u{10D0}", id: "t5")
        try d.addTag(name: "\u{1C90}", id: "t6")
        let tag = try d.addTag(name: "\u{FEFF} Travel planning\u{2028}", colorToken: "green", id: "t7")
        #expect(tag.name == "Travel planning")
        #expect(d.tags.map(\.id) == ["t1", "t2", "t3", "t4", "t5", "t6", "t7"])
        #expect(text(d.tagsSection()).hasSuffix(#",{"id":"t7","name":"Travel planning","colorToken":"green"}]"#))
        #expect(d.validateTagName("travel PLANNING") == .duplicateTagName)
        #expect(d.validateTagName("New") == nil)
    }

    @Test("a new rule is Dart's toJson: key order, null keys, double lexemes, int priority")
    func ruleShape() throws {
        var d = try data(twoTags)
        try d.addRule(RuleDraft(merchantPattern: "  Whole \"Foods\" ", transactionType: .expense, category: "Groceries", tagIds: ["t2", "t1"]), id: "r1")
        try d.addRule(
            RuleDraft(
                merchantPattern: "pay", matchType: .startsWith, transactionType: nil, minimumAmount: 0.1 + 0.2, maximumAmount: 1e21,
                category: "Salary", priority: -3, isEnabled: false), id: "r2")
        try d.addRule(
            RuleDraft(merchantPattern: "x", matchType: .exact, transactionType: .income, minimumAmount: -0.0, maximumAmount: 20, category: "C"),
            id: "r3")
        try d.addRule(RuleDraft(merchantPattern: "y", transactionType: .expense, minimumAmount: 1e-7, category: "C", priority: 1 << 53 + 1), id: "r4")
        #expect(text(d.rulesSection()) == "[" + [
            #"{"id":"r1","merchantPattern":"Whole \"Foods\"","matchType":"contains","transactionType":"expense","minimumAmount":null,"maximumAmount":null,"category":"Groceries","tagIds":["t2","t1"],"priority":0,"isEnabled":true}"#,
            #"{"id":"r2","merchantPattern":"pay","matchType":"startsWith","transactionType":null,"minimumAmount":0.30000000000000004,"maximumAmount":1e+21,"category":"Salary","tagIds":[],"priority":-3,"isEnabled":false}"#,
            #"{"id":"r3","merchantPattern":"x","matchType":"exact","transactionType":"income","minimumAmount":-0.0,"maximumAmount":20.0,"category":"C","tagIds":[],"priority":0,"isEnabled":true}"#,
            #"{"id":"r4","merchantPattern":"y","matchType":"contains","transactionType":"expense","minimumAmount":1e-7,"maximumAmount":null,"category":"C","tagIds":[],"priority":\#(1 << 53 + 1),"isEnabled":true}"#,
        ].joined(separator: ",") + "]")
        // The made record reads back as itself.
        let reparsed = try data(#"{"transactionTags":"# + text(d.tagsSection()) + #","categorizationRules":"# + text(d.rulesSection()) + "}")
        #expect(reparsed.rules == d.rules)
        #expect(d.rulesByPriority.map(\.id) == ["r4", "r1", "r3", "r2"])
    }

    @Test("addRule: the same id moves to the end; Swift-only checks refuse without changing anything")
    func addRule() throws {
        var d = try data(twoTags)
        try d.addRule(RuleDraft(merchantPattern: "a", transactionType: .expense, category: "A"), id: "r1")
        try d.addRule(RuleDraft(merchantPattern: "b", transactionType: .expense, category: "B"), id: "r2")
        try d.addRule(RuleDraft(merchantPattern: "a2", transactionType: .income, category: "A2"), id: "r1")
        #expect(d.rules.map(\.id) == ["r2", "r1"])
        #expect(d.rules.last?.merchantPattern == "a2")

        let before = text(d.rulesSection())
        #expect(throws: CategorizationEditError.rulePatternRequired) {
            try d.addRule(RuleDraft(merchantPattern: " \u{FEFF}", transactionType: .expense, category: "A"), id: "r9")
        }
        for bound in [Double.nan, .infinity, -.infinity] {
            #expect(throws: CategorizationEditError.ruleAmountNotFinite) {
                try d.addRule(RuleDraft(merchantPattern: "a", transactionType: .expense, maximumAmount: bound, category: "A"), id: "r9")
            }
        }
        #expect(throws: CategorizationEditError.unknownTag("t9")) {
            try d.addRule(RuleDraft(merchantPattern: "a", transactionType: .expense, category: "A", tagIds: ["t1", "t9"]), id: "r9")
        }
        #expect(text(d.rulesSection()) == before)
    }

    @Test("deleteTag: strips every occurrence from rules (only that key), keeps transactions' ids, unreadable rows")
    func deleteTag() throws {
        var d = try data(#"""
            {"transactionTags":[{"id":"t1","name":"Work"},{"id":"t2","name":"Home","colorToken":"accent"},{"id":"t1","name":"Dup","colorToken":"x"},7],
             "categorizationRules":[
               {"merchantPattern":"a","category":"A","tagIds":["t1",1,"t2","t1",null],"id":"r1","future":{"k":[1.50]}},
               {"id":"r2","merchantPattern":"b","category":"B","tagIds":["t2"],"minimumAmount":5},
               {"id":"r3","merchantPattern":"c","category":"C"},
               "bad"],
             "transactions":[{"id":"x1","type":"expense","description":"d","amount":1.0,"category":"A","date":"2026-09-01T00:00:00.000","recurringTemplateId":null,"tagIds":["t1"],"createdAt":"2026-09-01T10:00:00.000","updatedAt":"2026-09-01T10:00:00.000"}]}
            """#)
        let transactions = text(d.transactionsSection())
        let deleted = d.deleteTag(id: "t1")
        #expect(deleted == [Section.transactionTags, Section.categorizationRules])
        #expect(text(d.tagsSection()) == #"[{"id":"t2","name":"Home","colorToken":"accent"},7]"#)
        #expect(text(d.rulesSection()) == "[" + [
            #"{"merchantPattern":"a","category":"A","tagIds":[1,"t2",null],"id":"r1","future":{"k":[1.50]}}"#,
            #"{"id":"r2","merchantPattern":"b","category":"B","tagIds":["t2"],"minimumAmount":5}"#,
            #"{"id":"r3","merchantPattern":"c","category":"C"}"#,
            #""bad""#,
        ].joined(separator: ",") + "]")
        #expect(d.rules.map(\.tagIds) == [["t2"], ["t2"], []])
        #expect(text(d.transactionsSection()) == transactions)
        #expect(d.transactions.first?.tagIds == ["t1"])

        // Unknown everywhere: nothing to write.
        let none = d.deleteTag(id: "nope")
        #expect(none.isEmpty)
        // An orphan id only a rule still names: the rule changes.
        var orphan = try data(#"{"categorizationRules":[{"id":"r1","merchantPattern":"a","category":"A","tagIds":["gone"]}]}"#)
        let stripped = orphan.deleteTag(id: "gone")
        #expect(stripped == [Section.transactionTags, Section.categorizationRules])
        #expect(orphan.rules.first?.tagIds == [])
    }

    @Test("deleteRule: every rule with the id; unknown ids change nothing")
    func deleteRule() throws {
        var d = try data(#"{"categorizationRules":[{"id":"r1","merchantPattern":"a","category":"A"},{"id":"r2","merchantPattern":"b","category":"B"},{"id":"r1","merchantPattern":"c","category":"C"},[]]}"#)
        let caseVariant = d.deleteRule(id: "R1")
        let known = d.deleteRule(id: "r1")
        #expect(!caseVariant && known)
        #expect(text(d.rulesSection()) == #"[{"id":"r2","merchantPattern":"b","category":"B"},[]]"#)
        let again = d.deleteRule(id: "r1")
        #expect(!again)
    }

    @Test("suggestion: the first match wins; nil when its category is not active (later rules are not tried)")
    func suggestion() throws {
        let d = try data(#"""
            {"categorizationRules":[
              {"id":"low","merchantPattern":"shop","category":"Groceries","priority":0},
              {"id":"high","merchantPattern":"shop","category":"Archived","priority":5},
              {"id":"income","merchantPattern":"shop","category":"Salary","transactionType":"income","priority":9}]}
            """#)
        let active = ["Groceries", "Housing"]
        #expect(CategorizationEngine.suggest(rules: d.rules, type: .expense, description: "Shop", amount: 1)?.id == "high")
        #expect(CategorizationEngine.suggestion(rules: d.rules, type: .expense, description: "Shop", amount: 1, activeCategoryNames: active) == nil)
        #expect(
            CategorizationEngine.suggestion(rules: d.rules, type: .expense, description: "Shop", amount: 1, activeCategoryNames: active + ["Archived"])?.id
                == "high")
        #expect(CategorizationEngine.suggestion(rules: d.rules, type: .income, description: "shop", amount: 1, activeCategoryNames: ["Salary"])?.id == "income")
    }
}
