import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../design_system.dart';

/// Example page demonstrating the usage of AppButton components
/// This file shows various button configurations and states
class ButtonExamplesPage extends StatefulWidget {
  const ButtonExamplesPage({super.key});

  @override
  State<ButtonExamplesPage> createState() => _ButtonExamplesPageState();
}

class _ButtonExamplesPageState extends State<ButtonExamplesPage> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button Examples'),
      ),
      body: Container(
        color: AppDesign.getBackgroundColor(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesign.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primary Buttons Section
              Text(
                'Primary Buttons',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Primary Button',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Primary button pressed')),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'With Icon',
                icon: CupertinoIcons.add,
                onPressed: () {},
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Loading',
                onPressed: () {},
                isLoading: true,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Disabled',
                onPressed: null,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Secondary Buttons Section
              Text(
                'Secondary Buttons',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.secondary(
                label: 'Secondary Button',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Secondary button pressed')),
                  );
                },
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.secondary(
                label: 'With Icon',
                icon: CupertinoIcons.settings,
                onPressed: () {},
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.secondary(
                label: 'Loading',
                onPressed: () {},
                isLoading: true,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.secondary(
                label: 'Disabled',
                onPressed: null,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Button Sizes Section
              Text(
                'Button Sizes',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Small Button',
                onPressed: () {},
                size: AppButtonSize.small,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Medium Button',
                onPressed: () {},
                size: AppButtonSize.medium,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Large Button',
                onPressed: () {},
                size: AppButtonSize.large,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Custom Gradient Section
              Text(
                'Custom Gradients',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Income Gradient',
                icon: CupertinoIcons.arrow_up_circle_fill,
                onPressed: () {},
                gradient: AppColors.incomeGradient,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Expense Gradient',
                icon: CupertinoIcons.arrow_down_circle_fill,
                onPressed: () {},
                gradient: AppColors.expenseGradient,
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Accent Gradient',
                icon: CupertinoIcons.star_fill,
                onPressed: () {},
                gradient: AppColors.accentGradient,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Expanded Button Section
              Text(
                'Expanded Button',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: 'Full Width Button',
                icon: CupertinoIcons.checkmark_alt,
                onPressed: () {},
                expanded: true,
              ),
              const SizedBox(height: AppDesign.spacingXL),
              
              // Interactive Example
              Text(
                'Interactive Example',
                style: AppTypography.headingMedium.copyWith(
                  color: AppDesign.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: AppDesign.spacingM),
              
              AppButton.primary(
                label: isLoading ? 'Processing...' : 'Toggle Loading',
                icon: isLoading ? null : CupertinoIcons.play_fill,
                onPressed: () {
                  setState(() {
                    isLoading = !isLoading;
                  });
                  
                  if (isLoading) {
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    });
                  }
                },
                isLoading: isLoading,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
