import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'transaction.dart';
import 'spending_page.dart';
import 'transaction_page.dart';
import 'category_page.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'design_system.dart';

class BudgetHomePage extends StatefulWidget {
  const BudgetHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<BudgetHomePage> createState() => _BudgetHomePageState();
}

class _BudgetHomePageState extends State<BudgetHomePage> {
  double total = 0.0;
  List<Transaction> transactions = [];

  double totalIncome = 0.0;
  double totalExpenses = 0.0;

  int _currentIndex = 0;
  late PageController _pageController;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          SpendingPage(),
          const TransactionPage(),
          const CategoryPage(),
          const HistoryPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: _buildModernTabBar(isDark),
    );
  }

  Widget _buildModernTabBar(bool isDark) {
    return CupertinoTabBar(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      activeColor: AppColors.primary,
      inactiveColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
      currentIndex: _currentIndex,
      onTap: _onTabTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.money_dollar_circle),
          label: 'Spending',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.list_bullet),
          label: 'Transactions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart),
          label: 'Categories',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.chart_bar),
          label: 'Cash Flow',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.gear),
          label: 'Settings',
        ),
      ],
    );
  }
}
