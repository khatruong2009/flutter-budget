import BudgieCore
import Foundation
import Observation
import os
import UIKit
import WidgetKit

enum AppIdentifiers {
    static let bundleID = "com.khatruong.budgetbuddy"
    static let appGroup = "group.com.khatruong.budgetbuddy"
}

/// What the Add sheet should open with (quick actions, deep links, widget).
enum AddRoute: Equatable, Sendable {
    case expense, income
}

enum ThemeMode: String, CaseIterable, Sendable {
    case light, dark, system
}

/// The app's single source of truth. Owns the bootstrap (MIGRATION_SPEC
/// sections 6, 9, 10) and every mutation; views only read and call methods.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        /// Prewarmed or locked launch: nothing has been read.
        case waitingForUnlock
        case starting
        /// Something prevents a safe start; nothing was written.
        case blocked(Blocker)
        case ready
    }

    enum Blocker: Equatable {
        /// The pre-migration copy could not be made (rule 1); the store was
        /// not touched.
        case backupFailed(String)
        /// A store file exists but cannot be read. Never shown as empty data.
        case readFailed(String)
        /// Both store files were unreadable and set aside (approved Q3).
        case dataUnreadable([String])
    }

    private(set) var phase: Phase = .starting
    private(set) var data: FinancialData?
    private(set) var loadReport: FinancialStore.LoadReport?
    private(set) var backupOutcome: PreNativeMigrationBackup.Outcome?
    /// A quick action, widget or deep link waiting to open the add form.
    /// Views take it with `takePendingAdd()` once routes may open.
    var pendingAdd: AddRoute?
    /// Whether this session has passed App Lock. Starts false: a launch
    /// with the lock on is locked until the owner authenticates.
    private(set) var sessionUnlocked = false
    /// The message shown by the root toast host.
    private(set) var toast: Toast?
    /// The onboarding tour is showing (set by the onboarding flow).
    private(set) var showsOnboarding = false
    private(set) var themeMode: ThemeMode = .system
    private(set) var hasUnsavedChanges = false
    private(set) var lastSaveError: String?
    /// Everything derived from the ledger, rebuilt off the main thread once
    /// per change of the transactions. Views read this, never re-scan rows.
    private(set) var ledger = LedgerIndex.empty(calendar: DartCalendar(timeZone: .autoupdatingCurrent))
    /// Bumped whenever `ledger` is replaced; views observe this.
    private(set) var ledgerRevision = 0
    private var ledgerTask: Task<Void, Never>?
    /// The month Home, Flow and Insights show (Flutter
    /// `TransactionModel.selectedMonth`): shared, starts at the current
    /// month, not persisted.
    private(set) var selectedMonth: DartDateTime = {
        let calendar = DartCalendar(timeZone: .autoupdatingCurrent)
        return calendar.month(of: calendar.now())
    }()

    let calendar = DartCalendar(timeZone: .autoupdatingCurrent)
    private let protectedData: ProtectedDataMonitor
    private let preferences: UserDefaultsPreferences
    private let store: FinancialStore
    private let tracker: PersistenceTracker
    private let storeDirectory: URL
    private let applicationSupport: URL

    init() {
        protectedData = ProtectedDataMonitor()
        preferences = UserDefaultsPreferences(domainName: AppIdentifiers.bundleID)
        applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storeDirectory = applicationSupport.appendingPathComponent(StoreFile.directoryName, isDirectory: true)
        let calendar = self.calendar
        store = FinancialStore(
            fileSystem: DirectoryFileSystem(directory: storeDirectory), preferences: preferences,
            protectedData: protectedData, clock: { DartDateTime.now(timeZone: calendar.timeZone) })
        tracker = PersistenceTracker(store: store)
    }

    var now: DartDateTime { calendar.now() }

    /// Dart `selectMonth`: normalised to `DateTime(year, month)`.
    func selectMonth(_ month: DartDateTime) {
        selectedMonth = calendar.month(of: month)
    }

    private func newID() -> String { UUID().uuidString.lowercased() }

    // MARK: - Bootstrap

    private var isStarting = false

    func start() async {
        guard !isStarting, phase != .ready else { return }
        isStarting = true
        defer { isStarting = false }
        await bootstrap()
    }

    private func bootstrap() async {
        if !protectedData.isProtectedDataAvailable {
            phase = .waitingForUnlock
            await protectedData.waitUntilAvailable()
        }
        phase = .starting

        // Preferences are only trustworthy once protected data is available.
        #if DEBUG
        // UI tests and scripted runs start past the onboarding tour.
        if ProcessInfo.processInfo.environment["BUDGIE_SKIP_ONBOARDING"] == "1" {
            preferences.set(.bool(true), forKey: PreferenceKey.onboardingCompleted)
        }
        #endif
        themeMode = ThemeMode(rawValue: preferences.string(PreferenceKey.themeMode) ?? "") ?? .system

        // Rule 1: copy everything before the first read or write.
        do {
            let backup = PreNativeMigrationBackup(
                applicationSupport: applicationSupport,
                sources: .init(
                    storeDirectory: storeDirectory,
                    exportPreferences: { [preferences] in try preferences.exportDomain() },
                    exportAppGroupPreferences: {
                        let domain = UserDefaults(suiteName: AppIdentifiers.appGroup)?
                            .persistentDomain(forName: AppIdentifiers.appGroup) ?? [:]
                        return try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
                    }),
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
            backupOutcome = try backup.ensure(lastCommittedChecksum: preferences.string(PreferenceKey.lastCommittedChecksum))
        } catch {
            phase = .blocked(.backupFailed(String(describing: error)))
            return
        }

        let snapshot: FinancialSnapshot
        do {
            snapshot = try await store.read()
        } catch .dataUnreadable(let files) {
            phase = .blocked(.dataUnreadable(files))
            return
        } catch .protectedDataUnavailable {
            // The device locked between the check and the read: wait again.
            phase = .waitingForUnlock
            await protectedData.waitUntilAvailable()
            phase = .starting
            await bootstrap()
            return
        } catch {
            phase = .blocked(.readFailed(String(describing: error)))
            return
        }
        loadReport = await store.lastLoadReport

        var loaded = FinancialData.load(
            snapshot, preferences: preferences, calendar: calendar, now: { [calendar] in calendar.now() }, newID: newID)
        data = loaded.data
        netWorthRevision &+= 1
        if !loaded.pendingWrites.isEmpty {
            await persist(loaded.pendingWrites.map(\.0))
        }

        // Launch-time generation (Dart `_initializeApp`), rows and cursors in
        // one commit (approved Q2).
        let launchTime = now
        let result = RecurringGenerator.generateDue(in: &loaded.data, now: launchTime, clock: { [calendar] in calendar.now() }, newID: newID)
        if result.changed {
            data = loaded.data
            await persist([Section.transactions, Section.recurringTransactions])
        } else {
            syncWidget()
        }
        // The first index is awaited so the first frame already has totals.
        let transactions = loaded.data.transactions
        ledger = await Task.detached(priority: .userInitiated) { [calendar] in
            LedgerIndex.build(transactions, calendar: calendar)
        }.value
        ledgerRevision &+= 1
        phase = .ready
        #if DEBUG
        await RehearsalSummary.performScriptedEditsIfRequested(self)
        RehearsalSummary.writeIfRequested(self)
        #endif
    }

    /// Retry after a blocked start (backup or read failure).
    func retryStart() async {
        guard case .blocked = phase else { return }
        phase = .starting
        await start()
    }

    /// The user chose to start with an empty store after `dataUnreadable`.
    /// The set-aside files stay on disk.
    func startFresh(acknowledging files: [String]) async {
        do {
            try await store.acknowledgeUnreadableData(files)
        } catch {
            return
        }
        phase = .starting
        await start()
    }

    // MARK: - Persistence

    /// The current in-memory value of a section. Every section in
    /// `Section.all` has a typed serializer; any other name is a programming
    /// error. In release it writes the section as loaded rather than null.
    private func serialize(_ section: String) -> JSONValue {
        guard let data else { return .null }
        guard let value = data.serializedSection(section) else {
            assertionFailure("no serializer for section \(section)")
            return data.sections[section] ?? .null
        }
        return value
    }

    /// Writes the named sections (plus anything still unsaved) and waits for
    /// the verified result. The change is already visible in memory.
    @discardableResult
    private func persist(_ sections: [String]) async -> Bool {
        let payload = sections.map { ($0, serialize($0)) }
        let saved = await tracker.persist(payload, serialize: serialize)
        hasUnsavedChanges = tracker.hasUnsavedChanges
        lastSaveError = tracker.lastError.map { String(describing: $0) }
        if saved && sections.contains(Section.transactions) { syncWidget() }
        return saved
    }

    func retrySaves() async {
        _ = await tracker.retry(serialize: serialize)
        hasUnsavedChanges = tracker.hasUnsavedChanges
        lastSaveError = tracker.lastError.map { String(describing: $0) }
        if !hasUnsavedChanges { syncWidget() }
    }

    /// Rebuilds `ledger` off the main thread after the transactions changed
    /// in memory. A newer change supersedes a build still in flight.
    private func transactionsChanged() {
        guard let transactions = data?.transactions else { return }
        let calendar = self.calendar
        ledgerTask?.cancel()
        ledgerTask = Task {
            let index = await Task.detached(priority: .userInitiated) { LedgerIndex.build(transactions, calendar: calendar) }.value
            guard !Task.isCancelled else { return }
            ledger = index
            ledgerRevision &+= 1
        }
    }

    // MARK: - Widget

    /// `_syncWidgetCashFlow`: current month's cash flow into the App Group.
    private func syncWidget() {
        guard let data, protectedData.isProtectedDataAvailable else { return }
        let value = data.widgetCashFlow(now: now)
        let defaults = UserDefaults(suiteName: AppIdentifiers.appGroup)
        defaults?.set(value.amount, forKey: "cashFlow")
        defaults?.set(value.month, forKey: "cashFlowMonth")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Transactions

    @discardableResult
    func addTransaction(
        type: TransactionType, description: String, amount: Double, category: String, date: DartDateTime, tagIds: [String] = []
    ) async -> Bool {
        guard data != nil, amount.isFinite else { return false }
        _ = data!.addTransaction(
            type: type, description: description, amount: amount, category: category, date: date, tagIds: tagIds, id: newID(),
            now: now)
        transactionsChanged()
        return await persist([Section.transactions])
    }

    /// Whether a readable transaction with this id is in memory (a false
    /// update/delete for a missing row is not a save failure).
    func hasTransaction(id: String) -> Bool {
        data?.transactionRows.contains { $0.record?.id == id } ?? false
    }

    @discardableResult
    func updateTransaction(id: String, _ edit: TransactionRecord.Edit) async -> Bool {
        guard data != nil, edit.amount.isFinite, data!.updateTransaction(id: id, edit, now: now) else { return false }
        transactionsChanged()
        return await persist([Section.transactions])
    }

    @discardableResult
    func deleteTransaction(id: String) async -> Bool {
        guard data != nil, data!.deleteTransaction(id: id) else { return false }
        transactionsChanged()
        return await persist([Section.transactions])
    }

    // MARK: - Recurring

    /// Dart generates due occurrences right after a template is added.
    @discardableResult
    func addTemplate(_ edit: RecurringTemplate.Edit) async -> Bool {
        guard data != nil, edit.amount.isFinite else { return false }
        data!.addTemplate(.make(
            id: newID(), type: edit.type, description: edit.description, amount: edit.amount, category: edit.category,
            pattern: edit.pattern, startDate: edit.startDate, dayOfMonth: edit.dayOfMonth, dayOfWeek: edit.dayOfWeek))
        if RecurringGenerator.generateDue(in: &data!, now: now, clock: { [calendar] in calendar.now() }, newID: newID).changed {
            transactionsChanged()
        }
        return await persist([Section.recurringTransactions, Section.transactions])
    }

    @discardableResult
    func updateTemplate(id: String, _ edit: RecurringTemplate.Edit) async -> Bool {
        guard data != nil, edit.amount.isFinite, data!.updateTemplate(id: id, edit) else { return false }
        return await persist([Section.recurringTransactions])
    }

    @discardableResult
    func setTemplateActive(id: String, _ active: Bool) async -> Bool {
        guard data != nil, data!.setTemplateActive(id: id, active) else { return false }
        return await persist([Section.recurringTransactions])
    }

    @discardableResult
    func deleteTemplate(id: String) async -> Bool {
        guard data != nil, data!.deleteTemplate(id: id) else { return false }
        return await persist([Section.recurringTransactions])
    }

    // MARK: - Budgets

    /// Dart `getCategoryBudgetLimit`: exact name, nil when there is none.
    func budgetLimit(for category: String) -> Double? {
        data?.budgetLimit(for: category)
    }

    /// Dart `setCategoryBudgetLimit` (trimmed; `limit <= 0` removes).
    @discardableResult
    func setBudgetLimit(category: String, limit: Double) async -> Bool {
        guard data != nil, data!.setBudgetLimit(category: category, limit: limit) else { return false }
        return await persist([Section.categoryBudgetLimits])
    }

    /// Dart `removeCategoryBudgetLimit`.
    @discardableResult
    func removeBudgetLimit(category: String) async -> Bool {
        guard data != nil, data!.removeBudgetLimit(category: category) else { return false }
        return await persist([Section.categoryBudgetLimits])
    }

    /// Home's budget rows and the Edit/Add picker lists for `month`, in
    /// one pass over the categories and the ledger month summary.
    func budgetOverview(forMonth month: DartDateTime) -> FinancialData.BudgetOverview {
        data?.budgetOverview(ledger.summary(forMonth: month)) ?? .empty
    }

    // MARK: - Net worth

    /// The month the Worth tab shows (Flutter `selectedNetWorthMonth`):
    /// persisted, loaded as stored even when stale or in the future.
    var selectedNetWorthMonth: DartDateTime { data?.selectedNetWorthMonth ?? calendar.month(of: now) }

    /// Bumped by every change to the accounts or the selected Worth month
    /// (and by the load); keys `worthCache`.
    private(set) var netWorthRevision = 0
    /// The Worth tab's derived values, computed once per revision instead
    /// of on every render (the history walks every snapshot).
    @ObservationIgnored private var worthCache = WorthCache()

    private struct WorthCache {
        var revision = -1
        var history: [NetWorthHistoryPoint]?
        var months: (current: DartDateTime, value: [DartDateTime])?
        var changes: [DartDateTime: Double?] = [:]
    }

    /// The cache for the current revision (emptied when it moved on).
    /// Reading `netWorthRevision` here makes views observe it.
    private func currentWorthCache() -> WorthCache {
        if worthCache.revision != netWorthRevision { worthCache = WorthCache(revision: netWorthRevision) }
        return worthCache
    }

    /// The Worth month strip (`getNetWorthAvailableMonths`), newest first.
    var netWorthAvailableMonths: [DartDateTime] {
        guard let data else { return [] }
        let current = calendar.month(of: now)
        if let months = currentWorthCache().months, months.current == current { return months.value }
        let value = data.netWorthAvailableMonths(now: now)
        worthCache.months = (current, value)
        return value
    }

    /// The growth chart's points (`getNetWorthHistory(limit: 24)`), newest
    /// first.
    var netWorthHistory: [NetWorthHistoryPoint] {
        guard let data else { return [] }
        if let history = currentWorthCache().history { return history }
        let history = data.netWorthHistory(limit: 24)
        worthCache.history = history
        return history
    }

    /// `getNetWorthChange(month)`: nil without a change to show.
    func netWorthChange(forMonth month: DartDateTime) -> Double? {
        guard let data else { return nil }
        if let change = currentWorthCache().changes[month] { return change }
        let change = data.netWorthChange(forMonth: month)
        worthCache.changes[month] = .some(change)
        return change
    }

    /// Whether any readable account exists (the Worth empty state).
    var hasNetWorthEntries: Bool { data?.hasNetWorthEntries ?? false }

    /// The account with this id (the history page follows it live).
    func netWorthEntry(id: String) -> NetWorthEntryRecord? {
        data?.netWorthEntry(id: id)
    }

    /// `getNetWorthEntryHistory`: ascending; empty for an unknown id.
    func netWorthEntryHistory(id: String) -> [NetWorthSnapshotRecord] {
        data?.netWorthEntryHistory(id: id) ?? []
    }

    /// Dart `selectNetWorthMonth`: normalised to the month, then written,
    /// even when it is already selected (as Flutter).
    @discardableResult
    func selectNetWorthMonth(_ month: DartDateTime) async -> Bool {
        guard data != nil else { return false }
        data!.selectNetWorthMonth(month)
        netWorthRevision &+= 1
        return await persist([Section.selectedNetWorthMonth])
    }

    /// Dart `addNetWorthEntry`: the snapshot lands on `recordedAt`, else
    /// `now` for the current month or the month's end-of-month sentinel.
    /// False without a write for an empty name or a non-finite amount.
    @discardableResult
    func addNetWorthEntry(
        name: String, type: NetWorthEntryType, amount: Double, month: DartDateTime? = nil, recordedAt: DartDateTime? = nil
    ) async -> Bool {
        guard data != nil, amount.isFinite,
            data!.addNetWorthEntry(name: name, type: type, amount: amount, month: month, recordedAt: recordedAt, id: newID(), now: now)
                != nil
        else { return false }
        netWorthRevision &+= 1
        return await persist([Section.netWorthEntries])
    }

    /// Dart `updateNetWorthEntry` (also "update balance" for a month): name
    /// and type, plus one added or replaced snapshot.
    @discardableResult
    func updateNetWorthEntry(
        id: String, name: String, type: NetWorthEntryType, amount: Double, month: DartDateTime? = nil,
        recordedAt: DartDateTime? = nil
    ) async -> Bool {
        guard data != nil, amount.isFinite,
            data!.updateNetWorthEntry(id: id, name: name, type: type, amount: amount, month: month, recordedAt: recordedAt, now: now)
        else { return false }
        netWorthRevision &+= 1
        return await persist([Section.netWorthEntries])
    }

    /// Dart `deleteNetWorthEntry`: the account and all its snapshots.
    @discardableResult
    func deleteNetWorthEntry(id: String) async -> Bool {
        guard data != nil, data!.deleteNetWorthEntry(id: id) else { return false }
        netWorthRevision &+= 1
        return await persist([Section.netWorthEntries])
    }

    /// Dart `deleteNetWorthSnapshot`: the snapshot recorded at exactly
    /// `recordedAt`; false without a write when there is none.
    @discardableResult
    func deleteNetWorthSnapshot(entryID: String, recordedAt: DartDateTime) async -> Bool {
        guard data != nil, data!.deleteNetWorthSnapshot(entryID: entryID, recordedAt: recordedAt) else { return false }
        netWorthRevision &+= 1
        return await persist([Section.netWorthEntries])
    }

    /// Dart `carryNetWorthMonthForward` (Flutter has no UI for it): false
    /// without a write when no account needed a carried value.
    @discardableResult
    func carryNetWorthMonthForward(_ month: DartDateTime) async -> Bool {
        guard data != nil, data!.carryNetWorthMonthForward(month, now: now) else { return false }
        netWorthRevision &+= 1
        return await persist([Section.netWorthEntries])
    }

    // MARK: - Savings goals

    /// Dart's process-wide `SavingsGoal._idCounter`: advanced only by a
    /// goal that is actually added.
    private var savingsGoalIDCounter = 0

    /// The Goals tab's list (`_sortedGoals`): incomplete first, then target
    /// date ascending, stable.
    var savingsGoals: [SavingsGoalRecord] { SavingsGoalRecord.sorted(data?.savingsGoals ?? []) }

    /// The summary card's totals and ring.
    var savingsGoalsSummary: SavingsGoalsSummary { SavingsGoalsSummary(goals: data?.savingsGoals ?? []) }

    /// What a goal mutation did: written and verified, changed in memory
    /// but not written (the unsaved banner and Retry take over), or refused
    /// with nothing changed or written (so no save-failed toast).
    enum SaveOutcome: Equatable {
        case saved, failed, rejected
    }

    private func persistGoals() async -> SaveOutcome {
        await persist([Section.savingsGoals]) ? .saved : .failed
    }

    /// Dart `addSavingsGoal`: the trimmed name, the target date's local
    /// midnight, a Flutter-format id. Rejected (no write) for a blank name
    /// or a target that is not a positive finite number.
    @discardableResult
    func addSavingsGoal(name: String, targetAmount: Double, targetDate: DartDateTime) async -> SaveOutcome {
        let now = self.now
        guard data != nil, targetAmount.isFinite,
            data!.addSavingsGoal(
                name: name, targetAmount: targetAmount, targetDate: targetDate,
                id: SavingsGoalRecord.makeID(now: now, counter: savingsGoalIDCounter), now: now) != nil
        else { return .rejected }
        savingsGoalIDCounter += 1
        return await persistGoals()
    }

    /// Dart `updateSavingsGoal` (the edit form): name, target, saved amount
    /// and target date (not normalised); `completedAt` follows the amount.
    @discardableResult
    func updateSavingsGoal(id: String, _ edit: SavingsGoalRecord.Edit) async -> SaveOutcome {
        guard data != nil, edit.targetAmount.isFinite, edit.currentAmount.isFinite,
            data!.updateSavingsGoal(id: id, edit, now: now)
        else { return .rejected }
        return await persistGoals()
    }

    /// Dart `deleteSavingsGoal`: every goal with this id.
    @discardableResult
    func deleteSavingsGoal(id: String) async -> SaveOutcome {
        guard data != nil, data!.deleteSavingsGoal(id: id) else { return .rejected }
        return await persistGoals()
    }

    /// Dart `allocateToSavingsGoal` (Add money): no transaction is created.
    /// Whether it completes the goal is `willComplete(allocating:)` on the
    /// goal as shown before the dialog, as in Flutter.
    @discardableResult
    func allocateToSavingsGoal(id: String, amount: Double) async -> SaveOutcome {
        guard data != nil, amount.isFinite, data!.allocateToSavingsGoal(id: id, amount: amount, now: now) else {
            return .rejected
        }
        return await persistGoals()
    }

    // MARK: - Settings (store section + mirrored preference, like Dart)

    private static let settingsLog = Logger(subsystem: AppIdentifiers.bundleID, category: "settings")

    /// Dart `setBaseCurrencyCode`: trimmed and uppercased; a code that is
    /// not 3 characters long, or the current one, writes nothing. Amounts
    /// are not converted.
    @discardableResult
    func setBaseCurrency(_ code: String) async -> Bool {
        await updateSettings("baseCurrencyCode") { $0.setBaseCurrencyCode(code) }
    }

    /// Dart `setLocaleOverride`: nil or blank is "Match device" (the mirror
    /// is removed). Written even when unchanged, as Dart does.
    @discardableResult
    func setLocaleOverride(_ locale: String?) async -> Bool {
        await updateSettings("localeOverride") { $0.setLocaleOverride(locale) }
    }

    /// Dart `setAppLockEnabled`.
    @discardableResult
    func setAppLockEnabled(_ enabled: Bool) async -> Bool {
        await updateSettings("appLockEnabled") { $0.setAppLockEnabled(enabled) }
    }

    /// Dart `setAutoLockTimeoutSeconds`: a negative value writes nothing.
    @discardableResult
    func setAutoLockTimeoutSeconds(_ seconds: Int) async -> Bool {
        await updateSettings("autoLockTimeoutSeconds") { $0.setAutoLockTimeoutSeconds(seconds) }
    }

    /// Dart `setHideBalances`: `moneyFormatter` masks every amount at once.
    @discardableResult
    func setHideBalances(_ hidden: Bool) async -> Bool {
        await updateSettings("hideBalances") { $0.setHideBalances(hidden) }
    }

    /// One `AppSettingsProvider` setter: memory, the preference mirror, then
    /// the whole `appSettings` section, awaited. True when the write verified
    /// or the value was already current; false for a rejected value or a
    /// failed write, which stays in memory behind the unsaved banner (Flutter
    /// has no failure handling: its change reverts on relaunch).
    private func updateSettings(_ field: String, _ change: (inout AppSettings) -> SettingsUpdate) async -> Bool {
        guard data != nil else { return false }
        switch change(&data!.appSettings) {
        case .rejected:
            return false
        case .unchanged:
            return true
        case .write(let key, let value):
            preferences.set(value, forKey: key)
            let saved = await persist([Section.appSettings])
            if !saved { Self.settingsLog.error("appSettings.\(field, privacy: .public) not saved; kept in memory") }
            return saved
        }
    }

    /// Dart `ThemeProvider.setThemeMode`: the preference only, no store
    /// section; the current mode writes nothing.
    func setThemeMode(_ mode: ThemeMode) {
        guard mode != themeMode else { return }
        themeMode = mode
        preferences.set(.string(mode.rawValue), forKey: PreferenceKey.themeMode)
    }

    func categories(for type: TransactionType) -> [CategoryInfo] {
        data?.categoryPicker(for: type) ?? CategoryCatalog.pickerList(CategoryCatalog.builtIn, type: type, usedNames: [])
    }

    /// Transaction tags (`transactionTags`), read-only until tag management.
    var tags: [TransactionTagRecord] { data?.tags ?? [] }

    /// The form's auto-categorisation (`applySuggestion`,
    /// transaction_form.dart:106-121): the amount text parses with Dart's
    /// `double.tryParse(text) ?? 0`. The caller applies the rule only if its
    /// category is in the current picker list.
    func suggestion(type: TransactionType, description: String, amountText: String) -> CategorizationRuleRecord? {
        guard let data else { return nil }
        return CategorizationEngine.suggest(
            rules: data.rules, type: type, description: description, amount: DartDouble.tryParse(amountText) ?? 0)
    }

    func categoryInfo(named name: String, type: TransactionType) -> CategoryInfo? {
        data?.categoryInfo(named: name, type: type)
    }

    var moneyFormatter: MoneyFormatter {
        let settings = data?.appSettings
        return MoneyFormatter(
            currencyCode: settings?.baseCurrencyCode ?? "USD", locale: settings?.localeOverride,
            hideBalances: settings?.hideBalances ?? false)
    }

    // MARK: - CSV export

    /// Writes the export to a temporary file for the share sheet.
    func exportCSV() throws -> URL {
        let rows = (data?.transactions ?? []).map {
            CSVExport.Row(date: $0.date, isIncome: $0.type == .income, category: $0.category, description: $0.description, amount: $0.amount)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(CSVExport.fileName(now: now))
        try Data(CSVExport.export(rows)).write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Toasts

    func showToast(_ toast: Toast) { self.toast = toast }

    /// Dismisses `id` if it is still the one showing.
    func dismissToast(_ id: UUID) {
        if toast?.id == id { toast = nil }
    }

    // MARK: - Routing

    /// App Lock is on and this session has not authenticated.
    var isLocked: Bool { data?.appSettings.appLockEnabled == true && !sessionUnlocked }

    func markUnlocked() { sessionUnlocked = true }

    /// After the lock timeout in the background.
    func relock() { sessionUnlocked = false }

    /// Routes open only over unlocked, onboarded data: a quick action or
    /// deep link on a locked launch waits for the unlock (it used to open
    /// the form above the lock screen).
    var canOpenRoutes: Bool { phase == .ready && !isLocked && !showsOnboarding }

    /// The pending add route, cleared, when it may open now; otherwise nil
    /// and the route stays queued.
    func takePendingAdd() -> AddRoute? {
        guard canOpenRoutes, let route = pendingAdd else { return nil }
        pendingAdd = nil
        return route
    }

    func open(_ url: URL) {
        let action = url.host?.isEmpty == false ? url.host! : (url.pathComponents.dropFirst().first ?? "")
        switch action {
        case "add-income", "add_income": pendingAdd = .income
        // Voice entry is not in the MVP; its widget and quick action open
        // the expense form so already-placed widgets keep working.
        case "add-expense", "add_expense", "voice-add", "voice_add": pendingAdd = .expense
        default: break
        }
    }

    func handleShortcut(_ type: String) {
        switch type {
        case "action_add_income": pendingAdd = .income
        case "action_add_expense", "action_voice_add": pendingAdd = .expense
        default: break
        }
    }

    static func registerShortcuts() {
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "action_add_expense", localizedTitle: "Add Expense", localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "minus.circle.fill")),
            UIApplicationShortcutItem(
                type: "action_add_income", localizedTitle: "Add Income", localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")),
        ]
    }
}
