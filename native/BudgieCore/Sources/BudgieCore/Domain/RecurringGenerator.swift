import Foundation

/// Port of `TransactionGenerator` (MIGRATION_SPEC 7.4), bug-compatible by
/// decision (14.0 Q1): weekly/biweekly steps are 7/14 x 24 h of elapsed
/// time, so they drift an hour across DST exactly as in the Flutter app.
public enum RecurringGenerator {
    /// `_calculateNextOccurrence`.
    public static func nextOccurrence(of template: RecurringTemplate, after from: DartDateTime, calendar: DartCalendar) -> DartDateTime {
        switch template.pattern {
        case .weekly: return from.adding(days: 7)
        case .biweekly: return from.adding(days: 14)
        case .monthly:
            // `_calculateNextMonthlyOccurrence`: the template's day, clamped to
            // the next month's length, at midnight. Dart dereferences
            // `dayOfMonth!`; a monthly template without it cannot be generated.
            let f = from.fields
            var nextMonth = f.month + 1
            var nextYear = f.year
            if nextMonth > 12 {
                nextMonth = 1
                nextYear += 1
            }
            let daysInMonth = calendar.date(nextYear, nextMonth + 1, 0).day
            let day = template.dayOfMonth ?? f.day
            return calendar.date(nextYear, nextMonth, day > daysInMonth ? daysInMonth : day)
        }
    }

    public struct Result: Sendable {
        public var generated: [TransactionRecord] = []
        public var advancedTemplates: [String] = []
        public var changed: Bool { !generated.isEmpty || !advancedTemplates.isEmpty }
    }

    /// `generateDueTransactions`. Appends generated rows and advances the
    /// cursors in `data`; the caller commits both sections in one write.
    public static func generateDue(
        in data: inout FinancialData, now: DartDateTime, clock: () -> DartDateTime, newID: () -> String
    ) -> Result {
        let calendar = data.calendar
        var result = Result()
        let due = data.templates.filter { template in
            template.isActive && (template.nextOccurrence.isBefore(now) || calendar.isSameDay(template.nextOccurrence, now))
        }
        for template in due {
            // A monthly template without a day would crash the Dart app on the
            // same data; leave it untouched rather than guess.
            if template.pattern == .monthly && template.dayOfMonth == nil { continue }
            let maxLookback = now.adding(days: -90)
            var current = template.nextOccurrence
            while current.isBefore(now) || calendar.isSameDay(current, now) {
                if current.isAfter(maxLookback) || calendar.isSameDay(current, maxLookback) {
                    let record = data.addTransaction(
                        type: template.type, description: template.description, amount: template.amount,
                        category: template.category, date: current, recurringTemplateId: template.id,
                        id: newID(), now: clock())
                    result.generated.append(record)
                }
                current = nextOccurrence(of: template, after: current, calendar: calendar)
            }
            data.replaceTemplate(template.with(nextOccurrence: current))
            result.advancedTemplates.append(template.id)
        }
        return result
    }
}
