import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../design_system.dart';

/// Example page demonstrating micro-interactions including:
/// - Haptic feedback on various interactions
/// - Hover states for desktop platforms
/// - Long press gesture handling
/// - Scale animations on button press
class MicroInteractionsExamplesPage extends StatefulWidget {
  const MicroInteractionsExamplesPage({super.key});

  @override
  State<MicroInteractionsExamplesPage> createState() =>
      _MicroInteractionsExamplesPageState();
}

class _MicroInteractionsExamplesPageState
    extends State<MicroInteractionsExamplesPage> {
  String _lastAction = 'No action yet';
  int _tapCount = 0;
  int _longPressCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micro-Interactions Examples'),
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Display
              ElevatedCard(
                child: Column(
                  children: [
                    Text(
                      'Last Action',
                      style: AppTypography.headingMedium.copyWith(
                        color: AppDesign.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    Text(
                      _lastAction,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppDesign.getTextSecondary(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDesign.spacingM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_tapCount',
                              style: AppTypography.headingLarge.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Taps',
                              style: AppTypography.caption.copyWith(
                                color: AppDesign.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '$_longPressCount',
                              style: AppTypography.headingLarge.copyWith(
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Long Presses',
                              style: AppTypography.caption.copyWith(
                                color: AppDesign.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Haptic Feedback Section
              Text(
                'Haptic Feedback',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Text(
                'Tap these buttons to feel different haptic feedback types (mobile only)',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),

              AppButton.primary(
                label: 'Light Impact',
                icon: CupertinoIcons.hand_point_left,
                onPressed: () {
                  MicroInteractions.lightImpact();
                  setState(() {
                    _lastAction = 'Light haptic feedback triggered';
                    _tapCount++;
                  });
                },
              ),
              const SizedBox(height: AppDesign.spacingM),

              AppButton.primary(
                label: 'Medium Impact',
                icon: CupertinoIcons.hand_point_left_fill,
                onPressed: () {
                  MicroInteractions.mediumImpact();
                  setState(() {
                    _lastAction = 'Medium haptic feedback triggered';
                    _tapCount++;
                  });
                },
                gradient: AppColors.accentGradient,
              ),
              const SizedBox(height: AppDesign.spacingM),

              AppButton.primary(
                label: 'Heavy Impact',
                icon: CupertinoIcons.hand_raised_fill,
                onPressed: () {
                  MicroInteractions.heavyImpact();
                  setState(() {
                    _lastAction = 'Heavy haptic feedback triggered';
                    _tapCount++;
                  });
                },
                gradient: AppColors.expenseGradient,
              ),
              const SizedBox(height: AppDesign.spacingM),

              AppButton.secondary(
                label: 'Selection Click',
                icon: CupertinoIcons.hand_thumbsup,
                onPressed: () {
                  MicroInteractions.selectionClick();
                  setState(() {
                    _lastAction = 'Selection click feedback triggered';
                    _tapCount++;
                  });
                },
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Interactive Wrapper Section
              Text(
                'Interactive Wrapper',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Text(
                'Tap or long-press these cards. On desktop, hover to see effects.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),

              InteractiveWrapper(
                onTap: () {
                  setState(() {
                    _lastAction = 'Card tapped with light haptic';
                    _tapCount++;
                  });
                },
                onLongPress: () {
                  setState(() {
                    _lastAction = 'Card long-pressed with medium haptic';
                    _longPressCount++;
                  });
                },
                hapticType: HapticFeedbackType.light,
                child: ElevatedCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDesign.spacingS),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppDesign.radiusS),
                        ),
                        child: const Icon(
                          CupertinoIcons.hand_point_left,
                          color: Colors.white,
                          size: AppDesign.iconM,
                        ),
                      ),
                      const SizedBox(width: AppDesign.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap or Long Press',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'With light haptic feedback',
                              style: AppTypography.caption.copyWith(
                                color: AppDesign.getTextTertiary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),

              InteractiveWrapper(
                onTap: () {
                  setState(() {
                    _lastAction = 'Card tapped with heavy haptic';
                    _tapCount++;
                  });
                },
                onLongPress: () {
                  setState(() {
                    _lastAction = 'Card long-pressed with heavy haptic';
                    _longPressCount++;
                  });
                },
                hapticType: HapticFeedbackType.heavy,
                child: ElevatedCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppDesign.spacingS),
                        decoration: BoxDecoration(
                          gradient: AppColors.expenseGradient,
                          borderRadius: BorderRadius.circular(AppDesign.radiusS),
                        ),
                        child: const Icon(
                          CupertinoIcons.hand_raised_fill,
                          color: Colors.white,
                          size: AppDesign.iconM,
                        ),
                      ),
                      const SizedBox(width: AppDesign.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap or Long Press',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppDesign.getTextPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'With heavy haptic feedback',
                              style: AppTypography.caption.copyWith(
                                color: AppDesign.getTextTertiary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Hover States Section
              Text(
                'Hover States (Desktop)',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Text(
                MicroInteractions.shouldEnableHover()
                    ? 'Hover over these elements to see effects'
                    : 'Hover effects are only available on desktop platforms',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppDesign.getTextSecondary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),

              Row(
                children: [
                  Expanded(
                    child: ElevatedCard(
                      onTap: () {
                        setState(() {
                          _lastAction = 'Hoverable card 1 tapped';
                          _tapCount++;
                        });
                      },
                      child: Column(
                        children: [
                          const Icon(
                            CupertinoIcons.star_fill,
                            size: AppDesign.iconL,
                            color: Colors.amber,
                          ),
                          const SizedBox(height: AppDesign.spacingS),
                          Text(
                            'Hover Me',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppDesign.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDesign.spacingM),
                  Expanded(
                    child: ElevatedCard(
                      onTap: () {
                        setState(() {
                          _lastAction = 'Hoverable card 2 tapped';
                          _tapCount++;
                        });
                      },
                      child: Column(
                        children: [
                          const Icon(
                            CupertinoIcons.heart_fill,
                            size: AppDesign.iconL,
                            color: Colors.red,
                          ),
                          const SizedBox(height: AppDesign.spacingS),
                          Text(
                            'Hover Me',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppDesign.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Platform Info Section
              Text(
                'Platform Information',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),

              ElevatedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Platform Type',
                      MicroInteractions.isDesktop()
                          ? 'Desktop'
                          : MicroInteractions.isMobile()
                              ? 'Mobile'
                              : 'Web',
                      context,
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    _buildInfoRow(
                      'Haptic Support',
                      MicroInteractions.isMobile() ? 'Yes' : 'No',
                      context,
                    ),
                    const SizedBox(height: AppDesign.spacingS),
                    _buildInfoRow(
                      'Hover Support',
                      MicroInteractions.shouldEnableHover() ? 'Yes' : 'No',
                      context,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesign.spacingXL),

              // Reset Button
              AppButton.secondary(
                label: 'Reset Counters',
                icon: CupertinoIcons.refresh,
                onPressed: () {
                  setState(() {
                    _tapCount = 0;
                    _longPressCount = 0;
                    _lastAction = 'Counters reset';
                  });
                },
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextSecondary(context),
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: AppDesign.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
