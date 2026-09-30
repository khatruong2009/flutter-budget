import BudgieCore
import XCTest

@testable import Runner

/// A full `AppModel` bootstrap against a scratch Application Support
/// directory and a scratch preferences suite (never the host app's data).
@MainActor
private final class Scratch {
    let directory: URL
    let suite: String
    let defaults: UserDefaults
    let preferences: UserDefaultsPreferences

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("budgie-data-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "budgie.tests.data.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = UserDefaultsPreferences(defaults: defaults, domainName: suite)
        OnboardingFlag.markCompleted(preferences)
    }

    /// A started model.
    func start() async -> AppModel {
        let model = AppModel(applicationSupport: directory, preferences: preferences)
        await model.start()
        return model
    }

    var storeDirectory: URL { directory.appendingPathComponent(StoreFile.directoryName, isDirectory: true) }
    var preRestore: URL { directory.appendingPathComponent(PreRestoreBackup.folderName, isDirectory: true) }

    /// What is on disk now, read by a fresh store.
    func stored() async throws -> FinancialSnapshot {
        try await FinancialStore(
            fileSystem: DirectoryFileSystem(directory: storeDirectory), preferences: preferences, protectedData: AlwaysAvailable()
        ).read()
    }

    func completeSafetyCopies() throws -> [URL] {
        try PreRestoreBackup(
            applicationSupport: directory, store: DirectoryFileSystem(directory: storeDirectory),
            exportPreferences: { Data() }, appVersion: "test", clock: { DartDateTime.now(timeZone: .current) }
        ).completeSnapshots()
    }

    /// The store directory refuses writes until the returned closure runs.
    func lockStoreDirectory() throws -> () -> Void {
        let path = storeDirectory.path
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: path)
        return { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path) }
    }

    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: storeDirectory.path)
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
final class BackupModelTests: XCTestCase {
    private var scratch: Scratch!

    override func setUp() async throws {
        scratch = try Scratch()
    }

    override func tearDown() async throws {
        scratch.remove()
    }

    private var today: DartDateTime { DartCalendar(timeZone: .autoupdatingCurrent).now() }

    /// A current store the restores below replace: a transaction, a custom
    /// category and tag, EUR and hide balances.
    private func seededModel() async throws -> AppModel {
        let model = await scratch.start()
        XCTAssertEqual(model.phase, .ready)
        let added = await model.addTransaction(type: .expense, description: "Old lunch", amount: 9.5, category: "Food", date: today)
        XCTAssertTrue(added)
        let category = await model.addCategory(type: .expense, name: "Hobbies", iconIdentifier: "cart", colorToken: "green")
        XCTAssertEqual(category, .saved)
        let tag = await model.addTag(name: "Work")
        XCTAssertEqual(tag, .saved)
        let currency = await model.setBaseCurrency("EUR")
        XCTAssertTrue(currency)
        let hidden = await model.setHideBalances(true)
        XCTAssertTrue(hidden)
        return model
    }

    private static let schema3 = """
        {
          "schemaVersion": 3,
          "app": "budgie",
          "appVersion": "3.4.0",
          "exportedAt": "2026-09-01T09:00:00.000",
          "data": {
            "transactions": [
              {"id": "b1", "type": "income", "description": "Backup pay", "amount": 2500.0, "category": "Salary",
               "date": "2026-08-01T10:00:00.000", "recurringTemplateId": null, "tagIds": ["bt"],
               "createdAt": "2026-08-01T10:00:00.000", "updatedAt": "2026-08-01T10:00:00.000"},
              {"id": "b2", "type": "expense", "description": "Backup rent", "amount": 1200.0, "category": "Housing",
               "date": "2026-08-02T10:00:00.000", "recurringTemplateId": null, "tagIds": [],
               "createdAt": "2026-08-02T10:00:00.000", "updatedAt": "2026-08-02T10:00:00.000"}
            ],
            "netWorthEntries": [],
            "categoryBudgetLimits": {"Housing": 1500.0, "Dropped": 0},
            "savingsGoals": [],
            "recurringTransactions": [],
            "themeMode": "dark",
            "categories": [
              {"id": "expense-housing", "type": "expense", "name": "Housing", "iconIdentifier": "house", "colorToken": "blue",
               "sortOrder": 0, "isArchived": false, "isBuiltIn": true},
              {"id": "income-salary", "type": "income", "name": "Salary", "iconIdentifier": "briefcase", "colorToken": "green",
               "sortOrder": 0, "isArchived": false, "isBuiltIn": true}
            ],
            "transactionTags": [{"id": "bt", "name": "Backup tag", "colorToken": "accent"}],
            "categorizationRules": [],
            "baseCurrencyCode": "gbp",
            "localeOverride": null,
            "appLockEnabled": false,
            "autoLockTimeoutSeconds": 30,
            "hideBalances": false
          }
        }
        """

