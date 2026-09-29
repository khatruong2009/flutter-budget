import BudgieCore
import SwiftUI

/// Add / edit sheet (`transaction_form.dart`, spec 02 section 1.8), as a
/// card-styled sheet with an Expense/Income toggle (D5).
///
/// Date semantics follow the Flutter form: a new transaction is stamped with
/// `model.now` unless the user picks a day, which is stored as that day at
/// midnight (`calendar.date(y, m, d)`); an edit keeps the stored value unless
/// a day is picked. The `DatePicker` only ever carries a calendar day; stored
/// values stay `DartDateTime`.
///
/// "Make this recurring" swaps this sheet's content for the recurring form
/// in place (Flutter pops the dialog and opens the recurring one), so every
/// presenter gets it without a second, stacked sheet.
struct TransactionFormView: View {
    enum Mode: Hashable {
        case add(TransactionType)
        case edit(TransactionRecord)
    }

    let mode: Mode
    /// Preselected category for a new entry (the quick-expense sheet); used
    /// only if it is in the picker list.
    var initialCategory: String? = nil

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType
    @State private var amountText: String
    @State private var descriptionText: String
    @State private var category: String
    /// Tag ids in insertion order; an edit keeps ids whose tag is gone.
    @State private var selectedTagIds: [String]
    /// The ids the last rule suggestion put in `selectedTagIds` and the user
    /// has not toggled since; a type switch drops them.
    @State private var ruleTagIds: Set<String> = []
    /// The picked day at midnight; nil keeps now (add) or the stored date.
    @State private var pickedDate: DartDateTime?
    @State private var amountError: String?
    /// The picker lists. Rows are identified by index and names compared as
    /// UTF-16 (Dart), so canonically-equivalent spellings (NFC and NFD
    /// "Café") stay two rows with their own icons.
    @State private var options: [TransactionType: [CategoryInfo]] = [:]
    /// The edited record's own category info when the list lacks its name.
    @State private var recordInfo: CategoryInfo?
    @State private var loaded = false
    @State private var saving = false
    @State private var confirmingDelete = false
    @State private var deleteConfirms = 0
    @State private var wheelTicks = 0
    @State private var showingDatePicker = false
    @State private var showingRecurring = false

    init(mode: Mode, initialCategory: String? = nil) {
        self.mode = mode
        self.initialCategory = initialCategory
        switch mode {
        case .add(let type):
            _type = State(initialValue: type)
            _amountText = State(initialValue: "")
            _descriptionText = State(initialValue: "")
            _category = State(initialValue: "")
            _selectedTagIds = State(initialValue: [])
        case .edit(let record):
            _type = State(initialValue: record.type)
            _amountText = State(initialValue: DartFixed.toStringAsFixed(record.amount, 2))
            _descriptionText = State(initialValue: record.description)
            _category = State(initialValue: record.category)
            _selectedTagIds = State(initialValue: record.tagIds)
        }
    }

    private var editing: TransactionRecord? {
        if case .edit(let record) = mode { return record }
        return nil
    }

    var body: some View {
        Group {
            if showingRecurring {
                RecurringFormView(template: nil, initialType: type)
                    .transition(.opacity)
            } else {
                form
                    .budgieSheetChrome()
                    .transition(.opacity)
            }
        }
        .motion(Motion.easeOut(Motion.fast), value: showingRecurring)
    }

    // MARK: - Derived values

    /// The category rows for the current type; in edit mode the record's own
    /// category is kept even if the catalog no longer lists it.
    private var categoryRows: [(name: String, info: CategoryInfo?)] {
        var rows: [(name: String, info: CategoryInfo?)] = (options[type] ?? []).map { ($0.name, $0) }
        if let record = editing, record.type == type, !rows.contains(where: { DartString.equal($0.name, record.category) }) {
            rows.append((record.category, recordInfo))
        }
        return rows
    }

    private func hasCategory(_ name: String) -> Bool {
        categoryRows.contains { DartString.equal($0.name, name) }
    }

    /// The stored date for this save (see the type comment).
    private func resolvedDate() -> DartDateTime {
        pickedDate ?? editing?.date ?? model.now
    }

    private var title: String {
        (editing == nil ? "Add " : "Edit ") + (type == .income ? "Income" : "Expense")
    }

