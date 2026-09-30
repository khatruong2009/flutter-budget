import BudgieCore
import XCTest

@testable import Runner

/// A full `AppModel` bootstrap against a scratch Application Support
/// directory and a scratch preferences suite (never the host app's data).
@MainActor
private final class ScratchApp {
    let directory: URL
    let suite: String
    let defaults: UserDefaults
    let preferences: UserDefaultsPreferences

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("budgie-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suite = "budgie.tests.model.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        preferences = UserDefaultsPreferences(defaults: defaults, domainName: suite)
    }

    func makeModel() -> AppModel { AppModel(applicationSupport: directory, preferences: preferences) }

    var storeDirectory: URL { directory.appendingPathComponent(StoreFile.directoryName, isDirectory: true) }

    func store() -> FinancialStore {
        FinancialStore(fileSystem: DirectoryFileSystem(directory: storeDirectory), preferences: preferences, protectedData: AlwaysAvailable())
    }

    /// Writes `sections` as an existing store (before the model starts).
    func seed(_ sections: JSONObject) async throws {
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        _ = try await store().replace(sections: sections)
    }

    /// What is on disk now, read by a fresh store.
    func stored() async throws -> FinancialSnapshot { try await store().read() }

    func remove() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
}

@MainActor
final class OnboardingModelTests: XCTestCase {
    private var scratch: ScratchApp!

    override func setUp() async throws {
        scratch = try ScratchApp()
    }

    override func tearDown() async throws {
        unsetenv("BUDGIE_SKIP_ONBOARDING")
        scratch.remove()
    }

    /// A first launch shows the tour and holds routes; completing it writes
    /// Flutter's CFBoolean, opens the queued route, and later launches skip
    /// the tour.
    func testTourShowsUntilCompletedThenNeverAgain() async throws {
        let model = scratch.makeModel()
        XCTAssertFalse(model.showsOnboarding, "nothing is read before the bootstrap")
        await model.start()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.showsOnboarding)
        XCTAssertFalse(model.canOpenRoutes)
        model.open(URL(string: "budgetapp://add-income")!)
        XCTAssertNil(model.takePendingAdd(), "a route waits for the tour")
        XCTAssertEqual(model.pendingAdd, .income)

        model.completeOnboarding()
        XCTAssertFalse(model.showsOnboarding)
        XCTAssertTrue(model.canOpenRoutes)
        XCTAssertEqual(model.takePendingAdd(), .income)
        let raw = try XCTUnwrap(scratch.defaults.persistentDomain(forName: scratch.suite)?[PreferenceKey.onboardingCompleted] as? NSNumber)
        XCTAssertEqual(CFGetTypeID(raw), CFBooleanGetTypeID())
        XCTAssertTrue(raw.boolValue)

        let relaunched = scratch.makeModel()
        await relaunched.start()
        XCTAssertEqual(relaunched.phase, .ready)
        XCTAssertFalse(relaunched.showsOnboarding)
        XCTAssertTrue(relaunched.canOpenRoutes)
    }

    /// Flutter's `getBool` throws on another type and its gate shows the
    /// tour; so does a stored false.
    func testWrongTypeOrFalseShowsTheTour() async {
        for value: PreferenceValue in [.string("true"), .int(1), .bool(false)] {
            scratch.preferences.set(value, forKey: PreferenceKey.onboardingCompleted)
            let model = scratch.makeModel()
            await model.start()
            XCTAssertTrue(model.showsOnboarding, "\(value)")
            scratch.preferences.set(nil, forKey: PreferenceKey.onboardingCompleted)
        }
    }

    /// The UI-test hook: "1" writes the flag before it is read, "0" removes it.
    func testSkipHook() async {
        setenv("BUDGIE_SKIP_ONBOARDING", "1", 1)
        let skipped = scratch.makeModel()
        await skipped.start()
        XCTAssertFalse(skipped.showsOnboarding)
        XCTAssertEqual(scratch.preferences.value(forKey: PreferenceKey.onboardingCompleted), .bool(true))

        setenv("BUDGIE_SKIP_ONBOARDING", "0", 1)
        let reset = scratch.makeModel()
        await reset.start()
        XCTAssertTrue(reset.showsOnboarding)
        XCTAssertNil(scratch.preferences.value(forKey: PreferenceKey.onboardingCompleted))
    }
}

@MainActor
final class RecurringModelTests: XCTestCase {
    private var scratch: ScratchApp!

    override func setUp() async throws {
        scratch = try ScratchApp()
        // Past the tour, like every other launch in these tests.
        OnboardingFlag.markCompleted(scratch.preferences)
    }

    override func tearDown() async throws {
        scratch.remove()
    }

    private var calendar: DartCalendar { DartCalendar(timeZone: .autoupdatingCurrent) }

