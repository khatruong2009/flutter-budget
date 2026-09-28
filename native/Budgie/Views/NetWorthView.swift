import BudgieCore
import Charts
import SwiftUI

/// Read-only net worth (UI_SPEC "Net Worth"): month menu, header, history
/// chart and the asset / liability lists for the chosen month.
struct NetWorthView: View {
    @Environment(AppModel.self) private var model
    /// View state only; nil means `data.selectedNetWorthMonth`.
    @State private var pickedMonth: DartDateTime?

    var body: some View {
        NavigationStack {
            Group {
                if let data = model.data {
                    if data.netWorthEntries.isEmpty {
                        ContentUnavailableView(
                            "No accounts yet", systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Accounts are managed in the previous app version for now."))
                    } else {
                        content(data)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Net Worth")
            .toolbar {
                if let data = model.data, !data.netWorthEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { monthMenu(data) }
                }
            }
        }
    }

    private func currentMonth(_ data: FinancialData) -> DartDateTime {
        model.calendar.month(of: pickedMonth ?? data.selectedNetWorthMonth)
    }

    private func monthMenu(_ data: FinancialData) -> some View {
        let calendar = model.calendar
        let current = currentMonth(data)
        return Menu {
            Picker(
                "Month",
                selection: Binding(
                    get: { calendar.netWorthMonthKey(current) },
                    set: { pickedMonth = calendar.netWorthMonthFromKey($0) })
            ) {
                ForEach(data.netWorthAvailableMonths(now: model.now), id: \.self) { month in
                    Text(FieldDateText.monthYear(month)).tag(calendar.netWorthMonthKey(month))
                }
            }
        } label: {
            Label(FieldDateText.monthYear(current), systemImage: "calendar")
        }
        .accessibilityLabel("Month, \(FieldDateText.monthYear(current))")
    }

    private func content(_ data: FinancialData) -> some View {
        let month = currentMonth(data)
        let formatter = model.moneyFormatter
        let assets = data.netWorthEntries(forMonth: month, type: .asset)
        let liabilities = data.netWorthEntries(forMonth: month, type: .liability)
        return List {
            Section { header(data, month: month, formatter: formatter) }
            Section("History") { history(data, formatter: formatter) }
            entrySection("Assets", entries: assets, month: month, formatter: formatter)
            entrySection("Liabilities", entries: liabilities, month: month, formatter: formatter)
        }
    }

    // MARK: Header

    private func header(_ data: FinancialData, month: DartDateTime, formatter: MoneyFormatter) -> some View {
        let netWorth = data.netWorth(forMonth: month)
        let assets = data.totalAssets(forMonth: month)
        let liabilities = data.totalLiabilities(forMonth: month)
        let change = data.netWorthChange(forMonth: month)
        let f = month.fields
        let previous = model.calendar.date(f.year, f.month - 1)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Net worth").font(.subheadline).foregroundStyle(.secondary)
                Text(formatter.formatSigned(netWorth))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            if let change {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(formatter.formatSigned(change, plusForPositive: true)) vs \(FieldDateText.monthYear(previous))")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(change >= 0 ? Theme.income : Theme.expense)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(change >= 0 ? "Up" : "Down") \(formatter.format(abs(change))) compared with \(FieldDateText.monthYear(previous))"
                )
            }
            HStack {
                totalColumn("Assets", value: assets, color: Theme.income, formatter: formatter)
                Spacer()
                totalColumn("Liabilities", value: liabilities, color: Theme.expense, formatter: formatter)
            }
        }
        .padding(.vertical, 4)
    }

    private func totalColumn(_ title: String, value: Double, color: Color, formatter: MoneyFormatter) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(formatter.format(value)).font(.headline).monospacedDigit().foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Chart

    @ViewBuilder
    private func history(_ data: FinancialData, formatter: MoneyFormatter) -> some View {
        let points = Array(data.netWorthHistory(limit: 24).reversed())
        if points.isEmpty {
            Text("No history yet").foregroundStyle(.secondary)
        } else {
            Chart(points, id: \.date) { point in
                LineMark(x: .value("Date", point.date.date), y: .value("Net worth", point.netWorth))
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", point.date.date), y: .value("Net worth", point.netWorth))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(30)
                    .accessibilityLabel(FieldDateText.mediumDate(point.date))
                    .accessibilityValue(formatter.formatSigned(point.netWorth))
            }
            .chartYAxis {
                if !formatter.hideBalances {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter.formatSigned(amount, decimalDigits: 0))
                            }
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Net worth over time")
            .accessibilityValue(summary(points, formatter: formatter))
        }
    }

    private func summary(_ points: [NetWorthHistoryPoint], formatter: MoneyFormatter) -> String {
        guard let first = points.first, let last = points.last else { return "" }
        let start = "\(FieldDateText.mediumDate(first.date)), \(formatter.formatSigned(first.netWorth))"
        if points.count == 1 { return "One point, \(start)" }
        return "\(points.count) points from \(start), to \(FieldDateText.mediumDate(last.date)), \(formatter.formatSigned(last.netWorth))"
    }

    // MARK: Entries

    @ViewBuilder
    private func entrySection(_ title: String, entries: [NetWorthEntryRecord], month: DartDateTime, formatter: MoneyFormatter) -> some View {
        Section(title) {
            if entries.isEmpty {
                Text("None for this month").foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                let amount = entry.amount(forMonth: month, calendar: model.calendar) ?? 0
                let carried = carriedFrom(entry, month: month)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        if let carried {
                            Text("carried from \(FieldDateText.monthYear(carried))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(formatter.format(amount)).monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.name)
                .accessibilityValue(
                    formatter.format(amount) + (carried.map { ", carried from \(FieldDateText.monthYear($0))" } ?? ""))
            }
        }
    }

    /// The month of the entry's latest snapshot when it is earlier than `month`.
    private func carriedFrom(_ entry: NetWorthEntryRecord, month: DartDateTime) -> DartDateTime? {
        let calendar = model.calendar
        guard let latest = entry.latestSnapshot(through: calendar.endOfNetWorthMonth(month)),
            calendar.netWorthMonthKey(latest.recordedAt) != calendar.netWorthMonthKey(month)
        else { return nil }
        return calendar.month(of: latest.recordedAt)
    }
}

/// Date text built from `DartDateTime` fields (never `Date` arithmetic).
enum FieldDateText {
    private static let months = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
        "December",
    ]

    /// "September 2026"
    static func monthYear(_ d: DartDateTime) -> String {
        let f = d.fields
        return "\(months[f.month - 1]) \(f.year)"
    }

    /// "Oct 5, 2026"
    static func mediumDate(_ d: DartDateTime) -> String {
        let f = d.fields
        return "\(months[f.month - 1].prefix(3)) \(f.day), \(f.year)"
    }
}