    private var typeColor: Color { type == .income ? BudgieColor.income : BudgieColor.danger }

    /// The prefix glyph for the base currency (Flutter always shows `$`).
    private var currencySymbol: String { AmountInput.currencySymbolName(model.moneyFormatter) }

    // MARK: - Form

    private var form: some View {
        // Flutter's Column(Flexible(scroll), footer): the footer sits below
        // the scroll area (and above the keyboard) rather than over it, so it
        // needs no fill of its own and the sheet's side borders run unbroken.
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .textStyle(.headingMedium)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    SegmentedPills(items: ["Expense", "Income"], selection: typeIndex)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Transaction type")
                    BudgieField(
                        title: "Amount", text: $amountText, prompt: "0.00", symbol: currencySymbol, keyboard: .decimalPad,
                        error: amountError, autofocus: true
                    )
                    .padding(.top, Metrics.spacingM)
                    BudgieField(title: "Description", text: $descriptionText, prompt: "What was this for?", symbol: "text.alignleft")
                        .padding(.top, Metrics.spacingS)
                    // The wheel carries the "Category" label for VoiceOver.
                    fieldLabel("Category")
                        .accessibilityHidden(true)
                        .padding(.top, Metrics.spacingS)
                    categoryWheel
                    if !model.tags.isEmpty {
                        fieldLabel("Tags")
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, Metrics.spacingM)
                        tagChips
                    }
                    DateTile(label: "Date", value: DartDateFormat.MMMddyyyy(resolvedDate())) { showingDatePicker = true }
                        .padding(.top, Metrics.spacingM)
                    if editing != nil {
                        PillButton(title: "Delete Transaction", symbol: "trash", color: BudgieColor.danger) { confirmingDelete = true }
                            .disabled(saving)
                            .opacity(saving ? Metrics.opacityDisabled : 1)
                            .padding(.top, Metrics.spacingL)
                    }
                }
                .padding(EdgeInsets(top: Metrics.spacingS, leading: Metrics.spacingM, bottom: Metrics.spacingM, trailing: Metrics.spacingM))
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .onAppear(perform: loadCategories)
        .onChange(of: type) { _, _ in typeChanged() }
        .onChange(of: amountText) { _, _ in
            amountError = nil
            applySuggestion()
        }
        .onChange(of: descriptionText) { _, _ in applySuggestion() }
        .sheet(isPresented: $showingDatePicker) {
            DayPickerSheet(
                initial: resolvedDate(), earliest: earliestDay, latest: latestDay, calendar: model.calendar
            ) { day in
                pickedDate = day
            }
        }
        .alert("Delete Transaction", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteConfirms += 1
                Task { await delete() }
            }
        } message: {
            Text("Are you sure you want to delete this transaction?")
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: deleteConfirms)
        .interactiveDismissDisabled(saving)
    }

    private var typeIndex: Binding<Int> {
        Binding(get: { type == .income ? 1 : 0 }, set: { type = $0 == 1 ? .income : .expense })
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textStyle(.caption)
            .foregroundStyle(BudgieColor.textSecondary)
            .padding(.leading, 4)
            .padding(.bottom, 6)
    }

    // MARK: Category wheel

    private var categoryWheel: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
        return Group {
            if loaded {
                let rows = categoryRows
                Picker("Category", selection: wheelSelection) {
                    ForEach(rows.indices, id: \.self) { index in
                        CategoryWheelRow(name: rows[index].name, info: rows[index].info, color: typeColor).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .accessibilityLabel("Category")
                .accessibilityValue(category)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .clipShape(shape)
        .background(BudgieColor.chipSurface, in: shape)
        .overlay(shape.strokeBorder(BudgieColor.border, lineWidth: Metrics.borderMedium))
        .sensoryFeedback(.selection, trigger: wheelTicks)
    }

    /// The wheel's own changes (a rule's change moves it without a tick).
    private var wheelSelection: Binding<Int> {
        Binding(
            get: { categoryRows.firstIndex { DartString.equal($0.name, category) } ?? 0 },
            set: {
                let rows = categoryRows
                guard rows.indices.contains($0), !DartString.equal(rows[$0].name, category) else { return }
                category = rows[$0].name
                wheelTicks += 1
            })
    }

    // MARK: Tags

    private var tagChips: some View {
        FlowLayout(spacing: Metrics.spacingS) {
            ForEach(model.tags) { tag in
                let selected = selectedTagIds.contains(tag.id)
                Button {
                    if selected { selectedTagIds.removeAll { $0 == tag.id } } else { selectedTagIds.append(tag.id) }
                    ruleTagIds.remove(tag.id)
                } label: {
                    PillChip(
                        label: tag.name, color: selected ? BudgieColor.accent : BudgieColor.textSecondary, outlined: !selected,
                        symbol: selected ? "checkmark" : nil, style: .labelSmall, horizontalPadding: 12, verticalPadding: 8)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Metrics.spacingM) {
            HStack(spacing: Metrics.spacingM) {
                FormButton(title: "Cancel", fill: nil) { dismiss() }
                FormButton(
                    title: editing == nil ? "Add" : "Update",
                    fill: type == .income ? BudgieColor.incomeGradient : BudgieColor.expenseGradient, loading: saving
                ) {
                    Task { await save() }
                }
            }
            .disabled(saving)
            Button {
                showingRecurring = true
            } label: {
                HStack(spacing: Metrics.spacingS) {
                    Image(systemName: "repeat")
                        .font(.system(size: 17, weight: .medium))
                        .accessibilityHidden(true)
                    Text("Make this recurring").textStyle(.caption)
                }
                .foregroundStyle(BudgieColor.textSecondary)
                .padding(.horizontal, Metrics.spacingM)
                .padding(.vertical, Metrics.spacingS)
                .background(
                    BudgieColor.card.opacity(0.5), in: RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
                        .strokeBorder(BudgieColor.border, lineWidth: Metrics.borderMedium)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .opacity(saving ? Metrics.opacityDisabled : 1)
        }
        .padding(Metrics.spacingM)
    }

    // MARK: - Actions

    private func loadCategories() {
        guard !loaded else { return }
        for kind in TransactionType.allCases {
            options[kind] = model.categories(for: kind)
        }
        if let record = editing {
            recordInfo = model.categoryInfo(named: record.category, type: record.type)
        }
        if editing == nil, let initialCategory, let row = categoryRows.first(where: { DartString.equal($0.name, initialCategory) }) {
            category = row.name
        }
        if !hasCategory(category) { category = categoryRows.first?.name ?? "" }
        loaded = true
    }

    /// The Expense/Income toggle (D5; Flutter's form has none). Back on the
    /// record's own type an edit gets its stored category again; otherwise a
    /// category the new type lacks becomes its first. Tags the last rule
    /// applied go (the record's stored ids and manual picks stay), then the
    /// new type's rules run on the current description and amount.
    private func typeChanged() {
        if let record = editing, record.type == type {
            category = record.category
        } else if !hasCategory(category) {
            category = categoryRows.first?.name ?? ""
        }
        let stored = editing?.tagIds ?? []
        selectedTagIds.removeAll { ruleTagIds.contains($0) && !stored.contains($0) }
        ruleTagIds = []
        applySuggestion()
    }

    /// `applySuggestion` (transaction_form.dart:106-121): on every Amount or
    /// Description edit, a matching rule whose category is in the current
    /// list sets the category and replaces the selected tags.
    private func applySuggestion() {
        guard
            let rule = model.suggestion(
                type: type, description: descriptionText,
                amountText: Self.normalizedAmount(amountText, locale: .current)),
            let name = (options[type] ?? []).first(where: { DartString.equal($0.name, rule.category) })?.name
        else { return }
        category = name
        var tags: [String] = []
        for id in rule.tagIds where !tags.contains(id) { tags.append(id) }
        selectedTagIds = tags
        ruleTagIds = Set(tags)
    }

    private func save() async {
        guard !saving else { return }
        let parsed: Double
        switch Self.validateAmount(amountText) {
        case .failure(let error):
            amountError = error.message
            AccessibilityNotification.Announcement(error.message).post()
            return
        case .success(let value):
            parsed = value
        }
        let trimmed = DartString.trim(descriptionText)
        let description = trimmed.isEmpty ? "Transaction" : trimmed
        let date = resolvedDate()
        // The row went while the form was open (deleted elsewhere): nothing
        // to save and nothing failed.
        if let record = editing, !model.hasTransaction(id: record.id) {
            dismiss()
            return
        }
        saving = true
        let saved: Bool
        if let record = editing {
            // An untouched amount field keeps the stored value exactly (the
            // prefill is rounded to cents).
            let amount = amountText == DartFixed.toStringAsFixed(record.amount, 2) ? record.amount : parsed
            saved = await model.updateTransaction(
                id: record.id,
                TransactionRecord.Edit(
                    type: type, description: description, amount: amount, category: category, date: date,
                    tagIds: selectedTagIds))
        } else {
            saved = await model.addTransaction(
                type: type, description: description, amount: parsed, category: category, date: date,
                tagIds: selectedTagIds)
        }
        dismiss()
        if !saved {
            model.showToast(.saveFailed)
        } else if editing == nil,
            date.year != model.selectedMonth.year || date.month != model.selectedMonth.month
        {
            model.showToast(.addedTo(month: date, now: model.now))
        }
    }

    private func delete() async {
        guard let record = editing, !saving else { return }
        guard model.hasTransaction(id: record.id) else {
            dismiss()
            return
        }
        saving = true
        let deleted = await model.deleteTransaction(id: record.id)
        dismiss()
        model.showToast(deleted ? .transactionDeleted : .saveFailed)
    }

    // MARK: - Date range

    /// 2000-01-01, or the stored day when it is earlier (Flutter asserts).
    private var earliestDay: DartDateTime {
        let floor = model.calendar.date(2000, 1, 1)
        guard let stored = editing?.date, stored.isBefore(floor) else { return floor }
        return stored
    }

    /// Today, or the stored day when it is later (Flutter asserts).
    private var latestDay: DartDateTime {
        let now = model.now
        guard let stored = editing?.date, stored.isAfter(now) else { return now }
        return stored
    }

    // MARK: - Amount validation

    enum AmountError: Error, Equatable {
        case required, invalid, notPositive

        var message: String {
            switch self {
            case .required: "Amount is required"
            case .invalid: "Please enter a valid number"
            case .notPositive: "Amount must be greater than 0"
            }
        }
    }

    /// `validateForm` (transaction_form.dart:152-165): empty is required;
    /// Dart `double.tryParse` (after mapping the locale's decimal separator
    /// to '.') nil or non-finite is invalid; `<= 0` is not positive.
    nonisolated static func validateAmount(_ text: String, locale: Locale = .current) -> Result<Double, AmountError> {
        if text.isEmpty { return .failure(.required) }
        guard let value = DartDouble.tryParse(normalizedAmount(text, locale: locale)), value.isFinite else {
            return .failure(.invalid)
        }
        guard value > 0 else { return .failure(.notPositive) }
        return .success(value)
    }

    /// The text with the locale's decimal separator (e.g. ',') as '.'.
    nonisolated static func normalizedAmount(_ text: String, locale: Locale) -> String {
        guard let separator = locale.decimalSeparator, separator != "." else { return text }
        return text.replacingOccurrences(of: separator, with: ".")
    }
}

// MARK: - Pieces

/// A wheel row (transaction_form.dart:300-335): a 28pt radius-8 tile in the
/// type colour with a white category symbol, gap 16, the name.
private struct CategoryWheelRow: View {
    let name: String
    let info: CategoryInfo?
    let color: Color

    var body: some View {
        HStack(spacing: Metrics.spacingM) {
            Image(systemName: CategoryCatalog.symbol(for: info?.iconIdentifier ?? ""))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: Metrics.radiusS, style: .continuous))
                .accessibilityHidden(true)
            Text(name)
                .textStyle(.bodyMedium)
                .foregroundStyle(BudgieColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Metrics.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The footer buttons (`AppButton` medium): 48 high, radius 12; primary is
/// the type gradient with a white label (and a spinner while saving),
/// secondary is outlined. Presses to 0.95 with a light haptic; 0.38 opacity
/// when disabled.
private struct FormButton: View {
    let title: String
    /// nil is the outlined secondary button.
    let fill: LinearGradient?
    var loading = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var taps = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusM, style: .continuous)
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: Metrics.spacingS) {
                if loading {
                    ProgressView().tint(.white).accessibilityHidden(true)
                }
                Text(title).textStyle(.buttonMedium)
            }
            .foregroundStyle(fill == nil ? BudgieColor.textPrimary : .white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background {
                if let fill {
                    shape.fill(fill).shadow(color: .black.opacity(isEnabled ? 0.1 : 0), radius: 4, y: 4)
                }
            }
            .overlay {
                if fill == nil { shape.strokeBorder(BudgieColor.textPrimary.opacity(0.3), lineWidth: Metrics.borderMedium) }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle(scale: 0.95))
        .opacity(isEnabled ? 1 : Metrics.opacityDisabled)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// Wrapping rows of chips (Flutter `Wrap`), leading-aligned (also the Add
/// money dialog's quick amounts).
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in rows.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], width: CGFloat, height: CGFloat) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, widest, y + rowHeight)
    }
}

/// The date picker (Flutter `showDatePicker`): a graphical calendar in a
/// fitted sheet, Cancel / OK. The picker only carries a calendar day, read
/// back as Gregorian year / month / day in the app's time zone.
struct DayPickerSheet: View {
    let calendar: DartCalendar
    let range: ClosedRange<Date>
    let onPick: (DartDateTime) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day: Date
    @State private var height: CGFloat = 480

    init(initial: DartDateTime, earliest: DartDateTime, latest: DartDateTime, calendar: DartCalendar, onPick: @escaping (DartDateTime) -> Void) {
        self.calendar = calendar
        self.onPick = onPick
        let gregorian = Self.gregorian(calendar)
        // The whole of the earliest and latest days stay pickable.
        let lower = gregorian.startOfDay(for: Self.pickerDate(for: earliest, in: gregorian))
        let upper =
            gregorian.date(from: DateComponents(year: latest.year, month: latest.month, day: latest.day, hour: 23, minute: 59))
            ?? latest.date
        let range = lower...max(lower, upper)
        self.range = range
        _day = State(initialValue: min(max(Self.pickerDate(for: initial, in: gregorian), range.lowerBound), range.upperBound))
    }

    /// Gregorian in the app's zone, weeks starting on the user's first
    /// weekday (Flutter's picker follows the locale's).
    nonisolated static func gregorian(
        _ calendar: DartCalendar, firstWeekday: Int = Calendar.autoupdatingCurrent.firstWeekday
    ) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.firstWeekday = firstWeekday
        return gregorian
    }

    /// The picker's value for a day: 12:00 local on it, so a DST gap at
    /// midnight can never move it to a neighbouring day.
    nonisolated static func pickerDate(for day: DartDateTime, in gregorian: Calendar) -> Date {
        gregorian.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)) ?? day.date
    }

    /// The stored value for the picker's day: `DateTime(y, m, d)`.
    nonisolated static func storedDay(from date: Date, in gregorian: Calendar, calendar: DartCalendar) -> DartDateTime? {
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return calendar.date(year, month, day)
    }

    var body: some View {
        ScrollView {
            content
                .onGeometryChangeCompat { height = $0.height + 20 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .budgieSheetChrome()
        .presentationDetents([.height(height)])
    }

    private var content: some View {
        VStack(spacing: Metrics.spacingM) {
            Text("Select date")
                .textStyle(.headingSmall)
                .foregroundStyle(BudgieColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            DatePicker("Date", selection: $day, in: range, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(BudgieColor.accent)
                .environment(\.calendar, Self.gregorian(calendar))
                .environment(\.timeZone, calendar.timeZone)
            // The app's dialog buttons (Goals, Worth): an outlined Cancel and
            // an accent-filled OK, as Material's date picker actions are both
            // in the accent colour.
            HStack(spacing: 12) {
                PillButton(title: "Cancel", color: BudgieColor.textSecondary, height: 44) { dismiss() }
                    .accessibilityIdentifier("datePicker.cancel")
                PillButton(title: "OK", filled: true, height: 44) {
                    if let picked = Self.storedDay(from: day, in: Self.gregorian(calendar), calendar: calendar) { onPick(picked) }
                    dismiss()
                }
                .accessibilityIdentifier("datePicker.ok")
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.bottom, Metrics.spacingM)
    }
}
