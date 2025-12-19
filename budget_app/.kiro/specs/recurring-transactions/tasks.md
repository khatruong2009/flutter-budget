# Implementation Plan: Recurring Transactions

## Overview

This implementation plan breaks down the recurring transactions feature into incremental, testable steps. Each task builds on previous work, starting with core data models, then business logic, and finally UI integration. The plan ensures that functionality is validated early through tests and checkpoints.

## Tasks

- [x] 1. Create core data models and enums

  - Create `RecurrencePattern` enum (weekly, biweekly, monthly)
  - Create `RecurringTransaction` class with all required fields
  - Implement `toJson()` and `fromJson()` serialization methods
  - Implement `calculateNextOccurrence()` method for date calculations
  - Implement `generateTransaction()` method to create Transaction from template
  - _Requirements: 1.3, 1.4, 1.5, 1.6, 6.2, 6.3_

- [ ]\* 1.1 Write property test for serialization round-trip

  - **Property 3: Recurring Transaction Persistence Round-Trip**
  - **Validates: Requirements 1.7, 6.3, 6.4**

- [ ]\* 1.2 Write property test for bi-weekly calculation

  - **Property 2: Bi-weekly Occurrence Calculation**
  - **Validates: Requirements 1.6**

- [ ]\* 1.3 Write unit tests for edge cases

  - Test day 31 in months with fewer days (Feb, Apr, Jun, Sep, Nov)
  - Test February 29 in leap years and non-leap years
  - Test year boundary transitions (Dec → Jan)
  - _Requirements: 2.4, 7.1_

- [x] 2. Implement RecurringTransactionModel state management

  - Create `RecurringTransactionModel` class extending `ChangeNotifier`
  - Implement CRUD methods: `addRecurringTransaction`, `updateRecurringTransaction`, `deleteRecurringTransaction`
  - Implement `saveRecurringTransactions()` and `loadRecurringTransactions()` using SharedPreferences
  - Implement query methods: `getActiveRecurringTransactions()`, `getDueRecurringTransactions()`
  - Store recurring transactions in separate SharedPreferences key: `recurring_transactions`
  - _Requirements: 1.7, 4.1, 4.3, 4.4, 6.1_

- [ ]\* 2.1 Write property test for required fields validation

  - **Property 1: Required Fields Validation**
  - **Validates: Requirements 1.3**

- [ ]\* 2.2 Write unit tests for CRUD operations

  - Test add, update, delete operations
  - Test persistence and loading from SharedPreferences
  - Verify notifyListeners() is called appropriately
  - _Requirements: 1.7, 4.3, 4.4_

- [x] 3. Extend Transaction model with recurring support

  - Add optional `recurringTemplateId` field to `Transaction` class
  - Add `isRecurring` getter that checks if `recurringTemplateId` is non-null
  - Update `toJson()` and `fromJson()` to include new field
  - Update `TransactionModel.addTransaction()` to accept optional `recurringTemplateId` parameter
  - _Requirements: 2.3, 3.1, 6.2_

- [ ]\* 3.1 Write property test for recurring marker

  - **Property 6: Recurring Marker on Generated Transactions**
  - **Validates: Requirements 2.3**

- [ ]\* 3.2 Write unit test for backward compatibility

  - Test that existing transaction JSON without `recurringTemplateId` still loads correctly
  - _Requirements: 6.5_

- [x] 4. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement TransactionGenerator service

  - Create `TransactionGenerator` class with references to both models
  - Implement `generateDueTransactions()` main entry point
  - Implement `_generateMissedTransactions()` to handle multiple missed occurrences
  - Implement `_calculateNextOccurrence()` with pattern-specific logic
  - Implement `_calculateNextMonthlyOccurrence()` with month-boundary handling
  - Implement 90-day lookback limit for missed transactions
  - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6, 7.1, 7.2_

- [ ]\* 5.1 Write property test for transaction generation with template details

  - **Property 5: Transaction Generation with Template Details**
  - **Validates: Requirements 2.2**

- [ ]\* 5.2 Write property test for next occurrence update

  - **Property 7: Next Occurrence Update After Generation**
  - **Validates: Requirements 2.5**

- [ ]\* 5.3 Write property test for multiple missed occurrences

  - **Property 8: Multiple Missed Occurrences Generation**
  - **Validates: Requirements 2.6**

- [ ]\* 5.4 Write property test for 90-day lookback limit

  - **Property 16: 90-Day Lookback Limit**
  - **Validates: Requirements 7.2**

- [ ]\* 5.5 Write property test for future start date

  - **Property 17: Future Start Date No Generation**
  - **Validates: Requirements 7.4**

- [x] 6. Integrate TransactionGenerator with app lifecycle

  - Add `RecurringTransactionModel` to MultiProvider in `main.dart`
  - Create `TransactionGenerator` instance in `main.dart`
  - Call `generateDueTransactions()` on app startup after loading data
  - _Requirements: 2.1_

