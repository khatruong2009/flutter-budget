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
    static func emit(_ name: String, fileSystem: InMemoryFileSystem, preferences: InMemoryPreferences, snapshot: FinancialSnapshot) throws {
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
        let swift: [String: Any] = [
            "revision": snapshot.revision,
            "sectionsFnv": canonicalSections(snapshot).fnv,
        ]
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
