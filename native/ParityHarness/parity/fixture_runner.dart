// Runs one fixture scenario through the real Dart store and app, and writes
// input + expectations. Shared by the store and legacy fixture generators.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness_support.dart';
import 'model_summary.dart';

final store = AtomicFinancialStore.instance;
const primaryName = AtomicFinancialStore.primaryFileName;
const backupName = AtomicFinancialStore.backupFileName;

/// Launch clock for every expectation: after the fixture data, so the
/// generator has due occurrences to produce.
final launchNow = DateTime(2026, 9, 28, 9, 15, 30, 250, 125);

Future<Directory> scratch(String name) =>
    Directory.systemTemp.createTemp('parity_$name');

void copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync()) {
    final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (entity is File) {
      entity.copySync('${to.path}/$name');
    } else if (entity is Directory) {
      copyDir(entity, Directory('${to.path}/$name'));
    }
  }
}

/// The sections as Dart re-encodes them (`jsonEncode` of the decoded map):
/// the canonical form the Swift side reproduces for comparison. Large
/// payloads keep only the checksum and length.
Map<String, Object?> sectionsJson(FinancialSnapshot snapshot) {
  final text = jsonEncode(snapshot.sections);
  final bytes = utf8.encode(text);
  return {
    'fnv': fnv(bytes),
    'length': bytes.length,
    'keys': snapshot.sections.keys.toList(),
    if (bytes.length <= 200000) 'json': text,
  };
}

/// Runs the Dart side against a copy of [input] with [prefs] and records
/// everything the Swift side must reproduce.
Future<Map<String, Object?>> expectFor(
    Directory input, Map<String, Object> prefs, {bool runApp = true}) async {
  final work = await scratch('expect');
  final dir = Directory('${work.path}/financial_store');
  if (input.existsSync()) copyDir(input, dir);
  SharedPreferences.setMockInitialValues(Map.of(prefs));
  pinClock(launchNow);
  seedUuids(1001);
  await store.resetForTesting(directory: dir);

  final result = <String, Object?>{'launchNow': iso(launchNow)};
  try {
    final snapshot = await store.read();
    result['load'] = {
      'revision': snapshot.revision,
      'schemaVersion': snapshot.schemaVersion,
      'sections': sectionsJson(snapshot),
    };
  } catch (error) {
    result['load'] = {'error': error.runtimeType.toString()};
    result['filesAfterLoad'] = listing(dir);
    result['prefsAfterLoad'] = await dumpPrefs();
    return result;
  }
  result['filesAfterLoad'] = listing(dir);
  result['prefsAfterLoad'] = await dumpPrefs();

  // One more commit, to pin how the backup is chosen for this state.
  await store.resetForTesting(directory: dir);
  pinClock(launchNow);
  try {
    await store.updateSection('selectedNetWorthMonth', '2026-05-01T00:00:00.000');
    final after = await store.read();
    result['afterOneCommit'] = {
      'revision': after.revision,
      'files': listing(dir),
    };
  } catch (error) {
    result['afterOneCommit'] = {'error': error.runtimeType.toString()};
  }

  if (runApp) {
    // A full app launch (exactly _initializeApp) on the untouched input:
    // first without the generator to capture what loading alone writes,
    // then a second, real launch that also generates.
    final appWork = await scratch('app');
    final appDir = Directory('${appWork.path}/financial_store');
    if (input.existsSync()) copyDir(input, appDir);
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    pinClock(launchNow);
    try {
      await store.resetForTesting(directory: appDir);
      seedUuids(1002);
      final loaded = AppHarness();
      await loaded.initialize(generate: false);
      result['appBeforeGenerate'] = summarize(loaded, asOf: launchNow);
      final afterInit = await store.read();
      result['sectionsAfterInit'] = sectionsJson(afterInit);
      result['revisionAfterInit'] = afterInit.revision;

      final launchWork = await scratch('launch');
      final launchDir = Directory('${launchWork.path}/financial_store');
      if (input.existsSync()) copyDir(input, launchDir);
      SharedPreferences.setMockInitialValues(Map.of(prefs));
      pinClock(launchNow);
      await store.resetForTesting(directory: launchDir);
      seedUuids(1003);
      final launched = AppHarness();
      await launched.initialize(generate: true);
      result['appAfterGenerate'] = summarize(launched, asOf: launchNow);
      final end = await store.read();
      result['sectionsAfterGenerate'] = sectionsJson(end);
      result['revisionAfterGenerate'] = end.revision;
      result['filesAfterGenerate'] = listing(launchDir);
    } catch (error, stack) {
      result['appError'] = '${error.runtimeType}: $error';
      result['appErrorStack'] = stack.toString().split('\n').take(5).toList();
    }
  }
  return result;
}

void emit(String name, Directory input, Map<String, Object> prefs,
    Map<String, Object?> expected,
    {required String description, String group = 'store'}) {
  final out = fixtureDir('$group/$name');
  if (input.existsSync()) copyDir(input, Directory('${out.path}/input'));
  writeJson('${out.path}/prefs.json', typedPrefs(prefs));
  writeJson('${out.path}/expected.json', {
    'scenario': name,
    'description': description,
    'commit': parityCommit,
    'tz': parityTz,
    ...expected,
  });
}

