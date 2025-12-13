import 'dart:async';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'chat.dart';
import 'transaction.dart';
import 'transaction_model.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'utils/platform_utils.dart';

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
  }

  @override
  void dispose() {
    _responseController.close();
    _textEditingController.dispose();
    super.dispose();
  }

  Future<void> askQuestion() async {
    String userQuestion = _textEditingController.text.trim();
    if (userQuestion.isEmpty) {
      setState(() {
        apiResponse = "Please enter a question.";
        isLoading = false;
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: AppTypography.headingLarge.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SafeArea(
          child: Consumer<TransactionModel>(
            builder: (context, model, child) {
              final hasTransactions = model.currentMonthTransactions.isNotEmpty;
              
              if (!hasTransactions) {
                return EmptyState.noData(
                  title: 'No Data Available',
                  message: 'Add some transactions to see insights and ask questions about your finances',
                  icon: CupertinoIcons.chart_bar,
                );
              }

              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: CustomScrollView(
                  physics: PlatformUtils.platformScrollPhysics,
                  slivers: [
                    // Dashboard Metrics
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDesign.spacingM),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Financial Overview',
                              style: AppTypography.headingMedium.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            _buildMetricCards(model),
                          ],
                        ),
                      ),
                    ),

                    // AI Chat Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDesign.spacingM,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppDesign.spacingL),
                            Text(
                              'Ask Your Financial Advisor',
                              style: AppTypography.headingMedium.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: AppDesign.spacingM),
                            _buildChatInterface(),
                          ],
                        ),
                      ),
                    ),

                    // Response Section
                    if (apiResponse.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDesign.spacingM),
                          child: _buildResponseCard(),
                        ),
                      ),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppDesign.spacingXL),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCards(TransactionModel model) {
    final totalIncome = model.totalIncome;
    final totalExpenses = model.totalExpenses;
    final balance = totalIncome - totalExpenses;
    final transactionCount = model.currentMonthTransactions.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AnimatedMetricCard(
                label: 'Income',
                value: totalIncome,
                icon: CupertinoIcons.arrow_down_circle_fill,
                color: AppColors.getIncome(isDark),
                prefix: '\$',
              ),
            ),
            const SizedBox(width: AppDesign.spacingM),
            Expanded(
              child: AnimatedMetricCard(
                label: 'Expenses',
                value: totalExpenses,
                icon: CupertinoIcons.arrow_up_circle_fill,
                color: AppColors.getExpense(isDark),
                prefix: '\$',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesign.spacingM),
        Row(
          children: [
            Expanded(
              child: AnimatedMetricCard(
                label: 'Balance',
                value: balance,
                icon: CupertinoIcons.money_dollar_circle_fill,
                color: balance >= 0
                    ? AppColors.getIncome(isDark)
                    : AppColors.getExpense(isDark),
                prefix: '\$',
              ),
            ),
            const SizedBox(width: AppDesign.spacingM),
            Expanded(
              child: AnimatedMetricCard(
                label: 'Transactions',
                value: transactionCount.toDouble(),
                icon: CupertinoIcons.list_bullet,
                color: AppColors.getNeutral(isDark),
                fractionDigits: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChatInterface() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ElevatedCard(
      elevation: AppDesign.elevationS,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textEditingController,
            decoration: InputDecoration(
              labelText: 'Ask a question about your finances',
              labelStyle: AppTypography.bodyMedium.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                borderSide: BorderSide(
                  color: AppDesign.getTextSecondary(context).withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                borderSide: BorderSide(
                  color: AppDesign.getTextSecondary(context).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusM),
                borderSide: BorderSide(
                  color: AppDesign.getTextPrimary(context),
                  width: AppDesign.borderMedium,
                ),
              ),
              filled: true,
              fillColor: AppColors.getSurface(isDark).withValues(alpha: 0.5),
            ),
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppDesign.spacingM),
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  label: isLoading ? 'Loading...' : 'Ask',
                  onPressed: isLoading ? null : askQuestion,
                  icon: CupertinoIcons.chat_bubble_text,
                  isLoading: isLoading,
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              AppButton.secondary(
                label: 'Clear',
                onPressed: clearQuestion,
                icon: CupertinoIcons.clear,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponseCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ElevatedCard(
      elevation: AppDesign.elevationS,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesign.spacingS),
                decoration: BoxDecoration(
                  color: AppColors.getInfo(isDark),
                  borderRadius: BorderRadius.circular(AppDesign.radiusS),
                ),
                child: const Icon(
                  CupertinoIcons.lightbulb_fill,
                  color: AppColors.textOnPrimary,
                  size: AppDesign.iconM,
                ),
              ),
              const SizedBox(width: AppDesign.spacingM),
              Expanded(
                child: Text(
                  'AI Insights',
                  style: AppTypography.headingMedium.copyWith(
                    color: AppDesign.getTextPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.spacingM),
          Text(
            apiResponse,
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
