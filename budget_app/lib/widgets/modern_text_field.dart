import 'package:flutter/material.dart';

import '../design_system.dart';

class ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.prefixIcon,
    this.errorText,
    this.onChanged,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = widget.focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.error
        : _isFocused
            ? AppColors.primary
            : AppDesign.getBorderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed label - always visible
        Padding(
          padding: const EdgeInsets.only(
            left: AppDesign.spacingS,
            bottom: AppDesign.spacingXS,
          ),
          child: Text(
            widget.label,
            style: AppTypography.caption.copyWith(
              color: hasError
                  ? AppColors.error
                  : _isFocused
                      ? AppColors.primary
                      : AppDesign.getTextSecondary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Input field container
        Container(
          decoration: BoxDecoration(
            color: AppDesign.getCardColor(context),
            borderRadius: BorderRadius.circular(AppDesign.radiusM),
            border: Border.all(
              color: borderColor,
              width:
                  _isFocused ? AppDesign.borderThick : AppDesign.borderMedium,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.spacingM,
              vertical: AppDesign.spacingS,
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(
                    widget.prefixIcon,
                    size: AppDesign.iconM,
                    color: hasError
                        ? AppColors.error
                        : _isFocused
                            ? AppColors.primary
                            : AppDesign.getTextSecondary(context),
                  ),
                  const SizedBox(width: AppDesign.spacingS),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: widget.keyboardType,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppDesign.getTextPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTypography.bodyLarge.copyWith(
                        color: AppDesign.getTextTertiary(context),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: widget.onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Error message with icon
        if (hasError) ...[
          const SizedBox(height: AppDesign.spacingXS),
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: AppDesign.iconS,
                color: AppColors.error,
              ),
              const SizedBox(width: AppDesign.spacingXS),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
