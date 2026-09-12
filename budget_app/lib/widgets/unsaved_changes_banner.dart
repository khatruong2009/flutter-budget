import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../design_system.dart';
import '../recurring_transaction_model.dart';
import '../transaction_model.dart';

/// Shown whenever a model holds changes the store could not confirm on disk.
/// The rows stay visible in the app, so this is the only signal that they are
/// not yet safe across a restart. Retry re-attempts every flagged section.
class UnsavedChangesBanner extends StatelessWidget {
  const UnsavedChangesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final transactionModel = context.watch<TransactionModel>();
    final recurringModel = context.watch<RecurringTransactionModel>();
    final show =
        transactionModel.hasUnsavedChanges || recurringModel.hasUnsavedChanges;
    if (!show) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: const Key('unsaved-changes-banner'),
      color: AppColors.getDanger(isDark),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.spacingM,
            vertical: AppDesign.spacingS,
          ),
          child: Row(
            children: [
              const Icon(Symbols.cloud_off_rounded, color: Colors.white),
              const SizedBox(width: AppDesign.spacingS),
              Expanded(
                child: Text(
                  'Some changes are not saved to this device yet.',
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () {
                  unawaited(transactionModel.retryPendingSaves());
                  unawaited(recurringModel.retryPendingSaves());
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
