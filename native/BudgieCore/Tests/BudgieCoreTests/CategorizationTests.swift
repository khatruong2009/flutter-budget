import Foundation
import Testing

@testable import BudgieCore

@Suite("Categorization: rule matching and suggestions")
struct CategorizationTests {
    private func rule(_ json: String) -> CategorizationRuleRecord {
        CategorizationRuleRecord.parse(try! JSONParser.parse(json), newID: { "generated" })!
    }

    @Test("matching table: trim, case, inclusive bounds, type filter, disabled, empty pattern")
    func matching() {
        let contains = rule(#"{"id":"c","merchantPattern":"  Coffee ","category":"Eating Out"}"#)
        #expect(contains.matches(type: .expense, description: "  the COFFEE bar\u{FEFF}", amount: 3))
        #expect(contains.matches(type: .income, description: "coffee", amount: 3))
        #expect(!contains.matches(type: .expense, description: "cof fee", amount: 3))

        let prefix = rule(#"{"id":"p","merchantPattern":"star","matchType":"startsWith","category":"x"}"#)
        #expect(prefix.matches(type: .expense, description: "  Starbucks", amount: 0))
        #expect(!prefix.matches(type: .expense, description: "the star", amount: 0))

        let exact = rule(#"{"id":"e","merchantPattern":"Rent","matchType":"exact","transactionType":"expense","minimumAmount":1000,"maximumAmount":2000.0,"category":"Housing"}"#)
        #expect(exact.matches(type: .expense, description: " rent ", amount: 1000))
        #expect(exact.matches(type: .expense, description: "RENT", amount: 2000))
        #expect(!exact.matches(type: .expense, description: "rent", amount: 999.99))
        #expect(!exact.matches(type: .expense, description: "rent", amount: 2000.01))
        #expect(!exact.matches(type: .income, description: "rent", amount: 1500))
        #expect(!exact.matches(type: .expense, description: "rent due", amount: 1500))
        // NaN passes both bounds (every comparison is false), as in Dart.
        #expect(exact.matches(type: .expense, description: "rent", amount: .nan))

        #expect(!rule(#"{"id":"d","merchantPattern":"coffee","isEnabled":false,"category":"x"}"#)
            .matches(type: .expense, description: "coffee", amount: 1))
        #expect(!rule(#"{"id":"b","merchantPattern":"   ","category":"x"}"#)
            .matches(type: .expense, description: "   ", amount: 1))

        // Dart toLowerCase maps U+0130 to plain "i"; NFD and NFC differ.
        let dotted = rule(#"{"id":"i","merchantPattern":"İstanbul","category":"x"}"#)
        #expect(dotted.matches(type: .expense, description: "ISTANBUL", amount: 1))
        let nfc = rule(#"{"id":"n","merchantPattern":"Café","category":"x"}"#)
        #expect(!nfc.matches(type: .expense, description: "Cafe\u{301}", amount: 1))
    }

    @Test("suggest: priority descending, first match wins, ties keep stored order (also above 32 rules)")
    func suggest() {
        let rules = [
            rule(#"{"id":"low","merchantPattern":"shop","category":"a","priority":0}"#),
            rule(#"{"id":"high","merchantPattern":"shop","category":"b","priority":5,"maximumAmount":10}"#),
            rule(#"{"id":"mid","merchantPattern":"shop","category":"c","priority":2}"#),
            rule(#"{"id":"off","merchantPattern":"shop","category":"d","priority":9,"isEnabled":false}"#),
        ]
        #expect(CategorizationEngine.suggest(rules: rules, type: .expense, description: "Shop", amount: 5)?.id == "high")
        #expect(CategorizationEngine.suggest(rules: rules, type: .expense, description: "Shop", amount: 50)?.id == "mid")
        #expect(CategorizationEngine.suggest(rules: rules, type: .expense, description: "nothing", amount: 5) == nil)
        #expect(CategorizationEngine.suggest(rules: [], type: .expense, description: "shop", amount: 5) == nil)

        let many = (0..<40).map { rule(#"{"id":"r\#($0)","merchantPattern":"x","category":"c","priority":1}"#) }
        #expect(CategorizationEngine.suggest(rules: many, type: .expense, description: "x", amount: 1)?.id == "r0")
    }

    @Test("double.tryParse: form inputs")
    func tryParse() {
        #expect(DartDouble.tryParse("12.50") == 12.5)
        #expect(DartDouble.tryParse(" 1e3 ") == 1000)
        #expect(DartDouble.tryParse(".5") == 0.5)
        #expect(DartDouble.tryParse("5.") == 5)
        #expect(DartDouble.tryParse("Infinity") == .infinity)
        #expect(DartDouble.tryParse("-NaN")?.isNaN == true)
        for bad in ["", " ", "1,5", "0x10", "1e", ".", "1.2.3", "$5", "١"] {
            #expect(DartDouble.tryParse(bad) == nil, "\(bad)")
        }
    }
}
