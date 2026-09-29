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
    /// `goals`, when given, is what Dart's `savingsGoals` must be (order,
    /// ids, names, amounts as `toString`, and dates). `appSettings`, when
    /// given, is what Dart's `AppSettingsProvider` must load, and
    /// `themeMode` what its `ThemeProvider` must load (`light`, `dark` or
    /// `system`). `categories`, when given, is what Dart's
    /// `CategoryProvider` must hold after its launch pass (every field, in
    /// stored order, followed by `categoriesAddedAtLaunch` without ids),
    /// and the categories its transactions, templates and rules must carry.
    /// `tagsRules`, when given, is what Dart's `CategorizationProvider` must
    /// load (`tags`, and `rules` in its getter's order, bounds as
    /// `toString`); `newTagIDs` / `newRuleIDs` are rows Swift made, whose
    /// stored JSON must be Dart's `toJson` byte for byte.
    static func emit(
        _ name: String, fileSystem: InMemoryFileSystem, preferences: InMemoryPreferences, snapshot: FinancialSnapshot,
        budgetLimits: [(String, Double)]? = nil, netWorth: FinancialData? = nil, goals: FinancialData? = nil,
        appSettings: AppSettings? = nil, themeMode: String? = nil, categories: FinancialData? = nil,
        categoriesAddedAtLaunch: [CategoryInfo] = [], tagsRules: FinancialData? = nil, newTagIDs: [String] = [],
        newRuleIDs: [String] = []
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
        if let goals {
            swift["savingsGoals"] = goals.savingsGoals.map { goal -> [Any] in
                [goal.id, goal.name, DartDouble.format(goal.targetAmount), DartDouble.format(goal.currentAmount),
                 goal.targetDate.toIso8601String(), goal.createdAt.toIso8601String(),
                 goal.completedAt.map { $0.toIso8601String() as Any } ?? NSNull()]
            }
        }
        if let appSettings {
            swift["appSettings"] = [
                "baseCurrencyCode": appSettings.baseCurrencyCode,
                "localeOverride": appSettings.localeOverride as Any? ?? NSNull(),
                "appLockEnabled": appSettings.appLockEnabled,
                "autoLockTimeoutSeconds": appSettings.autoLockTimeoutSeconds,
                "hideBalances": appSettings.hideBalances,
            ]
        }
        if let themeMode { swift["themeMode"] = themeMode }
        if let categories {
            func fields(_ c: CategoryInfo) -> [Any] {
                [c.type.rawValue, c.name, c.iconIdentifier, c.colorToken, c.sortOrder, c.isArchived, c.isBuiltIn]
            }
            swift["categories"] = categories.categories.map { [$0.id] + fields($0) }
            swift["categoriesAddedAtLaunch"] = categoriesAddedAtLaunch.map(fields)
            swift["transactionCategories"] = categories.transactions.map { [$0.id, $0.type.rawValue, $0.category] }
            swift["templateCategories"] = categories.templates.map { [$0.id, $0.type.rawValue, $0.category] }
            swift["ruleCategories"] = categories.rules.sorted { DartString.precedes($0.id, $1.id) }.map { [$0.id, $0.category] }
        }
        if let tagsRules {
            swift["transactionTags"] = tagsRules.tags.map { [$0.id, $0.name, $0.colorToken] }
            swift["categorizationRules"] = tagsRules.rulesByPriority.map { r -> [Any] in
                [r.id, r.merchantPattern, r.matchType.rawValue, r.transactionType?.rawValue as Any? ?? NSNull(),
                 r.minimumAmount.map(DartDouble.format) as Any? ?? NSNull(), r.maximumAmount.map(DartDouble.format) as Any? ?? NSNull(),
                 r.category, r.tagIds, r.priority, r.isEnabled]
            }
            swift["newTagIds"] = newTagIDs
            swift["newRuleIds"] = newRuleIDs
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

    /// Goal rows another writer produced (Fixtures/goals `foreign`: int and
    /// string amounts, unknown keys, date-only and UTC lexemes, a blank
    /// name, dates that fall back to the launch clock, a duplicated id), plus
    /// a row without an id, and a plain last row for the edit pass to
    /// delete. Not the unreadable rows: Dart's load casts every
    /// row to a map and throws on one, whoever wrote the file.
    static func foreignGoalRows() throws -> [JSONValue] {
        let fixture = J(try JSONParser.parse([UInt8](Fixtures.data("goals/tz/America_New_York/mutations.json"))))
        let foreign = fixture["scenarios"].array.first { $0["name"].string == "foreign" }!
        let initial = try JSONParser.parse(foreign["initial"].string!)
        var rows = initial.objectValue![Section.savingsGoals]!.arrayValue!
        rows.insert(
            try JSONParser.parse(
                #"{"name":"No id","targetAmount":50,"currentAmount":"12.5","targetDate":"2026-11-30","createdAt":"2026-01-02T03:04:05.000Z","completedAt":null,"tag":[1]}"#),
            at: 2)
        // The edit pass deletes the last goal: keep the foreign rows.
        rows.append(try JSONParser.parse(
            #"{"id":"g-tail","name":"Tail","targetAmount":10.0,"currentAmount":0.0,"targetDate":"2026-12-01T00:00:00.000","createdAt":"2026-01-01T00:00:00.000","completedAt":null}"#))
        return rows
    }

    @Test("domain: stores after Swift edits (every mutation the app can make)")
    func edited() async throws {
        // "typical+foreign_goals": typical's store with the foreign-shaped
        // goal rows appended before the launch.
        for name in ["typical", "old_schema", "unknown_data", "fresh_install", "large_10k", "typical+foreign_goals"] {
            let base = name.components(separatedBy: "+")[0]
            let scenario = try Scenario(Fixtures.url("store/\(base)"))
            if base != name {
                let seeding = scenario.makeStore()
                let stored = try await seeding.read()
                let typicalGoals = stored.sections[Section.savingsGoals]?.arrayValue ?? []
                _ = try await seeding.updateSections([(Section.savingsGoals, .array(typicalGoals + Self.foreignGoalRows()))])
            }
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

            // Savings goals: every mutation the Goals tab makes, on new goals
            // and on goals from the input (typical's, written by the Flutter
            // model, and, in "typical+foreign_goals", rows another writer
            // produced; see `foreignGoalRows`).
            let storedGoals = data.savingsGoals
            if name.hasSuffix("+foreign_goals") {
                // A string amount, an int amount with unknown keys, a
                // reordered row with a blank name, the id-less row (its
                // generated id is saved) and one copy of a duplicated id;
                // the negative/garbage row stays untouched.
                data.allocateToSavingsGoal(id: "g-str", amount: 100, now: now)
                data.allocateToSavingsGoal(id: "g-int", amount: 0.5, now: now)
                data.updateSavingsGoal(
                    id: "g-reordered", .init(name: "Reordered", targetAmount: 800, currentAmount: 900, targetDate: calendar.date(2026, 5, 31)),
                    now: now)
                if let noID = storedGoals.first(where: { $0.name == "No id" }) {
                    data.allocateToSavingsGoal(id: noID.id, amount: 1, now: now)
                }
                data.allocateToSavingsGoal(id: "g-dup", amount: 5, now: now)
            }
            let trip = data.addSavingsGoal(
                name: " Swift Trip ☕️ ", targetAmount: 1234.5, targetDate: calendar.date(2026, 12, 24, 18),
                id: SavingsGoalRecord.makeID(now: now, counter: 0), now: now)!
            let fund = data.addSavingsGoal(
                name: "Swift \"Fund\"", targetAmount: 0.1 + 0.2, targetDate: calendar.date(2027, 2, 28),
                id: SavingsGoalRecord.makeID(now: now, counter: 1), now: now)!
            data.allocateToSavingsGoal(id: trip.id, amount: 1000, now: now)
            data.allocateToSavingsGoal(id: fund.id, amount: 0.3, now: now)
            data.allocateToSavingsGoal(id: fund.id, amount: 1e-7, now: now)
            data.allocateToSavingsGoal(id: fund.id, amount: -0.2, now: now)
            data.updateSavingsGoal(
                id: trip.id, .init(name: "Swift Trip", targetAmount: 1500, currentAmount: 1500, targetDate: calendar.date(2027, 1, 2, 9, 30)),
                now: now)
            if let first = storedGoals.first {
                data.allocateToSavingsGoal(id: first.id, amount: 25.5, now: now)
                data.updateSavingsGoal(
                    id: first.id, .init(name: first.name + " (Swift)", targetAmount: max(first.targetAmount, 1), currentAmount: first.currentAmount + 25.5,
                                        targetDate: first.targetDate), now: now)
            }
            if storedGoals.count > 1 { data.deleteSavingsGoal(id: storedGoals[storedGoals.count - 1].id) }
            let doomedGoal = data.addSavingsGoal(
                name: "Swift Delete Me", targetAmount: 5, targetDate: now, id: SavingsGoalRecord.makeID(now: now, counter: 2), now: now)!
            data.deleteSavingsGoal(id: doomedGoal.id)

            // Tags and rules: every edit the Tags & rules page makes (before
            // the category renames, which then carry into these rules):
            // tags with padding, quotes and emoji; rules of every match
            // type, both types and none, amount bounds with awkward
            // lexemes, priorities, disabled, tags in tap order; a rule
            // re-added under its id (moves to the end); deleting a tag the
            // rules use (typical's "Work" when present) and a rule.
            let tagsBefore = data.tags
            let swiftTag = try data.addTag(name: " Swift ☕️ \"Tag\" ", id: id())
            let plainTag = try data.addTag(name: "Swift Plain", colorToken: "cyan", id: id())
            _ = try? data.addTag(name: "swift plain", id: id())
            var newRuleIDs: [String] = []
            func addRule(_ draft: RuleDraft, id ruleID: String? = nil) throws {
                newRuleIDs.append(try data.addRule(draft, id: ruleID ?? id()).id)
            }
            try addRule(RuleDraft(
                merchantPattern: "  Whole \"Foods\" ☕️ ", transactionType: .expense, category: "Groceries",
                tagIds: [plainTag.id, swiftTag.id] + tagsBefore.prefix(1).map(\.id)))
            try addRule(RuleDraft(
                merchantPattern: "SWIFT PAYROLL", matchType: .startsWith, transactionType: .income, minimumAmount: 1000,
                category: "Salary", priority: 3))
            try addRule(RuleDraft(
                merchantPattern: "swift rent", matchType: .exact, transactionType: nil, minimumAmount: -0.0, maximumAmount: 0.1 + 0.2,
                category: "Housing", tagIds: [swiftTag.id], isEnabled: false))
            try addRule(RuleDraft(
                merchantPattern: "swift tiny", transactionType: .expense, minimumAmount: 1e-7, maximumAmount: 1e21,
                category: "Eating Out", priority: -2))
            let moved = id()
            try addRule(RuleDraft(merchantPattern: "swift first", transactionType: .expense, category: "Gift"), id: moved)
            try addRule(RuleDraft(merchantPattern: "swift moved", transactionType: .income, category: "Gift", tagIds: [plainTag.id]), id: moved)
            let doomedRule = id()
            try addRule(RuleDraft(merchantPattern: "swift delete me", transactionType: .expense, category: "Groceries"), id: doomedRule)
            data.deleteRule(id: doomedRule)
            data.deleteTag(id: tagsBefore.first?.id ?? swiftTag.id)
            if let storedRule = data.rules.first(where: { !newRuleIDs.contains($0.id) }) { data.deleteRule(id: storedRule.id) }
            let newTagIDs = [swiftTag.id, plainTag.id].filter { id in data.tags.contains { $0.id == id } }

            // Categories: every edit the Categories page makes. Adds in both
            // types (a taken slug gets a uuid id; an unknown icon is stored
            // as the grid), icon and colour edits, renames that carry
            // through transactions, templates, budget keys and rules (a
            // case change, a budget-key collision), archive and restore,
            // Flutter's move by one and the visible-row move over a hidden
            // archived row.
            func categoryID(_ name: String, _ type: TransactionType) -> String? { data.categoryInfo(named: name, type: type)?.id }
            func edit(_ name: String, _ type: TransactionType, to newName: String, icon: String? = nil, color: String? = nil) {
                guard let info = data.categoryInfo(named: name, type: type) else { return }
                _ = try? data.updateCategory(
                    id: info.id, name: newName, iconIdentifier: icon ?? info.iconIdentifier, colorToken: color ?? info.colorToken, now: now)
            }
            _ = try? data.addCategory(type: .expense, name: " Swift ☕️ \"Coffee\" ", iconIdentifier: "book", colorToken: "cyan", newID: id)
            _ = try? data.addCategory(type: .income, name: "Swift ☕️ \"Coffee\"", iconIdentifier: "nope", colorToken: "green", newID: id)
            _ = try? data.addCategory(type: .expense, name: "Gift!", iconIdentifier: "gift", colorToken: "teal", newID: id)
            edit("Eating Out", .expense, to: "Eating Out", icon: "film", color: "red")
            edit("Groceries", .expense, to: "Food & Groceries")
            edit("Eating Out", .expense, to: "Dining")
            edit("Salary", .income, to: "Paycheck ✨")
            edit("Housing", .expense, to: "housing")
            data.setBudgetLimit(category: "Pets", limit: 12.5)
            data.setBudgetLimit(category: "Swift Collide", limit: 5)
            edit("Pets", .expense, to: "Swift Collide")
            edit("Gift", .expense, to: "Presents")
            if let clothing = categoryID("Clothing", .expense) { _ = try? data.setCategoryArchived(id: clothing, true) }
            if let family = categoryID("Family", .expense) {
                _ = try? data.setCategoryArchived(id: family, true)
                _ = try? data.setCategoryArchived(id: family, false)
            }
            if let travel = categoryID("Travel", .expense) { data.moveCategory(id: travel, offset: -1) }
            if let health = categoryID("Health", .expense),
                let offset = data.categoryMoveOffset(id: health, direction: -1, includeArchived: false)
            {
                data.moveCategory(id: health, offset: offset)
            }
            if let other = categoryID("Other", .income) { data.moveCategory(id: other, offset: -100) }

            // Every section through its typed serializer, as the app's
            // save and retry paths write them.
            let snapshot = try await store.updateSections(Section.all.map { ($0, data.serializedSection($0)!) })
            // What the launch pass adds on reading this back (Flutter's
            // does the same on the same bytes): a padded legacy name is
            // re-added at every launch (typical's "  Padded Cat ").
            let relaunched = FinancialData.load(snapshot, preferences: scenario.preferences, calendar: calendar, now: { now }, newID: id).data
            try SwiftOutput.emit(
                "edited-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot,
                budgetLimits: data.budgetLimits, netWorth: data, goals: data, categories: data,
                categoriesAddedAtLaunch: Array(relaunched.categories.dropFirst(data.categories.count)), tagsRules: data,
                newTagIDs: newTagIDs, newRuleIDs: newRuleIDs.filter { id in data.rules.contains { $0.id == id } })
        }
    }

    @Test("settings: stores and preference mirrors after the Swift settings setters")
    func settings() async throws {
        for name in ["typical", "fresh_install", "unknown_data"] {
            let scenario = try Scenario(Fixtures.url("store/\(name)"))
            guard var data = try await launch(scenario) else { continue }
            let store = scenario.makeStore()
            _ = try await store.read()
            // AppModel's order: memory, the preference mirror, then the section.
            func apply(_ update: SettingsUpdate) {
                if case .write(let key, let value) = update { scenario.preferences.set(value, forKey: key) }
            }
            apply(data.appSettings.setBaseCurrencyCode(" jpy "))
            apply(data.appSettings.setLocaleOverride("de_DE"))
            apply(data.appSettings.setAppLockEnabled(!data.appSettings.appLockEnabled))
            apply(data.appSettings.setAutoLockTimeoutSeconds(900))
            apply(data.appSettings.setHideBalances(!data.appSettings.hideBalances))
            // AppModel.setThemeMode writes only this preference.
            scenario.preferences.set(.string("dark"), forKey: PreferenceKey.themeMode)
            var snapshot = try await store.updateSections([(Section.appSettings, data.appSettingsSection())])
            try SwiftOutput.emit(
                "settings-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot,
                appSettings: data.appSettings, themeMode: "dark")

            // "Match device" removes the locale mirror and writes null.
            apply(data.appSettings.setLocaleOverride(nil))
            snapshot = try await store.updateSections([(Section.appSettings, data.appSettingsSection())])
            try SwiftOutput.emit(
                "settings-match-device-\(name)", fileSystem: scenario.fileSystem, preferences: scenario.preferences,
                snapshot: snapshot, appSettings: data.appSettings)
        }

        // Without a stored section Dart falls back to the mirrored
        // preferences: they alone must load as what Swift set.
        let scenario = try Scenario(Fixtures.url("store/fresh_install"))
        guard var data = try await launch(scenario) else { return }
        let store = scenario.makeStore()
        var snapshot = try await store.read()
        for update in [
            data.appSettings.setBaseCurrencyCode("gbp"), data.appSettings.setLocaleOverride(" fr_FR "),
            data.appSettings.setAppLockEnabled(true), data.appSettings.setAutoLockTimeoutSeconds(0),
            data.appSettings.setHideBalances(true),
        ] {
            if case .write(let key, let value) = update { scenario.preferences.set(value, forKey: key) }
        }
        var sections = snapshot.sections
        sections[Section.appSettings] = nil
        snapshot = try await store.replace(sections: sections)
        try SwiftOutput.emit(
            "settings-prefs-only", fileSystem: scenario.fileSystem, preferences: scenario.preferences, snapshot: snapshot,
            appSettings: data.appSettings)
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
