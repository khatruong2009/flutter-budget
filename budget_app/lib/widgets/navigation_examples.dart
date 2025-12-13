import 'package:flutter/material.dart';
import '../design_system.dart';

/// Example page demonstrating the ModernAppBar component
class ModernAppBarExample extends StatelessWidget {
  const ModernAppBarExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: 'Modern AppBar',
        showGradient: true,
        useGlassEffect: true,
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: ListView(
          padding: const EdgeInsets.all(AppDesign.spacingL),
          children: [
            const Text(
              'AppBar Examples',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: AppDesign.spacingL),
            
            // Example 1: Basic AppBar with gradient
            _buildExample(
              context,
              'Basic Gradient AppBar',
              'AppBar with gradient background and glass effect',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const _ExamplePage(
                      appBar: ModernAppBar(
                        title: 'Gradient AppBar',
                        showGradient: true,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: AppDesign.spacingM),
            
            // Example 2: AppBar with subtitle
            _buildExample(
              context,
              'AppBar with Subtitle',
              'AppBar with title and subtitle text',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const _ExamplePage(
                      appBar: ModernAppBar(
                        title: 'Main Title',
                        subtitle: 'Subtitle text here',
                        showGradient: true,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: AppDesign.spacingM),
            
            // Example 3: AppBar with actions
            _buildExample(
              context,
              'AppBar with Actions',
              'AppBar with action buttons',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _ExamplePage(
                      appBar: ModernAppBar(
                        title: 'With Actions',
                        showGradient: true,
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: AppDesign.spacingXL),
            
            const Text(
              'Page Transition Examples',
              style: AppTypography.headingLarge,
            ),
            const SizedBox(height: AppDesign.spacingL),
            
            // Example 4: Slide transition
            _buildExample(
              context,
              'Slide Transition',
              'Navigate with slide animation',
              () {
                context.pushWithSlide(const _ExamplePage(
                  appBar: ModernAppBar(title: 'Slide Transition'),
                ));
              },
            ),
            
            const SizedBox(height: AppDesign.spacingM),
            
            // Example 5: Fade transition
            _buildExample(
              context,
              'Fade Transition',
              'Navigate with fade animation',
              () {
                context.pushWithFade(const _ExamplePage(
                  appBar: ModernAppBar(title: 'Fade Transition'),
                ));
              },
            ),
            
            const SizedBox(height: AppDesign.spacingM),
            
            // Example 6: Scale transition
            _buildExample(
              context,
              'Scale Transition',
              'Navigate with scale animation',
              () {
                context.pushWithScale(const _ExamplePage(
                  appBar: ModernAppBar(title: 'Scale Transition'),
                ));
              },
            ),
            
            const SizedBox(height: AppDesign.spacingM),
            
            // Example 7: Slide and fade transition
            _buildExample(
              context,
              'Slide & Fade Transition',
              'Navigate with combined animation',
              () {
                context.pushWithSlideAndFade(const _ExamplePage(
                  appBar: ModernAppBar(title: 'Slide & Fade'),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExample(
    BuildContext context,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return ElevatedCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppDesign.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: AppDesign.spacingXS),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: AppDesign.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Try it',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppDesign.spacingXS),
              const Icon(
                Icons.arrow_forward,
                size: AppDesign.iconS,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Example page used for demonstrations
class _ExamplePage extends StatelessWidget {
  final PreferredSizeWidget appBar;

  const _ExamplePage({required this.appBar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: AppDesign.spacingL),
              Text(
                'Example Page',
                style: AppTypography.headingLarge.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              Text(
                'This demonstrates the navigation features',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              AppButton.secondary(
                label: 'Go Back',
                onPressed: () => Navigator.pop(context),
                icon: Icons.arrow_back,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
