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
        final Map<String, double> expensesPerCategory = {};
        for (final transaction in transactionModel.currentMonthTransactions
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

        // Show empty state when no expenses
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
              child: Stack(
                children: <Widget>[
                  // Background Column with list
                  Column(
                    children: <Widget>[
                      const SizedBox(height: AppDesign.spacingL),
                      // Chart area placeholder
                      Expanded(
                        flex: 2,
                        child: Container(),
                      ),
                      // Legend with Elevated Cards
                      Expanded(
                        flex: 2,
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
                                child: ElevatedCard(
                                  elevation: isSelected ? AppDesign.elevationM : AppDesign.elevationS,
                                  padding: const EdgeInsets.all(AppDesign.spacingM),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: data.color,
                                          borderRadius: BorderRadius.circular(
                                              AppDesign.radiusM),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data.category,
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: AppDesign.getTextPrimary(
                                                    context),
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AppDesign.spacingXXS),
                                            Text(
                                              '${data.percentage.toStringAsFixed(1)}%',
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                color: AppDesign.getTextSecondary(
                                                    context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppDesign.spacingS),
                                      Flexible(
                                        child: Text(
                                          '\$${NumberFormat("#,##0.00", "en_US").format(data.value)}',
                                          style:
                                              AppTypography.headingMedium.copyWith(
                                            color: data.color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Animated Pie Chart on top layer
                  Positioned(
                    top: AppDesign.spacingL,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: false,
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.35,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _chartAnimation,
                            builder: (context, child) {
                              return Padding(
                                padding: const EdgeInsets.all(AppDesign.spacingL),
                                child: PieChart(
                              PieChartData(
                                sections: categoryDataList.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final data = entry.value;
                                  final isSelected = _touchedIndex == idx;
                                  final showPercentage = data.percentage >= 5.0;
                                  
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
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                    titlePositionPercentageOffset: 0.55,
                                    radius: isSelected ? 110 : 100,
                                    badgeWidget: data.percentage >= 4.0
                                        ? Container(
                                            padding: const EdgeInsets.all(AppDesign.spacingXS),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: AppDesign.shadowS,
                                            ),
                                            child: Icon(
                                              data.iconData,
                                              color: data.color,
                                              size: AppDesign.iconM,
                                            ),
                                          )
                                        : null,
                                    badgePositionPercentageOffset: 1.2,
                                  );
                                }).toList(),
                                sectionsSpace: 3,
                                centerSpaceRadius: 40,
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
                              ),
                            );
                          },
                        ),
                        ),
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