    /// Schema 1 (July 2026): only the first six `data` keys.
    private static let schema1 = """
        {"schemaVersion": 1, "app": "budgie", "appVersion": "2.0.0", "exportedAt": "2026-07-20T09:00:00.000",
         "data": {
           "transactions": [
             {"id": "v1", "type": "expense", "description": "Schema one", "amount": 5.0, "category": "Food",
              "date": "2026-07-19T10:00:00.000", "recurringTemplateId": null, "tagIds": [],
              "createdAt": "2026-07-19T10:00:00.000", "updatedAt": "2026-07-19T10:00:00.000"}
           ],
           "netWorthEntries": [], "categoryBudgetLimits": {}, "savingsGoals": [], "recurringTransactions": [],
           "themeMode": "light"}}
        """

    /// Export: the file is named for the clock, holds the envelope, and a
    /// decode of it gives back what was exported.
    func testExportDecodesBack() async throws {
        let model = try await seededModel()
        let url = try await model.exportBackup()
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("budgie_backup_"))
        XCTAssertEqual(url.pathExtension, "json")
        let bytes = [UInt8](try Data(contentsOf: url))
        XCTAssertTrue(String(decoding: bytes.prefix(60), as: UTF8.self).hasPrefix("{\n  \"schemaVersion\": 3,\n  \"app\": \"budgie\""))

        let plan = try await model.decodeBackup(bytes)
        XCTAssertEqual(plan.counts.transactions, 1)
        XCTAssertEqual(plan.transactions?.first?.description, "Old lunch")
        XCTAssertEqual(plan.baseCurrencyCode, "EUR")
        XCTAssertEqual(plan.hideBalances, true)
        XCTAssertEqual(plan.themeMode, "system")
        XCTAssertTrue(plan.categories?.contains { $0.name == "Hobbies" } ?? false)
        XCTAssertEqual(plan.tags?.map(\.name), ["Work"])
        XCTAssertTrue(plan.keptItems.isEmpty)
        XCTAssertEqual(plan.confirmationMessage, plan.flutterConfirmationMessage)