    func testToastCopy() {
        XCTAssertEqual(Toast.dueGenerated.message, "Due transactions generated and next occurrences updated")
        XCTAssertEqual(Toast.dueGenerated.style, .success)
        XCTAssertEqual(Toast.recurringDeleted.message, "Recurring transaction deleted")
        XCTAssertEqual(Toast.recurringDeleted.style, .success)
        XCTAssertNotEqual(Toast.dueGenerated.id, Toast.dueGenerated.id)
        XCTAssertEqual(AppModel.DueGeneration(generated: 0, saved: true).toast.message, Toast.dueGenerated.message)
        XCTAssertEqual(AppModel.DueGeneration(generated: 3, saved: false).toast.message, Toast.saveFailed.message)
    }

    /// Before the store is loaded there is nothing to generate or read.
    func testBeforeLoad() async {
        let model = AppModel()
        let result = await model.generateDueNow()
        XCTAssertEqual(result, AppModel.DueGeneration(generated: 0, saved: true))
        XCTAssertNil(model.lastGeneratedDate(forTemplate: "t"))
    }

    /// A paused template the launch skipped, resumed, then "Generate Due
    /// Transactions": every missed occurrence and the advanced cursor are
    /// on disk after the one call; a second call finds nothing due.
    func testGenerateDueNowWritesRowsAndCursorInOneCall() async throws {
        let start = calendar.now().adding(days: -14)
        let template = RecurringTemplate.make(
            id: "tpl", type: .expense, description: "Gym", amount: 12.5, category: "Health", pattern: .weekly,
            startDate: start, dayOfMonth: nil, dayOfWeek: start.weekday, isActive: false)
        try await scratch.seed(JSONObject(ordered: [(Section.recurringTransactions, .array([.object(template.raw)]))]))

        let model = scratch.makeModel()
        await model.start()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.data?.transactions.count, 0, "the launch skips a paused template")
        XCTAssertNil(model.lastGeneratedDate(forTemplate: "tpl"))
        let resumed = await model.setTemplateActive(id: "tpl", true)
        XCTAssertTrue(resumed)

        let result = await model.generateDueNow()
        XCTAssertEqual(result, AppModel.DueGeneration(generated: 3, saved: true))
        XCTAssertEqual(model.data?.transactions.map(\.date), [start, start.adding(days: 7), start.adding(days: 14)])
        XCTAssertEqual(model.data?.templates.first?.nextOccurrence, start.adding(days: 21))
        XCTAssertEqual(model.lastGeneratedDate(forTemplate: "tpl"), start.adding(days: 14))
        XCTAssertFalse(model.hasUnsavedChanges)

        let disk = try await scratch.stored()
        let rows = disk.sections[Section.transactions]?.arrayValue ?? []
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.allSatisfy { $0.objectValue?["recurringTemplateId"]?.stringValue == "tpl" })
        let storedTemplate = disk.sections[Section.recurringTransactions]?.arrayValue?.first?.objectValue
        XCTAssertEqual(storedTemplate?["nextOccurrence"]?.stringValue, start.adding(days: 21).toIso8601String())
        XCTAssertEqual(storedTemplate?["isActive"]?.boolValue, true)

        let again = await model.generateDueNow()
        XCTAssertEqual(again, AppModel.DueGeneration(generated: 0, saved: true))
        let unchanged = try await scratch.stored()
        XCTAssertEqual(unchanged.revision, disk.revision, "nothing due, nothing written")
    }

    /// The form's add path: a template whose start is the moment the form
    /// opened logs today's occurrence right away (Flutter runs the
    /// generator after the add).
    func testAddFromNowLogsTodayAndKeepsTheTimeOfDay() async throws {
        let model = scratch.makeModel()
        await model.start()
        let opened = model.now
        let start = RecurringForm.resolvedStart(picked: nil, stored: nil, openedAt: opened, calendar: model.calendar)
        let added = await model.addTemplate(RecurringForm.edit(
            type: .income, description: "Pay", amount: 800, category: "Salary", pattern: .monthly, start: start,
            dayOfMonth: opened.day))
        XCTAssertTrue(added)
        let template = try XCTUnwrap(model.data?.templates.first)
        XCTAssertEqual(template.startDate, opened, "time of day and microseconds kept")
        XCTAssertEqual(template.dayOfMonth, opened.day)
        XCTAssertNil(template.dayOfWeek)
        XCTAssertEqual(model.data?.transactions.map(\.date), [opened])
        XCTAssertEqual(
            template.nextOccurrence,
            RecurringGenerator.nextOccurrence(pattern: .monthly, dayOfMonth: opened.day, after: opened, calendar: model.calendar))
        XCTAssertEqual(model.lastGeneratedDate(forTemplate: template.id), opened)
    }
}
