import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_openai/dart_openai.dart';
import 'transaction.dart';

class ChatHelper {
  Future<String> generateText(
      String prompt, List<Transaction> transactions) async {
    await dotenv.load(fileName: '.env');
    final apiKey = dotenv.env['OPEN_AI_API_KEY'];
    OpenAI.apiKey = apiKey!;

    // print("Starting chat now...");

    // Convert transactions into a suitable format (e.g., a String) for API request.
    String transactionsData = convertTransactionsToString(transactions);

    OpenAIChatCompletionModel chatCompletion =
        await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          content:
              prompt + transactionsData, // Example of using transactionsData
          role: OpenAIChatMessageRole.user,
        ),
      ],
    );

    // print(chatCompletion.choices[0].message.content);
    // print(convertTransactionsToString(transactions));
    return chatCompletion.choices[0].message.content;
  }

  String convertTransactionsToString(List<Transaction> transactions) {
    return transactions.map((transaction) {
      return '${transaction.type}, ${transaction.description}, ${transaction.amount.toStringAsFixed(2)}, ${transaction.category}, ${transaction.date.toIso8601String()}';
    }).join('\n');
  }
}
