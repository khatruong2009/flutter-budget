import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _deepLinkChannel =
      MethodChannel('budget_app/deeplink');
  final Completer<void> _initializationCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();

    _setupDeepLinks();
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
        icon: 'minus.circle.fill',
      ),
      const ShortcutItem(
        type: 'action_add_income',
        localizedTitle: 'Add Income',
        icon: 'plus.circle.fill',
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

    try {
      // Load existing transactions and recurring transactions
      await transactionModel.getTransactions();
      await recurringModel.loadRecurringTransactions();

      // Create transaction generator and generate due transactions
      final generator = TransactionGenerator(
        transactionModel: transactionModel,
        recurringModel: recurringModel,
      );
      await generator.generateDueTransactions();
    } finally {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  void _setupDeepLinks() {
    _deepLinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'deep_link') {
        await _handleDeepLink(call.arguments as String?);
      } else {
        throw PlatformException(
            code: 'UNIMPLEMENTED',
            message: 'Method ${call.method} not implemented');
      }
    });

    _deepLinkChannel.invokeMethod<String>('getInitialLink').then((value) {
      _handleDeepLink(value);
    }).catchError((_) {
      // Silently ignore failures fetching the initial link so app startup isn't blocked.
    });
  }

  Future<void> _handleDeepLink(String? link) async {
    if (link == null || !mounted) return;
    final uri = Uri.tryParse(link);
    if (uri == null) return;

    final action = uri.host.isNotEmpty
        ? uri.host
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '');

    if (action.isEmpty) return;

    await _initializationCompleter.future;

    final targetContext = navigatorKey.currentContext ?? context;
    final transactionModel =
        Provider.of<TransactionModel>(targetContext, listen: false);

    void openForm(TransactionTyp type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTransactionForm(targetContext, type, transactionModel.addTransaction);
      });
    }

    if (action == 'add-income' || action == 'add_income') {
      openForm(TransactionTyp.income);
    } else if (action == 'add-expense' || action == 'add_expense') {
      openForm(TransactionTyp.expense);
    }
  }
}
