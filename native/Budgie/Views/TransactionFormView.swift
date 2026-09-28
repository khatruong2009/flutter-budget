import BudgieCore
import SwiftUI

/// Add / edit sheet (UI_SPEC "Transaction form").
///
/// Date semantics follow the Flutter form: a new transaction is stamped with
/// `model.now` unless the user picks a day, which is stored as that day at
/// midnight (`calendar.date(y, m, d)`); an edit keeps the stored value unless
/// a day is picked. The `DatePicker` only ever carries a calendar day; stored
/// values stay `DartDateTime`.
struct TransactionFormView: View {
    enum Mode: Hashable {
        case add(TransactionType)
        case edit(TransactionRecord)
    }

    let mode: Mode

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType
    @State private var amountText: String
    @State private var descriptionText: String
    @State private var category: String
    @State private var pickedDay: Date
    @State private var dayIsPicked = false
    @State private var options: [TransactionType: [String]] = [:]
    @State private var infos: [TransactionType: [String: CategoryInfo]] = [:]
    @State private var saving = false
    @State private var confirmingDelete = false
    @FocusState private var amountFocused: Bool

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add(let type):
            _type = State(initialValue: type)
            _amountText = State(initialValue: "")
            _descriptionText = State(initialValue: "")
            _category = State(initialValue: "")
            _pickedDay = State(initialValue: Date())
        case .edit(let record):
            _type = State(initialValue: record.type)
            _amountText = State(initialValue: DartFixed.toStringAsFixed(record.amount, 2))
            _descriptionText = State(initialValue: record.description)
            _category = State(initialValue: record.category)
            let fields = record.date.fields
            _pickedDay = State(
                initialValue: Calendar.current.date(from: DateComponents(year: fields.year, month: fields.month, day: fields.day)) ?? Date())
        }
    }

    private var editing: TransactionRecord? {
        if case .edit(let record) = mode { return record }
        return nil
    }

    // MARK: - Derived values

    private var parsedAmount: Double? { Self.parseAmount(amountText) }

    private var canSave: Bool { parsedAmount != nil && !saving }

    /// The category names for the current type; in edit mode the record's own
    /// category is always present even if the catalog no longer lists it.
    private var categoryNames: [String] {
        var names = options[type] ?? []
        if let record = editing, record.type == type, !names.contains(record.category) {
            names.append(record.category)
        }
        return names
    }

    private var dateRange: ClosedRange<Date> {
        let earliest = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        var latest = Date()
        if let record = editing {
            let fields = record.date.fields
            if let stored = Calendar.current.date(from: DateComponents(year: fields.year, month: fields.month, day: fields.day)) {
                latest = max(latest, stored)
            }
        }
        return min(earliest, latest)...latest
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Transaction type")
                }

                Section {
                    TextField("Amount", text: $amountText, prompt: Text("0.00"))
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                        .focused($amountFocused)
                        .accessibilityLabel("Amount")
                    TextField("Description", text: $descriptionText, prompt: Text("Optional"))
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Description")
                } footer: {
                    if !amountText.isEmpty, parsedAmount == nil {
                        Text("Enter an amount greater than 0.").foregroundStyle(Theme.expense)
                    }
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(categoryNames, id: \.self) { name in
                            Label {
                                Text(name)
                            } icon: {
                                CategoryIcon(info: infos[type]?[name], size: 24)
                            }
                            .tag(name)
                        }
                    }
                    DatePicker("Date", selection: dayBinding, in: dateRange, displayedComponents: .date)
                }

                if editing != nil {
                    Section {
                        Button("Delete Transaction", role: .destructive) { confirmingDelete = true }
                            .disabled(saving)
                    }
                }
            }
            .navigationTitle(editing == nil ? (type == .income ? "Add Income" : "Add Expense") : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this transaction?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            }
            .interactiveDismissDisabled(saving)
        }
        .tint(Theme.accent)
        .onAppear {
            loadCategories()
            if editing == nil { amountFocused = true }
        }
        .onChange(of: type) { _, _ in
            let names = categoryNames
            if !names.contains(category) { category = names.first ?? "" }
        }
    }

    private var dayBinding: Binding<Date> {
        Binding(
            get: { pickedDay },
            set: {
                pickedDay = $0
                dayIsPicked = true
            })
    }

    // MARK: - Actions

    private func loadCategories() {
        for kind in TransactionType.allCases {
            let list = model.categories(for: kind)
            options[kind] = list.map(\.name)
            infos[kind] = Dictionary(list.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        }
        if !categoryNames.contains(category) { category = categoryNames.first ?? "" }
    }

    /// The stored date for this save (see the type comment).
    private func resolvedDate() -> DartDateTime {
        if dayIsPicked {
            let parts = Calendar.current.dateComponents([.year, .month, .day], from: pickedDay)
            if let year = parts.year, let month = parts.month, let day = parts.day {
                return model.calendar.date(year, month, day)
            }
        }
        return editing?.date ?? model.now
    }

    private func save() async {
        guard let amount = parsedAmount, !saving else { return }
        saving = true
        let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmed.isEmpty ? "Transaction" : trimmed
        let date = resolvedDate()
        if let record = editing {
            // An untouched amount field keeps the stored value exactly (the
            // prefill is rounded to cents).
            let amount = amountText == DartFixed.toStringAsFixed(record.amount, 2) ? record.amount : amount
            await model.updateTransaction(
                id: record.id,
                TransactionRecord.Edit(type: type, description: description, amount: amount, category: category, date: date))
        } else {
            await model.addTransaction(type: type, description: description, amount: amount, category: category, date: date)
        }
        dismiss()
    }

    private func delete() async {
        guard let record = editing, !saving else { return }
        saving = true
        await model.deleteTransaction(id: record.id)
        dismiss()
    }

    // MARK: - Amount parsing

    /// Digits with at most one decimal separator: the current locale's, or
    /// '.'. Valid iff finite and greater than 0.
    static func parseAmount(_ text: String) -> Double? {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = Locale.current.decimalSeparator, separator != "." {
            normalized = normalized.replacingOccurrences(of: separator, with: ".")
        }
        guard !normalized.isEmpty,
            normalized.allSatisfy({ $0 == "." || ("0"..."9").contains($0) }),
            normalized.filter({ $0 == "." }).count <= 1
        else { return nil }
        if normalized.hasPrefix(".") { normalized = "0" + normalized }
        if normalized.hasSuffix(".") { normalized += "0" }
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }
}
