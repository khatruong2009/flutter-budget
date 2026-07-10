import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';
import 'storage/storage_keys.dart';

/// Shows the concise first-launch tour once, then leaves [child] untouched.
///
/// Completion is persisted locally, so existing users and returning users go
/// straight to the app. A missing key deliberately means the tour is shown.
class OnboardingTutorialGate extends StatefulWidget {
  final Widget child;

  const OnboardingTutorialGate({super.key, required this.child});

  @override
  State<OnboardingTutorialGate> createState() => _OnboardingTutorialGateState();
}

class _OnboardingTutorialGateState extends State<OnboardingTutorialGate> {
  bool? _showTutorial;

  @override
  void initState() {
    super.initState();
    _loadCompletionState();
  }

  Future<void> _loadCompletionState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final completed =
          preferences.getBool(StorageKeys.onboardingCompleted) ?? false;
      if (mounted) setState(() => _showTutorial = !completed);
    } catch (_) {
      // If local storage is temporarily unavailable, keep the app usable and
      // offer the tour rather than blocking startup.
      if (mounted) setState(() => _showTutorial = true);
    }
  }

  Future<void> _completeTutorial() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(StorageKeys.onboardingCompleted, true);
    } finally {
      if (mounted) setState(() => _showTutorial = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTutorial = _showTutorial;
    if (showTutorial == null) {
      return Scaffold(
        backgroundColor: AppDesign.getBackgroundColor(context),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.getAccent(
              Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      );
    }

    if (!showTutorial) return widget.child;

    return _OnboardingTutorial(onComplete: _completeTutorial);
  }
}

class _OnboardingTutorial extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _OnboardingTutorial({required this.onComplete});

  @override
  State<_OnboardingTutorial> createState() => _OnboardingTutorialState();
}

class _OnboardingTutorialState extends State<_OnboardingTutorial> {
  final PageController _pageController = PageController();
  var _currentPage = 0;
  var _isCompleting = false;

  static const _pages = [
    _TutorialPageData(
      icon: Icons.account_balance_wallet_rounded,
      eyebrow: 'WELCOME TO BUDGIE',
      title: 'Your money, made clearer.',
      description:
          'Budgie keeps your budget simple and private. Everything stays on this device.',
    ),
    _TutorialPageData(
      icon: Icons.add_chart_rounded,
      eyebrow: 'START HERE',
      title: 'Track what comes and goes.',
      description:
          'On Home, use the add button for income or expenses. Your balance and recent activity update as you go.',
    ),
    _TutorialPageData(
      icon: Icons.insights_rounded,
      eyebrow: 'EXPLORE WHEN READY',
      title: 'Plan ahead, then look back.',
      description:
          'Worth tracks accounts, Goals keeps savings in view, and Spend, Flow, and More help you understand and manage your budget.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextOrComplete() async {
    if (_isCompleting) return;

    if (_currentPage < _pages.length - 1) {
      await _pageController.nextPage(
        duration: AppAnimations.normal,
        curve: AppAnimations.easeInOut,
      );
      return;
    }

    setState(() => _isCompleting = true);
    await widget.onComplete();
  }

  Future<void> _skip() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.getAccent(isDark);
    final onAccent = AppColors.getOnAccent(isDark);
    final textPrimary = AppColors.getTextColor(isDark);
    final textSecondary = AppColors.getTextSecondaryColor(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesign.spacingL,
            AppDesign.spacingS,
            AppDesign.spacingL,
            AppDesign.spacingL,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isCompleting ? null : _skip,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemBuilder: (context, index) => _TutorialPage(
                    page: _pages[index],
                    pageNumber: index + 1,
                    pageCount: _pages.length,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ),
              Semantics(
                label: 'Tutorial page ${_currentPage + 1} of ${_pages.length}',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: AppAnimations.fast,
                      width: index == _currentPage ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _currentPage
                            ? accent
                            : AppColors.getBorder(isDark),
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusRound),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.spacingL),
              SizedBox(
                width: double.infinity,
                height: AppDesign.touchTargetL,
                child: FilledButton(
                  onPressed: _isCompleting ? null : _nextOrComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: onAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusL),
                    ),
                  ),
                  child: _isCompleting
                      ? SizedBox(
                          width: AppDesign.iconS,
                          height: AppDesign.iconS,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onAccent,
                          ),
                        )
                      : Text(
                          _currentPage == _pages.length - 1
                              ? 'Start budgeting'
                              : 'Continue',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final _TutorialPageData page;
  final int pageNumber;
  final int pageCount;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _TutorialPage({
    required this.page,
    required this.pageNumber,
    required this.pageCount,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tutorial page $pageNumber of $pageCount',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDesign.spacingS),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                boxShadow: AppColors.glow(
                  accent,
                  blurRadius: 32,
                  alpha: 0.25,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(page.icon, color: accent, size: 52),
            ),
            const SizedBox(height: AppDesign.spacingXXL),
            Text(
              page.eyebrow,
              textAlign: TextAlign.center,
              style: AppTypography.eyebrow.copyWith(color: accent),
            ),
            const SizedBox(height: AppDesign.spacingM),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: AppTypography.displayMedium.copyWith(color: textPrimary),
            ),
            const SizedBox(height: AppDesign.spacingM),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  color: textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPageData {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;

  const _TutorialPageData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}