        // Restoring its own export changes nothing the user sees.
        let before = model.data?.transactions.map(\.id)
        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .restored(generated: 0))
        XCTAssertEqual(model.data?.transactions.map(\.id), before)
        XCTAssertEqual(model.data?.appSettings.baseCurrencyCode, "EUR")
    }

    /// A schema-3 file replaces everything: memory, the one commit on disk,
    /// the five preference mirrors and the theme; budgets <= 0 are dropped;
    /// the safety copy holds the store as it was.
    func testRestoreSchema3ReplacesEverything() async throws {
        let model = try await seededModel()
        let before = try await scratch.stored()
        let plan = try await model.decodeBackup(Array(Self.schema3.utf8))
        XCTAssertEqual(
            plan.confirmationMessage,
            "This will import 2 transactions, 0 net worth entries, 2 budgets, 0 goals and 0 recurring templates, "
                + "replacing everything currently in Budgie. This cannot be undone.")

        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .restored(generated: 0))
        XCTAssertEqual(outcome.toast.message, "Backup restored")
        XCTAssertEqual(outcome.toast.style, .success)
        XCTAssertFalse(model.isRestoring)
        XCTAssertFalse(model.hasUnsavedChanges)

        let data = try XCTUnwrap(model.data)
        XCTAssertEqual(data.transactions.map(\.description), ["Backup pay", "Backup rent"])
        XCTAssertEqual(data.categories.map(\.name), ["Housing", "Salary"])
        XCTAssertEqual(data.tags.map(\.name), ["Backup tag"])
        XCTAssertEqual(data.budgetLimits.map(\.0), ["Housing"])
        XCTAssertEqual(data.budgetLimits.map(\.1), [1500])
        XCTAssertEqual(data.appSettings.baseCurrencyCode, "GBP")
        XCTAssertEqual(data.appSettings.autoLockTimeoutSeconds, 30)
        XCTAssertFalse(data.appSettings.hideBalances)
        XCTAssertEqual(model.themeMode, .dark)

        let prefs = scratch.preferences
        XCTAssertEqual(prefs.value(forKey: PreferenceKey.baseCurrencyCode), .string("GBP"))
        XCTAssertNil(prefs.value(forKey: PreferenceKey.localeOverride))
        XCTAssertEqual(prefs.value(forKey: PreferenceKey.appLockEnabled), .bool(false))
        XCTAssertEqual(prefs.value(forKey: PreferenceKey.autoLockTimeoutSeconds), .int(30))
        XCTAssertEqual(prefs.value(forKey: PreferenceKey.hideBalances), .bool(false))
        XCTAssertEqual(prefs.value(forKey: PreferenceKey.themeMode), .string("dark"))

        let disk = try await scratch.stored()
        XCTAssertEqual(disk.revision, before.revision + 1, "one commit")
        XCTAssertEqual(disk.sections[Section.transactions]?.arrayValue?.count, 2)
        XCTAssertEqual(disk.sections[Section.appSettings]?.objectValue?["baseCurrencyCode"]?.stringValue, "GBP")
        for section in Section.all { XCTAssertEqual(disk.sections[section], data.serializedSection(section), section) }

        let copies = try scratch.completeSafetyCopies()
        XCTAssertEqual(copies.count, 1)
        let copiedPrimary = copies[0].appendingPathComponent(StoreFile.directoryName).appendingPathComponent(StoreFile.primaryName)
        let copied = try XCTUnwrap(StoreFile.verify([UInt8](try Data(contentsOf: copiedPrimary))))
        XCTAssertEqual(copied.revision, before.revision, "the copy is the store before the restore")
    }

    /// D10: a schema-1 file replaces its six keys and keeps the categories,
    /// tags, rules and settings (and their preferences) it does not carry.
    func testRestoreSchema1KeepsAbsentSections() async throws {
        let model = try await seededModel()
        let categoriesBefore = model.data?.categories
        let plan = try await model.decodeBackup(Array(Self.schema1.utf8))
        XCTAssertEqual(plan.keptItems, ["categories", "tags", "rules", "settings"])
        XCTAssertTrue(plan.confirmationMessage.hasSuffix(" Your categories, tags, rules and settings are kept."))

        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .restored(generated: 0))
        let data = try XCTUnwrap(model.data)
        XCTAssertEqual(data.transactions.map(\.description), ["Schema one"])
        // Kept, plus the launch pass's definition for the restored rows'
        // "Food" (Flutter adds it at its next launch).
        let before = try XCTUnwrap(categoriesBefore)
        XCTAssertEqual(Array(data.categories.prefix(before.count)), before)
        XCTAssertEqual(data.categories.dropFirst(before.count).map(\.name), ["Food"])
        XCTAssertEqual(data.tags.map(\.name), ["Work"])
        XCTAssertEqual(data.appSettings.baseCurrencyCode, "EUR")
        XCTAssertTrue(data.appSettings.hideBalances)
        XCTAssertEqual(scratch.preferences.value(forKey: PreferenceKey.baseCurrencyCode), .string("EUR"))
        XCTAssertEqual(scratch.preferences.value(forKey: PreferenceKey.hideBalances), .bool(true))
        XCTAssertEqual(model.themeMode, .light)
    }

    /// A file Flutter refuses gives its message and changes nothing.
    func testCorruptFileChangesNothing() async throws {
        let model = try await seededModel()
        let before = try await scratch.stored()
        let dataBefore = model.data?.transactions
        for (text, expected) in [
            ("not json", BackupError.notABackup), (#"{"schemaVersion": 4, "data": {}}"#, .newerVersion),
            (#"{"schemaVersion": 3}"#, .missingData), (#"{"schemaVersion": 3, "data": {"transactions": [{"id": 1}]}}"#, .corrupt),
        ] {
            do {
                _ = try await model.decodeBackup(Array(text.utf8))
                XCTFail("\(text) decoded")
            } catch {
                XCTAssertEqual(error, expected, text)
            }
        }
        XCTAssertEqual(
            BackupEnvelope.importFailedMessage(BackupError.notABackup.message),
            "Could not import backup: This is not a valid Budgie backup file")
        XCTAssertEqual(model.data?.transactions, dataBefore)
        let after = try await scratch.stored()
        XCTAssertEqual(after.revision, before.revision)
        XCTAssertEqual(try scratch.completeSafetyCopies(), [])
    }

    /// Each restore makes a safety copy; only the newest three are kept.
    func testSafetyCopiesArePrunedToThree() async throws {
        let model = await scratch.start()
        let plan = try await model.decodeBackup(Array(Self.schema3.utf8))
        for _ in 0..<4 {
            let outcome = await model.restoreBackup(plan)
            XCTAssertEqual(outcome, .restored(generated: 0))
        }
        XCTAssertEqual(try scratch.completeSafetyCopies().count, 3)
    }

    /// A failed commit leaves memory, preferences, the theme and the unsaved
    /// flags as they were; the message names the failure.
    func testFailedCommitLeavesEverythingUnchanged() async throws {
        let model = try await seededModel()
        let plan = try await model.decodeBackup(Array(Self.schema3.utf8))
        let dataBefore = model.data
        let unlock = try scratch.lockStoreDirectory()
        defer { unlock() }

        let outcome = await model.restoreBackup(plan)
        guard case .failed = outcome else { return XCTFail("\(outcome)") }
        XCTAssertTrue(outcome.toast.message.hasPrefix("Could not import backup: "))
        XCTAssertEqual(outcome.toast.style, .danger)
        XCTAssertEqual(model.data?.transactions, dataBefore?.transactions)
        XCTAssertEqual(model.data?.appSettings, dataBefore?.appSettings)
        XCTAssertFalse(model.hasUnsavedChanges, "nothing is flagged")
        XCTAssertFalse(model.isRestoring)
        XCTAssertEqual(model.themeMode, .system)
        XCTAssertEqual(scratch.preferences.value(forKey: PreferenceKey.baseCurrencyCode), .string("EUR"))
        XCTAssertNil(scratch.preferences.value(forKey: PreferenceKey.themeMode))
        unlock()
        let disk = try await scratch.stored()
        XCTAssertEqual(disk.sections[Section.transactions]?.arrayValue?.count, 1)
    }

    /// No safety copy, no restore.
    func testNoRestoreWithoutASafetyCopy() async throws {
        let model = try await seededModel()
        let before = try await scratch.stored()
        let plan = try await model.decodeBackup(Array(Self.schema3.utf8))
        // A file where the copies' folder should be.
        try Data().write(to: scratch.preRestore)

        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .failed(AppModel.DataTransferError(reason: "A safety copy of your current data could not be made.")))
        XCTAssertEqual(model.data?.transactions.map(\.description), ["Old lunch"])
        let after = try await scratch.stored()
        XCTAssertEqual(after.revision, before.revision)
    }

    /// A restore supersedes changes that were only in memory: their flags
    /// clear and a later retry writes nothing old back.
    func testRestoreClearsUnsavedFlags() async throws {
        let model = try await seededModel()
        let plan = try await model.decodeBackup(Array(Self.schema3.utf8))
        let unlock = try scratch.lockStoreDirectory()
        let added = await model.addTransaction(type: .expense, description: "Unsaved", amount: 1, category: "Food", date: today)
        XCTAssertFalse(added)
        XCTAssertTrue(model.hasUnsavedChanges)
        unlock()

        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .restored(generated: 0))
        XCTAssertFalse(model.hasUnsavedChanges)
        XCTAssertNil(model.lastSaveError)
        let revision = try await scratch.stored().revision
        await model.retrySaves()
        let afterRetry = try await scratch.stored()
        XCTAssertEqual(afterRetry.revision, revision, "nothing left to retry")
        XCTAssertEqual(model.data?.transactions.map(\.description), ["Backup pay", "Backup rent"])
    }

    /// Restore never marks the session unlocked: a file that turns App Lock
    /// on locks at once (Flutter's false -> true).
    func testRestoreTurningLockOnLocks() async throws {
        let model = await scratch.start()
        XCTAssertFalse(model.isLocked)
        let text = Self.schema3.replacingOccurrences(of: #""appLockEnabled": false"#, with: #""appLockEnabled": true"#)
        let plan = try await model.decodeBackup(Array(text.utf8))
        let outcome = await model.restoreBackup(plan)
        XCTAssertEqual(outcome, .restored(generated: 0))
        XCTAssertTrue(model.isLocked)
        XCTAssertFalse(model.canOpenRoutes)
    }
}

