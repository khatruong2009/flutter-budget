import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../transaction.dart';
import '../transaction_form.dart';
import '../transaction_model.dart';
import '../voice_expense_service.dart';
import 'pill_chip.dart';

bool _quickEntryFlowActive = false;

/// Opens the local quick-entry flow.
///
/// The old name remains so existing deep links and native widgets continue to
/// work. The flow no longer records or uploads audio.
Future<void> startVoiceExpenseFlow(BuildContext context) async {
  if (_quickEntryFlowActive) return;
  _quickEntryFlowActive = true;
  try {
    final model = Provider.of<TransactionModel>(context, listen: false);
    final draft = await showVoiceRecordingSheet(context);
    if (draft == null || !context.mounted) return;
    await showTransactionForm(
      context,
      draft.type,
      model.addTransaction,
      prefill: draft,
    );
  } finally {
    _quickEntryFlowActive = false;
  }
}

/// Compatibility name for callers that previously opened the voice sheet.
Future<Transaction?> showVoiceRecordingSheet(BuildContext context) {
  return showModalBottomSheet<Transaction>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => const _LocalQuickEntrySheet(),
  );
}

class _LocalQuickEntrySheet extends StatefulWidget {
  const _LocalQuickEntrySheet();

  @override
  State<_LocalQuickEntrySheet> createState() => _LocalQuickEntrySheetState();
}

class _LocalQuickEntrySheetState extends State<_LocalQuickEntrySheet> {
  final _controller = TextEditingController();
  final _service = VoiceExpenseService();
  String? _error;
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final draft = await _service.parse(_controller.text, DateTime.now());
      if (mounted) Navigator.of(context).pop(draft);
    } on VoiceExpenseException catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          border: Border.all(color: AppColors.getCardBorder(isDark)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.getTextTertiaryColor(isDark)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Symbols.edit_note_rounded,
                      color: accent,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Quick entry',
                      style: AppTypography.sectionHeader.copyWith(
                        color: AppColors.getTextColor(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Type a short description. Budgie parses it on this device and never uploads it.',
                  style: AppTypography.rowSubtitle.copyWith(
                    color: AppColors.getTextSecondaryColor(isDark),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _continue(),
                  decoration: InputDecoration(
                    hintText: 'e.g. \$12.50 lunch at Chipotle yesterday',
                    errorText: _error,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: _processing ? 'Parsing...' : 'Continue',
                  icon: Symbols.arrow_forward_rounded,
                  color: accent,
                  filled: true,
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
