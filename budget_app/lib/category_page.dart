import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'transaction_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'transaction.dart';

class CategoryPage extends StatelessWidget {
  CategoryPage({Key? key}) : super(key: key);

  final Map<String, IconData> expenseCategories = {
    'General': CupertinoIcons.square_grid_2x2,
    'Eating Out': CupertinoIcons.drop_triangle,
    'Groceries': CupertinoIcons.cart,
    'Housing': CupertinoIcons.house,
    'Transportation': CupertinoIcons.car_detailed,
    'Travel': CupertinoIcons.airplane,
    'Clothing': CupertinoIcons.bag,
    'Gift': CupertinoIcons.gift,
    'Health': CupertinoIcons.heart,
    'Entertainment': CupertinoIcons.film,
  };

  final List<Color> colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.brown,
    Colors.purple,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionModel>(
      builder: (context, transactionModel, child) {
        final Map<String, double> expensesPerCategory = {};
        for (final transaction in transactionModel.currentMonthTransactions
            .where((t) => t.type == TransactionTyp.EXPENSE)) {
          expensesPerCategory.update(
            transaction.category,
            (existingValue) => existingValue + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }

        double totalAmount = expensesPerCategory.values.isNotEmpty
            ? expensesPerCategory.values.reduce((a, b) => a + b)
            : 0.0;

        if (totalAmount == 0.0) {
          return Center(
            child: Text(
              'No expenses',
              style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  decoration: TextDecoration.none),
            ),
          );
        }

        final List<CategoryPieChartSectionData> sections = [];

        int index = 0;
        expensesPerCategory.forEach((key, value) {
          final color = colors[index % colors.length];
          double percentage = (value / totalAmount) * 100;
          sections.add(
            CategoryPieChartSectionData(
              color: color,
              value: value,
              title: '',
              radius: 100,
              percentage: percentage,
              badgeWidget: Icon(
                expenseCategories[key],
                color: color,
                size: 24,
              ),
              badgePositionPercentageOffset: 1.2,
              iconData: expenseCategories[key],
              category: key,
            ),
          );
          index++;
        });

        sections.sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                    Icons.more_vert), // Example for additional actions
                onPressed: () {
                  // Placeholder for more actions
                },
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * .7,
                  height: MediaQuery.of(context).size.height * .7,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      sectionsSpace: 2, // Slight space for clarity
                      centerSpaceRadius: 30,
                      pieTouchData: PieTouchData(
                        enabled: true, // Allow touch interactions
                        touchCallback:
                            (FlTouchEvent event, PieTouchResponse? response) {
                          // Placeholder for touch interactions
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // legend
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: sections.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                            decoration: TextDecoration.none,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                color: sections[index].color, // Color box
                                child: Icon(
                                  sections[index].iconData,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(
                                width: 16,
                              ),
                              Expanded(
                                child: Text(
                                  '${sections[index].category}: ${sections[index].percentage?.toStringAsFixed(2)}% - \$${expensesPerCategory[sections[index].category]?.toStringAsFixed(2)}',
                                  maxLines: 1,
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
        );
      },
    );
  }
}

class CategoryPieChartSectionData extends PieChartSectionData {
  final IconData? iconData;
  final String? category;
  final double? percentage;

  CategoryPieChartSectionData({
    Color? color,
    double? value,
    String? title,
    double? radius,
    TextStyle? titleStyle,
    Widget? badgeWidget,
    double? badgePositionPercentageOffset,
    this.iconData,
    this.category,
    this.percentage,
  }) : super(
          color: color,
          value: value,
          title: title,
          radius: radius,
          titleStyle: titleStyle,
          badgeWidget: badgeWidget,
          badgePositionPercentageOffset: badgePositionPercentageOffset,
        );
}
