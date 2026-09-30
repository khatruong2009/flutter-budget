import Foundation
import Testing

@testable import BudgieCore

/// Zones of Fixtures/recurring: the four logic zones plus America/Santiago,
/// whose DST change happens at midnight.
let recurringZones = fixtureZones + ["America/Santiago"]

private func recurringFixture(_ zone: String, _ file: String) throws -> J {
    J(try JSONParser.parse([UInt8](Fixtures.data("recurring/tz/\(zone.replacingOccurrences(of: "/", with: "_"))/\(file)"))))
}

/// A fixture instant, from its microseconds (an ambiguous local time
/// cannot be re-derived from its ISO text).
private func instant(_ j: J, _ tz: TimeZone) -> DartDateTime {
    DartDateTime(microsecondsSinceEpoch: Int64(j["us"].int!), timeZone: tz)
}

@Suite("Recurring: form preview and generation against Dart in five time zones")
struct RecurringParityTests {
    @Test("Next 3 Occurrences preview", arguments: recurringZones)
    func preview(zone: String) throws {
        let tz = TimeZone(identifier: zone)!
        let calendar = DartCalendar(timeZone: tz)
        let fixture = try recurringFixture(zone, "preview.json")
        #expect(fixture["tz"].string == zone)
        #expect(fixture["cases"].array.count >= 25)
        for c in fixture["cases"].array {
            let start = instant(c["start"], tz)
            let label = "\(zone) \(c["label"].string!)"
            #expect(start.toIso8601String() == c["start"]["iso"].string, "\(label) start")
            let pattern = RecurrencePattern(rawValue: c["pattern"].string!)!
            let dates = RecurringGenerator.previewOccurrences(
                pattern: pattern, start: start, dayOfMonth: c["dayOfMonth"].int, calendar: calendar)
            let expected = c["dates"].array
            #expect(dates.map { $0.toIso8601String() } == expected.map { $0["iso"].string! }, "\(label) iso")
            #expect(dates.map(\.microsecondsSinceEpoch) == expected.map { Int64($0["us"].int!) }, "\(label) us")
            #expect(dates.map(\.weekday) == expected.map { $0["weekday"].int! }, "\(label) weekday")
            #expect(dates.map(DartDateFormat.EEEEMMMddyyyy).count == 3)
        }
    }

    @Test("generate due on form-written templates", arguments: recurringZones)
    func generate(zone: String) throws {
        let tz = TimeZone(identifier: zone)!
        let calendar = DartCalendar(timeZone: tz)
        let fixture = try recurringFixture(zone, "generate.json")
        for c in fixture["cases"].array {
            let template = RecurringTemplate.parse(c["template"].value!, calendar: calendar, newID: { "x" })!
            var data = FinancialData.load(
                FinancialSnapshot(revision: 0, sections: JSONObject(ordered: [(Section.recurringTransactions, .array([.object(template.raw)]))])),
                preferences: InMemoryPreferences(), calendar: calendar, now: { calendar.date(2026, 1, 1, 12) }, newID: { "id" }
            ).data
            let now = instant(c["now"], tz)
            _ = RecurringGenerator.generateDue(in: &data, now: now, clock: { now }, newID: { UUID().uuidString })
            let label = "\(zone) \(c["label"].string!)"
            let generated = c["generated"].array
            #expect(data.transactions.map { $0.date.toIso8601String() } == generated.map { $0["date"]["iso"].string! }, "\(label) dates")
            #expect(data.transactions.map(\.date.microsecondsSinceEpoch) == generated.map { Int64($0["date"]["us"].int!) }, "\(label) us")
            #expect(data.transactions.map { $0.createdAt.toIso8601String() } == generated.map { $0["createdAt"].string! }, "\(label) createdAt")
            #expect(data.transactions.allSatisfy { $0.recurringTemplateId == template.id }, "\(label) link")
            #expect(data.templates[0].nextOccurrence.toIso8601String() == c["nextOccurrence"]["iso"].string, "\(label) cursor")
            #expect(data.templates[0].nextOccurrence.microsecondsSinceEpoch == Int64(c["nextOccurrence"]["us"].int!), "\(label) cursor us")
            #expect(data.templates[0].isActive == c["isActive"].bool, "\(label) active")
        }
    }
}
