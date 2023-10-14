import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat.dart';
import 'transaction.dart';
import 'transaction_model.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({
    Key? key,
  }) : super(key: key);

  @override
  InsightsPageState createState() => InsightsPageState();
}

class InsightsPageState extends State<InsightsPage> {
  String apiResponse = "";
  bool isLoading = true;

  late StreamController<String> _responseController;
  ChatHelper chatHelper = ChatHelper();

  // This method will convert transactions to string and send it to the API
  Future<void> fetchInsights() async {
    StringBuffer fullContent = StringBuffer();
    // Accessing transactions using Provider
    List<Transaction> transactions =
        Provider.of<TransactionModel>(context, listen: false)
            .currentMonthTransactions;

    Stream<OpenAIStreamChatCompletionModel> chatStream =
        chatHelper.generateTextStream(
      "Pretend you are my financial advisor. I'm going to give you a summary of my financial transactions this month. The format is as follows: [Transaction Type] [Description] [Amount] [Category] [Date]. For example, 'Expense Groceries 100 Food 2021-10-01'. Can you give me some high level insights about this month's finances without listing all the categories? If spending in a category is normal, do not include it in the insights. Here is how I want the insights to be formatted: I want you first to list anything that might be concerning or unusual. Then, I want you to give me a quick summary of my financial health this month.",
      transactions,
    );

    chatStream.listen((event) {
      final content = event.choices.first.delta.content;
      fullContent.write(content!);
      _responseController.add(fullContent.toString());
    }, onError: (error) {
      _responseController.addError(error);
    }, onDone: () {});
  }

  @override
  void initState() {
    super.initState();
    _responseController = StreamController<String>();
    fetchInsights();
  }

  @override
  void dispose() {
    _responseController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgie Insights')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<String>(
          stream: _responseController.stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (snapshot.hasData) {
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 20.0),
                  child: Text(
                    snapshot.data!,
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            } else {
              return const Center(child: Text('No insights available.'));
            }
          },
        ),
      ),
    );
  }
}
