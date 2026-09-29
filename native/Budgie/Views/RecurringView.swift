import BudgieCore
import SwiftUI

/// Recurring templates (UI_SPEC "Recurring"): active first, then paused.
struct RecurringView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FormSheet?
    @State private var pendingDelete: RecurringTemplate?

    enum FormSheet: Identifiable {
        case add
        case edit(RecurringTemplate)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let template): template.id
            }
        }

        var template: RecurringTemplate? {
            if case .edit(let template) = self { template } else { nil }
        }
    }

    var body: some View {
        Group {
            Group {
                if let data = model.data {
                    let templates = data.templates.filter(\.isActive) + data.templates.filter { !$0.isActive }
                    if templates.isEmpty {
                        ContentUnavailableView {
                            Label("No recurring transactions", systemImage: "arrow.triangle.2.circlepath")
                        } description: {
                            Text("Add rent, salary or subscriptions once and they are recorded automatically.")
                        } actions: {
                            Button("Add Recurring") { sheet = .add }
                        }
                    } else {
                        list(templates)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add recurring transaction")
                }
            }
            .sheet(item: $sheet) { sheet in
                RecurringFormView(template: sheet.template)
            }
            .confirmationDialog(
                "Delete recurring transaction?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible, presenting: pendingDelete
            ) { template in
                Button("Delete \(template.description)", role: .destructive) {
                    Task { await model.deleteTemplate(id: template.id) }
                }
            } message: { _ in
                Text("Transactions already recorded from it are kept.")
            }
        }
    }

    private func list(_ templates: [RecurringTemplate]) -> some View {
        List(templates) { template in
            Button { sheet = .edit(template) } label: { row(template) }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDelete = template
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        Task { await model.setTemplateActive(id: template.id, !template.isActive) }
                    } label: {
                        Label(template.isActive ? "Pause" : "Resume", systemImage: template.isActive ? "pause.fill" : "play.fill")
                    }
                    .tint(template.isActive ? Theme.warning : Theme.accent)
                }
        }
    }

    private func row(_ template: RecurringTemplate) -> some View {
        let formatter = model.moneyFormatter
        let amount = formatter.format(template.amount)
        let pattern = Self.patternText(template)
        let next = "Next: \(FieldDateText.mediumDate(template.nextOccurrence))"
        return HStack(spacing: 12) {
            CategoryIcon(info: model.categoryInfo(named: template.category, type: template.type))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(template.description).font(.body)
                    if !template.isActive {
                        Text("Paused")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.warning.opacity(0.2), in: Capsule())
                            .foregroundStyle(Theme.warning)
                    }
                }
                Text("\(pattern) \u{00B7} \(next)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount).monospacedDigit()
                .foregroundStyle(template.type == .income ? Theme.income : Theme.expense)
        }
        .opacity(template.isActive ? 1 : 0.65)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(template.description), \(template.type == .income ? "income" : "expense"), \(amount), \(pattern), \(next)"
                + (template.isActive ? "" : ", paused"))
        .accessibilityHint("Opens the editor")
    }

    static func patternText(_ template: RecurringTemplate) -> String {
        switch template.pattern {
        case .weekly: "Weekly"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Monthly on the \(ordinal(template.dayOfMonth ?? template.startDate.day))"
        }
    }

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

/// Add (`template == nil`) or edit a recurring template.
struct RecurringFormView: View {
    let template: RecurringTemplate?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var type: TransactionType
    @State private var descriptionText: String
    @State private var amountText: String
    @State private var category: String
    @State private var pattern: RecurrencePattern
    @State private var startDate: Date
    @State private var dayOfMonth: Int
    @State private var dayOfMonthEdited: Bool
    @State private var saving = false
    @FocusState private var focus: Field?

    private enum Field { case description, amount }

    /// `initialType` is the new template's type (the transaction form's
    /// "Make this recurring" opens it for the form's type).
    init(template: RecurringTemplate?, initialType: TransactionType = .expense) {
        self.template = template
        _type = State(initialValue: template?.type ?? initialType)
        _descriptionText = State(initialValue: template?.description ?? "")
        _amountText = State(initialValue: template.map { Self.amountString($0.amount) } ?? "")
        _category = State(initialValue: template?.category ?? "")
        _pattern = State(initialValue: template?.pattern ?? .monthly)
        _startDate = State(initialValue: template?.startDate.date ?? Date())
        let startDay = template?.startDate.day
        let storedDay = template?.dayOfMonth
        _dayOfMonth = State(initialValue: storedDay ?? startDay ?? Calendar.current.component(.day, from: Date()))
        _dayOfMonthEdited = State(initialValue: storedDay != nil && storedDay != startDay)
    }

