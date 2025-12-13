import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design_system.dart';
import 'empty_state.dart';

/// Example page demonstrating various EmptyState configurations
class EmptyStateExamples extends StatelessWidget {
  const EmptyStateExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Empty State Examples'),
      ),
      child: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppDesign.spacingM),
            children: [
              // Example 1: No Data State
              _buildSection(
                context,
                'No Data State',
                'Default empty state when no data exists',
                EmptyState.noData(
                  actionLabel: 'Add Transaction',
                  onAction: () {
                    _showSnackBar(context, 'Add Transaction tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 2: No Results State
              _buildSection(
                context,
                'No Results State',
                'Empty state when search returns no results',
                EmptyState.noResults(
                  actionLabel: 'Clear Filters',
                  onAction: () {
                    _showSnackBar(context, 'Clear Filters tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 3: Error State
              _buildSection(
                context,
                'Error State',
                'Empty state when an error occurs',
                EmptyState.error(
                  actionLabel: 'Try Again',
                  onAction: () {
                    _showSnackBar(context, 'Try Again tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 4: Custom No Data State
              _buildSection(
                context,
                'Custom No Data State',
                'Custom title, message, and icon',
                EmptyState.noData(
                  title: 'No Transactions',
                  message: 'Start tracking your expenses by adding your first transaction',
                  icon: CupertinoIcons.money_dollar_circle,
                  actionLabel: 'Add First Transaction',
                  onAction: () {
                    _showSnackBar(context, 'Add First Transaction tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 5: Custom No Results State
              _buildSection(
                context,
                'Custom No Results State',
                'Custom search empty state',
                EmptyState.noResults(
                  title: 'No Matching Transactions',
                  message: 'We couldn\'t find any transactions matching your search criteria',
                  icon: CupertinoIcons.search_circle,
                  actionLabel: 'Reset Search',
                  onAction: () {
                    _showSnackBar(context, 'Reset Search tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 6: Custom Error State
              _buildSection(
                context,
                'Custom Error State',
                'Custom error message',
                EmptyState.error(
                  title: 'Connection Failed',
                  message: 'Unable to sync your data. Please check your internet connection',
                  icon: CupertinoIcons.wifi_slash,
                  actionLabel: 'Retry',
                  onAction: () {
                    _showSnackBar(context, 'Retry tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 7: Empty State with Gradient Icon
              _buildSection(
                context,
                'Empty State with Gradient Icon',
                'Using gradient background for icon',
                EmptyState(
                  type: EmptyStateType.noData,
                  title: 'No Categories',
                  message: 'Create your first category to organize your transactions',
                  icon: CupertinoIcons.tag,
                  iconGradient: AppColors.primaryGradient,
                  actionLabel: 'Create Category',
                  onAction: () {
                    _showSnackBar(context, 'Create Category tapped');
                  },
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 8: Empty State without Action Button
              _buildSection(
                context,
                'Empty State without Action',
                'No action button provided',
                EmptyState.noData(
                  title: 'No History',
                  message: 'Your transaction history will appear here',
                ),
              ),
              
              const SizedBox(height: AppDesign.spacingXL),
              
              // Example 9: Empty State with Custom Icon Size
              _buildSection(
                context,
                'Empty State with Custom Icon Size',
                'Larger icon size',
                EmptyState(
                  type: EmptyStateType.noData,
                  title: 'No Insights Available',
                  message: 'Add more transactions to see insights about your spending',
                  icon: CupertinoIcons.chart_bar,
                  iconSize: AppDesign.iconXXL * 1.5,
                  iconGradient: AppColors.incomeGradient,
                  actionLabel: 'Add Transactions',
                  onAction: () {
                    _showSnackBar(context, 'Add Transactions tapped');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    Widget example,
  ) {
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
        ElevatedCard(
          child: SizedBox(
            height: 300,
            child: example,
          ),
        ),
      ],
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
