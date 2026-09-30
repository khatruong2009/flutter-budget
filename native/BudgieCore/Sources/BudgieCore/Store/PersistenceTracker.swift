import Foundation

/// The Flutter `PersistenceStatus` mixin: memory is updated first, then the
/// write is awaited; a failed write flags its sections as unsaved and every
/// later save carries them too, so one successful write heals everything.
/// A change only counts as saved once the store verified it on disk.
@MainActor
public final class PersistenceTracker {
    public private(set) var unsavedSections: Set<String> = []
    public private(set) var lastError: FinancialStoreError?
    public var hasUnsavedChanges: Bool { !unsavedSections.isEmpty }

    private let store: FinancialStore

    public init(store: FinancialStore) {
        self.store = store
    }

    /// Persists `sections` (already serialized) plus every flagged section,
    /// serialized now by `serialize`. Never throws. Returns whether the write
    /// was verified.
    @discardableResult
    public func persist(
        _ sections: [(String, JSONValue)], serialize: (String) -> JSONValue
    ) async -> Bool {
        let requested = Set(sections.map(\.0))
        var payload: [(String, JSONValue)] = unsavedSections.subtracting(requested).sorted().map { ($0, serialize($0)) }
        payload.append(contentsOf: sections)
        do {
            try await store.updateSections(payload)
        } catch {
            unsavedSections.formUnion(payload.map(\.0))
            lastError = error
            return false
        }
        let wasFlagged = !unsavedSections.isEmpty
        unsavedSections.subtract(payload.map(\.0))
        if wasFlagged && unsavedSections.isEmpty { lastError = nil }
        return true
    }

    /// Flags `sections` as unsaved without writing them (a write that must
    /// not run now, e.g. during a restore): the banner and the retries take
    /// them from here.
    public func flag(_ sections: [String], because error: FinancialStoreError) {
        unsavedSections.formUnion(sections)
        lastError = error
    }

    /// Retries every flagged section. True when nothing is left unsaved.
    @discardableResult
    public func retry(serialize: (String) -> JSONValue) async -> Bool {
        if unsavedSections.isEmpty { return true }
        return await persist(unsavedSections.sorted().map { ($0, serialize($0)) }, serialize: serialize)
    }
}
