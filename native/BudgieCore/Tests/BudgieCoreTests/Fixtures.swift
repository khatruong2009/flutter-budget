import Foundation

/// Access to native/Fixtures (produced by native/ParityHarness from the real
/// Flutter code).
enum Fixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // BudgieCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // BudgieCore
        .deletingLastPathComponent()  // native
        .appendingPathComponent("Fixtures")

    static func url(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }

    static func data(_ relative: String) throws -> Data {
        try Data(contentsOf: url(relative))
    }

    static func json(_ relative: String) throws -> Any {
        try JSONSerialization.jsonObject(with: data(relative), options: [.fragmentsAllowed])
    }

    /// Scenario directories under `store/` or `legacy/`.
    static func scenarios(_ group: String) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: url(group), includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Every store file (primary, backup, leftovers) in every scenario input.
    static func allStoreFiles() throws -> [URL] {
        var files: [URL] = []
        for group in ["store", "legacy"] {
            for scenario in try scenarios(group) {
                let input = scenario.appendingPathComponent("input")
                guard let names = try? FileManager.default.contentsOfDirectory(atPath: input.path) else { continue }
                for name in names.sorted() {
                    var isDirectory: ObjCBool = false
                    let file = input.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                        files.append(file)
                    }
                }
            }
        }
        return files
    }
}
