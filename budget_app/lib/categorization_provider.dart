import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'categorization_rule.dart';
import 'storage/storage_keys.dart';
import 'storage/atomic_financial_store.dart';
import 'transaction.dart';
import 'transaction_tag.dart';

class CategorizationSuggestion {
  final CategorizationRule rule;

  const CategorizationSuggestion(this.rule);

  String get category => rule.category;
  List<String> get tagIds => rule.tagIds;
}

class CategorizationProvider extends ChangeNotifier {
  final List<TransactionTag> _tags = [];
  final List<CategorizationRule> _rules = [];

  List<TransactionTag> get tags => List.unmodifiable(_tags);
  List<CategorizationRule> get rules {
    final result = List<CategorizationRule>.from(_rules)
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(result);
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final snapshot = await AtomicFinancialStore.instance.read();
    _tags
      ..clear()
      ..addAll(_decodeList(
        _encodedSection(
          snapshot.sections[FinancialSections.transactionTags],
          preferences.getString(StorageKeys.transactionTags),
        ),
        TransactionTag.fromJson,
      ));
    _rules
      ..clear()
      ..addAll(_decodeList(
        _encodedSection(
          snapshot.sections[FinancialSections.categorizationRules],
          preferences.getString(StorageKeys.categorizationRules),
        ),
        CategorizationRule.fromJson,
      ));
    notifyListeners();
  }

  Future<TransactionTag> addTag(String name,
      {String colorToken = 'accent'}) async {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError('Tag name is required');
    if (_tags
        .any((tag) => tag.name.toLowerCase() == normalized.toLowerCase())) {
      throw ArgumentError('A tag with this name already exists');
    }
    final tag = TransactionTag(name: normalized, colorToken: colorToken);
    _tags.add(tag);
    await _persistTags();
    notifyListeners();
    return tag;
  }

  Future<void> deleteTag(String id) async {
    _tags.removeWhere((tag) => tag.id == id);
    for (var i = 0; i < _rules.length; i++) {
      final rule = _rules[i];
      if (!rule.tagIds.contains(id)) continue;
      _rules[i] = CategorizationRule(
        id: rule.id,
        merchantPattern: rule.merchantPattern,
        matchType: rule.matchType,
        transactionType: rule.transactionType,
        minimumAmount: rule.minimumAmount,
        maximumAmount: rule.maximumAmount,
        category: rule.category,
        tagIds: rule.tagIds.where((tagId) => tagId != id).toList(),
        priority: rule.priority,
        isEnabled: rule.isEnabled,
      );
    }
    await Future.wait([_persistTags(), _persistRules()]);
    notifyListeners();
  }

  Future<void> addRule(CategorizationRule rule) async {
    _rules.removeWhere((existing) => existing.id == rule.id);
    _rules.add(rule);
    await _persistRules();
    notifyListeners();
  }

  Future<void> restoreFromBackup({
    required List<TransactionTag> tags,
    required List<CategorizationRule> rules,
  }) async {
    final tagIds = tags.map((tag) => tag.id).toSet();
    final ruleIds = rules.map((rule) => rule.id).toSet();
    if (tagIds.length != tags.length || ruleIds.length != rules.length) {
      throw const FormatException('Backup contains duplicate tags or rules');
    }
    if (rules.any((rule) => rule.tagIds.any((id) => !tagIds.contains(id)))) {
      throw const FormatException('Backup rule references an unknown tag');
    }
    _tags
      ..clear()
      ..addAll(tags);
    _rules
      ..clear()
      ..addAll(rules);
    await Future.wait([_persistTags(), _persistRules()]);
    notifyListeners();
  }

  Future<void> deleteRule(String id) async {
    _rules.removeWhere((rule) => rule.id == id);
    await _persistRules();
    notifyListeners();
  }

  Future<void> renameCategory(String oldName, String newName) async {
    var changed = false;
    for (var index = 0; index < _rules.length; index++) {
      final rule = _rules[index];
      if (rule.category != oldName) continue;
      changed = true;
      _rules[index] = CategorizationRule(
        id: rule.id,
        merchantPattern: rule.merchantPattern,
        matchType: rule.matchType,
        transactionType: rule.transactionType,
        minimumAmount: rule.minimumAmount,
        maximumAmount: rule.maximumAmount,
        category: newName,
        tagIds: rule.tagIds,
        priority: rule.priority,
        isEnabled: rule.isEnabled,
      );
    }
    if (!changed) return;
    await _persistRules();
    notifyListeners();
  }

  CategorizationSuggestion? suggest({
    required TransactionTyp type,
    required String description,
    required double amount,
  }) {
    for (final rule in rules) {
      if (rule.matches(
        type: type,
        description: description,
        amount: amount,
      )) {
        return CategorizationSuggestion(rule);
      }
    }
    return null;
  }

  Future<void> _persistTags() async {
    final serialized = _tags.map((tag) => tag.toJson()).toList();
    await AtomicFinancialStore.instance.updateSection(
      FinancialSections.transactionTags,
      serialized,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      StorageKeys.transactionTags,
      jsonEncode(serialized),
    );
  }

  Future<void> _persistRules() async {
    final serialized = _rules.map((rule) => rule.toJson()).toList();
    await AtomicFinancialStore.instance.updateSection(
      FinancialSections.categorizationRules,
      serialized,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      StorageKeys.categorizationRules,
      jsonEncode(serialized),
    );
  }

  String? _encodedSection(dynamic section, String? legacy) {
    return section is List ? jsonEncode(section) : legacy;
  }

  List<T> _decodeList<T>(
    String? encoded,
    T Function(Map<String, dynamic>) decoder,
  ) {
    if (encoded == null || encoded.isEmpty) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .map((item) => decoder(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
