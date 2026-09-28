import Foundation

/// Net worth queries, ported from `TransactionModel` (sections 483-585 and
/// 1326-1450 of transaction_model.dart).
public struct NetWorthHistoryPoint: Hashable, Sendable {
    public enum Granularity: String, Sendable { case day, month }
    public let date: DartDateTime
    public let assets: Double
    public let liabilities: Double
    public let assetCount: Int
    public let liabilityCount: Int
    public let granularity: Granularity
    public var netWorth: Double { assets - liabilities }
}

extension FinancialData {
    /// `getNetWorthEntriesForMonth`: entries with a value, by amount desc
    /// then lowercased name asc.
    public func netWorthEntries(forMonth month: DartDateTime, type: NetWorthEntryType? = nil) -> [NetWorthEntryRecord] {
        netWorthEntries
            .filter { (type == nil || $0.type == type) && $0.amount(forMonth: month, calendar: calendar) != nil }
            .sorted { a, b in
                let x = a.amount(forMonth: month, calendar: calendar) ?? 0
                let y = b.amount(forMonth: month, calendar: calendar) ?? 0
                if x != y { return x > y }
                return a.name.lowercased() < b.name.lowercased()
            }
    }

    func sum(at date: DartDateTime, _ type: NetWorthEntryType) -> Double {
        netWorthEntries.filter { $0.type == type }.map { $0.amount(at: date) ?? 0 }.reduce(0, +)
    }

    func count(at date: DartDateTime, _ type: NetWorthEntryType) -> Int {
        netWorthEntries.filter { $0.type == type && $0.amount(at: date) != nil }.count
    }

    public func totalAssets(forMonth month: DartDateTime) -> Double {
        sum(at: calendar.endOfNetWorthMonth(month), .asset)
    }

    public func totalLiabilities(forMonth month: DartDateTime) -> Double {
        sum(at: calendar.endOfNetWorthMonth(month), .liability)
    }

    public func netWorth(forMonth month: DartDateTime) -> Double {
        totalAssets(forMonth: month) - totalLiabilities(forMonth: month)
    }

    public func hasNetWorthData(forMonth month: DartDateTime) -> Bool {
        netWorthEntries.contains { $0.amount(forMonth: month, calendar: calendar) != nil }
    }

    public func trackedNetWorthEntryCount(forMonth month: DartDateTime) -> Int {
        netWorthEntries.filter { $0.amount(forMonth: month, calendar: calendar) != nil }.count
    }

    public func updatedNetWorthEntryCount(forMonth month: DartDateTime) -> Int {
        netWorthEntries.filter { $0.snapshot(forMonth: month) != nil }.count
    }

    public func staleNetWorthEntryCount(forMonth month: DartDateTime) -> Int {
        let key = calendar.netWorthMonthKey(month)
        return netWorthEntries.filter { entry in
            guard let latest = entry.latestSnapshot(through: calendar.endOfNetWorthMonth(month)) else { return false }
            return calendar.netWorthMonthKey(latest.recordedAt) != key
        }.count
    }

    public func netWorthChange(forMonth month: DartDateTime) -> Double? {
        if updatedNetWorthEntryCount(forMonth: month) == 0 { return nil }
        let f = month.fields
        let previous = calendar.date(f.year, f.month - 1)
        if !hasNetWorthData(forMonth: previous) { return nil }
        return netWorth(forMonth: month) - netWorth(forMonth: previous)
    }

    /// `getNetWorthAvailableMonths`: current month, selected month, and every
    /// snapshot's month; newest first.
    public func netWorthAvailableMonths(now: DartDateTime) -> [DartDateTime] {
        var keys = Set([calendar.netWorthMonthKey(calendar.month(of: now)), calendar.netWorthMonthKey(selectedNetWorthMonth)])
        for entry in netWorthEntries {
            for snapshot in entry.snapshots { keys.insert(calendar.netWorthMonthKey(snapshot.recordedAt)) }
        }
        return keys.compactMap { calendar.netWorthMonthFromKey($0) }.sorted { $0 > $1 }
    }

    /// `getNetWorthHistory` / `_buildNetWorthHistoryPoints`.
    public func netWorthHistory(limit: Int = 24) -> [NetWorthHistoryPoint] {
        var dayKeys = Set<String>()
        for entry in netWorthEntries {
            for snapshot in entry.snapshots { dayKeys.insert(calendar.netWorthDayKey(snapshot.recordedAt)) }
        }
        if dayKeys.isEmpty || limit <= 0 { return [] }
        let sortedKeys = dayKeys.sorted(by: >)
        var bucketOrder: [String] = []
        var buckets: [String: [String]] = [:]
        for dayKey in sortedKeys {
            let monthKey = calendar.netWorthMonthKey(dayFromKey(dayKey))
            if buckets[monthKey] == nil { bucketOrder.append(monthKey) }
            buckets[monthKey, default: []].append(dayKey)
        }
        var compressed = Set<String>()
        var pointCount = sortedKeys.count
        for monthKey in buckets.keys.sorted() {
            if pointCount <= limit { break }
            let reducible = buckets[monthKey]!.count - 1
            if reducible <= 0 { continue }
            compressed.insert(monthKey)
            pointCount -= reducible
        }
        var points: [NetWorthHistoryPoint] = []
        for monthKey in bucketOrder {
            if compressed.contains(monthKey) {
                let end = calendar.endOfNetWorthMonth(calendar.netWorthMonthFromKey(monthKey)!)
                points.append(point(display: end, effective: end, granularity: .month))
                continue
            }
            for dayKey in buckets[monthKey]! {
                let day = dayFromKey(dayKey)
                points.append(point(display: day, effective: calendar.endOfNetWorthDay(day), granularity: .day))
            }
        }
        return Array(points.prefix(limit))
    }

    private func dayFromKey(_ key: String) -> DartDateTime {
        let parts = key.split(separator: "-").map { Int($0)! }
        return calendar.date(parts[0], parts[1], parts[2])
    }

    private func point(display: DartDateTime, effective: DartDateTime, granularity: NetWorthHistoryPoint.Granularity) -> NetWorthHistoryPoint {
        NetWorthHistoryPoint(
            date: display, assets: sum(at: effective, .asset), liabilities: sum(at: effective, .liability),
            assetCount: count(at: effective, .asset), liabilityCount: count(at: effective, .liability), granularity: granularity)
    }
}
