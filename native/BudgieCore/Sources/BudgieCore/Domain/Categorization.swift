import Foundation

// MARK: - Transaction tag

/// Dart `TransactionTag` (`transaction_tag.dart`).
public struct TransactionTagRecord: Identifiable, Hashable, Sendable {
    public private(set) var id: String
    public private(set) var name: String
    public private(set) var colorToken: String
    public private(set) var raw: JSONObject

    /// Dart `TransactionTag.fromJson`. nil where Dart's casts would throw.
    /// A missing id gets a fresh one (Dart's constructor), written into
    /// `raw` so the next save keeps it, as Dart's `toJson` would.
    static func parse(_ value: JSONValue, newID: () -> String) -> TransactionTagRecord? {
        guard case .object(var object) = value else { return nil }
        guard case .some(let id) = Read.optionalString(object, "id") else { return nil }
        guard case .some(let name) = Read.optionalString(object, "name") else { return nil }
        guard case .some(let colorToken) = Read.optionalString(object, "colorToken") else { return nil }
        let resolvedID = id ?? newID()
        if id == nil { object["id"] = .string(resolvedID) }
        return TransactionTagRecord(
            id: resolvedID, name: DartString.trim(name ?? ""), colorToken: colorToken ?? "accent", raw: object)
    }

    /// A new tag as Dart `TransactionTag(...).toJson()` writes it.
    public static func make(id: String, name: String, colorToken: String = "accent") -> TransactionTagRecord {
        let trimmed = DartString.trim(name)
        return TransactionTagRecord(
            id: id, name: trimmed, colorToken: colorToken,
            raw: JSONObject(ordered: [("id", .string(id)), ("name", .string(trimmed)), ("colorToken", .string(colorToken))]))
    }
}

// MARK: - Categorization rule

public enum MerchantMatchType: String, Sendable, Hashable, CaseIterable {
    case contains, startsWith, exact
}

/// Dart `CategorizationRule` (`categorization_rule.dart`).
public struct CategorizationRuleRecord: Identifiable, Hashable, Sendable {
    public private(set) var id: String
    public private(set) var merchantPattern: String
    public private(set) var matchType: MerchantMatchType
    public private(set) var transactionType: TransactionType?
    public private(set) var minimumAmount: Double?
    public private(set) var maximumAmount: Double?
    public private(set) var category: String
    public private(set) var tagIds: [String]
    public private(set) var priority: Int
    public private(set) var isEnabled: Bool
    public private(set) var raw: JSONObject

    /// Dart `CategorizationRule.fromJson`, with its defaults. nil where
    /// Dart's casts would throw.
    static func parse(_ value: JSONValue, newID: () -> String) -> CategorizationRuleRecord? {
        guard case .object(var object) = value else { return nil }
        guard case .some(let id) = Read.optionalString(object, "id") else { return nil }
        guard case .some(let pattern) = Read.optionalString(object, "merchantPattern") else { return nil }
        guard case .some(let typeName) = Read.optionalString(object, "transactionType") else { return nil }
        func optionalNumber(_ key: String) -> Double?? {
            switch object[key] {
            case nil, .null?: return .some(nil)
            case .number(let n)?: return .some(n.doubleValue)
            default: return nil
            }
        }
        guard case .some(let minimum) = optionalNumber("minimumAmount") else { return nil }
        guard case .some(let maximum) = optionalNumber("maximumAmount") else { return nil }
        guard case .some(let category) = Read.optionalString(object, "category") else { return nil }
        var tagIds: [String] = []
        switch object["tagIds"] {
        case nil, .null?: break
        case .array(let items)?: tagIds = items.compactMap(\.stringValue)
        default: return nil
        }
        let priority: Int
        switch object["priority"] {
        case nil, .null?: priority = 0
        case .number(let n)?: priority = Int(DartNumbers.toInt(n.doubleValue, lexeme: n))
        default: return nil
        }
        let isEnabled: Bool
        switch object["isEnabled"] {
        case nil, .null?: isEnabled = true
        case .bool(let b)?: isEnabled = b
        default: return nil
        }
        let resolvedID = id ?? newID()
        if id == nil { object["id"] = .string(resolvedID) }
        // `matchType` accepts any JSON value; an unknown one is `contains`.
        let matchType = object["matchType"]?.stringValue.flatMap(MerchantMatchType.init(rawValue:)) ?? .contains
        return CategorizationRuleRecord(
            id: resolvedID, merchantPattern: DartString.trim(pattern ?? ""), matchType: matchType,
            transactionType: typeName.map { $0 == "income" ? .income : .expense },
            minimumAmount: minimum, maximumAmount: maximum, category: category ?? "General", tagIds: tagIds,
            priority: priority, isEnabled: isEnabled, raw: object)
    }
}
