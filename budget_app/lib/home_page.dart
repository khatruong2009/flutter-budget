import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import 'net_worth_page.dart';
import 'spending_page.dart';
import 'savings_goals_page.dart';
import 'category_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'design_system.dart';
import 'transaction_model.dart';

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  int _currentIndex = 0;
  late PageController _pageController;

  static const List<DockItem> _dockItems = [
    DockItem(
      icon: Symbols.paid_rounded,
      filledIcon: Symbols.paid_rounded,
      label: 'Home',
    ),
    DockItem(
      icon: Symbols.donut_small_rounded,
      filledIcon: Symbols.donut_small_rounded,
      label: 'Worth',
    ),
    DockItem(
      icon: Symbols.flag_rounded,
      filledIcon: Symbols.flag_rounded,
      label: 'Goals',
    ),
    DockItem(
      icon: Symbols.pie_chart_rounded,
      filledIcon: Symbols.pie_chart_rounded,
      label: 'Spend',
    ),
    DockItem(
      icon: Symbols.bar_chart_rounded,
      filledIcon: Symbols.bar_chart_rounded,
      label: 'Flow',
    ),
    DockItem(
      icon: Symbols.settings_rounded,
      filledIcon: Symbols.settings_rounded,
      label: 'More',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });

      _pageController.animateToPage(
        index,
        duration: AppAnimations.normal,
        curve: AppAnimations.easeInOut,
      );
    }
  }

  void _onTabDragged(int index) {
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const SpendingPage(),
                ),
              ),
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const NetWorthPage(),
                ),
              ),
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => SavingsGoalsPage(
                    model: context.watch<TransactionModel>(),
                  ),
                ),
              ),
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const CategoryPage(),
                ),
              ),
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const HistoryPage(),
                ),
              ),
              Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: DockMetrics.bottomOffset(context),
            child: Center(
              child: FloatingDock(
                items: _dockItems,
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                onDragSelect: _onTabDragged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
