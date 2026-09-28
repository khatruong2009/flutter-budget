import Foundation

/// A category definition (`BudgetCategory` in the Flutter app). Read-only in
/// the MVP: the Swift app never writes the `categories` section.
public struct CategoryInfo: Hashable, Sendable, Identifiable {
    public let id: String
    public let type: TransactionType
    public let name: String
    public let iconIdentifier: String
    public let colorToken: String
    public let sortOrder: Int
    public let isArchived: Bool
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
            CategoryInfo(id: "expense-\(slug(c.0))", type: .expense, name: c.0, iconIdentifier: c.1, colorToken: c.2, sortOrder: i, isArchived: false)
        } + incomes.enumerated().map { i, c in
            CategoryInfo(id: "income-\(slug(c.0))", type: .income, name: c.0, iconIdentifier: c.1, colorToken: c.2, sortOrder: i, isArchived: false)
        }
    }()

    /// `CategoryProvider.load`: the stored list when it decodes (with Dart's
    /// defaults for missing keys), else the built-in seeds. Any malformed row
    /// makes Dart fall back to the seeds for the whole list; so does this.
    public static func load(_ section: JSONValue?) -> [CategoryInfo] {
        guard case .array(let rows)? = section, !rows.isEmpty else { return builtIn }
        var result: [CategoryInfo] = []
        for row in rows {
            guard let object = row.objectValue, let id = object["id"]?.stringValue, let name = object["name"]?.stringValue else {
                return builtIn
            }
            let sort = object["sortOrder"]?.numberValue.map { Int(DartNumbers.toInt($0.doubleValue, lexeme: $0)) } ?? 0
            result.append(CategoryInfo(
                id: id, type: object["type"]?.stringValue == "income" ? .income : .expense, name: name,
                iconIdentifier: object["iconIdentifier"]?.stringValue ?? "square_grid_2x2",
                colorToken: object["colorToken"]?.stringValue ?? "accent", sortOrder: sort,
                isArchived: object["isArchived"]?.boolValue ?? false))
        }
        return result
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
            result.append(CategoryInfo(
                id: "\(type.rawValue)-legacy-\(name)", type: type, name: name, iconIdentifier: "square_grid_2x2",
                colorToken: "accent", sortOrder: Int.max, isArchived: false))
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
    public var categories: [CategoryInfo] { CategoryCatalog.load(sections[Section.categories]) }

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
