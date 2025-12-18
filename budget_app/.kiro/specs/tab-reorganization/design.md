# Design Document: Tab Reorganization

## Overview

This design reorganizes the Transaction and History tabs to eliminate functional overlap and provide better financial insights. The Transaction tab will adopt the current History tab's functionality (comprehensive transaction history with month selection), while the History tab will be transformed into a visual analytics page featuring a net cash flow chart that shows financial trends over time.

## Architecture

### Component Structure

```
BudgetHomePage (home_page.dart)
├── SpendingPage
├── TransactionPage (NEW: Historical view with month selector)
├── CategoryPage
├── HistoryPage (NEW: Net cash flow chart)
└── SettingsPage
```

### Data Flow

1. **TransactionModel** provides all transaction data and computed summaries
2. Both pages consume TransactionModel via Provider
3. TransactionPage uses existing methods: `getAvailableMonths()`, `getTransactionsForMonth()`, `getMonthlySummary()`
4. HistoryPage uses existing methods plus new computed properties for chart data

## Components and Interfaces

### 1. TransactionPage (Modified)

**Purpose**: Display comprehensive transaction history with month selection and grouping

**Key Features**:

- Month selector dropdown (reused from current HistoryPage)
- Monthly summary card showing income, expenses, and net cash flow
- Grouped transaction list with sticky date headers
- Transaction edit and delete capabilities
- Empty state handling

**UI Structure**:

```
AppBar
└── "Transactions" title

Body
├── Month Selector Dropdown (ElevatedCard)
├── Monthly Summary Card (ElevatedCard)
│   ├── Income display
│   ├── Expenses display
│   └── Net Cash Flow display
└── Grouped Transaction List (CustomScrollView)
    └── For each date:
        ├── Sticky Date Header
        └── Transaction Items (ModernTransactionListItem)
```

**State Management**:

- `selectedMonth: DateTime?` - Currently selected month
- Initialized to most recent month with transactions
- Updates trigger list rebuild

### 2. HistoryPage (Redesigned)

**Purpose**: Visualize net cash flow trends over time with interactive charts

**Key Features**:

- Bar chart showing net cash flow per month
- Color-coded bars (green for positive, red for negative)
- Summary statistics (average, highest, lowest)
- Interactive bar selection for detailed view
- Responsive layout for different screen sizes
- Empty state for no data

**UI Structure**:

```
AppBar
└── "Cash Flow History" title

Body
├── Summary Statistics Card (ElevatedCard)
│   ├── Average Net Cash Flow
│   ├── Best Month
│   └── Worst Month
├── Chart Card (ElevatedCard)
│   └── Bar Chart (fl_chart)
│       ├── X-axis: Month labels
│       ├── Y-axis: Currency values
│       └── Bars: Net cash flow per month
└── Selected Month Details (Optional, shown on tap)
    ├── Month name
    ├── Income
    ├── Expenses
    └── Net Cash Flow
```

**State Management**:

- `selectedBarIndex: int?` - Currently selected bar for detail view
- `chartData: List<MonthCashFlow>` - Computed from TransactionModel
- Updates on data changes via Consumer<TransactionModel>

### 3. TransactionModel Extensions

**New Computed Properties** (added to existing model):

```dart
// Get net cash flow data for all months (for charting)
List<MonthCashFlow> getNetCashFlowHistory() {
  List<DateTime> months = getAvailableMonths();
  return months.map((month) {
    Map<String, double> summary = getMonthlySummary(month);
    return MonthCashFlow(
      month: month,
      netCashFlow: summary['net'] ?? 0.0,
      income: summary['income'] ?? 0.0,
      expenses: summary['expenses'] ?? 0.0,
    );
  }).toList();
}

// Get summary statistics for cash flow history
CashFlowStatistics getCashFlowStatistics() {
  List<MonthCashFlow> history = getNetCashFlowHistory();
  if (history.isEmpty) {
    return CashFlowStatistics.empty();
  }

  double average = history
      .map((m) => m.netCashFlow)
      .reduce((a, b) => a + b) / history.length;

  MonthCashFlow best = history.reduce(
    (a, b) => a.netCashFlow > b.netCashFlow ? a : b
  );

  MonthCashFlow worst = history.reduce(
    (a, b) => a.netCashFlow < b.netCashFlow ? a : b
  );

  return CashFlowStatistics(
    average: average,
    bestMonth: best,
    worstMonth: worst,
  );
}
```

