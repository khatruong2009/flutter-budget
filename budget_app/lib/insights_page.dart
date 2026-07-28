import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'design_system.dart';
import 'transaction_model.dart';
import 'widgets/local_insights_section.dart';

/// Full-page presentation of the same deterministic insights shown in Flow.
class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesign.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Insights'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<TransactionModel>(
        builder: (context, model, _) => ListView(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          children: [
            LocalInsightsSection(model: model),
            const SizedBox(height: AppDesign.spacingM),
            Text(
              'Insights use fixed rules and only the financial data stored in Budgie. Nothing is sent to an AI service.',
              style: AppTypography.caption.copyWith(
                color: AppDesign.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
