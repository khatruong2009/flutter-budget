// Emits native/Fixtures/logic/date_formats.json and strings.json: the
// en_US intl DateFormat patterns the app uses, and Dart String operations
// (trim, toLowerCase, contains, startsWith, ==, compareTo) over a corpus of
// awkward inputs. Zone-independent (local wall-clock fields only).

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'harness_support.dart';

void main() {
  test('date formats', () {
    final patterns = <String, DateFormat>{
      'MMMM': DateFormat.MMMM(),
      'MMM': DateFormat.MMM(),
      'y': DateFormat.y(),
      'MMMd': DateFormat.MMMd(),
      'yMMMd': DateFormat.yMMMd(),
      'MMM d, y': DateFormat('MMM d, y'),
      'MMM dd, yyyy': DateFormat('MMM dd, yyyy'),
      'yMMMM': DateFormat.yMMMM(),
      'MMMM y': DateFormat('MMMM y'),
      'MMMM yyyy': DateFormat('MMMM yyyy'),
      'yMMMMd': DateFormat.yMMMMd(),
      "MMM ''yy": DateFormat("MMM ''yy"),
      'EEEE': DateFormat('EEEE'),
      'EEEE, MMM dd, yyyy': DateFormat('EEEE, MMM dd, yyyy'),
      'yyyy-MM-dd': DateFormat('yyyy-MM-dd'),
      'yyyy-MM': DateFormat('yyyy-MM'),
      'jm': DateFormat.jm(),
    };
    final dates = <DateTime>[
      DateTime(2026, 9, 28, 9, 15, 30),
      DateTime(2026, 1, 1, 0, 0),
      DateTime(2026, 12, 31, 23, 59),
      DateTime(2026, 5, 8, 12, 0),
      DateTime(2026, 2, 3, 12, 5),
      DateTime(2026, 6, 14, 13, 1),
      DateTime(2026, 7, 19, 11, 59),
      DateTime(2000, 3, 5, 0, 30),
      DateTime(1999, 10, 9, 22, 0),
      DateTime(2100, 4, 22, 1, 2),
      DateTime(9, 8, 7, 6, 5),
      DateTime(2024, 11, 3, 18, 45),
    ];
    final cases = [
      for (final d in dates)
        {
          'fields': [d.year, d.month, d.day, d.hour, d.minute],
          'formats': {
            for (final entry in patterns.entries) entry.key: entry.value.format(d),
          },
        },
    ];
    writeJson('$fixturesRoot/logic/date_formats.json', {'cases': cases});
  });

  test('strings', () {
    const corpus = <String>[
      '',
      ' ',
      '  Groceries  ',
      '﻿BOM﻿',
      '\u0085nel ',
      '᠎mongolian᠎',
      ' line ',
      '​zero width​',
      '\t\n\r\u000B\u000C mixed 　',
      'Whole Foods Market',
      'WHOLE FOODS',
      'whole',
      'İstanbul',
      'ISTANBUL',
      'ΣΑΣ',
      'ẞtraße',
      'Café',
      'Café',
      'café',
      'ǅ Ǆ ǆ',
      '😀 Emoji ☕️',
      '\u{10400}Deseret',
      'a',
      'A',
      'Z',
      '_',
      'ä',
      'é',
      'é',
    ];
    final trims = [
      for (final s in corpus) {'s': s, 'trim': s.trim(), 'lower': s.toLowerCase()}
    ];
    final pairs = <Map<String, Object?>>[];
    for (final a in corpus) {
      for (final b in corpus) {
        pairs.add({
          'a': a,
          'b': b,
          'equal': a == b,
          'contains': a.contains(b),
          'startsWith': a.startsWith(b),
          'compare': a.compareTo(b).sign,
        });
      }
    }
    writeJson('$fixturesRoot/logic/strings.json', {'single': trims, 'pairs': pairs});
  });
}
