// Emits native/Fixtures/recurring/tz/<zone>/ : the recurring form's
// "Next 3 Occurrences" preview and the real generator on the templates the
// form writes, run under several zones (run.sh), including DST zones and
// America/Santiago, whose DST change happens at midnight.
//
// preview.json: the form's private `_calculatePreviewDates`
// (recurring_transaction_form.dart:713-743) is character for character the
// model's public `calculateNextOccurrence` (recurring_transaction.dart:75-101)
// stepped from the start date, which is what this calls; no app code needs
// a seam.
//
// generate.json: `TransactionGenerator.generateDueTransactions` on one
// template at a pinned clock, as the form's Save (add, then generate) and
// the Recurring page's "Generate Due Transactions" run it.

import 'package:budget_app/recurring_transaction.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_generator.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness_support.dart';

String get zoneDir => 'recurring/tz/${parityTz.replaceAll('/', '_')}';

Map<String, Object?> dt(DateTime d) => {
      'iso': d.toIso8601String(),
      'us': d.microsecondsSinceEpoch,
      'weekday': d.weekday,
    };

RecurringTransaction template(String id, RecurrencePattern pattern,
        DateTime start,
        {int? dom, DateTime? next, bool active = true}) =>
    RecurringTransaction(
      id: id,
      type: TransactionTyp.expense,
      description: id,
      amount: 10.0,
      category: 'General',
      pattern: pattern,
      startDate: start,
      nextOccurrence: next,
      // What the form's Save writes: the day for monthly only, the weekday
      // for weekly/biweekly only.
      dayOfMonth: pattern == RecurrencePattern.monthly ? dom : null,
      dayOfWeek: pattern == RecurrencePattern.monthly ? null : start.weekday,
      isActive: active,
    );

