import Foundation

/// Why a tag or rule edit was refused. Nothing changed.
public enum CategorizationEditError: Error, Hashable, Sendable {
    /// The trimmed tag name is empty (categorization_provider.dart:59). The
    /// Flutter dialog closes silently before this can happen.
    case tagNameRequired
    /// A readable tag has this name after Dart `trim` and `toLowerCase`,
    /// compared as UTF-16 code units (:60-63).
    case duplicateTagName
    /// Swift-only: the trimmed merchant pattern is empty. Flutter's
    /// provider accepts it (the rule then never matches); its dialog keeps
    /// Add inert instead.
    case rulePatternRequired
    /// Swift-only: a bound is NaN or infinite, which JSON cannot hold.
    case ruleAmountNotFinite
    /// Swift-only: the rule names a tag id that no readable tag has. Flutter
    /// accepts it, but its backup import then refuses the whole file
    /// ("Backup rule references an unknown tag", backup.dart:131-133).
    case unknownTag(String)

    /// Flutter's `ArgumentError` copy for the tag errors (the page shows it
    /// in a snackbar); Swift copy for the rest, which Flutter never shows.
    public var message: String {
        switch self {
        case .tagNameRequired: "Tag name is required"
        case .duplicateTagName: "A tag with this name already exists"
        case .rulePatternRequired: "Merchant text is required"
        case .ruleAmountNotFinite: "Rule amounts must be numbers"
        case .unknownTag: "This rule uses a tag that no longer exists"
        }
    }
}

extension CategorizationEditError: LocalizedError {
    public var errorDescription: String? { message }
}

/// The fields of a Dart `CategorizationRule` (categorization_rule.dart:19-31)
/// with the constructor's defaults. Flutter's "New merchant rule" dialog
/// sets only the pattern, match type, transaction type, category and tags
/// (categorization_settings_page.dart:236-250); the rest keep their defaults.
public struct RuleDraft: Hashable, Sendable {
    /// Trimmed (Dart `trim`) when the rule is made.
    public var merchantPattern: String
    public var matchType: MerchantMatchType
    /// nil applies to both types; Flutter's dialog always sets one.
    public var transactionType: TransactionType?
    /// Inclusive bounds.
    public var minimumAmount: Double?
    public var maximumAmount: Double?
    public var category: String
    /// Stored as given (Flutter: tap order, a Set, so no duplicates).
    public var tagIds: [String]
    public var priority: Int
    public var isEnabled: Bool

    public init(
        merchantPattern: String, matchType: MerchantMatchType = .contains, transactionType: TransactionType?,
        minimumAmount: Double? = nil, maximumAmount: Double? = nil, category: String, tagIds: [String] = [],
        priority: Int = 0, isEnabled: Bool = true
    ) {
        self.merchantPattern = merchantPattern
        self.matchType = matchType
        self.transactionType = transactionType
        self.minimumAmount = minimumAmount
        self.maximumAmount = maximumAmount
        self.category = category
        self.tagIds = tagIds
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// Tag and rule management (`CategorizationProvider` addTag, deleteTag,
/// addRule, deleteRule; categorization_provider.dart:56-126). Every mutator
/// validates before it changes anything. Only readable rows take part;
/// unreadable rows stay verbatim. Rows are patched in place, new ones have
/// Dart's `toJson` shape.
extension FinancialData {
    /// Dart's `rules` getter (priority descending): the order the Tags &
    /// rules page lists them and `suggest` tries them.
    public var rulesByPriority: [CategorizationRuleRecord] { CategorizationEngine.ordered(rules) }

    /// The error `addTag` would throw for `name`, else nil.
    public func validateTagName(_ name: String) -> CategorizationEditError? {
        let trimmed = DartString.trim(name)
        if trimmed.isEmpty { return .tagNameRequired }
        let wanted = DartString.lowercase(trimmed)
        return tags.contains { DartString.equal(DartString.lowercase($0.name), wanted) } ? .duplicateTagName : nil
    }

    /// Dart `addTag`: the trimmed name, appended. `id` is Dart's
    /// `Uuid().v4()`. Write `transactionTags`.
    @discardableResult
    public mutating func addTag(name: String, colorToken: String = "accent", id: String) throws(CategorizationEditError)
        -> TransactionTagRecord
    {
        if let error = validateTagName(name) { throw error }
        let tag = TransactionTagRecord.make(id: id, name: name, colorToken: colorToken)
        tagRows.append(.record(tag))
        return tag
    }

    /// Dart `deleteTag`: every tag with this id goes, and every rule drops
    /// the id from its `tagIds`. Transactions keep it (D9: orphan ids, as in
    /// Flutter). Returns the sections to write in one commit, tags then
    /// rules (Dart writes both, as two commits, even when nothing changed);
    /// empty when nothing changed.
    @discardableResult
    public mutating func deleteTag(id: String) -> [String] {
        let before = tagRows.count
        tagRows.removeAll { $0.record.map { DartString.equal($0.id, id) } ?? false }
        var changed = tagRows.count != before
        for index in ruleRows.indices {
            guard let rule = ruleRows[index].record, rule.tagIds.contains(where: { DartString.equal($0, id) }) else { continue }
            ruleRows[index] = .record(rule.removingTag(id))
            changed = true
        }
        return changed ? [Section.transactionTags, Section.categorizationRules] : []
    }

    /// The error `addRule` would throw for `draft`, else nil (Swift-only
    /// checks; see `CategorizationEditError`).
    public func validateRule(_ draft: RuleDraft) -> CategorizationEditError? {
        if DartString.trim(draft.merchantPattern).isEmpty { return .rulePatternRequired }
        for bound in [draft.minimumAmount, draft.maximumAmount] {
            if let bound, !bound.isFinite { return .ruleAmountNotFinite }
        }
        let known = tags.map(\.id)
        if let unknown = draft.tagIds.first(where: { id in !known.contains { DartString.equal($0, id) } }) {
            return .unknownTag(unknown)
        }
        return nil
    }

    /// Dart `addRule`: rules with the same id go, then the new rule is
    /// appended (so re-adding an id moves it to the end). Write
    /// `categorizationRules`.
    @discardableResult
    public mutating func addRule(_ draft: RuleDraft, id: String) throws(CategorizationEditError) -> CategorizationRuleRecord {
        if let error = validateRule(draft) { throw error }
        let rule = CategorizationRuleRecord.make(id: id, draft)
        ruleRows.removeAll { $0.record.map { DartString.equal($0.id, id) } ?? false }
        ruleRows.append(.record(rule))
        return rule
    }

    /// Dart `deleteRule`: every rule with this id. False when there was none
    /// (Dart still writes the unchanged list). Write `categorizationRules`.
    @discardableResult
    public mutating func deleteRule(id: String) -> Bool {
        let before = ruleRows.count
        ruleRows.removeAll { $0.record.map { DartString.equal($0.id, id) } ?? false }
        return ruleRows.count != before
    }
}