- [ ]\* 6.1 Write property test for initial transaction generation

  - **Property 4: Initial Transaction Generation**
  - **Validates: Requirements 1.8**

- [x] 7. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Create RecurrenceIndicator widget

  - Create `lib/widgets/recurrence_indicator.dart` file
  - Implement `RecurrenceIndicator` widget with CustomPaint
  - Implement `_RecurrenceIconPainter` to draw elongated oval with two arrows
  - Support light and dark theme colors
  - Make size and color customizable via parameters
  - _Requirements: 3.1, 3.2, 3.5, 7.5_

- [ ]\* 8.1 Write unit test for RecurrenceIndicator widget

  - Test widget renders without errors
  - Test size and color parameters are applied
  - _Requirements: 3.1_

- [x] 9. Add recurrence indicator to transaction displays

  - Update `modern_transaction_list_item.dart` to show RecurrenceIndicator for recurring transactions
  - Update `history_page.dart` transaction list to show RecurrenceIndicator
  - Update `transaction_page.dart` transaction list to show RecurrenceIndicator
  - Position indicator next to transaction description or category
  - _Requirements: 3.1, 3.3, 3.4_

- [ ]\* 9.1 Write property test for indicator display

  - **Property 9: Recurrence Indicator Display**
  - **Validates: Requirements 3.1, 3.4**

- [x] 10. Create recurring transaction form UI

  - Create `lib/recurring_transaction_form.dart` file
  - Implement `showRecurringTransactionForm()` function with similar structure to `showTransactionForm()`
  - Add recurrence pattern picker (weekly/biweekly/monthly) using CupertinoPicker
  - Add conditional day selection: day-of-month (1-31) for monthly, day-of-week for weekly/biweekly
  - Add start date picker with validation (not more than 1 year in past)
  - Add preview section showing next 3 occurrence dates
  - Implement form validation for all required fields
  - Wire up save button to create RecurringTransaction via RecurringTransactionModel
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ]\* 10.1 Write property test for dynamic date options

  - **Property 13: Dynamic Date Options by Pattern**
  - **Validates: Requirements 5.3**

- [ ]\* 10.2 Write property test for start date validation

  - **Property 14: Start Date Validation**
  - **Validates: Requirements 5.4**

- [ ]\* 10.3 Write property test for occurrence preview

  - **Property 15: Occurrence Preview Calculation**
  - **Validates: Requirements 5.5**

- [ ]\* 10.4 Write unit tests for form UI

  - Test form opens and displays correctly
  - Test pattern selection changes available date options
  - Test validation error messages display
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 11. Add recurring transaction link to existing transaction form

  - Update `lib/transaction_form.dart` to include "Make this recurring" link
  - Position link below the action buttons or in a subtle location
  - Implement tap handler that closes current form and opens recurring form
  - Pass transaction type to recurring form
  - _Requirements: 1.1, 1.2_

- [ ]\* 11.1 Write unit test for recurring link

  - Test link is visible in transaction form
  - Test tapping link opens recurring form
  - _Requirements: 1.1, 1.2_

- [x] 12. Checkpoint - Ensure all tests pass

  - Ensure all tests pass, ask the user if questions arise.

- [x] 13. Create recurring transactions management screen

  - Create `lib/recurring_transactions_page.dart` file
  - Implement list view of all recurring transactions
  - Display recurrence pattern, next occurrence date, and transaction details for each item
  - Add edit button that opens recurring form with pre-filled data
  - Add delete button with confirmation dialog
  - Style using existing design system components
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ]\* 13.1 Write property test for display fields

  - **Property 10: Recurring Transaction Display Fields**
  - **Validates: Requirements 4.2**

- [ ]\* 13.2 Write property test for template edit isolation

  - **Property 11: Template Edit Isolation**
  - **Validates: Requirements 4.3**

- [ ]\* 13.3 Write property test for deletion stops generation

  - **Property 12: Deletion Stops Future Generation**
  - **Validates: Requirements 4.4**

- [ ]\* 13.4 Write unit tests for management screen

  - Test list displays recurring transactions
  - Test edit opens form with correct data
  - Test delete shows confirmation dialog
  - Test delete removes recurring transaction
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 14. Add navigation to recurring transactions management screen

  - Add menu item or button in settings page to access recurring transactions
  - Alternatively, add to main navigation if appropriate
  - _Requirements: 4.1_

- [x] 15. Final checkpoint - Ensure all tests pass
  - Run full test suite
  - Verify all property tests pass with 100+ iterations
  - Verify all unit tests pass
  - Test end-to-end flows manually
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties across many inputs
- Unit tests validate specific examples, edge cases, and UI interactions
- The implementation follows Flutter/Dart conventions and integrates with existing Provider-based state management
