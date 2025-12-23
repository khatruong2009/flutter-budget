import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction.dart';
import 'common.dart';
import 'package:intl/intl.dart';
import 'design_system.dart';
import 'widgets/empty_state.dart';
import 'utils/platform_utils.dart';
import 'category_transactions_page.dart';
import 'widgets/month_selector.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _chartAnimation;
  int _touchedIndex = -1;
  DateTime? selectedMonth;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        List<DateTime> availableMonths = transactionModel.getAvailableMonths();

        // Set initial selected month to most recent month if not set
        if (selectedMonth == null && availableMonths.isNotEmpty) {
          selectedMonth = availableMonths.first;
        }

        // Get transactions for selected month
        final monthTransactions = selectedMonth != null
            ? transactionModel.getTransactionsForMonth(selectedMonth!)
            : transactionModel.currentMonthTransactions;

        final Map<String, double> expensesPerCategory = {};
        for (final transaction in monthTransactions
            .where((t) => t.type == TransactionTyp.expense)) {
          expensesPerCategory.update(
            transaction.category,
            (existingValue) => existingValue + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }

        double totalAmount = expensesPerCategory.values.isNotEmpty
            ? expensesPerCategory.values.reduce((a, b) => a + b)
            : 0.0;

        // Show empty state when no months available
        if (availableMonths.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Categories'),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            extendBodyBehindAppBar: true,
            body: Container(
              color: AppDesign.getBackgroundColor(context),
              child: SafeArea(
                child: EmptyState(
                  type: EmptyStateType.noData,
                  title: 'No Expenses Yet',
                  message: 'Start tracking your expenses to see category breakdowns',
                  icon: CupertinoIcons.chart_pie,
                  iconGradient: AppDesign.getExpenseGradient(context),
                ),
              ),
            ),
          );
        }

        // Show empty state when no expenses for selected month
        if (totalAmount == 0.0) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Categories'),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            extendBodyBehindAppBar: true,
            body: Container(
              color: AppDesign.getBackgroundColor(context),
              child: SafeArea(
                child: Column(
                  children: [
                    // Month selector
                    MonthSelector(
                      selectedMonth: selectedMonth,
                      availableMonths: availableMonths,
                      onMonthChanged: (DateTime newMonth) {
                        setState(() {
                          selectedMonth = newMonth;
                          _touchedIndex = -1;
                        });
                      },
                    ),
                    Expanded(
                      child: EmptyState(
                        type: EmptyStateType.noData,
                        title: 'No Expenses',
                        message: 'No expenses recorded for this month',
                        icon: CupertinoIcons.chart_pie,
                        iconGradient: AppDesign.getExpenseGradient(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final List<_CategoryData> categoryDataList = [];
        final chartColors = AppDesign.getChartColors(context);

        int index = 0;
        expensesPerCategory.forEach((key, value) {
          final color = chartColors[index % chartColors.length];
          double percentage = (value / totalAmount) * 100;
          categoryDataList.add(
            _CategoryData(
              category: key,
              value: value,
              percentage: percentage,
              color: color,
              iconData: expenseCategories[key],
            ),
          );
          index++;
        });

        categoryDataList.sort((a, b) => b.value.compareTo(a.value));

        final double screenWidth = MediaQuery.of(context).size.width;
        final double baseChartDiameter = math.max(
          200.0,
          math.min(screenWidth - AppDesign.spacingL * 2, 300.0),
        ).toDouble();
        final double chartHeight = baseChartDiameter + AppDesign.spacingM * 2;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            color: AppDesign.getBackgroundColor(context),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  // Month selector
                  MonthSelector(
                    selectedMonth: selectedMonth,
                    availableMonths: availableMonths,
                    onMonthChanged: (DateTime newMonth) {
                      setState(() {
                        selectedMonth = newMonth;
                        _touchedIndex = -1;
                        // Restart animation when month changes
                        _animationController.reset();
                        _animationController.forward();
                      });
                    },
                  ),
                  // Animated Pie Chart with dedicated space between selector and list
                  SizedBox(
                    height: chartHeight,
                    child: Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double maxDiameter = math.max(
                            200.0,
                            math.min(
                              math.max(constraints.maxWidth - AppDesign.spacingL * 2, 0),
                              300.0,
                            ),
                          ).toDouble();
                          final double chartDiameter = math.min(baseChartDiameter, maxDiameter).toDouble();
                          final double baseRadius = math.min(chartDiameter / 3.4, 110.0).toDouble();
                          final double selectedRadius = baseRadius + 6;

                          return SizedBox(
                            width: chartDiameter,
                            height: chartDiameter,
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _chartAnimation,
                                builder: (context, child) {
                                  return PieChart(
                                    PieChartData(
                                      sections: categoryDataList
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final data = entry.value;
                                        final isSelected = _touchedIndex == idx;
                                        final showPercentage =
                                            data.percentage >= 5.0;

                                        return PieChartSectionData(
                                          color: data.color,
                                          value: data.value * _chartAnimation.value,
                                          title: showPercentage
                                              ? '${data.percentage.toStringAsFixed(0)}%'
                                              : '',
                                          titleStyle: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textOnPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                offset: const Offset(0, 1),
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                          titlePositionPercentageOffset: 0.55,
                                          radius: isSelected
                                              ? selectedRadius
                                              : baseRadius,
                                          badgeWidget: data.percentage >= 4.0
                                              ? Container(
                                                  padding: const EdgeInsets.all(
                                                      AppDesign.spacingXS),
                                                  decoration: BoxDecoration(
                                                    color: AppDesign.getBackgroundColor(
                                                        context),
                                                    shape: BoxShape.circle,
                                                    boxShadow: AppDesign.shadowS,
                                                  ),
                                                  child: Icon(
                                                    data.iconData,
                                                    color: data.color,
                                                    size: AppDesign.iconS,
                                                  ),
                                                )
                                              : null,
                                          badgePositionPercentageOffset: 1.15,
                                        );
                                      }).toList(),
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 30,
                                      pieTouchData: PieTouchData(
                                        enabled: true,
                                        touchCallback: (FlTouchEvent event,
                                            PieTouchResponse? response) {
                                          setState(() {
                                            if (!event.isInterestedForInteractions ||
                                                response == null ||
                                                response.touchedSection == null) {
                                              _touchedIndex = -1;
                                              return;
                                            }
                                            _touchedIndex = response
                                                .touchedSection!.touchedSectionIndex;
                                          });

                                          if (event.isInterestedForInteractions) {
                                            HapticFeedback.selectionClick();
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Legend with Elevated Cards
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesign.spacingM,
                        vertical: AppDesign.spacingS,
                      ),
                      child: ListView.separated(
                        physics: PlatformUtils.platformScrollPhysics,
                        padding: const EdgeInsets.only(
                          bottom: AppDesign.spacingL,
                        ),
                        itemCount: categoryDataList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppDesign.spacingS),
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemBuilder: (BuildContext context, int index) {
                          final data = categoryDataList[index];
                          final isSelected = _touchedIndex == index;

                          return AnimatedScale(
                            scale: isSelected ? 1.02 : 1.0,
                            duration: AppAnimations.fast,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => CategoryTransactionsPage(
                                      category: data.category,
                                      categoryColor: data.color,
                                      categoryIcon: data.iconData,
                                      month: selectedMonth ?? transactionModel.selectedMonth,
                                    ),
                                  ),
                                );
                              },
                              child: ElevatedCard(
                                elevation: isSelected
                                    ? AppDesign.elevationM
                                    : AppDesign.elevationS,
                                padding:
                                    const EdgeInsets.all(AppDesign.spacingM),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: data.color,
                                        borderRadius:
                                            BorderRadius.circular(AppDesign.radiusM),
                                        boxShadow: AppDesign.shadowS,
                                      ),
                                      child: Icon(
                                        data.iconData,
                                        color: AppColors.textOnPrimary,
                                        size: AppDesign.iconM,
                                      ),
                                    ),
                                    const SizedBox(width: AppDesign.spacingM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data.category,
                                            style: AppTypography.bodyLarge.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppDesign.getTextPrimary(context),
                                            ),
                                          ),
                                          const SizedBox(height: AppDesign.spacingXXS),
                                          Text(
                                            '${data.percentage.toStringAsFixed(1)}%',
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: AppDesign.getTextSecondary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppDesign.spacingS),
                                    Flexible(
                                      child: Text(
                                        '\$${NumberFormat("#,##0.00", "en_US").format(data.value)}',
                                        style: AppTypography.headingMedium.copyWith(
                                          color: data.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppDesign.spacingS),
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      color: AppDesign.getTextSecondary(context),
                                      size: AppDesign.iconS,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryData {
  final String category;
  final double value;
  final double percentage;
  final Color color;
  final IconData? iconData;

  _CategoryData({
    required this.category,
    required this.value,
    required this.percentage,
    required this.color,
    this.iconData,
  });
}
