import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../design_system.dart';

/// A modern, compact month selector with horizontal scrolling
class MonthSelector extends StatefulWidget {
  final DateTime? selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime> onMonthChanged;

  const MonthSelector({
    Key? key,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Scroll to selected month after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth();
    });
  }

  @override
  void didUpdateWidget(MonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      _scrollToSelectedMonth();
    }
  }

  void _scrollToSelectedMonth() {
    if (widget.selectedMonth == null || widget.availableMonths.isEmpty) return;
    
    final index = widget.availableMonths.indexWhere(
      (month) => _isSameMonth(month, widget.selectedMonth!),
    );
    
    if (index != -1 && _scrollController.hasClients) {
      // Calculate position to center the selected month
      const itemWidth = 120.0;
      const spacing = 12.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetPosition = (itemWidth + spacing) * index - (screenWidth / 2) + (itemWidth / 2);
      
      _scrollController.animateTo(
        targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: AppAnimations.normal,
        curve: AppAnimations.easeOut,
      );
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableMonths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(vertical: AppDesign.spacingS),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingM),
        itemCount: widget.availableMonths.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppDesign.spacingS),
        itemBuilder: (context, index) {
          final month = widget.availableMonths[index];
          final isSelected = widget.selectedMonth != null && 
                            _isSameMonth(month, widget.selectedMonth!);
          
          return _MonthChip(
            month: month,
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onMonthChanged(month);
            },
          );
        },
      ),
    );
  }
}

class _MonthChip extends StatelessWidget {
  final DateTime month;
  final bool isSelected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.month,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.MMM().format(month);
    final year = DateFormat.y().format(month);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.easeOut,
        width: 120,
        height: 64,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesign.spacingS,
          vertical: AppDesign.spacingS,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppDesign.radiusM),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppDesign.getBorderColor(context),
            width: isSelected ? 2 : AppDesign.borderThin,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : AppDesign.shadowS,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              monthName.toUpperCase(),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.textOnPrimary
                    : AppDesign.getTextPrimary(context),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppDesign.spacingXXS),
            Text(
              year,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected
                    ? AppColors.textOnPrimary.withValues(alpha: 0.9)
                    : AppDesign.getTextSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
