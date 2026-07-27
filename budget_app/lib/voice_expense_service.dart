import 'dart:convert';

import 'common.dart';
import 'transaction.dart';

class VoiceExpenseException implements Exception {
  final String message;
  final String? transcript;

  VoiceExpenseException(this.message, {this.transcript});

  @override
  String toString() => message;
}

/// Parses typed quick-entry phrases locally.
///
/// This service deliberately performs no network or audio work. It keeps the
/// former voice-entry prefill flow useful without transmitting a recording or
/// financial details to a third party.
class VoiceExpenseService {
  Future<Transaction> parse(String text, DateTime today) async {
    final transcript = text.trim();
    if (transcript.isEmpty) {
      throw VoiceExpenseException(
        'Describe a transaction to continue.',
        transcript: transcript,
      );
    }

    final type = _detectType(transcript);
    final amount = _detectAmount(transcript);
    final category = _detectCategory(transcript, type);
    final date = _detectDate(transcript, today);
    final description = _description(transcript);

    return Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
    );
  }

  static TransactionTyp _detectType(String text) {
    final lower = text.toLowerCase();
    const incomeWords = [
      'income',
      'earned',
      'received',
      'deposit',
      'paycheck',
      'salary',
      'refund',
      'got paid',
    ];
    return incomeWords.any(lower.contains)
        ? TransactionTyp.income
        : TransactionTyp.expense;
  }

  static double _detectAmount(String text) {
    final withoutDate =
        text.replaceAll(RegExp(r'\b20\d{2}-\d{1,2}-\d{1,2}\b'), '');
    final match = RegExp(
      r'(?:\$|usd\s*)?((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(withoutDate);
    if (match == null) return 0;
    return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  }

  static String _detectCategory(String text, TransactionTyp type) {
    final lower = text.toLowerCase();
    final categories = type == TransactionTyp.income
        ? incomeCategories.keys
        : expenseCategories.keys;

    for (final category in categories) {
      if (lower.contains(category.toLowerCase())) return category;
    }

    if (type == TransactionTyp.income) {
      if (_containsAny(lower, ['paycheck', 'salary', 'wages', 'got paid'])) {
        return 'Salary';
      }
      if (_containsAny(lower, ['dividend', 'interest', 'investment'])) {
        return 'Investment';
      }
      if (lower.contains('gift')) return 'Gift';
      return 'Other';
    }

    const keywords = <String, List<String>>{
      'Eating Out': [
        'restaurant',
        'lunch',
        'dinner',
        'coffee',
        'cafe',
        'takeout'
      ],
      'Groceries': ['grocery', 'groceries', 'supermarket'],
      'Housing': ['rent', 'mortgage', 'utilities', 'electric', 'water bill'],
      'Transportation': ['gas', 'fuel', 'uber', 'lyft', 'transit', 'parking'],
      'Travel': ['hotel', 'flight', 'airline', 'vacation'],
      'Clothing': ['clothes', 'clothing', 'shoes'],
      'Gift': ['gift', 'present'],
      'Health': ['doctor', 'medical', 'pharmacy', 'dentist'],
      'Entertainment': ['movie', 'concert', 'game', 'streaming'],
      'Pets': ['pet', 'vet'],
      'Family': ['childcare', 'family'],
      'Loan Payment': ['loan', 'debt payment'],
    };
    for (final entry in keywords.entries) {
      if (_containsAny(lower, entry.value)) return entry.key;
    }
    return 'General';
  }

  static DateTime _detectDate(String text, DateTime today) {
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final lower = text.toLowerCase();
    if (lower.contains('yesterday')) {
      return normalizedToday.subtract(const Duration(days: 1));
    }
    final isoMatch =
        RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b').firstMatch(text);
    if (isoMatch == null) return normalizedToday;
    final parsed = DateTime.tryParse(
      '${isoMatch.group(1)}-${isoMatch.group(2)!.padLeft(2, '0')}-${isoMatch.group(3)!.padLeft(2, '0')}',
    );
    if (parsed == null) return normalizedToday;
    if (parsed.isAfter(normalizedToday)) return normalizedToday;
    return parsed.isBefore(DateTime(2000)) ? DateTime(2000) : parsed;
  }

  static String _description(String text) {
    var result = text
        .replaceAll(RegExp(r'\b20\d{2}-\d{1,2}-\d{1,2}\b'), '')
        .replaceAll(RegExp(r'\$\s*\d[\d,]*(?:\.\d{1,2})?'), '')
        .replaceAll(RegExp(r'\b\d[\d,]*(?:\.\d{1,2})?\b'), '')
        .replaceAll(RegExp(r'\b(today|yesterday)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    result = result.replaceFirst(
      RegExp(
        r'^(spent|paid|bought|income|earned|received|deposit|got paid)\s+',
        caseSensitive: false,
      ),
      '',
    );
    return result.trim().isEmpty ? text : result.trim();
  }

  static bool _containsAny(String value, Iterable<String> candidates) =>
      candidates.any(value.contains);

  /// Kept for backward-compatible backup/tests that validate old AI output.
  /// No production path sends or receives this JSON.
  static Transaction parseVoiceJson(
    String output,
    String transcript,
    DateTime today,
  ) {
    var raw = output.trim();
    if (raw.startsWith('```')) {
      raw = raw.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      if (raw.endsWith('```')) raw = raw.substring(0, raw.length - 3);
      raw = raw.trim();
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not an object');
      }
      json = decoded;
    } catch (_) {
      throw VoiceExpenseException(
        "Couldn't read that as a transaction.",
        transcript: transcript,
      );
    }
    if (json.containsKey('error')) {
      throw VoiceExpenseException(
        "That didn't sound like a transaction.",
        transcript: transcript,
      );
    }

    final type = json['type'] == 'income'
        ? TransactionTyp.income
        : TransactionTyp.expense;
    final categories = type == TransactionTyp.income
        ? incomeCategories.keys
        : expenseCategories.keys;
    final fallback = type == TransactionTyp.income ? 'Other' : 'General';
    final rawCategory = json['category'];
    final category =
        categories.contains(rawCategory) ? rawCategory as String : fallback;

    final rawAmount = json['amount'];
    double amount = rawAmount is num
        ? rawAmount.toDouble()
        : rawAmount is String
            ? double.tryParse(rawAmount) ?? 0
            : 0.0;
    if (!amount.isFinite || amount < 0) amount = 0;

    final rawDescription = json['description'];
    final description =
        rawDescription is String && rawDescription.trim().isNotEmpty
            ? rawDescription.trim()
            : transcript;

    var date = today;
    final rawDate = json['date'];
    if (rawDate is String) date = DateTime.tryParse(rawDate) ?? today;
    if (date.isAfter(today)) {
      date = today;
    } else if (date.isBefore(DateTime(2000))) {
      date = DateTime(2000);
    }

    return Transaction(
      type: type,
      description: description,
      amount: amount,
      category: category,
      date: date,
    );
  }
}
