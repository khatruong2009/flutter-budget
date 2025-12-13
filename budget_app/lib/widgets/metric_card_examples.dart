import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../design_system.dart';

/// Example page demonstrating the usage of AnimatedMetricCard components
/// This file shows various metric card configurations and animations
class MetricCardExamplesPage extends StatefulWidget {
  const MetricCardExamplesPage({super.key});

  @override
  State<MetricCardExamplesPage> createState() => _MetricCardExamplesPageState();
}

class _MetricCardExamplesPageState extends State<MetricCardExamplesPage> {
  double incomeValue = 5432.10;
  double expenseValue = 3210.50;
  double balanceValue = 2221.60;
  double savingsRate = 40.8;

  void _updateValues() {
    setState(() {
      incomeValue += 100;
      expenseValue += 50;
      balanceValue = incomeValue - expenseValue;
      savingsRate = ((incomeValue - expenseValue) / incomeValue * 100);
    });
  }

  void _resetValues() {
    setState(() {
      incomeValue = 5432.10;
      expenseValue = 3210.50;
      balanceValue = 2221.60;
      savingsRate = 40.8;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metric Card Examples'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: _resetValues,
            tooltip: 'Reset Values',
          ),
        ],
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Metric Cards Section
              Text(
                'Financial Metrics',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AnimatedMetricCard(
                label: 'Total Income',
                value: incomeValue,
                icon: CupertinoIcons.arrow_up_circle_fill,
                color: AppColors.getIncome(isDark),
                prefix: '\$',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Income: \$${incomeValue.toStringAsFixed(2)}')),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AnimatedMetricCard(
                label: 'Total Expenses',
                value: expenseValue,
                icon: CupertinoIcons.arrow_down_circle_fill,
                color: AppColors.getExpense(isDark),
                prefix: '\$',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Expenses: \$${expenseValue.toStringAsFixed(2)}')),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AnimatedMetricCard(
                label: 'Net Balance',
                value: balanceValue,
                icon: CupertinoIcons.money_dollar_circle_fill,
                color: AppColors.primary,
                prefix: '\$',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Balance: \$${balanceValue.toStringAsFixed(2)}')),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Percentage Metrics Section
              Text(
                'Performance Metrics',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AnimatedMetricCard(
                label: 'Savings Rate',
                value: savingsRate,
                icon: CupertinoIcons.chart_bar_fill,
                color: AppColors.warning,
                suffix: '%',
                fractionDigits: 1,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Grid Layout Section
              Text(
                'Grid Layout',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              Row(
                children: [
                  Expanded(
                    child: AnimatedMetricCard(
                      label: 'Income',
                      value: incomeValue,
                      icon: CupertinoIcons.arrow_up,
                      color: AppColors.getIncome(isDark),
                      prefix: '\$',
                      fractionDigits: 0,
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingM),
                  Expanded(
                    child: AnimatedMetricCard(
                      label: 'Expenses',
                      value: expenseValue,
                      icon: CupertinoIcons.arrow_down,
                      color: AppColors.getExpense(isDark),
                      prefix: '\$',
                      fractionDigits: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Different Gradients Section
              Text(
                'Custom Gradients',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              const AnimatedMetricCard(
                label: 'Card Color',
                value: 1234.56,
                icon: CupertinoIcons.creditcard_fill,
                color: AppColors.warning,
                prefix: '\$',
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AnimatedMetricCard(
                label: 'Neutral Color',
                value: 789.12,
                icon: CupertinoIcons.square_stack_3d_up_fill,
                color: AppColors.getNeutral(isDark),
                prefix: '\$',
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Integer Values Section
              Text(
                'Count Metrics',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              const AnimatedMetricCard(
                label: 'Total Transactions',
                value: 42,
                icon: CupertinoIcons.list_bullet,
                color: AppColors.primary,
                fractionDigits: 0,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Interactive Example
              Text(
                'Interactive Animation',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              Text(
                'Tap the button below to see the values animate',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Update Values',
                icon: CupertinoIcons.arrow_clockwise,
                onPressed: _updateValues,
                expanded: true,
              ),
              const SizedBox(height: AppDesign.spacingL),
            ],
          ),
        ),
      ),
    );
  }
}