/// `_calculatePreviewDates(pattern, start, dayOfMonth, _)`: the start
/// verbatim, then two next occurrences.
List<DateTime> preview(RecurrencePattern pattern, DateTime start, int? dom) {
  var t = template('p', pattern, start, dom: dom);
  final out = <DateTime>[start];
  while (out.length < 3) {
    t = t.copyWith(nextOccurrence: out.last);
    out.add(t.calculateNextOccurrence());
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AtomicFinancialStore.instance.resetForTesting();
    pinClock(DateTime(2026, 1, 1, 12));
    seedUuids(7);
  });

  test('preview occurrences', () {
    final cases = <Map<String, Object?>>[];
    void add(String label, RecurrencePattern pattern, DateTime start,
        {int? dom}) {
      cases.add({
        'label': label,
        'pattern': pattern.name,
        'start': dt(start),
        'dayOfMonth': dom,
        'dates': preview(pattern, start, dom).map(dt).toList(),
      });
    }

    const weekly = RecurrencePattern.weekly;
    const biweekly = RecurrencePattern.biweekly;
    const monthly = RecurrencePattern.monthly;
    // Elapsed 7/14 days across the spring and fall DST changes.
    add('weekly midnight before spring DST', weekly, DateTime(2026, 3, 1));
    add('weekly on the spring DST day', weekly, DateTime(2026, 3, 8));
    add('weekly two weeks before spring DST', weekly, DateTime(2026, 2, 22));
    add('weekly midnight before fall DST', weekly, DateTime(2026, 10, 25));
    add('weekly on the Saturday before fall DST', weekly, DateTime(2026, 10, 31));
    add('biweekly across spring DST', biweekly, DateTime(2026, 2, 23));
    add('biweekly across fall DST', biweekly, DateTime(2026, 10, 19));
    add('weekly with time and microseconds', weekly,
        DateTime(2026, 6, 1, 14, 32, 11, 123, 456));
    add('weekly with time before spring DST', weekly,
        DateTime(2026, 3, 5, 14, 32, 11, 123, 456));
    add('weekly from a nonexistent local time', weekly,
        DateTime(2026, 3, 8, 2, 30));
    add('weekly from an ambiguous local time', weekly,
        DateTime(2026, 11, 1, 1, 30));
    add('weekly Santiago gap season', weekly, DateTime(2026, 8, 30));
    // Monthly: the wheel's day clamped to each month, at midnight.
    add('monthly dom 31 from Jan 31', monthly, DateTime(2026, 1, 31), dom: 31);
    add('monthly dom 30 from Jan 30', monthly, DateTime(2026, 1, 30), dom: 30);
    add('monthly dom 31 from Aug 31', monthly, DateTime(2026, 8, 31), dom: 31);
    add('monthly leap dom 29', monthly, DateTime(2028, 1, 29), dom: 29);
    add('monthly non-leap dom 29', monthly, DateTime(2027, 1, 29), dom: 29);
    add('monthly year boundary', monthly, DateTime(2026, 12, 15), dom: 15);
    add('monthly dom 1', monthly, DateTime(2026, 9, 1), dom: 1);
    add('monthly wheel day after the start day', monthly, DateTime(2026, 1, 5),
        dom: 29);
    add('monthly wheel day before the start day', monthly,
        DateTime(2026, 1, 31),
        dom: 15);
    add('monthly start with time', monthly,
        DateTime(2026, 1, 31, 14, 32, 11, 123),
        dom: 31);
    add('monthly into the Santiago midnight gap', monthly, DateTime(2026, 8, 6),
        dom: 6);
    add('monthly out of the Santiago fall-back day', monthly,
        DateTime(2026, 3, 7),
        dom: 7);
    // The form's add-mode default: now, with time of day.
    add('weekly from now', weekly, DateTime(2026, 9, 28, 9, 15, 30, 250, 125));
    add('biweekly from now', biweekly,
        DateTime(2026, 9, 28, 9, 15, 30, 250, 125));
    add('monthly from now', monthly, DateTime(2026, 9, 28, 9, 15, 30, 250, 125),
        dom: 28);

    writeJson('$fixturesRoot/$zoneDir/preview.json',
        {'tz': parityTz, 'cases': cases});
  });

  test('generate due for form-written templates', () async {
    final cases = <Map<String, Object?>>[];
    Future<void> run(String label, RecurringTransaction t, DateTime now) async {
      SharedPreferences.setMockInitialValues({});
      await AtomicFinancialStore.instance.resetForTesting();
      final transactions = TransactionModel();
      final recurring = RecurringTransactionModel();
      await recurring.addRecurringTransaction(t);
      pinClock(now);
      await TransactionGenerator(
        transactionModel: transactions,
        recurringModel: recurring,
      ).generateDueTransactions();
      final after = recurring.recurringTransactions.single;
      cases.add({
        'label': label,
        'template': t.toJson(),
        'now': dt(now),
        'generated': [
          for (final tx in transactions.transactions)
            {
              'date': dt(tx.date),
              'recurringTemplateId': tx.recurringTemplateId,
              'createdAt': tx.createdAt.toIso8601String(),
            }
        ],
        'nextOccurrence': dt(after.nextOccurrence),
        'isActive': after.isActive,
      });
      pinClock(DateTime(2026, 1, 1, 12));
    }

    const weekly = RecurrencePattern.weekly;
    const biweekly = RecurrencePattern.biweekly;
    const monthly = RecurrencePattern.monthly;
    final now = DateTime(2026, 9, 28, 9, 15, 30, 250, 125);
    // Save of a new template with the untouched default start (now): the
    // generator runs right after and logs today's occurrence.
    await run('add weekly from now', template('a1', weekly, now), now);
    await run('add biweekly from now', template('a2', biweekly, now), now);
    await run('add monthly from now', template('a3', monthly, now, dom: 28), now);
    // Save a second later: the start is still today.
    await run('add weekly, generate a second later', template('a4', weekly, now),
        now.add(const Duration(seconds: 1)));
    // A picked day (midnight) in the past, the future, and today.
    await run('add monthly picked in the past, wheel day differs',
        template('a5', monthly, DateTime(2026, 1, 5), dom: 29),
        DateTime(2026, 4, 10, 10, 30));
    await run('add weekly picked next week',
        template('a6', weekly, DateTime(2026, 10, 5)), now);
    await run('add weekly picked today', template('a7', weekly, DateTime(2026, 9, 28)),
        now);
    await run('add monthly picked 6 months back (lookback cap)',
        template('a8', monthly, DateTime(2026, 3, 31), dom: 31), now);
    // "Generate Due Transactions" after a pause: an old cursor.
    await run('resumed weekly with an old cursor',
        template('g1', weekly, DateTime(2026, 6, 1, 7, 45),
            next: DateTime(2026, 8, 3, 7, 45)),
        now);
    await run('biweekly across fall DST',
        template('g2', biweekly, DateTime(2026, 10, 19)),
        DateTime(2026, 12, 1, 8));
    await run('monthly into the Santiago midnight gap',
        template('g3', monthly, DateTime(2026, 8, 6), dom: 6),
        DateTime(2026, 10, 10, 12));
    await run('weekly through the Santiago gap',
        template('g4', weekly, DateTime(2026, 8, 30)),
        DateTime(2026, 10, 1, 12));
    await run('paused stays put',
        template('g5', weekly, DateTime(2026, 8, 3), active: false), now);
    await run('nothing due', template('g6', monthly, DateTime(2026, 10, 1), dom: 1),
        now);

    writeJson('$fixturesRoot/$zoneDir/generate.json',
        {'tz': parityTz, 'cases': cases});
  });
}
