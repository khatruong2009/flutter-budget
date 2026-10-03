// Emits native/Fixtures/launch/tz/<zone>/<scenario>.json : the Flutter app's
// launch (exactly `_initializeApp`: load every provider, then the recurring
// generator) over the store fixtures' inputs, run under several zones
// (run.sh), including America/Santiago and Asia/Beirut, whose DST changes
// happen at midnight.
//
// The store fixtures (native/Fixtures/store/*) pin the same launch in
// America/New_York only. Each file here holds what the Swift launch must
// reproduce in the zone:
//   summary                 `summarize()` (model_summary.dart) after the launch
//   sectionsAfterGenerate   the store's sections as Dart re-encodes them
//                           (checksum, length, keys; the JSON when small)
//   generatedIds            row ids the launch generated, in document order
//                           (the Swift side has its own and aligns them)
//
// The inputs are read from native/Fixtures/store/<scenario>/ (written by the
// store generator), so this generator does not rewrite them.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_runner.dart';
import 'harness_support.dart';
import 'model_summary.dart';

const scenarios = ['typical', 'old_schema', 'unknown_data', 'large_10k'];

String get zoneDir => 'launch/tz/${parityTz.replaceAll('/', '_')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory out;
  setUpAll(() => out = fixtureDir(zoneDir));

  for (final name in scenarios) {
    test('launch $name', () async {
      final input = Directory('$fixturesRoot/store/$name/input');
      final prefs = prefsFrom(File('$fixturesRoot/store/$name/prefs.json'));
      expect(input.existsSync(), isTrue, reason: 'run the store generator first');

      // The sections before the launch: the ids already in the store.
      final beforeWork = await scratch('launch_before_$name');
      final beforeDir = Directory('${beforeWork.path}/financial_store');
      copyDir(input, beforeDir);
      SharedPreferences.setMockInitialValues(Map.of(prefs));
      pinClock(launchNow);
      await store.resetForTesting(directory: beforeDir);
      final before = await store.read();

      final work = await scratch('launch_$name');
      final dir = Directory('${work.path}/financial_store');
      copyDir(input, dir);
      SharedPreferences.setMockInitialValues(Map.of(prefs));
      pinClock(launchNow);
      await store.resetForTesting(directory: dir);
      seedUuids(1003);
      final launched = AppHarness();
      await launched.initialize(generate: true);
      final summary = summarize(launched, asOf: launchNow);
      final end = await store.read();
      final sections = sectionsJson(end);

      writeJson('${out.path}/$name.json', {
        'tz': parityTz,
        'scenario': name,
        'launchNow': iso(launchNow),
        'summary': summary,
        'sectionsAfterGenerate': sections,
        'generatedIds': generatedIds(
            pretty.convert(end.sections), Map<String, dynamic>.from(before.sections)),
      });
    });
  }
}
