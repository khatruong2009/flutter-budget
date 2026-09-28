import Foundation

/// Whether the device's protected data (the app container) is readable.
/// On iOS this is `UIApplication.shared.isProtectedDataAvailable`, kept in a
/// thread-safe flag by the app. It must be synchronous so a commit never
/// suspends between its checks and its writes.
public protocol ProtectedDataAvailability: Sendable {
    var isProtectedDataAvailable: Bool { get }
}

/// For tests and platforms without file protection.
public struct AlwaysAvailable: ProtectedDataAvailability {
    public init() {}
    public var isProtectedDataAvailable: Bool { true }
}

public enum FinancialStoreError: Error, Equatable, Sendable {
    /// The device is locked (or prewarmed before first unlock). Nothing was
    /// read or written.
    case protectedDataUnavailable
    /// A file exists but could not be read. Never treated as "no data".
    case readFailed(name: String, reason: String)
    case writeFailed(name: String, reason: String)
    /// The primary read back from disk did not verify at the expected revision.
    case verificationFailed(expected: Int64, found: Int64?)
    /// Both store files were unreadable, were set aside as `.corrupt-<ms>`,
    /// and no legacy data exists. Dart would silently start empty; the Swift
    /// app stops and asks (MIGRATION_SPEC 14.0 Q3). `corruptFiles` are the
    /// set-aside names not yet acknowledged.
    case dataUnreadable(corruptFiles: [String])
}