**New Data Classes**:

```dart
class MonthCashFlow {
  final DateTime month;
  final double netCashFlow;
  final double income;
  final double expenses;

  MonthCashFlow({
    required this.month,
    required this.netCashFlow,
    required this.income,
    required this.expenses,
  });
}

class CashFlowStatistics {
  final double average;
  final MonthCashFlow bestMonth;
  final MonthCashFlow worstMonth;

  CashFlowStatistics({
    required this.average,
    required this.bestMonth,
    required this.worstMonth,
  });

  factory CashFlowStatistics.empty() {
    DateTime now = DateTime.now();
    MonthCashFlow empty = MonthCashFlow(
      month: now,
      netCashFlow: 0.0,
      income: 0.0,
      expenses: 0.0,
    );
    return CashFlowStatistics(
      average: 0.0,
      bestMonth: empty,
      worstMonth: empty,
    );
  }
}
```

## Data Models

### Chart Data Structure

The chart will use `fl_chart`'s `BarChart` widget with the following data structure:

```dart
BarChartData(
  barGroups: [
    BarChartGroupData(
      x: monthIndex,
      barRods: [
        BarChartRodData(
          toY: netCashFlow,
          color: netCashFlow >= 0 ? AppColors.income : AppColors.expense,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    ),
  ],
  titlesData: FlTitlesData(
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (value, meta) => Text(monthLabel),
      ),
    ),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (value, meta) => Text(currencyFormat),
      ),
    ),
  ),
)
```

### Month Display Logic

- Display up to 12 most recent months (including current month)
- If more than 12 months exist, show most recent 12
- X-axis labels: "Jan", "Feb", "Mar", etc. (using `DateFormat.MMM()`)
- Y-axis labels: Formatted currency with appropriate scale (K for thousands)

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property 1: Month data consistency

_For any_ selected month in the Transaction tab, the displayed transactions should exactly match `getTransactionsForMonth()` for that month, and the summary values (income, expenses, net) should match `getMonthlySummary()` for that month.

**Validates: Requirements 1.2, 2.1, 2.2, 2.3**

### Property 2: Transaction list grouping correctness

_For any_ list of transactions displayed in the Transaction tab, all transactions with the same date should appear under exactly one date header, and date headers should appear in descending chronological order.

**Validates: Requirements 1.3**

### Property 3: Net cash flow calculation

_For any_ month with transactions, the net cash flow should always equal the total income minus the total expenses for that month.

**Validates: Requirements 2.3**

### Property 4: Color coding consistency

_For any_ displayed net cash flow value (in summary cards or chart bars), if the value is greater than or equal to zero, the color should be green (AppColors.income), otherwise it should be red (AppColors.expense).

**Validates: Requirements 2.4, 3.3**

### Property 5: Chart data completeness

_For any_ set of transactions in the system, the History tab chart should include a bar for every month that has transactions, and each bar height should represent the net cash flow for that month.

**Validates: Requirements 3.2, 3.3**

### Property 6: Month label formatting

_For any_ month displayed on the chart x-axis, the label should be formatted in MMM format (e.g., "Jan", "Feb", "Mar").

**Validates: Requirements 3.5**

### Property 7: Summary statistics accuracy

_For any_ set of monthly cash flow data, the average should equal the sum of all net cash flows divided by the number of months, the best month should be the month with the maximum net cash flow, and the worst month should be the month with the minimum net cash flow.

**Validates: Requirements 4.1, 4.2, 4.3**

### Property 8: Currency formatting consistency

_For any_ currency value displayed in the application, it should be formatted with the same pattern (thousand separators, two decimal places, dollar sign prefix).

**Validates: Requirements 4.4**

### Property 9: Theme-aware color updates

_For any_ theme change (light to dark or dark to light), all chart colors and UI elements should update to use the appropriate theme colors while maintaining proper contrast.

**Validates: Requirements 5.5**

## Error Handling

### Data Availability

