import Foundation

/// A category definition (`BudgetCategory`, `category_definition.dart`).
/// Keeps the row it was read from so edits patch it in place.
public struct CategoryInfo: Hashable, Sendable, Identifiable {
    public let id: String
    public let type: TransactionType
    public let name: String
    public let iconIdentifier: String
    public let colorToken: String
    public let sortOrder: Int
    public let isArchived: Bool
    public let isBuiltIn: Bool
    public let raw: JSONObject

    /// Dart `BudgetCategory.fromJson`. nil where its casts would throw.
    static func parse(_ value: JSONValue) -> CategoryInfo? {
        guard case .object(let object) = value,
            let id = Read.requiredString(object, "id"),
            let name = Read.requiredString(object, "name"),
            case .some(let icon) = Read.optionalString(object, "iconIdentifier"),
            case .some(let color) = Read.optionalString(object, "colorToken")
        else { return nil }
        let sortOrder: Int
        switch object["sortOrder"] {
        case nil, .null?: sortOrder = 0
        case .number(let n)?: sortOrder = Int(DartNumbers.toInt(n.doubleValue, lexeme: n))
        default: return nil
        }
        func optionalBool(_ key: String) -> Bool?? {
            switch object[key] {
            case nil, .null?: return .some(nil)
            case .bool(let b)?: return .some(b)
            default: return nil
            }
        }
        guard case .some(let archived) = optionalBool("isArchived"), case .some(let builtIn) = optionalBool("isBuiltIn") else {
            return nil
        }
        return CategoryInfo(
            id: id, type: object["type"]?.stringValue == "income" ? .income : .expense, name: name,
            iconIdentifier: icon ?? "square_grid_2x2", colorToken: color ?? "accent", sortOrder: sortOrder,
            isArchived: archived ?? false, isBuiltIn: builtIn ?? false, raw: object)
    }

    /// A new definition as Dart `BudgetCategory(...).toJson()` writes it.
    public static func make(
        id: String, type: TransactionType, name: String, iconIdentifier: String, colorToken: String, sortOrder: Int,
        isArchived: Bool = false, isBuiltIn: Bool
    ) -> CategoryInfo {
        let raw = JSONObject(ordered: [
            ("id", .string(id)),
            ("type", .string(type.rawValue)),
            ("name", .string(name)),
            ("iconIdentifier", .string(iconIdentifier)),
            ("colorToken", .string(colorToken)),
            ("sortOrder", .int(sortOrder)),
            ("isArchived", .bool(isArchived)),
            ("isBuiltIn", .bool(isBuiltIn)),
        ])
        return CategoryInfo(
            id: id, type: type, name: name, iconIdentifier: iconIdentifier, colorToken: colorToken, sortOrder: sortOrder,
            isArchived: isArchived, isBuiltIn: isBuiltIn, raw: raw)
    }
}

public enum CategoryCatalog {
    /// `CategoryProvider._builtInCategories()` (research C section 3).
    public static let builtIn: [CategoryInfo] = {
        let expenses: [(String, String, String)] = [
            ("General", "square_grid_2x2", "accent"), ("Eating Out", "asterisk_circle", "orange"),
            ("Groceries", "cart", "green"), ("Housing", "house", "blue"), ("Transportation", "car", "purple"),
            ("Travel", "airplane", "cyan"), ("Clothing", "bag", "pink"), ("Gift", "gift", "purple"),
            ("Health", "heart", "red"), ("Entertainment", "film", "orange"), ("Pets", "paw", "green"),
            ("Family", "people", "blue"), ("Loan Payment", "money", "red"),
        ]
        let incomes: [(String, String, String)] = [
            ("Salary", "money", "green"), ("Investment", "chart", "blue"), ("Gift", "gift", "purple"),
            ("Other", "square_grid_2x2", "accent"),
        ]
        func slug(_ name: String) -> String { name.lowercased().replacingOccurrences(of: " ", with: "-") }
        return expenses.enumerated().map { i, c in
            CategoryInfo.make(
                id: "expense-\(slug(c.0))", type: .expense, name: c.0, iconIdentifier: c.1, colorToken: c.2, sortOrder: i,
                isBuiltIn: true)
        } + incomes.enumerated().map { i, c in
            CategoryInfo.make(
                id: "income-\(slug(c.0))", type: .income, name: c.0, iconIdentifier: c.1, colorToken: c.2, sortOrder: i,
                isBuiltIn: true)
        }
    }()

    /// The stored rows of the `categories` section: each readable (Dart
    /// `fromJson` rules) or kept verbatim. Empty when the section is absent
    /// or not a list. Dart falls back to the seeds for the whole list when
    /// any row is malformed; Swift keeps the readable rows (PARITY_GAPS).
    public static func rows(_ section: JSONValue?) -> [StoredRow<CategoryInfo>] {
        guard case .array(let rows)? = section else { return [] }
        return rows.map { row in CategoryInfo.parse(row).map { .record($0) } ?? .unreadable(row) }
    }

    /// The definitions the app uses: the readable rows, or the built-in
    /// seeds when there are none (Dart `_decodeOrSeed`).
    public static func effective(_ rows: [StoredRow<CategoryInfo>]) -> [CategoryInfo] {
        let records = rows.compactMap(\.record)
        return records.isEmpty ? builtIn : records
    }

    /// Picker list for a type: active definitions by sort order (Dart
    /// normalises sort order per type, stable in list order), then any name
    /// used by an existing transaction of that type without a definition
    /// (the Flutter app creates definitions for those at launch).
    public static func pickerList(_ categories: [CategoryInfo], type: TransactionType, usedNames: [String]) -> [CategoryInfo] {
        let defined = categories.enumerated()
            .filter { $0.element.type == type }
            .sorted { ($0.element.sortOrder, $0.offset) < ($1.element.sortOrder, $1.offset) }
            .map(\.element)
        var result = defined.filter { !$0.isArchived }
        var known = Set(defined.map { $0.name.lowercased() })
        for name in usedNames where known.insert(name.lowercased()).inserted {
            result.append(CategoryInfo.make(
                id: "\(type.rawValue)-legacy-\(name)", type: type, name: name, iconIdentifier: "square_grid_2x2",
                colorToken: "accent", sortOrder: Int.max, isBuiltIn: false))
        }
        return result
    }

    /// SF Symbol for a Flutter icon identifier (CupertinoIcons registry,
    /// common.dart). Unknown identifiers fall back like Flutter does.
    public static func symbol(for iconIdentifier: String) -> String {
        switch iconIdentifier {
        case "square_grid_2x2": "square.grid.2x2"
        case "asterisk_circle": "fork.knife.circle"
        case "cart": "cart"
        case "house": "house"
        case "car": "car"
        case "airplane": "airplane"
        case "bag": "bag"
        case "gift": "gift"
        case "heart": "heart"
        case "film": "film"
        case "paw": "pawprint"
        case "people": "person.2"
        case "money": "dollarsign.circle"
        case "chart": "chart.bar"
        case "book": "book"
        case "phone": "iphone"
        case "wrench": "hammer"
        case "leaf": "leaf"
        default: "square.grid.2x2"
        }
    }
}

extension FinancialData {
    public func categoryPicker(for type: TransactionType) -> [CategoryInfo] {
        var used: [String] = []
        for transaction in transactions where transaction.type == type && !used.contains(transaction.category) {
            used.append(transaction.category)
        }
        return CategoryCatalog.pickerList(categories, type: type, usedNames: used)
    }

    public func categoryInfo(named name: String, type: TransactionType) -> CategoryInfo? {
        categories.first { $0.type == type && $0.name.lowercased() == name.lowercased() }
    }
}
