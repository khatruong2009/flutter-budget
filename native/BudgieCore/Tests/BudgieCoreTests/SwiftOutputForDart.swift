import Foundation
import Testing

@testable import BudgieCore

/// Writes stores produced by the Swift code for the Dart verifier
/// (native/ParityHarness/run.sh verify). Enabled by BUDGIE_SWIFT_OUT; the
/// companion script native/scripts/verify-swift-output-in-dart.sh sets it.
enum SwiftOutput {
    static var directory: URL? {
        ProcessInfo.processInfo.environment["BUDGIE_SWIFT_OUT"].map { URL(fileURLWithPath: $0) }
    }

    /// Saves the store files and prefs of `fileSystem`/`preferences` as a case.
    /// `budgetLimits`, when given, is what Dart's `categoryBudgetLimits`
    /// must hold after loading the case (the verifier checks key order and
    /// values, the latter as Dart's `toString`). `netWorth`, when given, is
    /// what Dart's `netWorthEntries` (order, ids, names, types, dates and
    /// snapshot amounts as `toString`) and `selectedNetWorthMonth` must be.
    static func emit(
        _ name: String, fileSystem: InMemoryFileSystem, preferences: InMemoryPreferences, snapshot: FinancialSnapshot,
        budgetLimits: [(String, Double)]? = nil, netWorth: FinancialData? = nil
    ) throws {
        guard let root = directory else { return }
        let caseDir = root.appendingPathComponent(name)
        let storeDir = caseDir.appendingPathComponent("financial_store")
        try? FileManager.default.removeItem(at: caseDir)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        for (file, bytes) in fileSystem.snapshot {
            try Data(bytes).write(to: storeDir.appendingPathComponent(file))
        }
        var typed: [String: Any] = [:]
        for (key, value) in preferences.all where key.hasPrefix("flutter.") {
            switch value {
            case .string(let v): typed[key] = ["type": "string", "value": v]
            case .stringList(let v): typed[key] = ["type": "stringList", "value": v]
            case .int(let v): typed[key] = ["type": "int", "value": v]
            case .double(let v): typed[key] = ["type": "double", "value": v]
            case .bool(let v): typed[key] = ["type": "bool", "value": v]
            }
        }
        try JSONSerialization.data(withJSONObject: typed, options: [.prettyPrinted, .sortedKeys])
            .write(to: caseDir.appendingPathComponent("prefs.json"))
        var swift: [String: Any] = [
            "revision": snapshot.revision,
            "sectionsFnv": canonicalSections(snapshot).fnv,
        ]
        if let budgetLimits {
            swift["categoryBudgetLimits"] = budgetLimits.map { [$0.0, DartDouble.format($0.1)] }
        }
        if let netWorth {
            swift["netWorthEntries"] = netWorth.netWorthEntries.map { entry -> [Any] in
                [entry.id, entry.name, entry.type.rawValue, entry.createdAt.toIso8601String(),
                 entry.snapshots.map { [$0.recordedAt.toIso8601String(), DartDouble.format($0.amount)] }]
            }
            swift["selectedNetWorthMonth"] = netWorth.selectedNetWorthMonth.toIso8601String()
        }
        try JSONSerialization.data(withJSONObject: swift, options: [.prettyPrinted, .sortedKeys])
            .write(to: caseDir.appendingPathComponent("swift.json"))
    }
}

