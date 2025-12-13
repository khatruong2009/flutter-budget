import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design_system.dart';
import 'loading_shimmer.dart';

/// Examples demonstrating the usage of LoadingShimmer component
/// 
/// This file provides practical examples of how to use the LoadingShimmer
/// widget in different scenarios within the budget app.
class LoadingShimmerExamples extends StatefulWidget {
  const LoadingShimmerExamples({super.key});

  @override
  State<LoadingShimmerExamples> createState() => _LoadingShimmerExamplesState();
}

class _LoadingShimmerExamplesState extends State<LoadingShimmerExamples> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Loading Shimmer Examples'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDesign.spacingM),
          children: [
            // Toggle button
            AppButton.primary(
              label: _isLoading ? 'Show Content' : 'Show Loading',
              onPressed: () {
                setState(() {
                  _isLoading = !_isLoading;
                });
              },
              expanded: true,
            ),
            const SizedBox(height: AppDesign.spacingXL),

            // Example 1: List Shimmer
            _buildSection(
              title: 'List Shimmer',
              description: 'Used for transaction lists while loading',
              child: _isLoading
                  ? LoadingShimmer.list(itemCount: 3)
                  : _buildSampleList(),
            ),

            const SizedBox(height: AppDesign.spacingXL),

            // Example 2: Card Shimmer
            _buildSection(
              title: 'Card Shimmer',
              description: 'Used for metric cards while loading',
              child: _isLoading
                  ? LoadingShimmer.card(itemCount: 2)
                  : _buildSampleCards(),
            ),

            const SizedBox(height: AppDesign.spacingXL),

            // Example 3: Text Shimmer
            _buildSection(
              title: 'Text Shimmer',
              description: 'Used for text content while loading',
              child: _isLoading
                  ? LoadingShimmer.text(itemCount: 4)
                  : _buildSampleText(),
            ),

            const SizedBox(height: AppDesign.spacingXL),

            // Example 4: Custom Shimmer
            _buildSection(
              title: 'Custom Shimmer',
              description: 'Custom skeleton layout for specific needs',
              child: _isLoading
                  ? LoadingShimmer.custom(
                      child: _buildCustomSkeleton(),
                    )
                  : _buildSampleCustomContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headingMedium.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: AppDesign.spacingXS),
        Text(
          description,
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
        const SizedBox(height: AppDesign.spacingM),
        child,
      ],
    );
  }

  Widget _buildSampleList() {
    return Column(
      children: [
        _buildListItem('Groceries', 'Food & Dining', '\$45.99', Colors.red),
        const SizedBox(height: AppDesign.spacingM),
        _buildListItem('Salary', 'Income', '\$3,500.00', Colors.green),
        const SizedBox(height: AppDesign.spacingM),
        _buildListItem('Gas', 'Transportation', '\$52.30', Colors.red),
      ],
    );
  }

  Widget _buildListItem(String title, String category, String amount, Color color) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
            child: Icon(
              CupertinoIcons.money_dollar_circle,
              color: color,
            ),
          ),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppDesign.getTextTertiary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTypography.headingMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppDesign.spacingM,
      mainAxisSpacing: AppDesign.spacingM,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Income', '\$3,500', CupertinoIcons.arrow_down_circle, AppColors.incomeGradient),
        _buildMetricCard('Expenses', '\$2,150', CupertinoIcons.arrow_up_circle, AppColors.expenseGradient),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Gradient gradient) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDesign.spacingS),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(AppDesign.radiusS),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: AppDesign.iconM,
                ),
              ),
              const SizedBox(width: AppDesign.spacingS),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppDesign.getTextSecondary(context),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your spending this month is on track with your budget.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppDesign.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: AppDesign.spacingS),
        Text(
          'You have spent \$2,150 out of your \$3,000 budget.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSkeleton() {
    return Container(
      padding: const EdgeInsets.all(AppDesign.spacingL),
      decoration: BoxDecoration(
        color: AppDesign.getGlassSurface(context, AppDesign.glassOpacity),
        borderRadius: BorderRadius.circular(AppDesign.radiusL),
      ),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(AppDesign.radiusS),
            ),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(AppDesign.radiusS),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleCustomContent() {
    return GlassCard(
      padding: const EdgeInsets.all(AppDesign.spacingL),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.chart_pie,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppDesign.spacingM),
          Text(
            'Monthly Overview',
            style: AppTypography.headingMedium.copyWith(
              color: AppDesign.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Text(
            'Your financial summary for this month',
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Example showing LoadingShimmer in a real transaction list context
class TransactionListWithShimmer extends StatefulWidget {
  const TransactionListWithShimmer({super.key});

  @override
  State<TransactionListWithShimmer> createState() => _TransactionListWithShimmerState();
}

class _TransactionListWithShimmerState extends State<TransactionListWithShimmer> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Transactions'),
      ),
      child: SafeArea(
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(AppDesign.spacingM),
                child: LoadingShimmer.list(itemCount: 5),
              )
            : ListView(
                padding: const EdgeInsets.all(AppDesign.spacingM),
                children: [
                  _buildTransaction('Groceries', 'Food & Dining', '\$45.99'),
                  const SizedBox(height: AppDesign.spacingM),
                  _buildTransaction('Salary', 'Income', '\$3,500.00'),
                  const SizedBox(height: AppDesign.spacingM),
                  _buildTransaction('Gas', 'Transportation', '\$52.30'),
                  const SizedBox(height: AppDesign.spacingM),
                  _buildTransaction('Coffee', 'Food & Dining', '\$5.50'),
                  const SizedBox(height: AppDesign.spacingM),
                  _buildTransaction('Rent', 'Housing', '\$1,200.00'),
                ],
              ),
      ),
    );
  }

  Widget _buildTransaction(String title, String category, String amount) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDesign.radiusM),
            ),
            child: const Icon(
              CupertinoIcons.money_dollar_circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppDesign.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: AppTypography.caption.copyWith(
                    color: AppDesign.getTextTertiary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTypography.headingMedium.copyWith(
              color: AppColors.expense,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