- **No transactions exist**: Display appropriate empty states with helpful messaging
- **Selected month has no transactions**: Show zero values in summary, empty transaction list
- **Single month of data**: Chart and statistics still display correctly with single data point

### UI Edge Cases

- **Very long transaction descriptions**: Truncate with ellipsis in list items
- **Large currency values**: Format with thousand separators and appropriate precision
- **Many months of data**: Limit chart to 12 most recent months, consider horizontal scroll
- **Rapid month selection changes**: Debounce or ensure state updates don't conflict

### Chart Rendering

- **Extreme values**: Auto-scale Y-axis to accommodate all values
- **Zero or near-zero values**: Ensure bars are still visible with minimum height
- **Negative values**: Ensure Y-axis includes negative range, bars extend downward

## Testing Strategy

### Unit Testing

We will use Flutter's built-in testing framework for unit tests:

**Transaction Model Tests**:

- Test `getNetCashFlowHistory()` returns correct data structure
- Test `getCashFlowStatistics()` calculates correct averages
- Test edge cases: empty data, single month, multiple months
- Test that existing methods still work correctly

**Data Transformation Tests**:

- Test MonthCashFlow creation from transaction data
- Test CashFlowStatistics calculation with various data sets
- Test month sorting and filtering logic

**Widget Tests**:

- Test TransactionPage renders correctly with mock data
- Test HistoryPage renders chart with mock data
- Test empty states display correctly
- Test month selector interaction
- Test transaction list grouping

### Property-Based Testing

We will use the `test` package with custom property test helpers for property-based testing. Each property-based test should run a minimum of 100 iterations.

**Property Test Implementation**:

Each property-based test will be tagged with a comment explicitly referencing the correctness property from this design document using the format: `**Feature: tab-reorganization, Property {number}: {property_text}**`

**Test Coverage**:

1. **Property 1 Test**: Generate random transactions for random months, verify displayed data matches model methods
2. **Property 2 Test**: Generate random transactions with various dates, verify grouping and sorting
3. **Property 3 Test**: Generate random transaction sets, verify chart bar heights match calculated net cash flow
4. **Property 4 Test**: Generate transactions resulting in positive and negative net cash flows, verify bar colors
5. **Property 5 Test**: Generate various monthly data sets, verify statistics calculations
6. **Property 6 Test**: Test with empty transaction lists, verify empty states appear
7. **Property 7 Test**: Generate random income and expense transactions, verify net = income - expenses

### Integration Testing

- Test full user flow: navigate to Transaction tab, select month, view transactions
- Test full user flow: navigate to History tab, view chart, tap bar for details
- Test data persistence: add transaction, verify it appears in both tabs correctly
- Test theme switching: verify chart colors update correctly
- Test navigation between tabs maintains state correctly

### Visual Regression Testing

- Capture screenshots of both tabs in light and dark modes
- Test with various data scenarios: empty, single month, multiple months
- Test responsive layouts on different screen sizes

## Implementation Notes

### Code Reuse

- TransactionPage will reuse most of the current HistoryPage implementation
- Reuse existing widgets: `ModernTransactionListItem`, `EmptyState`, `ElevatedCard`
- Reuse existing date header delegate: `_DateHeaderDelegate`

### Chart Library

- Use `fl_chart` package (already in dependencies)
- `BarChart` widget for the main visualization
- Configure with `BarChartData` for data and styling
- Use `BarTouchData` for interactivity

### Performance Considerations

- Transaction list uses `addAutomaticKeepAlives: false` and `addRepaintBoundaries: true`
- Chart data computed once per build, cached in local variable
- Month selector dropdown reuses existing efficient implementation
- Sticky headers use `SliverPersistentHeader` for optimal performance

### Accessibility

- All interactive elements have semantic labels
- Chart includes text-based summary for screen readers
- Color coding supplemented with labels (not color-only information)
- Touch targets meet minimum size requirements (48x48 logical pixels)

### Theme Support

- Chart colors adapt to light/dark mode using AppColors
- Background colors use `AppDesign.getBackgroundColor(context)`
- Text colors use `AppDesign.getTextPrimary/Secondary(context)`
- Maintain proper contrast ratios in both themes
