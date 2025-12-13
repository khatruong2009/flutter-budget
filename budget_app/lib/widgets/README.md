# Widgets Directory

This directory contains reusable UI components for the budget tracking application.

## Components

### ModernTransactionListItem

A modern, glassmorphic transaction list item component with the following features:

- **Glassmorphism effect**: Semi-transparent background with backdrop blur
- **Gradient icon containers**: Category icons displayed in gradient-colored containers
- **Proper typography**: Uses design system typography for consistent text styling
- **Tap to edit**: Supports tap interactions for editing transactions
- **Swipe to delete**: Integrated Dismissible widget for swipe-to-delete functionality
- **Semantic colors**: Green for income, red for expenses

#### Usage

```dart
import 'package:budget_app/widgets/modern_transaction_list_item.dart';

ModernTransactionListItem(
  transaction: myTransaction,
  onTap: () {
    // Handle edit action
  },
  onDelete: () {
    // Handle delete action
  },
)
```

#### Requirements Validated

- **6.1**: Transaction lists display with clear visual separation and semantic colors
- **6.2**: Transaction amounts use color coding (green for income, red for expenses)
- **6.3**: Category icons displayed with colored gradient backgrounds

### Button Examples

Demonstrates the usage of AppButton component with various configurations.

### Metric Card Examples

Demonstrates the usage of AnimatedMetricCard component with various configurations.

### Transaction List Item Examples

Demonstrates the usage of ModernTransactionListItem component with sample data.

### EmptyState

A reusable empty state component for displaying helpful messages when there's no data to show. Features include:

- **Multiple types**: Supports noData, noResults, and error states
- **Customizable content**: Custom icons, titles, and messages
- **Call-to-action**: Optional action button with callback
- **Gradient icons**: Optional gradient background for icons
- **Responsive**: Adapts to different screen sizes
- **Design system integration**: Uses AppDesign tokens for consistent styling

#### Usage

```dart
import 'package:budget_app/widgets/empty_state.dart';

// Basic usage with defaults
EmptyState.noData(
  actionLabel: 'Add Transaction',
  onAction: () {
    // Handle action
  },
)

// Custom empty state
EmptyState(
  type: EmptyStateType.noData,
  title: 'No Transactions',
  message: 'Start tracking your expenses',
  icon: CupertinoIcons.money_dollar_circle,
  iconGradient: AppColors.primaryGradient,
  actionLabel: 'Get Started',
  onAction: () {
    // Handle action
  },
)
```

#### Requirements Validated

- **5.5**: Empty states display with helpful illustrations and guidance
- **10.1**: No transactions display empty state with illustration and call-to-action
- **10.4**: Search with no results displays helpful empty state with suggestions

## Design System Integration

All components in this directory follow the design system defined in `lib/design_system.dart`:

- Use `AppDesign` constants for spacing, sizing, and layout
- Use `AppColors` for colors and gradients
- Use `AppTypography` for text styles
- Use `AppAnimations` for animation curves and durations

## Testing

Each component has corresponding tests in the `test/` directory. Run tests with:

```bash
flutter test test/modern_transaction_list_item_test.dart
```