@MainActor
final class CSVImportModelTests: XCTestCase {
    private var scratch: Scratch!

    override func setUp() async throws {
        scratch = try Scratch()
    }

    override func tearDown() async throws {
        scratch.remove()
    }

    private static let header = "Date,Type,Category,Description,Amount"

    private func csv(_ rows: String...) -> [UInt8] { Array(([Self.header] + rows).joined(separator: "\r\n").utf8) }

    /// Import: the rows, a new category defined in the same commit, one
    /// write; a second import of the same file finds only duplicates.
    func testImportThenAllDuplicates() async throws {
        let model = await scratch.start()
        let before = try await scratch.stored()
        let file = csv("2026-09-01,Income,Salary,Pay,\"$1,000.00\"", "2026-09-02,Expense,Board games,Dice,12.50")
        let summary = try await model.previewCSVImport(file)
        XCTAssertEqual(summary.drafts.count, 2)
        XCTAssertEqual(summary.confirmTitle, "Import 2 transactions?")
        XCTAssertNil(summary.confirmMessage)
        XCTAssertNil(summary.emptyResultMessage)

        let saved = await model.importCSV(summary)
        XCTAssertTrue(saved)
        XCTAssertEqual(summary.successMessage.text, "Imported 2 transactions")
        XCTAssertEqual(summary.successMessage.tone, .success)
        XCTAssertEqual(model.data?.transactions.map(\.description), ["Pay", "Dice"])
        XCTAssertTrue(model.categories(for: .expense).contains { $0.name == "Board games" })
        let disk = try await scratch.stored()
        XCTAssertEqual(disk.revision, before.revision + 1, "one commit")
        XCTAssertEqual(disk.sections[Section.transactions]?.arrayValue?.count, 2)
        XCTAssertTrue(disk.sections[Section.categories]?.arrayValue?.contains { $0.objectValue?["name"]?.stringValue == "Board games" } ?? false)

        let again = try await model.previewCSVImport(file)
        XCTAssertEqual(again.drafts.count, 0)
        XCTAssertEqual(again.duplicateCount, 2)
        XCTAssertEqual(again.emptyResultMessage?.text, "All transactions in this file already exist")
        XCTAssertEqual(again.emptyResultMessage?.tone, .neutral)
    }

