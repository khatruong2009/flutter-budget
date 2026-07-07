import 'dart:convert';

import 'package:budget_app/transaction.dart';
import 'package:budget_app/voice_expense_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed "today" used everywhere so nothing depends on the wall clock.
  // Includes a time component so future-date clamping can be exercised
  // against same-day ISO dates that parse to local midnight.
  final today = DateTime(2026, 7, 7, 12, 0, 0);

  String jsonOutput({
    Object? type,
    Object? description,
    Object? amount,
    Object? category,
    Object? date,
    Map<String, Object?>? extra,
  }) {
    final map = <String, Object?>{
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (amount != null) 'amount': amount,
      if (category != null) 'category': category,
      if (date != null) 'date': date,
      ...?extra,
    };
    return jsonEncode(map);
  }

  group('type', () {
    test('defaults to expense when type is missing', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'coffee', amount: 4, category: 'Eating Out'),
        'coffee for four dollars',
        today,
      );
      expect(txn.type, TransactionTyp.expense);
    });

    test('honors income when JSON says income', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'income',
          description: 'paycheck',
          amount: 3000,
          category: 'Salary',
        ),
        'got paid three thousand',
        today,
      );
      expect(txn.type, TransactionTyp.income);
    });

    test('clamps a garbage type value to expense', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'refund-or-something',
          description: 'stuff',
          amount: 10,
          category: 'General',
        ),
        'bought stuff',
        today,
      );
      expect(txn.type, TransactionTyp.expense);
    });

    test('a non-string type value falls back to expense', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 42,
          description: 'stuff',
          amount: 10,
          category: 'General',
        ),
        'bought stuff',
        today,
      );
      expect(txn.type, TransactionTyp.expense);
    });
  });

  group('category exact-match clamp and fallback', () {
    test('valid expense category passes through', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'expense',
          description: 'chipotle',
          amount: 12.5,
          category: 'Eating Out',
        ),
        'twelve fifty for lunch at chipotle',
        today,
      );
      expect(txn.category, 'Eating Out');
    });

    test('unknown expense category falls back to General', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'expense',
          description: 'mystery',
          amount: 5,
          category: 'Not A Real Category',
        ),
        'spent five on a mystery',
        today,
      );
      expect(txn.category, 'General');
    });

    test('valid income category passes through', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'income',
          description: 'dividends',
          amount: 100,
          category: 'Investment',
        ),
        'got a hundred in dividends',
        today,
      );
      expect(txn.category, 'Investment');
    });

    test('unknown income category falls back to Other', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'income',
          description: 'windfall',
          amount: 500,
          category: 'Bonus',
        ),
        'received five hundred bonus',
        today,
      );
      expect(txn.category, 'Other');
    });

    test('an expense category is not honored for an income type', () {
      // "Groceries" is an expense category, invalid for income -> Other.
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'income',
          description: 'thing',
          amount: 20,
          category: 'Groceries',
        ),
        'income thing',
        today,
      );
      expect(txn.category, 'Other');
    });

    test('missing category falls back per type (expense -> General)', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(type: 'expense', description: 'thing', amount: 7),
        'spent seven',
        today,
      );
      expect(txn.category, 'General');
    });

    test('missing category falls back per type (income -> Other)', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(type: 'income', description: 'thing', amount: 7),
        'earned seven',
        today,
      );
      expect(txn.category, 'Other');
    });

    test('a non-string category falls back', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'expense',
          description: 'thing',
          amount: 7,
          category: 99,
        ),
        'spent seven',
        today,
      );
      expect(txn.category, 'General');
    });
  });

  group('amount', () {
    test('numeric double is honored', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', amount: 12.5, category: 'Eating Out'),
        'twelve fifty lunch',
        today,
      );
      expect(txn.amount, 12.5);
    });

    test('numeric integer is coerced to double', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', amount: 3000, category: 'Eating Out'),
        'three thousand',
        today,
      );
      expect(txn.amount, 3000.0);
      expect(txn.amount, isA<double>());
    });

    test('string amount like "12.50" is parsed to double', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: '12.50',
          category: 'Eating Out',
        ),
        'twelve fifty lunch',
        today,
      );
      expect(txn.amount, 12.5);
    });

    test('unparseable string amount becomes 0.0 sentinel', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 'a lot',
          category: 'Eating Out',
        ),
        'a lot for lunch',
        today,
      );
      expect(txn.amount, 0.0);
    });

    test('missing amount becomes 0.0 sentinel', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', category: 'Eating Out'),
        'lunch',
        today,
      );
      expect(txn.amount, 0.0);
    });

    test('negative amount is clamped to 0.0', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', amount: -5, category: 'Eating Out'),
        'negative five',
        today,
      );
      expect(txn.amount, 0.0);
    });

    test('a boolean amount becomes 0.0 sentinel', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', amount: true, category: 'Eating Out'),
        'lunch',
        today,
      );
      expect(txn.amount, 0.0);
    });
  });

  group('description', () {
    test('valid description passes through (trimmed)', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: '  Chipotle  ',
          amount: 12.5,
          category: 'Eating Out',
        ),
        'twelve fifty at chipotle',
        today,
      );
      expect(txn.description, 'Chipotle');
    });

    test('missing description falls back to the raw transcript', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(amount: 12.5, category: 'Eating Out'),
        'twelve fifty at chipotle',
        today,
      );
      expect(txn.description, 'twelve fifty at chipotle');
    });

    test('empty/whitespace description falls back to the raw transcript', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: '   ',
          amount: 12.5,
          category: 'Eating Out',
        ),
        'twelve fifty at chipotle',
        today,
      );
      expect(txn.description, 'twelve fifty at chipotle');
    });

    test('a non-string description falls back to the raw transcript', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 123,
          amount: 12.5,
          category: 'Eating Out',
        ),
        'twelve fifty at chipotle',
        today,
      );
      expect(txn.description, 'twelve fifty at chipotle');
    });
  });

  group('date', () {
    test('valid past ISO date passes through', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: '2026-03-15',
        ),
        'lunch on march 15',
        today,
      );
      expect(txn.date, DateTime(2026, 3, 15));
    });

    test('missing date defaults to today', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(description: 'lunch', amount: 12.5, category: 'Eating Out'),
        'lunch',
        today,
      );
      expect(txn.date, today);
    });

    test('invalid date string defaults to today', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: 'not-a-date',
        ),
        'lunch',
        today,
      );
      expect(txn.date, today);
    });

    test('a non-string date defaults to today', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: 20260315,
        ),
        'lunch',
        today,
      );
      expect(txn.date, today);
    });

    test('future date is clamped to today', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: '2030-01-01',
        ),
        'lunch next decade',
        today,
      );
      expect(txn.date, today);
    });

    test('pre-2000 date is clamped to DateTime(2000)', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: '1985-06-01',
        ),
        'lunch in the eighties',
        today,
      );
      expect(txn.date, DateTime(2000));
    });

    test('exactly DateTime(2000) lower bound passes through', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          description: 'lunch',
          amount: 12.5,
          category: 'Eating Out',
          date: '2000-01-01',
        ),
        'lunch at the millennium',
        today,
      );
      expect(txn.date, DateTime(2000));
    });
  });

  group('markdown fence stripping', () {
    test('strips a plain triple-backtick fence', () {
      final body = jsonOutput(
          description: 'lunch', amount: 12.5, category: 'Eating Out');
      final txn = VoiceExpenseService.parseVoiceJson(
        '```\n$body\n```',
        'lunch',
        today,
      );
      expect(txn.description, 'lunch');
      expect(txn.amount, 12.5);
      expect(txn.category, 'Eating Out');
    });

    test('strips a triple-backtick-json fence', () {
      final body = jsonOutput(
          description: 'lunch', amount: 12.5, category: 'Eating Out');
      final txn = VoiceExpenseService.parseVoiceJson(
        '```json\n$body\n```',
        'lunch',
        today,
      );
      expect(txn.description, 'lunch');
      expect(txn.amount, 12.5);
      expect(txn.category, 'Eating Out');
    });
  });

  group('error handling', () {
    test('malformed JSON throws VoiceExpenseException carrying the transcript',
        () {
      const transcript = 'this could not be parsed';
      expect(
        () => VoiceExpenseService.parseVoiceJson(
          '{ this is not valid json',
          transcript,
          today,
        ),
        throwsA(
          isA<VoiceExpenseException>().having(
            (e) => e.transcript,
            'transcript',
            transcript,
          ),
        ),
      );
    });

    test('an error key throws VoiceExpenseException carrying the transcript',
        () {
      const transcript = 'what is the weather today';
      expect(
        () => VoiceExpenseService.parseVoiceJson(
          jsonEncode({'error': 'not_a_transaction'}),
          transcript,
          today,
        ),
        throwsA(
          isA<VoiceExpenseException>().having(
            (e) => e.transcript,
            'transcript',
            transcript,
          ),
        ),
      );
    });

    test('a non-object JSON root (array) throws with the transcript', () {
      const transcript = 'a list of things';
      expect(
        () => VoiceExpenseService.parseVoiceJson(
          '[1, 2, 3]',
          transcript,
          today,
        ),
        throwsA(
          isA<VoiceExpenseException>().having(
            (e) => e.transcript,
            'transcript',
            transcript,
          ),
        ),
      );
    });

    test('a bare JSON scalar root throws with the transcript', () {
      const transcript = 'just a number';
      expect(
        () => VoiceExpenseService.parseVoiceJson(
          '42',
          transcript,
          today,
        ),
        throwsA(
          isA<VoiceExpenseException>().having(
            (e) => e.transcript,
            'transcript',
            transcript,
          ),
        ),
      );
    });
  });

  group('returned Transaction object', () {
    test('is the existing Transaction with correct fields for an expense', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'expense',
          description: 'Chipotle',
          amount: 12.5,
          category: 'Eating Out',
          date: '2026-07-06',
        ),
        'twelve fifty for lunch at chipotle yesterday',
        today,
      );
      expect(txn, isA<Transaction>());
      expect(txn.type, TransactionTyp.expense);
      expect(txn.description, 'Chipotle');
      expect(txn.amount, 12.5);
      expect(txn.category, 'Eating Out');
      expect(txn.date, DateTime(2026, 7, 6));
      expect(txn.recurringTemplateId, isNull);
    });

    test('is the existing Transaction with correct fields for income', () {
      final txn = VoiceExpenseService.parseVoiceJson(
        jsonOutput(
          type: 'income',
          description: 'Paycheck',
          amount: 3000,
          category: 'Salary',
          date: '2026-07-07',
        ),
        'got paid three thousand',
        today,
      );
      expect(txn, isA<Transaction>());
      expect(txn.type, TransactionTyp.income);
      expect(txn.description, 'Paycheck');
      expect(txn.amount, 3000.0);
      expect(txn.category, 'Salary');
    });
  });
}
