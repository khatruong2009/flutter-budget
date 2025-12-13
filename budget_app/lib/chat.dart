import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_openai/dart_openai.dart';
import 'transaction.dart';

class ChatHelper {
  Future<List<OpenAIChatCompletionChoiceMessageContentItemModel>?> generateText(
      String prompt, List<Transaction> transactions) async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPEN_AI_API_KEY'];
    OpenAI.apiKey = apiKey!;

    // Convert transactions into a suitable format (e.g., a String) for API request.
    final transactionsData = convertTransactionsToString(transactions);
    final enhancedPrompt =
        '$prompt\n\nTransactions:\n$transactionsData';

    OpenAIChatCompletionModel chatCompletion =
        await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel(
              text: enhancedPrompt,
              type: 'text',
            )
          ],
          role: OpenAIChatMessageRole.user,
        ),
      ],
    );
    return chatCompletion.choices[0].message.content;
  }

  Stream<OpenAIStreamChatCompletionModel> generateTextStream(
      String prompt, List<Transaction> transactions) async* {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPEN_AI_API_KEY'];
    OpenAI.apiKey = apiKey!;
    final transactionsData = convertTransactionsToString(transactions);
    final enhancedPrompt =
        '$prompt\n\nTransactions:\n$transactionsData';

    yield* OpenAI.instance.chat.createStream(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel(
              text: enhancedPrompt,
              type: 'text',
            )
          ],
          role: OpenAIChatMessageRole.user,
        ),
      ],
    );
  }

  String convertTransactionsToString(List<Transaction> transactions) {
    return transactions.map((transaction) {
      return '${transaction.type}, ${transaction.description}, ${transaction.amount.toStringAsFixed(2)}, ${transaction.category}, ${transaction.date.toIso8601String()}';
    }).join('\n');
  }
}
