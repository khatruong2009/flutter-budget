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
  bool isLoading = false;

  late StreamController<String> _responseController;
  ChatHelper chatHelper = ChatHelper();
  final _textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _responseController = StreamController<String>();
    // fetchInsights();
  }

  @override
  void dispose() {
    _responseController.close();
    super.dispose();
  }

  Future<void> askQuestion() async {
    String userQuestion = _textEditingController.text.trim();
    if (userQuestion.isEmpty) {
      setState(() {
        apiResponse = "Please enter a question.";
        isLoading =
            false; // Ensure isLoading is set to false if no question is asked
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    FocusScope.of(context).unfocus();

    // Accessing transactions using Provider
    List<Transaction> transactions =
        Provider.of<TransactionModel>(context, listen: false)
            .currentMonthTransactions;

    try {
      StringBuffer fullResponse = StringBuffer();
      Stream<OpenAIStreamChatCompletionModel> responseStream =
          chatHelper.generateTextStream(
        "Pretend you are my financial advisor. I'm going to give you a summary of my financial transactions this month. The format is as follows: [Transaction Type] [Description] [Amount] [Category] [Date]. For example, 'Expense Groceries 100 Food 2021-10-01'. $userQuestion\n",
        transactions,
      );

      responseStream.listen(
        (event) {
          final content = event.choices.first.delta.content;
          if (content != null) {
            fullResponse.write(content);
            setState(() {
              apiResponse = fullResponse.toString();
            });
          }
        },
        onError: (error) {
          // print('Error: $error'); // Log error for debugging
          setState(() {
            apiResponse = 'Error: Something went wrong';
            isLoading = false;
          });
        },
        onDone: () {
          setState(() {
            isLoading = false;
          });
        },
        cancelOnError: true,
      );
    } catch (error) {
      // print('Error: $error'); // Log error for debugging
      setState(() {
        apiResponse = 'Error: Something went wrong';
        isLoading = false;
      });
    }
  }

  void clearQuestion() {
    _textEditingController.clear();
    setState(() {
      apiResponse = "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgie Insights')),
      body: SafeArea(
        // Step 1: Wrap your content with SafeArea
        child: GestureDetector(
          onTap: () {
            // Step 2: Call FocusScope.of(context).unfocus() when a tap is detected
            FocusScope.of(context).unfocus();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textEditingController,
                  decoration: const InputDecoration(
                    labelText: 'Ask a question about your finances',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: isLoading ? null : askQuestion,
                      child: Text(isLoading ? 'Loading...' : 'Submit'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: clearQuestion,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      apiResponse,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