@Suite("Swift-written stores for the Dart verifier", .enabled(if: SwiftOutput.directory != nil))
struct SwiftOutputForDartTests {
    @Test("store: Swift load -> save of every readable store scenario")
    func resaveStores() async throws {
        for name in storeScenarioNames {
            let scenario = try Scenario(Fixtures.url("store/\(name)"))
            let store = scenario.makeStore()
            guard var snapshot = try? await store.read() else { continue }
            snapshot = try await store.replace(sections: snapshot.sections)
            try SwiftOutput.emit("store-resave-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot)
        }
    }

    @Test("legacy: stores migrated from SharedPreferences by Swift")
    func migratedLegacy() async throws {
        for name in legacyScenarioNames {
            let scenario = try Scenario(Fixtures.url("legacy/\(name)"))
            let store = scenario.makeStore()
            let snapshot = try await store.read()
            guard snapshot.revision > 0 || !scenario.fileSystem.snapshot.isEmpty else { continue }
            try SwiftOutput.emit("legacy-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot)
        }
    }

    @Test("domain: stores after Swift edits (every mutation the MVP can make)")
    func edited() async throws {
        for name in ["typical", "old_schema", "unknown_data", "fresh_install", "large_10k"] {
            let scenario = try Scenario(Fixtures.url("store/\(name)"))
            guard var data = try await launch(scenario) else { continue }
            let calendar = data.calendar
            let now = scenario.launchNow
            let store = scenario.makeStore()
            _ = try await store.read()
            func id() -> String { UUID().uuidString.lowercased() }

            let added = data.addTransaction(
                type: .expense, description: "Swift ☕️ \"quoted\", comma", amount: 1200, category: "Groceries",
                date: calendar.date(2026, 9, 27, 18, 30), tagIds: ["tag-a", "tag-b"], id: id(), now: now)
            _ = data.addTransaction(type: .income, description: "", amount: 0.1 + 0.2, category: "Salary",
                                    date: now, id: id(), now: now)
            if let first = data.transactions.first {
                data.updateTransaction(id: first.id, .init(type: .expense, description: first.description + " (edited)", amount: 42,
                                                           category: "Health", date: calendar.date(2026, 2, 28)), now: now)
            }
            data.updateTransaction(id: added.id, .init(type: .income, description: added.description, amount: 1e-7,
                                                       category: added.category, date: added.date, tagIds: ["tag-b"]), now: now)
            if data.transactions.count > 3 { data.deleteTransaction(id: data.transactions[2].id) }

            let monthly = RecurringTemplate.make(
                id: id(), type: .expense, description: "Swift rent", amount: 1500, category: "Housing", pattern: .monthly,
                startDate: calendar.date(2026, 1, 31), dayOfMonth: 31, dayOfWeek: nil)
            let weekly = RecurringTemplate.make(
                id: id(), type: .income, description: "Swift pay", amount: 800, category: "Salary", pattern: .weekly,
                startDate: calendar.date(2026, 9, 1, 9), dayOfMonth: nil, dayOfWeek: calendar.date(2026, 9, 1).weekday)
            data.addTemplate(monthly)
            data.addTemplate(weekly)
            _ = RecurringGenerator.generateDue(in: &data, now: now, clock: { now }, newID: id)
            data.updateTemplate(id: monthly.id, .init(type: .expense, description: "Swift rent (edited)", amount: 1550,
                                                      category: "Housing", pattern: .monthly, startDate: calendar.date(2026, 1, 15),
                                                      dayOfMonth: 15, dayOfWeek: nil))
            data.setTemplateActive(id: weekly.id, false)
            data.appSettings.baseCurrencyCode = "EUR"
            data.appSettings.appLockEnabled.toggle()

            // Budgets: a new key, an existing key (typical), a trimmed key, a
            // key Dart dropped at load (old_schema's "Zero":0, appended), a
            // removal, and a limit <= 0. old_schema's "Groceries":250 int
            // lexeme stays untouched next to the patched entries.
            data.setBudgetLimit(category: "Swift Budget ☕️", limit: 123.45)
            data.setBudgetLimit(category: "Eating Out", limit: 175.25)
            data.setBudgetLimit(category: "  Travel \u{FEFF}", limit: 99.99)
            data.setBudgetLimit(category: "Zero", limit: 20)
            data.removeBudgetLimit(category: "Pet Food")
            data.setBudgetLimit(category: "Cafe\u{301}", limit: 1e-7)
            data.setBudgetLimit(category: "Housing", limit: 0)

            // Net worth: every mutation the Worth tab makes, on new accounts
            // and on accounts from the input (typical has some, written by
            // the Flutter model).
            let stored = data.netWorthEntries
            let pastMonth = calendar.date(2026, 6)
            let brokerage = data.addNetWorthEntry(
                name: " Swift Brokerage ☕️ ", type: .asset, amount: 1234.5, month: pastMonth, id: id(), now: now)!
            let card = data.addNetWorthEntry(name: "Swift \"Card\"", type: .liability, amount: 0.1 + 0.2, id: id(), now: now)!
            data.updateNetWorthEntry(id: brokerage.id, name: "Swift Brokerage", type: .asset, amount: 1300, month: pastMonth, now: now)
            data.updateNetWorthEntry(id: brokerage.id, name: "Swift Brokerage", type: .asset, amount: 1e-7, month: now, now: now)
            let july4 = calendar.date(2026, 7, 4, 12, 0, 0, 0, 5)
            data.updateNetWorthEntry(id: card.id, name: "Swift Card", type: .asset, amount: 250, recordedAt: july4, now: now)
            data.updateNetWorthEntry(id: card.id, name: "Swift Card", type: .asset, amount: 260, month: calendar.date(2026, 8), now: now)
            data.deleteNetWorthSnapshot(entryID: card.id, recordedAt: july4)
            if let first = stored.first {
                data.updateNetWorthEntry(id: first.id, name: first.name + " (Swift)", type: first.type, amount: 4321.25,
                                         month: calendar.date(2026, 5), now: now)
                if let oldest = first.snapshots.first, first.snapshots.count > 1 {
                    data.deleteNetWorthSnapshot(entryID: first.id, recordedAt: oldest.recordedAt)
                }
            }
            if stored.count > 1 { data.deleteNetWorthEntry(id: stored[stored.count - 1].id) }
            data.carryNetWorthMonthForward(calendar.date(2026, 10), now: now)
            let doomed = data.addNetWorthEntry(name: "Swift Delete Me", type: .liability, amount: 5, id: id(), now: now)!
            data.deleteNetWorthEntry(id: doomed.id)
            data.selectNetWorthMonth(calendar.date(2026, 7, 19, 8))

            // Every section through its typed serializer, as the app's
            // save and retry paths write them.
            let snapshot = try await store.updateSections(Section.all.map { ($0, data.serializedSection($0)!) })
            try SwiftOutput.emit(
                "edited-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot,
                budgetLimits: data.budgetLimits, netWorth: data)
        }
    }

    @Test("store: damaged inputs recovered by Swift, then saved")
    func recovered() async throws {
        for name in ["primary_truncated", "primary_stale", "primary_missing", "backup_corrupt", "tmp_leftover_valid_newer", "both_corrupt_with_legacy"] {
            let scenario = try Scenario(Fixtures.url("store/\(name)"))
            let store = scenario.makeStore()
            _ = try await store.read()
            let snapshot = try await store.updateSections([(Section.selectedNetWorthMonth, .string("2026-06-01T00:00:00.000"))])
            try SwiftOutput.emit("recovered-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot)
        }
    }
}
