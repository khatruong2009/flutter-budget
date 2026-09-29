import Foundation

/// Display strings of the Worth tab (net_worth_page.dart), each checked
/// against the Dart code in Fixtures/worth/formatting.json. Money goes
/// through `MoneyFormatter`, so the base currency and Hide balances apply
/// wherever Flutter's `MoneyFormatter` applies them.

extension MoneyFormatter {
    /// `_formatCompactCurrencyNoDecimals` (NW:2950-2959): intl's compact
    /// currency with `decimalDigits: 1`, which keeps three significant digits
    /// (`$1.23K`, `$12.3K`, `$123K`, `$999.99` -> `$1K`, `5` -> `$5.0`), with
    /// a leading `-` for negatives (`-••••` when balances are hidden).
    public func formatCompact(_ value: Double) -> String {
        if value < 0 { return "-" + format(abs(value), decimalDigits: 1, compact: true) }
        return format(value, decimalDigits: 1, compact: true)
    }

    /// The history chips and timeline deltas: `+` for `>= 0`, then
    /// `formatCompact` (which carries the `-`).
    public func formatCompactDelta(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + formatCompact(value)
    }
}

public enum NetWorthText {
    /// Hero eyebrow: `TOTAL · MARCH 2026` (U+00B7).
    public static func heroEyebrow(month: DartDateTime) -> String {
        "TOTAL \u{00B7} " + DartString.uppercase(DartDateFormat.yMMMM(month))
    }

    /// Hero accessibility label: `Net worth -$1,234.56`.
    public static func heroAccessibilityLabel(netWorth: Double, formatter: MoneyFormatter) -> String {
        "Net worth " + formatter.formatSigned(netWorth)
    }

    /// `_DeltaPill` (NW:338-349): `+$4,120 · +2.3% this month`; the percent is
    /// `±—` when `|previous| <= 0.001`. Zero change is `+`.
    public static func deltaPill(change: Double, previousNetWorth: Double, formatter: MoneyFormatter) -> String {
        let sign = change >= 0 ? "+" : "-"
        let dollars = sign + formatter.formatSigned(abs(change), decimalDigits: 0)
        let percent = abs(previousNetWorth) > 0.001
            ? sign + DartFixed.toStringAsFixed(abs(change) / abs(previousNetWorth) * 100, 1) + "%"
            : sign + "\u{2014}"
        return "\(dollars) \u{00B7} \(percent) this month"
    }

    /// Row share label: `78.9% of assets` (the ACTIVE tab's word).
    public static func rowShare(_ share: Double, isAssetsTab: Bool) -> String {
        DartFixed.toStringAsFixed(share * 100, 1) + "% of " + (isAssetsTab ? "assets" : "liabilities")
    }

    /// Row change: `+50.0%`, `-12.5%`, or `—` when there is none.
    public static func rowChange(_ percentChange: Double?) -> String {
        guard let percentChange else { return "\u{2014}" }
        return (percentChange >= 0 ? "+" : "") + DartFixed.toStringAsFixed(percentChange, 1) + "%"
    }

    /// Empty account list: `No assets tracked for March 2026.`
    public static func emptyList(isAssetsTab: Bool, month: DartDateTime) -> String {
        "No \(isAssetsTab ? "assets" : "liabilities") tracked for \(DartDateFormat.yMMMM(month))."
    }

    /// Growth chart axis label: `MAR '26`.
    public static func axisLabel(_ date: DartDateTime) -> String {
        DartString.uppercase(DartDateFormat.MMMyy(date))
    }

    /// Hover card title: `March 2026` for a month point, `Mar 5, 2026` for a day.
    public static func hoverTitle(_ point: NetWorthHistoryPoint) -> String {
        point.granularity == .month ? DartDateFormat.yMMMM(point.date) : DartDateFormat.yMMMd(point.date)
    }

    /// History hero chip: `1 snapshot`, `2 snapshots`.
    public static func snapshotCount(_ n: Int) -> String { "\(n) \(n == 1 ? "snapshot" : "snapshots")" }

    /// Timeline header: `1 entry`, `2 entries`.
    public static func entryCount(_ n: Int) -> String { "\(n) \(n == 1 ? "entry" : "entries")" }

