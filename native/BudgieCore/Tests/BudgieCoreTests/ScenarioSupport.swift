import Foundation

@testable import BudgieCore

/// A fixture scenario (native/Fixtures/{store,legacy}/<name>/) loaded into
/// in-memory stand-ins for the store directory and NSUserDefaults.
struct Scenario {
    let name: String
    let url: URL
    let expected: [String: Any]
    let fileSystem: InMemoryFileSystem
    let preferences: InMemoryPreferences

    static let zone = TimeZone(identifier: "America/New_York")!

    init(_ url: URL) throws {
        self.url = url
        name = url.lastPathComponent
        expected = try JSONSerialization.jsonObject(with: Data(contentsOf: url.appendingPathComponent("expected.json"))) as! [String: Any]
        var files: [String: [UInt8]] = [:]
        let input = url.appendingPathComponent("input")
        if let names = try? FileManager.default.contentsOfDirectory(atPath: input.path) {
            for fileName in names {
                var isDirectory: ObjCBool = false
                let file = input.appendingPathComponent(fileName)
                guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
                files[fileName] = [UInt8](try Data(contentsOf: file))
            }
        }
        // Git does not keep the empty directory this scenario places where
        // the primary file belongs; recreate it.
        let directories: Set<String> = name == "primary_is_directory" ? [StoreFile.primaryName] : []
        fileSystem = InMemoryFileSystem(files: files, directories: directories)
        preferences = InMemoryPreferences(try Scenario.loadPrefs(url.appendingPathComponent("prefs.json")))
    }

    static func loadPrefs(_ url: URL) throws -> [String: PreferenceValue] {
        let typed = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: [String: Any]]
        var result: [String: PreferenceValue] = [:]
        for (key, entry) in typed {
            let raw = entry["value"]!
            switch entry["type"] as! String {
            case "string": result[key] = .string(raw as! String)
            case "stringList": result[key] = .stringList(raw as! [String])
            case "int": result[key] = .int((raw as! NSNumber).int64Value)
            case "double": result[key] = .double((raw as! NSNumber).doubleValue)
            case "bool": result[key] = .bool(raw as! Bool)
            default: fatalError("unknown pref type")
            }
        }
        return result
    }

    /// The Dart launch clock for every expectation.
    var launchNow: DartDateTime {
        try! DartDateTime.parse(expected["launchNow"] as! String, timeZone: Scenario.zone)
    }

    func makeStore(protectedData: ProtectedDataAvailability = AlwaysAvailable()) -> FinancialStore {
        let now = launchNow
        return FinancialStore(fileSystem: fileSystem, preferences: preferences, protectedData: protectedData, clock: { now })
    }

    /// Same shape as the harness `listing()`: name (corrupt stamps
    /// normalised) -> size and FNV of the bytes.
    func listing() -> [String: [String: AnyHashable]] {
        var out: [String: [String: AnyHashable]] = [:]
        for (name, bytes) in fileSystem.snapshot {
            let normalized = name.replacingOccurrences(of: #"\.corrupt-\d+$"#, with: ".corrupt-*", options: .regularExpression)
            out[normalized] = ["size": bytes.count, "fnv": StoreFile.checksum(bytes)]
        }
        return out
    }

    static func listing(_ json: Any?) -> [String: [String: AnyHashable]] {
        guard let dict = json as? [String: [String: Any]] else { return [:] }
        return dict.mapValues { entry in
            ["size": (entry["size"] as! NSNumber).intValue, "fnv": entry["fnv"] as! String]
        }
    }

    func prefsSnapshot() -> [String: PreferenceValue] {
        preferences.all
    }
}

/// Dart-canonical sections checksum, comparable with expected.json.
func canonicalSections(_ snapshot: FinancialSnapshot) -> (fnv: String, length: Int, keys: [String]) {
    let bytes = DartJSON.encode(.object(snapshot.sections), mode: .dartCanonical)
    return (StoreFile.checksum(bytes), bytes.count, snapshot.sections.keys)
}