    /// Existing rows cancel matching file rows; the rest import; unreadable
    /// rows are counted.
    func testDuplicatesSkipped() async throws {
        let model = await scratch.start()
        let date = try XCTUnwrap(model.calendar.tryParse("2026-09-03"))
        let added = await model.addTransaction(type: .expense, description: "Coffee", amount: 4, category: "Food", date: date)
        XCTAssertTrue(added)
        let summary = try await model.previewCSVImport(csv(
            "2026-09-03,Expense,Food,Coffee,4.00", "2026-09-03,Expense,Food,Coffee,4.00", "2026-02-30,Expense,Food,Bad,1"))
        XCTAssertEqual(summary.drafts.count, 1)
        XCTAssertEqual(summary.confirmTitle, "Import 1 transaction?")
        XCTAssertEqual(summary.confirmMessage, "1 duplicate will be skipped\n1 row could not be read")
        let saved = await model.importCSV(summary)
        XCTAssertTrue(saved)
        XCTAssertEqual(summary.successMessage.text, "Imported 1 transaction, 1 duplicate skipped")
        XCTAssertEqual(model.data?.transactions.count, 2)
    }

    /// A file without the header is refused with the bare message.
    func testHeaderFailure() async throws {
        let model = await scratch.start()
        do {
            _ = try await model.previewCSVImport(Array("date;type\n1;2".utf8))
            XCTFail("parsed")
        } catch {
            XCTAssertEqual(error, .notATransactionsCSV)
            XCTAssertEqual(CSVImport.failureMessage(error).text, "Could not import: Not a valid transactions CSV export")
            XCTAssertEqual(CSVImport.failureMessage(error).tone, .error)
        }
        XCTAssertEqual(CSVImport.failureMessage(.unreadableFile).text, "Could not import: The file could not be read")
    }

    /// A failed write keeps the rows in memory behind the unsaved banner and
    /// reports false (the caller shows the save-failed toast).
    func testFailedWrite() async throws {
        let model = await scratch.start()
        let summary = try await model.previewCSVImport(csv("2026-09-01,Expense,Food,Lunch,8"))
        let unlock = try scratch.lockStoreDirectory()
        defer { unlock() }
        let saved = await model.importCSV(summary)
        XCTAssertFalse(saved)
        XCTAssertTrue(model.hasUnsavedChanges)
        XCTAssertEqual(model.data?.transactions.map(\.description), ["Lunch"])
    }

    /// Nothing to import writes nothing.
    func testEmptySummaryWritesNothing() async throws {
        let model = await scratch.start()
        let before = try await scratch.stored()
        let summary = try await model.previewCSVImport(csv())
        XCTAssertEqual(summary.emptyResultMessage?.text, "No transactions found in this file")
        XCTAssertEqual(summary.emptyResultMessage?.tone, .neutral)
        let saved = await model.importCSV(summary)
        XCTAssertTrue(saved)
        let after = try await scratch.stored()
        XCTAssertEqual(after.revision, before.revision)
    }
}