    private var categoryOptions: [String] {
        var names = model.categories(for: type).map(\.name)
        if !category.isEmpty && !names.contains(category) { names.insert(category, at: 0) }
        return names
    }

    private var parsedAmount: Double? { Self.parseAmount(amountText) }
    private var trimmedDescription: String { descriptionText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { parsedAmount != nil && !trimmedDescription.isEmpty && !category.isEmpty && !saving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Type")
                }
                Section {
                    TextField("Description (required)", text: $descriptionText)
                        .focused($focus, equals: .description)
                        .submitLabel(.next)
                        .onSubmit { focus = .amount }
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .amount)
                        .monospacedDigit()
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    if !amountText.trimmingCharacters(in: .whitespaces).isEmpty && parsedAmount == nil {
                        Text("Enter an amount greater than zero.").foregroundStyle(Theme.expense)
                    }
                }
                Section {
                    Picker("Frequency", selection: $pattern) {
                        Text("Weekly").tag(RecurrencePattern.weekly)
                        Text("Every 2 weeks").tag(RecurrencePattern.biweekly)
                        Text("Monthly").tag(RecurrencePattern.monthly)
                    }
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                        .environment(\.timeZone, model.calendar.timeZone)
                    if pattern == .monthly {
                        Picker("Day of month", selection: Binding(
                            get: { dayOfMonth },
                            set: { dayOfMonth = $0; dayOfMonthEdited = true })
                        ) {
                            ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
                        }
                    }
                } footer: {
                    if pattern == .monthly {
                        Text("Months with fewer days use their last day.")
                    }
                }
            }
            .navigationTitle(template == nil ? "New Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .onChange(of: type) { _, _ in
                if !categoryOptions.contains(category) || category.isEmpty { category = categoryOptions.first ?? "" }
            }
            .onChange(of: startDate) { _, _ in
                if !dayOfMonthEdited { dayOfMonth = pickedDay.day }
            }
            .onAppear {
                if category.isEmpty { category = categoryOptions.first ?? "" }
                if template == nil { focus = .description }
            }
            .interactiveDismissDisabled(saving)
        }
    }

    /// The picked calendar day in the app's time zone, as year / month / day.
    private var pickedDay: (year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = model.calendar.timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: startDate)
        return (c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    private func save() {
        guard let amount = parsedAmount, canSave else { return }
        let picked = pickedDay
        let calendar = model.calendar
        // Keep the stored start (which may carry a time) unless the day changed.
        var start = calendar.date(picked.year, picked.month, picked.day)
        if let existing = template?.startDate, calendar.isSameDay(existing, start) { start = existing }
        let edit = RecurringTemplate.Edit(
            type: type, description: trimmedDescription, amount: amount, category: category, pattern: pattern,
            startDate: start, dayOfMonth: pattern == .monthly ? dayOfMonth : nil,
            dayOfWeek: pattern == .monthly ? nil : start.weekday)
        saving = true
        Task {
            if let template {
                await model.updateTemplate(id: template.id, edit)
            } else {
                await model.addTemplate(edit)
            }
            dismiss()
        }
    }

    // MARK: Amount

    /// Digits with at most one decimal separator, either the locale's or '.'.
    /// Finite and greater than zero, else nil.
    static func parseAmount(_ text: String, locale: Locale = .current) -> Double? {
        var normalized = text.trimmingCharacters(in: .whitespaces)
        if let separator = locale.decimalSeparator, separator != "." {
            normalized = normalized.replacingOccurrences(of: separator, with: ".")
        }
        guard !normalized.isEmpty, normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
            normalized.filter({ $0 == "." }).count <= 1, let value = Double(normalized), value.isFinite, value > 0
        else { return nil }
        return value
    }

    /// Shortest exact text for an amount, in the locale's separator.
    static func amountString(_ amount: Double, locale: Locale = .current) -> String {
        var text = "\(amount)"
        if text.contains("e") || text.contains("E") { text = String(format: "%.2f", amount) }
        if text.hasSuffix(".0") { text.removeLast(2) }
        if let separator = locale.decimalSeparator, separator != "." {
            text = text.replacingOccurrences(of: ".", with: separator)
        }
        return text
    }
}
