import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'transaction_model.dart';
import 'recurring_transaction_model.dart';
import 'transaction_generator.dart';
import 'theme_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'transaction_form.dart';
import 'transaction.dart';
import 'utils/platform_enhancements.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TransactionModel()),
        ChangeNotifierProvider(create: (context) => RecurringTransactionModel()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const AppContainer(child: MyApp()),
    ),
  );
}

class AppContainer extends StatelessWidget {
  final Widget child;

  const AppContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Budgeting App',
      // Platform-specific scroll behavior
      scrollBehavior: const PlatformScrollBehavior(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: child,
    );
  }
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: context.read<TransactionModel>().getTransactions(),
//       builder: (BuildContext context, AsyncSnapshot snapshot) {
//         if (snapshot.connectionState == ConnectionState.done) {
//           return const BudgetHomePage(title: 'Home');
//         } else {
//           return const Center(child: CircularProgressIndicator());
//         }
//       },
//     );
//   }
// }

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final QuickActions quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();

    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_add_expense') {
        showTransactionForm(
            context,
            TransactionTyp.expense,
            Provider.of<TransactionModel>(context, listen: false)
                .addTransaction);
      } else if (shortcutType == 'action_add_income') {
        showTransactionForm(
            context,
            TransactionTyp.income,
            Provider.of<TransactionModel>(context, listen: false)
                .addTransaction);
      }
    });

    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_add_expense',
        localizedTitle: 'Add Expense',
        icon: 'minus',
      ),
      const ShortcutItem(
        type: 'action_add_income',
        localizedTitle: 'Add Income',
        icon: 'plus',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeApp(context),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const BudgetHomePage(title: 'Home');
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  /// Initialize app by loading data and generating due recurring transactions
  Future<void> _initializeApp(BuildContext context) async {
    final transactionModel = context.read<TransactionModel>();
    final recurringModel = context.read<RecurringTransactionModel>();

    // Load existing transactions and recurring transactions
    await transactionModel.getTransactions();
    await recurringModel.loadRecurringTransactions();

    // Create transaction generator and generate due transactions
    final generator = TransactionGenerator(
      transactionModel: transactionModel,
      recurringModel: recurringModel,
    );
    await generator.generateDueTransactions();
  }
}
