import 'dart:async';
import 'dart:math' as math;
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
import 'design_system.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          surface: AppColors.surfaceLight,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        cardColor: AppColors.cardLight,
        canvasColor: AppColors.backgroundLight,
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.cardLight,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.cardLight,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: AppColors.borderLight,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundLight,
        ),
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          surface: AppColors.surfaceDark,
          error: AppColors.errorDarkTheme,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        cardColor: AppColors.cardDark,
        canvasColor: AppColors.backgroundDark,
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: AppColors.borderDark,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDark,
        ),
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
  static const Duration _deepLinkDedupWindow = Duration(seconds: 2);
  String? _lastHandledLink;
  DateTime? _lastHandledLinkAt;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();

    _setupDeepLinks();
    quickActions.initialize(_handleQuickAction);

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
    _initFuture ??= _initializeApp(context);
    return FutureBuilder(
      future: _initFuture,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: ready
              ? const BudgetHomePage(title: 'Home')
              : const _OpeningScreen(),
        );
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

  Future<void> _handleQuickAction(String shortcutType) async {
    await _initializationCompleter.future;
    if (!mounted) return;

    final targetContext = navigatorKey.currentContext ?? context;
    final transactionModel =
        Provider.of<TransactionModel>(targetContext, listen: false);

    void openForm(TransactionTyp type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTransactionForm(targetContext, type, transactionModel.addTransaction);
      });
    }

    if (shortcutType == 'action_add_expense') {
      openForm(TransactionTyp.expense);
    } else if (shortcutType == 'action_add_income') {
      openForm(TransactionTyp.income);
    }
  }

  Future<void> _handleDeepLink(String? link) async {
    if (link == null || !mounted) return;
    if (!_shouldHandleDeepLink(link)) return;
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

  bool _shouldHandleDeepLink(String link) {
    final lastHandledAt = _lastHandledLinkAt;
    final now = DateTime.now();
    if (_lastHandledLink == link &&
        lastHandledAt != null &&
        now.difference(lastHandledAt) < _deepLinkDedupWindow) {
      return false;
    }
    _lastHandledLink = link;
    _lastHandledLinkAt = now;
    return true;
  }
}

/// Opening screen shown while app data loads.
///
/// Its first frame matches the native launch screen exactly (same app-icon
/// gradient, same 120pt mark dead center), so the native-to-Flutter handoff
/// is invisible. The glow, wordmark, and loader then animate in on top.
class _OpeningScreen extends StatefulWidget {
  const _OpeningScreen();

  static const double logoSize = 120;

  // Vertical gradient sampled from the app icon background.
  static const Color gradientTop = Color(0xFF0C27DF);
  static const Color gradientBottom = Color(0xFF4C67FF);

  @override
  State<_OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<_OpeningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final Animation<double> _glow;
  late final Animation<double> _logoLift;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameRise;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineRise;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward();
    _pulse = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _glow = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _logoLift = Tween<double>(begin: 1.0, end: 1.03).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));
    _nameFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
    );
    _nameRise = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic),
    ));
    _taglineFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );
    _taglineRise = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOutCubic),
    ));
    _loaderFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _OpeningScreen.gradientTop,
              _OpeningScreen.gradientBottom,
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _OpeningGlowPainter(
                    intensity: _glow,
                  ),
                ),
              ),
              Center(
                child: ScaleTransition(
                  scale: _logoLift,
                  child: Image.asset(
                    'assets/budgie_mark.png',
                    width: _OpeningScreen.logoSize,
                    height: _OpeningScreen.logoSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: height / 2 +
                    _OpeningScreen.logoSize / 2 +
                    AppDesign.spacingL,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: _nameFade,
                      child: SlideTransition(
                        position: _nameRise,
                        child: Text(
                          'Budgie',
                          textAlign: TextAlign.center,
                          style: AppTypography.displayMedium.copyWith(
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: SlideTransition(
                        position: _taglineRise,
                        child: Text(
                          'BUDGET IN BALANCE',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 2.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: height * 0.08,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _loaderFade,
                  child: _PulsingDots(
                    animation: _pulse,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          );
        },
          ),
        ),
      ),
    );
  }
}

/// Soft radial washes that ground the logo on the blue brand canvas: a warm
/// light halo directly behind the mark, a faint sheen high on the page, and
/// a ground shadow under the mark's feet.
class _OpeningGlowPainter extends CustomPainter {
  final Animation<double> intensity;

  _OpeningGlowPainter({required this.intensity}) : super(repaint: intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final t = intensity.value;
    if (t == 0) return;

    final center = size.center(Offset.zero);
    final base = size.shortestSide;

    void glow(Offset c, double radius, Color color, double alpha) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha * t),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, paint);
    }

    glow(center, base * 0.46, Colors.white, 0.14);
    glow(center, base * 0.26, AppColors.warning, 0.18);
    glow(Offset(size.width * 0.50, -size.height * 0.06), base * 0.7,
        Colors.white, 0.06);

    final shadowPaint = Paint()
      ..color = const Color(0xFF041370).withValues(alpha: 0.30 * t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, _OpeningScreen.logoSize / 2 + 8),
        width: 88,
        height: 18,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OpeningGlowPainter oldDelegate) {
    return oldDelegate.intensity != intensity;
  }
}

class _PulsingDots extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _PulsingDots({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (animation.value - i / 3) * 2 * math.pi;
            final wave = (math.sin(phase) + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDesign.spacingXS),
              child: Opacity(
                opacity: 0.25 + 0.75 * wave,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
