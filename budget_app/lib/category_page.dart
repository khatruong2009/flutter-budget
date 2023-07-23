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
        for (final transaction in transactionModel.transactions
            .where((t) => t.type == TransactionType.EXPENSE)) {
          expensesPerCategory.update(
            transaction.category,
            (existingValue) => existingValue + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        }

        double totalAmount = expensesPerCategory.values.reduce((a, b) => a + b);

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

        return Column(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * .7,
                height: MediaQuery.of(context).size.height * .7,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 0,
                    centerSpaceRadius: 0,
                    pieTouchData: PieTouchData(
                      enabled: false,
                    ),
                  ),
                ),
              ),
            ),
            // legend
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: ListView.builder(
                  itemCount: sections.length,
                  itemBuilder: (BuildContext context, int index) {
                    return DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sections[index].iconData,
                            color: sections[index].color,
                            size: 24,
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                              '${sections[index].category}: ${sections[index].percentage?.toStringAsFixed(2)}% - \$${expensesPerCategory[sections[index].category]?.toStringAsFixed(2)}'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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