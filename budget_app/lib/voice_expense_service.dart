import 'dart:convert';
import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import 'common.dart';
import 'transaction.dart';

class VoiceExpenseException implements Exception {
  final String message;
  final String? transcript;

  VoiceExpenseException(this.message, {this.transcript});

  @override
  String toString() => message;
}

class VoiceExpenseService {
  Future<void> _ensureKey() async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPEN_AI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw VoiceExpenseException(
        'OpenAI is not configured. Add OPEN_AI_API_KEY to the app .env file.',
      );
    }
    OpenAI.apiKey = apiKey;
  }

  Future<String> transcribe(File audio) async {
    await _ensureKey();

    final result = await OpenAI.instance.audio.createTranscription(
      file: audio,
      model: 'gpt-4o-mini-transcribe',
      prompt:
          'Personal expense phrases with dollar amounts like \$12.50 and merchant names.',
    );

    final transcript = result.text.trim();
    if (transcript.isEmpty) {
      throw VoiceExpenseException("Didn't catch anything — try again");
    }
    return transcript;
  }

  Future<Transaction> parse(String transcript, DateTime today) async {
    await _ensureKey();

    final dateLabel = DateFormat('yyyy-MM-dd').format(today);
    final weekday = DateFormat('EEEE').format(today);
    final expenseVocab = expenseCategories.keys.join(', ');
    final incomeVocab = incomeCategories.keys.join(', ');

    final systemPrompt = '''
You extract a single personal-finance transaction from a spoken phrase and return JSON only.

Today is $dateLabel ($weekday), the device's local date. Resolve relative dates like "yesterday", "last Tuesday", or "two days ago" against it.

Return exactly this JSON shape:
{"type","description","amount","category","date"}

Fields:
- "type": either "expense" or "income". Default to "expense" unless the phrase clearly describes money coming in (for example "got paid", "salary", "received", "refund", "deposit"), in which case use "income".
- "description": a short merchant or purpose label from the phrase.
- "amount": a number. Spoken amounts map to decimals — "twelve fifty" means 12.50, "three thousand" means 3000. If no amount is stated, use 0.
- "category": for expenses pick exactly one of: $expenseVocab. For income pick exactly one of: $incomeVocab. Choose the closest match.
- "date": an ISO-8601 date (YYYY-MM-DD). Default to today ($dateLabel). Never return a date in the future.

If the phrase is not describing a transaction at all, return {"error":"not_a_transaction"}.''';

    final completion = await OpenAI.instance.chat.create(
      model: 'gpt-5.4-nano',
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              systemPrompt,
            ),
          ],
          role: OpenAIChatMessageRole.system,
        ),
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(transcript),
          ],
          role: OpenAIChatMessageRole.user,
        ),
      ],
      responseFormat: {'type': 'json_object'},
    );

    final output = completion.choices.first.message.content
            ?.map((item) => item.text ?? '')
            .join() ??
        '';

    return parseVoiceJson(output, transcript, today);
  }

  static Transaction parseVoiceJson(
    String llmOutput,
    String transcript,
    DateTime today,
  ) {
    var raw = llmOutput.trim();
    if (raw.startsWith('```')) {
      raw = raw.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      if (raw.endsWith('```')) {
        raw = raw.substring(0, raw.length - 3);
      }
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
        "Couldn't read that as a transaction — try again",
        transcript: transcript,
      );
    }

    if (json.containsKey('error')) {
      throw VoiceExpenseException(
        "That didn't sound like a transaction — try again",
        transcript: transcript,
      );
    }

    final type = json['type'] == 'income'
        ? TransactionTyp.income
        : TransactionTyp.expense;

    final categories = type == TransactionTyp.income
        ? incomeCategories.keys
        : expenseCategories.keys;
    final fallbackCategory =
        type == TransactionTyp.income ? 'Other' : 'General';
    final rawCategory = json['category'];
    final category = categories.contains(rawCategory)
        ? rawCategory as String
        : fallbackCategory;

    double amount = 0.0;
    final rawAmount = json['amount'];
    if (rawAmount is num) {
      amount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      amount = double.tryParse(rawAmount) ?? 0.0;
    }
    if (amount.isNaN || amount.isInfinite || amount < 0) {
      amount = 0.0;
    }

    final rawDescription = json['description'];
    final description =
        (rawDescription is String && rawDescription.trim().isNotEmpty)
            ? rawDescription.trim()
            : transcript;

    DateTime date = today;
    final rawDate = json['date'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        date = parsed;
      }
    }
    final lowerBound = DateTime(2000);
    if (date.isAfter(today)) {
      date = today;
    } else if (date.isBefore(lowerBound)) {
      date = lowerBound;
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
