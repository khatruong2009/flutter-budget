import BudgieCore
import Foundation
import Observation
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

    /// Home's budget rows for `month`, from the ledger index.
    func budgetProgress(forMonth month: DartDateTime) -> [BudgetProgress] {
        data?.budgetProgress(ledger.summary(forMonth: month)) ?? []
    }

    /// Budgeted expense categories in category order (EDIT sheet).
    func budgetedCategories() -> [CategoryInfo] {
        data?.budgetedCategories() ?? []
    }

    /// Expense categories without a limit, in category order (Add sheet).
    func unbudgetedCategories() -> [CategoryInfo] {
        data?.unbudgetedCategories() ?? []
    }

    // MARK: - Settings (store section + mirrored preference, like Dart)

    func setBaseCurrency(_ code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count == 3, data != nil else { return }
        preferences.set(.string(normalized), forKey: PreferenceKey.baseCurrencyCode)
        data!.appSettings.baseCurrencyCode = normalized
        await persist([Section.appSettings])
    }

    func setAppLockEnabled(_ enabled: Bool) async {
        guard data != nil else { return }
        preferences.set(.bool(enabled), forKey: PreferenceKey.appLockEnabled)
        data!.appSettings.appLockEnabled = enabled
        await persist([Section.appSettings])
    }

    func setThemeMode(_ mode: ThemeMode) {
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