/// The single owner of `financial_store_v2.json` and its backup.
///
/// A port of `AtomicFinancialStore` (MIGRATION_SPEC sections 4, 6, 8):
/// same file format, load precedence, commit protocol and legacy migration,
/// so the Flutter build can be reinstalled over the Swift app at any time.
/// Commits are serialized by the actor; no method suspends between reading
/// the current state and finishing its writes.
public actor FinancialStore {
    public struct LoadReport: Sendable, Equatable {
        public var restoredFromBackup = false
        public var setAside: [String] = []
        public var migratedFrom: LegacyMigration.Source?
        public var removedPreferenceKeys: [String] = []
    }

    private let fileSystem: StoreFileSystem
    private let preferences: PreferencesStore
    private let protectedData: ProtectedDataAvailability
    /// Dart `DateTime.now()`; used for `writtenAt` and `.corrupt-<ms>` stamps.
    private let clock: @Sendable () -> DartDateTime

    private var snapshot: FinancialSnapshot?
    public private(set) var lastLoadReport = LoadReport()

    public init(
        fileSystem: StoreFileSystem,
        preferences: PreferencesStore,
        protectedData: ProtectedDataAvailability,
        clock: @escaping @Sendable () -> DartDateTime = { DartDateTime.now(timeZone: .current) }
    ) {
        self.fileSystem = fileSystem
        self.preferences = preferences
        self.protectedData = protectedData
        self.clock = clock
    }

    public var isLoaded: Bool { snapshot != nil }

    /// The current snapshot, loading it on first use. A fresh install yields
    /// `FinancialSnapshot.empty` and writes nothing.
    public func read() throws(FinancialStoreError) -> FinancialSnapshot {
        if let snapshot { return snapshot }
        let loaded = try load()
        snapshot = loaded
        return loaded
    }

    /// Dart `updateSections`: merge, bump the revision, commit, verify.
    @discardableResult
    public func updateSections(_ updates: [(String, JSONValue)]) throws(FinancialStoreError) -> FinancialSnapshot {
        let current = try read()
        let next = current.applying(updates)
        try commit(next)
        snapshot = next
        return next
    }

    /// Dart `replace`: all sections replaced, revision = current + 1.
    @discardableResult
    public func replace(sections: JSONObject) throws(FinancialStoreError) -> FinancialSnapshot {
        let current = try read()
        let next = FinancialSnapshot(schemaVersion: StoreFile.schemaVersion, revision: current.revision + 1, sections: sections)
        try commit(next)
        snapshot = next
        return next
    }

    /// After `dataUnreadable`, the user chose to start with an empty store.
    /// The `.corrupt-*` files stay on disk.
    public func acknowledgeUnreadableData(_ corruptFiles: [String]) throws(FinancialStoreError) {
        let known = Set(acknowledgedCorruptFiles())
        let all = (known.union(corruptFiles)).sorted()
        preferences.set(.stringList(all), forKey: PreferenceKey.acknowledgedCorruptFiles)
        snapshot = nil
    }

    /// Forgets the in-memory snapshot (as a relaunch would).
    public func resetInMemoryState() {
        snapshot = nil
    }

    // MARK: - Loading (Dart `_load`)

    private func load() throws(FinancialStoreError) -> FinancialSnapshot {
        try requireProtectedData()
        var report = LoadReport()
        defer { lastLoadReport = report }

        let primaryBytes = try readIfPresent(StoreFile.primaryName)
        let backupBytes = try readIfPresent(StoreFile.backupName)
        let primary = primaryBytes.flatMap(StoreFile.decode)
        let backup = backupBytes.flatMap(StoreFile.decode)

        if primary != nil || backup != nil {
            if let primary, backup == nil || primary.revision >= backup!.revision {
                return primary
            }
            // Primary missing, unreadable or older: restore it from the
            // backup (same revision, fresh header); the backup is untouched.
            let restored = backup!
            try writeAtomically(StoreFile.primaryName, StoreFile.encode(restored, writtenAt: now()))
            try verifyOnDisk(restored.revision)
            report.restoredFromBackup = true
            return restored
        }

        if primaryBytes != nil || backupBytes != nil {
            // Both exist (or the only one exists) and neither decodes: keep
            // them for forensics and fall through to the legacy sources.
            let stamp = millisecondsSinceEpoch()
            for (name, bytes) in [(StoreFile.primaryName, primaryBytes), (StoreFile.backupName, backupBytes)]
            where bytes != nil {
                let newName = "\(name).corrupt-\(stamp)"
                do {
                    try fileSystem.rename(name, to: newName)
                } catch {
                    throw .writeFailed(name: name, reason: "\(error)")
                }
                report.setAside.append(newName)
            }
        }

        guard let migrated = LegacyMigration.migrate(preferences) else {
            let unacknowledged = try unacknowledgedCorruptFiles()
            if !unacknowledged.isEmpty {
                // Swift divergence (approved): do not open an empty ledger
                // over data that exists but cannot be read.
                throw .dataUnreadable(corruptFiles: unacknowledged)
            }
            return .empty
        }
        try commit(migrated.snapshot)
        report.migratedFrom = migrated.source
        report.removedPreferenceKeys = PreferenceKey.migratedKeys.filter { preferences.contains($0) }
        LegacyMigration.removeMigratedKeys(preferences)
        return migrated.snapshot
    }

    private func unacknowledgedCorruptFiles() throws(FinancialStoreError) -> [String] {
        let names: [String]
        do {
            names = try fileSystem.list()
        } catch {
            throw .readFailed(name: StoreFile.directoryName, reason: "\(error)")
        }
        let acknowledged = Set(acknowledgedCorruptFiles())
        return names.filter { name in
            (name.hasPrefix(StoreFile.primaryName + ".corrupt-") || name.hasPrefix(StoreFile.backupName + ".corrupt-"))
                && !acknowledged.contains(name)
        }
    }

    private func acknowledgedCorruptFiles() -> [String] {
        if case .stringList(let names)? = preferences.value(forKey: PreferenceKey.acknowledgedCorruptFiles) {
            return names
        }
        return []
    }

    // MARK: - Committing (Dart `_commit`)

    private func commit(_ next: FinancialSnapshot) throws(FinancialStoreError) {
        try requireProtectedData()
        let encoded = StoreFile.encode(next, writtenAt: now())

        // Preserve the intact current primary as the backup, byte for byte.
        if let current = try readIfPresent(StoreFile.primaryName), StoreFile.verify(current) != nil {
            try writeAtomically(StoreFile.backupName, current)
        }
        try writeAtomically(StoreFile.primaryName, encoded)
        try verifyOnDisk(next.revision)

        if let header = StoreFile.verify(encoded) {
            preferences.set(.string(header.payloadChecksum), forKey: PreferenceKey.lastCommittedChecksum)
        }
    }

    private func verifyOnDisk(_ expectedRevision: Int64) throws(FinancialStoreError) {
        let written = try readIfPresent(StoreFile.primaryName)
        let header = written.flatMap(StoreFile.verify)
        guard let header, header.revision == expectedRevision else {
            throw .verificationFailed(expected: expectedRevision, found: header?.revision)
        }
    }

    // MARK: - Primitives

    private func requireProtectedData() throws(FinancialStoreError) {
        guard protectedData.isProtectedDataAvailable else { throw .protectedDataUnavailable }
    }

    private func readIfPresent(_ name: String) throws(FinancialStoreError) -> [UInt8]? {
        do {
            return try fileSystem.read(name)
        } catch {
            throw .readFailed(name: name, reason: "\(error)")
        }
    }

    private func writeAtomically(_ name: String, _ bytes: [UInt8]) throws(FinancialStoreError) {
        // Re-checked per write: the device can lock mid-commit.
        try requireProtectedData()
        do {
            try fileSystem.writeStaged(name, bytes)
            try fileSystem.commitStaged(name)
        } catch {
            throw .writeFailed(name: name, reason: "\(error)")
        }
    }

    private func now() -> DartDateTime {
        clock()
    }

    private func millisecondsSinceEpoch() -> Int64 {
        DartDateTime.flooredDivision(now().microsecondsSinceEpoch, 1_000)
    }
}
