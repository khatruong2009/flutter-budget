import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'transaction_model.dart';
import 'theme_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'transaction_form.dart';
import 'transaction.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => TransactionModel()),
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
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
  _MyAppState createState() => _MyAppState();
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
            TransactionTyp.EXPENSE,
            Provider.of<TransactionModel>(context, listen: false)
                .addTransaction);
      } else if (shortcutType == 'action_add_income') {
        showTransactionForm(
            context,
            TransactionTyp.INCOME,
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
      future: context.read<TransactionModel>().getTransactions(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const BudgetHomePage(title: 'Home');
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
