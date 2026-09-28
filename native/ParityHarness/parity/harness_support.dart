// Shared plumbing for the parity harness. Copied into the exported copy of
// budget_app at test/parity/ by native/ParityHarness/run.sh.

import 'dart:convert';
import 'dart:io';

import 'package:budget_app/app_settings_provider.dart';
import 'package:budget_app/categorization_provider.dart';
import 'package:budget_app/category_definition.dart';
import 'package:budget_app/category_provider.dart';
import 'package:budget_app/parity_clock.dart';
import 'package:budget_app/recurring_transaction_model.dart';
import 'package:budget_app/storage/atomic_financial_store.dart';
import 'package:budget_app/transaction.dart';
import 'package:budget_app/transaction_generator.dart';
import 'package:budget_app/transaction_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

final String fixturesRoot = Platform.environment['PARITY_FIXTURES'] ??
    (throw StateError('PARITY_FIXTURES not set; use run.sh'));
final String parityTz = Platform.environment['PARITY_TZ'] ?? 'unknown';
final String parityCommit = Platform.environment['PARITY_COMMIT'] ?? 'unknown';

const JsonEncoder pretty = JsonEncoder.withIndent('  ');

Directory fixtureDir(String relative) {
  final dir = Directory('$fixturesRoot/$relative');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  return dir;
}

void writeJson(String path, Object? value) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${pretty.convert(value)}\n');
}

/// FNV-1a 64 exactly as the store formats it, for fixture manifests.
String fnv(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// Pins every `DateTime.now()` in the app (see parity_clock.dart).
void pinClock(DateTime? now) => parityClockOverride = now;

/// Typed description of a SharedPreferences state, keyed by the on-device
/// NSUserDefaults key (with the `flutter.` prefix). This is what the Swift
/// side feeds into its preferences source.
Map<String, Object> typedPrefs(Map<String, Object> dartValues) {
  final out = <String, Object>{};
  for (final entry in dartValues.entries) {
    final key = entry.key.startsWith('flutter.')
        ? entry.key
        : 'flutter.${entry.key}';
    final value = entry.value;
    final String type;
    if (value is bool) {
      type = 'bool';
    } else if (value is int) {
      type = 'int';
    } else if (value is double) {
      type = 'double';
    } else if (value is String) {
      type = 'string';
    } else if (value is List<String>) {
      type = 'stringList';
    } else {
      throw ArgumentError('unsupported pref type ${value.runtimeType}');
    }
    out[key] = {'type': type, 'value': value};
  }
  return out;
}

/// Current SharedPreferences contents in the typed form above.
Future<Map<String, Object>> dumpPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final values = <String, Object>{};
  for (final key in prefs.getKeys()) {
    values[key] = prefs.get(key)!;
  }
  return typedPrefs(values);
}

/// Mirrors `_initializeApp` in lib/main.dart: the same providers, loaded in
/// the same order, then recurring generation.
class AppHarness {
  final transactionModel = TransactionModel();
  final recurringModel = RecurringTransactionModel();
  final categoryProvider = CategoryProvider();
  final appSettings = AppSettingsProvider();
  final categorizationProvider = CategorizationProvider();

  Future<void> initialize({bool generate = true}) async {
    await AtomicFinancialStore.instance.read();
    await Future.wait([
      categoryProvider.load(),
      appSettings.load(),
      categorizationProvider.load(),
    ]);
    await transactionModel.getTransactions();
    await recurringModel.loadRecurringTransactions();
    await categoryProvider.ensureLegacyCategories(
      transactionModel.transactions,
    );
    await categoryProvider.ensureLegacyCategoryNames([
      ...recurringModel.recurringTransactions.map(
        (template) => (
          template.type == TransactionTyp.income
              ? BudgetCategoryType.income
              : BudgetCategoryType.expense,
          template.category,
        ),
      ),
      ...transactionModel.categoryBudgetLimits.keys.map(
        (name) => (BudgetCategoryType.expense, name),
      ),
    ]);
    if (generate) {
      await TransactionGenerator(
        transactionModel: transactionModel,
        recurringModel: recurringModel,
      ).generateDueTransactions();
    }
  }
}

/// Every file in [dir] with size and checksum; `.corrupt-<stamp>` suffixes
/// are normalised to `.corrupt-*` so expectations do not depend on the clock.
Map<String, Object> listing(Directory dir) {
  final out = <String, Object>{};
  if (!dir.existsSync()) return out;
  final files = dir.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last
        .replaceAll(RegExp(r'\.corrupt-\d+$'), '.corrupt-*');
    final bytes = file.readAsBytesSync();
    out[name] = {'size': bytes.length, 'fnv': fnv(bytes)};
  }
  return out;
}

String iso(DateTime value) => value.toIso8601String();
