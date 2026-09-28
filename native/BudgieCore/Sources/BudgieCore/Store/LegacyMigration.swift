import Foundation

/// Reads the pre-file storage formats the Flutter app still migrates from
/// (`AtomicFinancialStore._migrateFromPreferences`), with the same precedence.
/// MIGRATION_SPEC section 8.
public enum LegacyMigration {
    /// Dart `_decodeLegacyEnvelope`: a JSON object with a `checksum` string
    /// over the Dart re-encoding of the rest, `schemaVersion <= 1`.
    public static func decodeEnvelope(_ encoded: String?) -> FinancialSnapshot? {
        guard let encoded, case .object(var object)? = try? JSONParser.parse(encoded) else { return nil }
        guard case .string(let checksum)? = object["checksum"] else { return nil }
        object["checksum"] = nil
        // Dart verifies over jsonEncode of the decoded map, i.e. the
        // canonical re-encoding, not the stored text.
        let reencoded = DartJSON.encode(.object(object), mode: .dartCanonical)
        guard StoreFile.checksum(reencoded) == checksum.value else { return nil }
        guard
            let version = object["schemaVersion"]?.numberValue?.intValue, version <= 1,
            let revision = object["revision"]?.numberValue?.intValue,
            case .object(let sections)? = object["sections"]
        else { return nil }
        return FinancialSnapshot(schemaVersion: Int(version), revision: revision, sections: sections)
    }

    /// Dart `_readLegacySections`, in its key order. nil = absent/unreadable.
    public static func readLegacySections(_ preferences: PreferencesStore) -> [(String, JSONValue?)] {
        func decodeOrNull(_ key: String) -> JSONValue? {
            guard let raw = preferences.string(key), !raw.isEmpty else { return nil }
            return try? JSONParser.parse(raw)
        }
        let hasAppSettings = [
            PreferenceKey.baseCurrencyCode, PreferenceKey.localeOverride, PreferenceKey.appLockEnabled,
            PreferenceKey.autoLockTimeoutSeconds, PreferenceKey.hideBalances,
        ].contains { preferences.contains($0) }

        var appSettings: JSONValue? = nil
        if hasAppSettings {
            let locale = preferences.string(PreferenceKey.localeOverride)
            appSettings = .object(
                JSONObject(ordered: [
                    ("baseCurrencyCode", .string(preferences.string(PreferenceKey.baseCurrencyCode) ?? "USD")),
                    ("localeOverride", locale.map { .string($0) } ?? .null),
                    ("appLockEnabled", .bool(preferences.bool(PreferenceKey.appLockEnabled) ?? false)),
                    ("autoLockTimeoutSeconds",
                     .number(JSONNumber(int: preferences.int(PreferenceKey.autoLockTimeoutSeconds) ?? 60))),
                    ("hideBalances", .bool(preferences.bool(PreferenceKey.hideBalances) ?? false)),
                ]))
        }
        // `net_worth_selected_month` is taken raw (getString, not decoded),
        // so even an empty string counts as present, as in Dart.
        let selectedMonth = preferences.string(PreferenceKey.netWorthSelectedMonth).map { JSONValue.string($0) }
        return [
            (Section.transactions, decodeOrNull(PreferenceKey.transactions)),
            (Section.netWorthEntries, decodeOrNull(PreferenceKey.netWorthEntries)),
            (Section.selectedNetWorthMonth, selectedMonth),
            (Section.categoryBudgetLimits, decodeOrNull(PreferenceKey.categoryBudgetLimits)),
            (Section.savingsGoals, decodeOrNull(PreferenceKey.savingsGoals)),
            (Section.recurringTransactions, decodeOrNull(PreferenceKey.recurringTransactions)),
            (Section.categories, decodeOrNull(PreferenceKey.categories)),
            (Section.transactionTags, decodeOrNull(PreferenceKey.transactionTags)),
            (Section.categorizationRules, decodeOrNull(PreferenceKey.categorizationRules)),
            (Section.appSettings, appSettings),
        ]
    }

    public enum Source: String, Sendable {
        case envelope, envelopeBackup, legacyKeys
    }

    public struct Result: Sendable {
        public var snapshot: FinancialSnapshot
        public var source: Source
    }

    /// Dart `_migrateFromPreferences`. nil when there is nothing to migrate.
    public static func migrate(_ preferences: PreferencesStore) -> Result? {
        let primary = decodeEnvelope(preferences.string(PreferenceKey.legacyEnvelope))
        let backup = decodeEnvelope(preferences.string(PreferenceKey.legacyEnvelopeBackup))
        let legacy = readLegacySections(preferences)
        let hasLegacyData = legacy.contains { $0.1 != nil }
        if primary == nil && backup == nil && !hasLegacyData { return nil }

        let chosen: FinancialSnapshot?
        let chosePrimary: Bool
        if let primary, backup == nil || primary.revision >= backup!.revision {
            chosen = primary
            chosePrimary = true
        } else {
            chosen = backup
            chosePrimary = false
        }

        var sections = chosen?.sections ?? JSONObject()
        // The old store mirrored the ledger to the bare key after every
        // envelope commit, so when the primary envelope is not used the bare
        // list is at least as new as the backup envelope. Any list, even [].
        if !chosePrimary, let transactions = legacy.first(where: { $0.0 == Section.transactions })?.1,
            case .array = transactions
        {
            sections[Section.transactions] = transactions
        }
        for (section, value) in legacy {
            if let value, !sections.contains(section) { sections[section] = value }
        }
        let source: Source = chosen == nil ? .legacyKeys : chosePrimary ? .envelope : .envelopeBackup
        return Result(
            snapshot: FinancialSnapshot(schemaVersion: StoreFile.schemaVersion, revision: chosen?.revision ?? 0, sections: sections),
            source: source)
    }

    /// Dart `_removeMigratedPreferenceKeys`. Call only after a verified commit.
    public static func removeMigratedKeys(_ preferences: PreferencesStore) {
        for key in PreferenceKey.migratedKeys where preferences.contains(key) {
            preferences.set(nil, forKey: key)
        }
    }
}