    /// History hero subtitle: `Last update Mar 5, 2026` or `No recorded updates yet`.
    public static func lastUpdate(_ date: DartDateTime?) -> String {
        date.map { "Last update " + DartDateFormat.yMMMd($0) } ?? "No recorded updates yet"
    }

    /// Trend card subtitle: `Showing the first recorded balance.` for one
    /// point, else `Jan 20 to Mar 5`.
    public static func trendRange(_ history: [NetWorthSnapshotRecord]) -> String {
        guard let first = history.first, let last = history.last else { return "" }
        if history.count == 1 { return "Showing the first recorded balance." }
        return DartDateFormat.MMMd(first.recordedAt) + " to " + DartDateFormat.MMMd(last.recordedAt)
    }

    /// Account history trend axis: `JAN 20`.
    public static func trendAxisLabel(_ date: DartDateTime) -> String {
        DartString.uppercase(DartDateFormat.MMMd(date))
    }

    /// Delete-account confirmation body.
    public static func deleteAccountMessage(name: String) -> String {
        "Remove \(name) and all of its saved monthly balances?"
    }

    /// Delete-snapshot confirmation body (`yMMMd().add_jm()`, U+202F before
    /// AM/PM).
    public static func deleteSnapshotMessage(recordedAt: DartDateTime, name: String) -> String {
        "Remove the \(DartDateFormat.yMMMd(recordedAt)) \(DartDateFormat.jm(recordedAt)) balance for \(name)? "
            + "This only removes this one data point."
    }
}

/// The editor's amount field (`_CurrencyInputFormatter`, the prefill and
/// `_save`'s parse; NW:2161-2200, 2236-2242, 2449-2466). Flutter fixes all
/// three to en_US (`.` decimal, `,` grouping) whatever the app locale.
public enum NetWorthAmountInput {
    /// `NumberFormat('#,##0.##').format(amount)` in en_US: grouped, at most
    /// two decimals (intl rounding), no trailing zeros: `1,000`, `2,750.25`,
    /// `10,000.5`, `0.005` -> `0.01`.
    public static func prefill(_ amount: Double) -> String {
        let data = IntlLocaleData.resolve(nil)
        return IntlNumberSpec(
            decimalSeparator: data.decimalSeparator, groupSeparator: data.groupSeparator,
            positivePrefix: "", positiveSuffix: "", negativePrefix: "-", negativeSuffix: "",
            minimumFractionDigits: 0, maximumFractionDigits: 2, isForCurrency: false, decimalDigits: 2
        ).format(amount)
    }

    /// `_CurrencyInputFormatter.formatEditUpdate`: the text after an edit.
    /// Commas are dropped and re-inserted every three integer digits; an
    /// edit that is not ASCII digits with at most one `.` and two decimals
    /// is refused (the old text stays). The caret goes to the end.
    public static func sanitize(old: String, new: String) -> String {
        if new.isEmpty { return new }
        let stripped = Array(new.utf16.filter { $0 != 0x2C })
        let isDigit: (UInt16) -> Bool = { (0x30...0x39).contains($0) }
        let dot = stripped.firstIndex(of: 0x2E)
        let integer = dot.map { Array(stripped[..<$0]) } ?? stripped
        let decimals = dot.map { Array(stripped[($0 + 1)...]) }
        guard integer.allSatisfy(isDigit), (decimals ?? []).allSatisfy(isDigit), (decimals?.count ?? 0) <= 2 else {
            return old
        }
        var formatted: [UInt16] = []
        for (i, unit) in integer.enumerated() {
            if i > 0 && (integer.count - i) % 3 == 0 { formatted.append(0x2C) }
            formatted.append(unit)
        }
        if let decimals { formatted += [0x2E] + decimals }
        return String(decoding: formatted, as: UTF16.self)
    }

    /// `_save`: `double.tryParse(text.replaceAll(',', '').trim())`, valid
    /// when it parses and is `>= 0` (zero is valid). Non-finite values are
    /// also refused here (Flutter accepts a 330-digit string as Infinity
    /// and then fails every save).
    public static func parse(_ text: String) -> Double? {
        let clean = DartString.trim(String(decoding: text.utf16.filter { $0 != 0x2C }, as: UTF16.self))
        guard let value = DartDouble.tryParse(clean), value.isFinite, value >= 0 else { return nil }
        return value
    }
}
