# Requirements Document

## Introduction

This feature enables users to create and manage recurring transactions (both expenses and income) that automatically generate transaction entries based on a defined schedule. Users can set up monthly, weekly, or bi-weekly recurring patterns with customizable start dates and recurrence parameters. The feature integrates seamlessly with the existing transaction system while maintaining a clean, uncluttered UI.

## Glossary

- **Recurring_Transaction**: A template transaction that automatically generates actual transactions based on a defined schedule
- **Recurrence_Pattern**: The frequency at which a recurring transaction repeats (monthly, weekly, bi-weekly)
- **Transaction_Generator**: The system component responsible for creating actual transactions from recurring templates
- **Recurrence_Indicator**: A visual icon (two arrows in an elongated oval) that marks transactions as recurring in the UI
- **Transaction_Form**: The existing modal dialog for adding/editing transactions
- **Recurring_Form**: A separate modal dialog specifically for creating/editing recurring transactions
- **Start_Date**: The date when a recurring transaction begins generating actual transactions
- **Day_Of_Month**: For monthly recurrence, the specific day (1-31) when the transaction should occur
- **Day_Of_Week**: For weekly/bi-weekly recurrence, the specific day of the week when the transaction should occur

## Requirements

### Requirement 1: Create Recurring Transactions

**User Story:** As a user, I want to create recurring transactions for regular expenses and income, so that I don't have to manually enter the same transaction repeatedly.

#### Acceptance Criteria

1. WHEN a user opens the transaction form, THE System SHALL display a small option to create a recurring transaction instead
2. WHEN a user selects the recurring option, THE System SHALL open a separate recurring transaction form
3. WHEN creating a recurring transaction, THE System SHALL require transaction type, description, amount, category, recurrence pattern, and start date
4. WHEN a user selects monthly recurrence, THE System SHALL allow selection of a specific day of the month (1-31)
5. WHEN a user selects weekly recurrence, THE System SHALL allow selection of a specific day of the week
6. WHEN a user selects bi-weekly recurrence, THE System SHALL allow selection of a specific day of the week and calculate occurrences every 14 days
7. WHEN a user saves a recurring transaction, THE System SHALL persist it to local storage
8. WHEN a user saves a recurring transaction, THE System SHALL generate the first actual transaction if the start date is today or in the past

### Requirement 2: Generate Transactions from Recurring Templates

**User Story:** As a user, I want recurring transactions to automatically create actual transactions on their scheduled dates, so that my transaction history stays up-to-date without manual intervention.

#### Acceptance Criteria

1. WHEN the app launches, THE Transaction_Generator SHALL check all recurring transactions for due dates
2. WHEN a recurring transaction's next occurrence date has passed, THE Transaction_Generator SHALL create an actual transaction with the recurring template's details
3. WHEN generating a transaction, THE Transaction_Generator SHALL mark it as originating from a recurring template
4. WHEN a monthly recurring transaction is set for day 31 and the current month has fewer days, THE Transaction_Generator SHALL create the transaction on the last day of that month
5. WHEN generating transactions, THE Transaction_Generator SHALL update the recurring template's next occurrence date
6. WHEN multiple occurrences are missed (app not opened for days/weeks), THE Transaction_Generator SHALL generate all missed transactions up to the current date

### Requirement 3: Display Recurring Transaction Indicator

**User Story:** As a user, I want to see which transactions in my history are recurring, so that I can distinguish them from one-time transactions.

#### Acceptance Criteria

1. WHEN displaying a transaction that originated from a recurring template, THE System SHALL show a recurrence indicator icon
2. THE Recurrence_Indicator SHALL be two arrows forming an elongated oval shape
3. WHEN a user views the transaction list, THE Recurrence_Indicator SHALL be clearly visible next to recurring transactions
4. WHEN a user views the history page, THE Recurrence_Indicator SHALL appear on all transactions generated from recurring templates
5. THE Recurrence_Indicator SHALL use appropriate colors that match the app's design system

### Requirement 4: Manage Recurring Transactions

**User Story:** As a user, I want to view, edit, and delete my recurring transactions, so that I can keep my recurring expenses and income up-to-date.

#### Acceptance Criteria

1. THE System SHALL provide a dedicated section or page to view all recurring transactions
2. WHEN viewing recurring transactions, THE System SHALL display the recurrence pattern, next occurrence date, and transaction details
3. WHEN a user edits a recurring transaction, THE System SHALL update the template without affecting previously generated transactions
4. WHEN a user deletes a recurring transaction, THE System SHALL stop generating future transactions but preserve previously generated transactions
5. WHEN a user deletes a recurring transaction, THE System SHALL prompt for confirmation before deletion

### Requirement 5: Recurring Transaction Form UI

**User Story:** As a developer, I want the recurring transaction form to be intuitive and follow the app's design patterns, so that users have a consistent experience.

#### Acceptance Criteria

1. THE Recurring_Form SHALL follow the same design system as the existing Transaction_Form
2. WHEN displaying recurrence pattern options, THE System SHALL use a picker interface similar to the category picker
3. WHEN a user selects a recurrence pattern, THE System SHALL dynamically show relevant date selection options
4. THE Recurring_Form SHALL validate that the start date is not in the distant past (more than 1 year ago)
5. THE Recurring_Form SHALL display a preview of the next 3 occurrence dates based on the selected pattern and start date

### Requirement 6: Data Persistence and Migration

**User Story:** As a developer, I want recurring transaction data to be properly stored and the existing data model to be extended, so that the feature integrates seamlessly with the current system.

#### Acceptance Criteria

1. THE System SHALL store recurring transactions separately from regular transactions in SharedPreferences
2. THE System SHALL extend the Transaction model to include an optional recurring template reference
3. WHEN serializing recurring transactions, THE System SHALL include all recurrence parameters
4. WHEN deserializing recurring transactions, THE System SHALL properly reconstruct the recurrence pattern and next occurrence date
5. THE System SHALL maintain backward compatibility with existing transaction data

### Requirement 7: Edge Cases and Error Handling

**User Story:** As a user, I want the recurring transaction feature to handle edge cases gracefully, so that I don't encounter unexpected behavior.

#### Acceptance Criteria

1. WHEN a monthly recurring transaction is scheduled for a day that doesn't exist in a month, THE System SHALL create the transaction on the last day of that month
2. WHEN the app is not opened for an extended period, THE System SHALL generate all missed recurring transactions up to a maximum of 90 days in the past
3. IF transaction generation fails, THE System SHALL log the error and retry on the next app launch
4. WHEN a user creates a recurring transaction with a start date in the future, THE System SHALL not generate any transactions until that date arrives
5. WHEN displaying the recurrence indicator, THE System SHALL handle both light and dark themes appropriately
