import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'lib/design_system.dart';

void main() {
  runApp(const MetricCardTestApp());
}

class MetricCardTestApp extends StatelessWidget {
  const MetricCardTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metric Card Test',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const MetricCardTestPage(),
    );
  }
}

class MetricCardTestPage extends StatefulWidget {
  const MetricCardTestPage({super.key});

  @override
  State<MetricCardTestPage> createState() => _MetricCardTestPageState();
}

class _MetricCardTestPageState extends State<MetricCardTestPage> {
  double value = 1234.56;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnimatedMetricCard Test'),
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesign.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedMetricCard(
                  label: 'Total Balance',
                  value: value,
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  color: AppColors.getIncome(isDark),
                  prefix: '\$',
                  onTap: () {
                    setState(() {
                      value += 100;
                    });
                  },
                ),
                const SizedBox(height: AppDesign.spacingXL),
                AppButton.primary(
                  label: 'Increase Value',
                  icon: CupertinoIcons.add,
                  onPressed: () {
                    setState(() {
                      value += 100;
                    });
                  },
                  expanded: true,
                ),
                const SizedBox(height: AppDesign.spacingM),
                AppButton.secondary(
                  label: 'Reset',
                  icon: CupertinoIcons.refresh,
                  onPressed: () {
                    setState(() {
                      value = 1234.56;
                    });
                  },
                  expanded: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
