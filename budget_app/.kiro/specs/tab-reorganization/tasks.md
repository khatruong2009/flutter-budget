# Implementation Plan

- [x] 1. Add data model extensions to TransactionModel

  - Add `MonthCashFlow` and `CashFlowStatistics` data classes
  - Implement `getNetCashFlowHistory()` method
  - Implement `getCashFlowStatistics()` method
  - _Requirements: 3.1, 3.2, 4.1, 4.2, 4.3_

- [ ]\* 1.1 Write property test for net cash flow history

  - **Property 5: Chart data completeness**
  - **Validates: Requirements 3.2, 3.3**

- [ ]\* 1.2 Write property test for cash flow statistics

  - **Property 7: Summary statistics accuracy**
  - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 2. Redesign TransactionPage to show historical transactions

  - Copy current HistoryPage implementation to TransactionPage
  - Update app bar title to "Transactions"
  - Ensure month selector defaults to most recent month
  - Maintain all existing functionality (edit, delete, grouping)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [ ]\* 2.1 Write property test for month data consistency

  - **Property 1: Month data consistency**
  - **Validates: Requirements 1.2, 2.1, 2.2, 2.3**

- [ ]\* 2.2 Write property test for transaction grouping

  - **Property 2: Transaction list grouping correctness**
  - **Validates: Requirements 1.3**

- [x] 3. Add monthly summary card to TransactionPage

  - Display income, expenses, and net cash flow
  - Use color coding (green for positive, red for negative)
  - Format currency values consistently
  - Handle empty state (show zeros)
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ]\* 3.1 Write property test for net cash flow calculation

  - **Property 3: Net cash flow calculation**
  - **Validates: Requirements 2.3**

- [ ]\* 3.2 Write property test for color coding

  - **Property 4: Color coding consistency**
  - **Validates: Requirements 2.4, 3.3**

- [ ]\* 3.3 Write property test for currency formatting

  - **Property 8: Currency formatting consistency**
  - **Validates: Requirements 4.4**

- [x] 4. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Redesign HistoryPage with net cash flow chart

  - Replace transaction list with bar chart using fl_chart
  - Implement chart data transformation from TransactionModel
  - Configure BarChart with proper styling and colors
  - Add x-axis labels (month names in MMM format)
  - Add y-axis labels (currency values)
  - Handle empty state (no transactions)
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ]\* 5.1 Write property test for month label formatting

  - **Property 6: Month label formatting**
  - **Validates: Requirements 3.5**

- [x] 6. Add summary statistics card to HistoryPage

  - Display average monthly net cash flow
  - Display best month (highest net cash flow)
  - Display worst month (lowest net cash flow)
  - Format all values consistently
  - Handle edge case of single month
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 7. Implement chart interactivity

  - Add tap handling for chart bars
  - Show detailed month information on tap
  - Display month name, income, expenses, and net cash flow
  - Highlight selected bar
  - _Requirements: 5.1, 5.2_

- [x] 8. Add responsive layout and theme support

  - Ensure chart adapts to different screen sizes
  - Implement horizontal scrolling or limit display for many months
  - Update chart colors based on theme (light/dark)
  - Maintain proper contrast in both themes
  - _Requirements: 5.3, 5.4, 5.5_

- [ ]\* 8.1 Write property test for theme-aware colors

  - **Property 9: Theme-aware color updates**
  - **Validates: Requirements 5.5**

- [x] 9. Update home_page.dart tab labels

  - Update "Transaction" tab label if needed
  - Update "History" tab label to "Cash Flow" or keep as "History"
  - Ensure tab icons are appropriate for new functionality
  - _Requirements: 1.1, 3.1_

- [ ]\* 9.1 Write widget tests for both redesigned pages

  - Test TransactionPage renders correctly with mock data
  - Test HistoryPage renders chart with mock data
  - Test empty states display correctly
  - Test month selector interaction
  - Test chart bar tap interaction

- [x] 10. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
