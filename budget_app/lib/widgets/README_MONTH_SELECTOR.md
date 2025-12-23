# Month Selector Widget

A modern, compact month selector component that replaces the old full-screen dropdown with a horizontal scrollable interface.

## Features

- **Horizontal Scrolling**: Swipe through months naturally instead of opening a full-screen dropdown
- **Visual Feedback**: Selected month is highlighted with gradient and shadow
- **Auto-Centering**: Automatically scrolls to center the selected month
- **Smooth Animations**: Animated transitions when changing months
- **Haptic Feedback**: Tactile response on selection (mobile devices)
- **Responsive Design**: Adapts to different screen sizes
- **Theme Support**: Works seamlessly with light and dark modes

## Usage

```dart
MonthSelector(
  selectedMonth: selectedMonth,
  availableMonths: availableMonths,
  onMonthChanged: (DateTime newMonth) {
    setState(() {
      selectedMonth = newMonth;
    });
  },
)
```

## Design

Each month chip displays:

- Month name (abbreviated, uppercase)
- Year
- Visual distinction for selected state with gradient background
- Subtle shadow for depth

## Implementation

Used in:

- `category_page.dart` - Category spending analysis
- `transaction_page.dart` - Transaction list view

## Benefits Over Dropdown

1. **Better UX**: No full-screen takeover, stays in context
2. **More Intuitive**: Natural horizontal scrolling gesture
3. **Visual Clarity**: See multiple months at once
4. **Modern Design**: Aligns with contemporary mobile UI patterns
5. **Compact**: Takes less vertical space (80px vs dropdown + padding)
