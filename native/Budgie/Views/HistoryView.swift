import BudgieCore
import SwiftUI

/// All transactions, newest first, grouped by calendar day (UI_SPEC
/// "History"). The grouping (one sort plus one pass) is built off the main
/// thread whenever the transaction rows change and cached in `@State`; the
/// list only renders the cached sections, lazily.
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    @State private var days: [HistoryDay] = []
    @State private var shown: [HistoryDay] = []
    @State private var building = true
    @State private var buildTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var editing: TransactionRecord?
    @State private var pendingDelete: TransactionRecord?

    var body: some View {
        let formatter = model.moneyFormatter
        NavigationStack {
            Group {
                if building && days.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if days.isEmpty {
                    ContentUnavailableView(
                        "No transactions yet", systemImage: "list.bullet.rectangle",
                        description: Text("Transactions you add appear here."))
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(shown) { day in
                            Section {
                                ForEach(day.items) { item in
                                    Button { editing = item.record } label: {
                                        HistoryRow(item: item, formatter: formatter)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Delete", role: .destructive) { pendingDelete = item.record }
                                    }
                                }
                            } header: {
                                HistoryDayHeader(day: day, formatter: formatter)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search description or category")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        .sheet(item: $editing) { record in
            TransactionFormView(mode: .edit(record))
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible, presenting: pendingDelete
        ) { record in
            Button("Delete", role: .destructive) { Task { await model.deleteTransaction(id: record.id) } }
            Button("Cancel", role: .cancel) {}
        } message: { record in
            Text("\(record.description), \(formatter.format(record.amount))")
        }
        .onChange(of: model.ledgerRevision, initial: true) { _, _ in rebuild() }
        .onChange(of: searchText) { _, _ in refresh() }
    }

    /// Re-groups off the main thread; a newer change supersedes an older build.
    private func rebuild() {
        buildTask?.cancel()
        guard let data = model.data else {
            days = []
            building = false
            refresh()
            return
        }
        building = true
        let rows = model.ledger.newestFirst
        buildTask = Task {
            let built = await Task.detached(priority: .userInitiated) { HistoryDay.build(from: data, rows: rows) }.value
            guard !Task.isCancelled else { return }
            days = built
            building = false
            refresh()
        }
    }

    private func refresh() {
        shown = HistoryDay.filter(days, query: searchText)
    }
}

// MARK: - Model

struct HistoryItem: Identifiable, Sendable {
    let record: TransactionRecord
    let icon: CategoryInfo?
    /// Lower-cased "description category" for search.
    let haystack: String
    var id: String { record.id }
}

struct HistoryDay: Identifiable, Sendable {
    /// year * 10000 + month * 100 + day
    let id: Int
    let title: String
    var items: [HistoryItem]
    var net: Double

    private static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private struct CategoryKey: Hashable {
        let type: TransactionType
        let name: String
    }

    /// One pass over the ledger index's newest-first rows.
    static func build(from data: FinancialData, rows: [LedgerRow]) -> [HistoryDay] {
        var icons: [CategoryKey: CategoryInfo?] = [:]
        var result: [HistoryDay] = []
        for row in rows {
            let record = row.record
            let fields = record.date.fields
            let key = row.dayKey
            let categoryKey = CategoryKey(type: record.type, name: record.category)
            let icon: CategoryInfo?
            if let cached = icons[categoryKey] {
                icon = cached
            } else {
                icon = data.categoryInfo(named: record.category, type: record.type)
                icons[categoryKey] = .some(icon)
            }
            let item = HistoryItem(
                record: record, icon: icon, haystack: (record.description + "\n" + record.category).lowercased())
            let signed = record.type == .income ? record.amount : -record.amount
            if result.last?.id == key {
                result[result.count - 1].items.append(item)
                result[result.count - 1].net += signed
            } else {
                let title = "\(weekdays[fields.weekday - 1]), \(months[fields.month - 1]) \(fields.day), \(fields.year)"
                result.append(HistoryDay(id: key, title: title, items: [item], net: signed))
            }
        }
        return result
    }

    static func filter(_ days: [HistoryDay], query: String) -> [HistoryDay] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return days }
        var result: [HistoryDay] = []
        for day in days {
            let items = day.items.filter { $0.haystack.contains(needle) }
            if items.isEmpty { continue }
            var net = 0.0
            for item in items { net += item.record.type == .income ? item.record.amount : -item.record.amount }
            result.append(HistoryDay(id: day.id, title: day.title, items: items, net: net))
        }
        return result
    }
}

// MARK: - Views

private struct HistoryDayHeader: View {
    let day: HistoryDay
    let formatter: MoneyFormatter

    var body: some View {
        let net = formatter.formatSigned(day.net, plusForPositive: true)
        HStack {
            Text(day.title)
            Spacer()
            Text(net).monospacedDigit()
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.title), net \(net)")
        .accessibilityAddTraits(.isHeader)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let formatter: MoneyFormatter

    var body: some View {
        let record = item.record
        let isIncome = record.type == .income
        let amount = formatter.formatSigned(isIncome ? record.amount : -record.amount, plusForPositive: true)
        HStack(spacing: 12) {
            CategoryIcon(info: item.icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.description).font(.body).lineLimit(1)
                Text(record.category).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isIncome ? Theme.income : Color.primary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(record.description), \(record.category), \(isIncome ? "income" : "expense") \(formatter.format(record.amount))")
        .accessibilityHint("Double tap to edit")
        .accessibilityAddTraits(.isButton)
    }
}
