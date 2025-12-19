# Design Document: Recurring Transactions

## Overview

The recurring transactions feature extends the existing budget app to support automatic generation of transactions based on user-defined schedules. The design maintains separation between recurring transaction templates and the actual transactions they generate, ensuring data integrity and allowing independent management of both.

The system consists of three main components:

1. **Recurring Transaction Model** - Data structures and business logic for recurring templates
2. **Transaction Generator** - Background service that creates actual transactions from templates
3. **UI Extensions** - Form components and visual indicators integrated into existing screens

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
├─────────────────────────────────────────────────────────────┤
│  Transaction Form  │  Recurring Form  │  Management Screen  │
│  (with link)       │  (separate modal)│  (list/edit/delete) │
└──────────┬─────────┴────────┬─────────┴──────────┬──────────┘
           │                  │                     │
           ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      Business Logic Layer                    │
├─────────────────────────────────────────────────────────────┤
│  TransactionModel  │  RecurringTransactionModel             │
│  (existing)        │  (new)                                 │
└──────────┬─────────┴────────┬──────────────────────────────┘
           │                  │
           ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Transaction Generator                     │
│  - Checks on app launch                                     │
│  - Generates due transactions                               │
│  - Updates next occurrence dates                            │
└──────────┬──────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                              │
├─────────────────────────────────────────────────────────────┤
│  SharedPreferences                                          │
│  - transactions (existing)                                  │
│  - recurring_transactions (new)                             │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Creation Flow**: User → Recurring Form → RecurringTransactionModel → SharedPreferences
2. **Generation Flow**: App Launch → Transaction Generator → Check Due Dates → Create Transactions → TransactionModel
3. **Display Flow**: TransactionModel → UI → Check Recurring Flag → Show Indicator

## Components and Interfaces

### 1. RecurringTransaction Model

```dart
enum RecurrencePattern {
  weekly,
  biweekly,
  monthly,
}

class RecurringTransaction {
  final String id;                    // Unique identifier
  final TransactionTyp type;          // Income or expense
  final String description;
  final double amount;
  final String category;
  final RecurrencePattern pattern;
  final DateTime startDate;
  final DateTime nextOccurrence;      // Next date to generate transaction
  final int? dayOfMonth;              // For monthly: 1-31
  final int? dayOfWeek;               // For weekly/biweekly: 1-7 (Monday-Sunday)
  final bool isActive;                // Can be paused without deletion

  RecurringTransaction({...});

  // Serialization
  Map<String, dynamic> toJson();
  factory RecurringTransaction.fromJson(Map<String, dynamic> json);

  // Calculate next occurrence date
  DateTime calculateNextOccurrence();

  // Create a transaction from this template
  Transaction generateTransaction(DateTime date);
}
```

### 2. RecurringTransactionModel (ChangeNotifier)

```dart
class RecurringTransactionModel extends ChangeNotifier {
  List<RecurringTransaction> recurringTransactions = [];

  // CRUD operations
  void addRecurringTransaction(RecurringTransaction recurring);
  void updateRecurringTransaction(String id, RecurringTransaction updated);
  void deleteRecurringTransaction(String id);
  RecurringTransaction? getRecurringTransaction(String id);

  // Persistence
  Future<void> saveRecurringTransactions();
  Future<void> loadRecurringTransactions();

  // Query operations
  List<RecurringTransaction> getActiveRecurringTransactions();
  List<RecurringTransaction> getDueRecurringTransactions(DateTime asOf);
}
```

### 3. Transaction Model Extension

```dart
class Transaction {
  // Existing fields...
  final String? recurringTemplateId;  // NEW: Links to recurring template

  // Existing methods...

  // NEW: Check if transaction is from recurring template
  bool get isRecurring => recurringTemplateId != null;
}
```

### 4. TransactionGenerator Service

```dart
class TransactionGenerator {
  final TransactionModel transactionModel;
  final RecurringTransactionModel recurringModel;

  // Main entry point - called on app launch
  Future<void> generateDueTransactions() async {
    final now = DateTime.now();
    final dueRecurring = recurringModel.getDueRecurringTransactions(now);

    for (var recurring in dueRecurring) {
      await _generateMissedTransactions(recurring, now);
    }
  }

  // Generate all missed occurrences up to current date
  Future<void> _generateMissedTransactions(
    RecurringTransaction recurring,
    DateTime upTo,
  ) async {
    final maxLookback = upTo.subtract(Duration(days: 90));
    DateTime current = recurring.nextOccurrence;

    while (current.isBefore(upTo) || _isSameDay(current, upTo)) {
      if (current.isAfter(maxLookback)) {
        final transaction = recurring.generateTransaction(current);
        transactionModel.addTransaction(
          transaction.type,
          transaction.description,
          transaction.amount,
          transaction.category,
          transaction.date,
          recurringTemplateId: recurring.id,
        );
      }
      current = _calculateNextOccurrence(recurring, current);
    }

    // Update next occurrence date
    recurring.nextOccurrence = current;
    recurringModel.updateRecurringTransaction(recurring.id, recurring);
  }

  // Calculate next occurrence based on pattern
  DateTime _calculateNextOccurrence(
    RecurringTransaction recurring,
    DateTime from,
  ) {
    switch (recurring.pattern) {
      case RecurrencePattern.weekly:
        return from.add(Duration(days: 7));
      case RecurrencePattern.biweekly:
        return from.add(Duration(days: 14));
      case RecurrencePattern.monthly:
        return _calculateNextMonthlyOccurrence(from, recurring.dayOfMonth!);
    }
  }

  // Handle monthly recurrence with day-of-month logic
  DateTime _calculateNextMonthlyOccurrence(DateTime from, int dayOfMonth) {
    int nextMonth = from.month + 1;
    int nextYear = from.year;

    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    // Handle months with fewer days
    int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    int actualDay = dayOfMonth > daysInMonth ? daysInMonth : dayOfMonth;

    return DateTime(nextYear, nextMonth, actualDay);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
```

### 5. UI Components

#### Recurring Transaction Link (in existing Transaction Form)

```dart
// Add to transaction_form.dart
Widget _buildRecurringTransactionLink(BuildContext context) {
  return GestureDetector(
    onTap: () {
      Navigator.of(context).pop(); // Close current form
      showRecurringTransactionForm(context, type);
    },
    child: Container(
      padding: EdgeInsets.all(AppDesign.spacingS),
      decoration: BoxDecoration(
        color: AppDesign.getCardColor(context).withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppDesign.radiusM),
        border: Border.all(
          color: AppDesign.getBorderColor(context),
          width: AppDesign.borderMedium,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: AppDesign.iconS,
            color: AppDesign.getTextSecondary(context),
          ),
          SizedBox(width: AppDesign.spacingXS),
          Text(
            'Make this recurring',
            style: AppTypography.caption.copyWith(
              color: AppDesign.getTextSecondary(context),
            ),
          ),
        ],
      ),
    ),
  );
}
```

#### Recurring Transaction Form

```dart
// New file: lib/recurring_transaction_form.dart
Future<void> showRecurringTransactionForm(
  BuildContext context,
  TransactionTyp type,
  [RecurringTransaction? templateToEdit]
) async {
  // Similar structure to transaction_form.dart but with:
  // - Recurrence pattern picker (weekly/biweekly/monthly)
  // - Conditional day selection based on pattern
  // - Start date picker
  // - Preview of next 3 occurrences
  // - Save button that creates RecurringTransaction
}
```

#### Recurrence Indicator Icon

```dart
// Add to common.dart or create new file: lib/widgets/recurrence_indicator.dart
class RecurrenceIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const RecurrenceIndicator({
    this.size = 16.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppDesign.getTextSecondary(context);

    return CustomPaint(
      size: Size(size, size * 0.6), // Elongated oval aspect ratio
      painter: _RecurrenceIconPainter(iconColor),
    );
  }
}

class _RecurrenceIconPainter extends CustomPainter {
  final Color color;

  _RecurrenceIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Draw elongated oval with two arrows
    // Arrow 1: Top-right pointing
    // Arrow 2: Bottom-left pointing
    // Connected by curved paths forming oval

    final path = Path();
    // ... implementation of elongated oval with arrows

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

#### Recurring Transactions Management Screen

```dart
// New file: lib/recurring_transactions_page.dart
class RecurringTransactionsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<RecurringTransactionModel>(
      builder: (context, model, child) {
        final recurring = model.recurringTransactions;

        return Scaffold(
          appBar: ModernAppBar(title: 'Recurring Transactions'),
          body: ListView.builder(
            itemCount: recurring.length,
            itemBuilder: (context, index) {
              return _RecurringTransactionListItem(
                recurring: recurring[index],
                onEdit: () => _editRecurring(context, recurring[index]),
                onDelete: () => _deleteRecurring(context, recurring[index]),
              );
            },
          ),
        );
      },
    );
  }
}
```

## Data Models

### RecurringTransaction JSON Structure

```json
{
  "id": "uuid-string",
  "type": "expense",
  "description": "Netflix Subscription",
  "amount": 15.99,
  "category": "Entertainment",
  "pattern": "monthly",
  "startDate": "2024-01-01T00:00:00.000Z",
  "nextOccurrence": "2024-02-01T00:00:00.000Z",
  "dayOfMonth": 1,
  "dayOfWeek": null,
  "isActive": true
}
```

### Extended Transaction JSON Structure

```json
{
  "type": "expense",
  "description": "Netflix Subscription",
  "amount": 15.99,
  "category": "Entertainment",
  "date": "2024-01-01T00:00:00.000Z",
  "recurringTemplateId": "uuid-string"
}
```

## Correctness Properties

_A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees._

### Property Reflection

After analyzing all acceptance criteria, I identified the following potential redundancies:

- Properties 3.1 and 3.4 both test that recurring transactions show indicators - these can be combined
- Properties 6.3 and 6.4 both test serialization round-trip - these can be combined
- Properties 2.4 and 7.1 are identical edge cases - will be handled by generators

The following properties represent unique, non-redundant validation requirements:

### Property 1: Required Fields Validation

_For any_ recurring transaction creation attempt, if any required field (type, description, amount, category, pattern, start date) is missing or invalid, the system should reject the creation and return a validation error.
**Validates: Requirements 1.3**

### Property 2: Bi-weekly Occurrence Calculation

_For any_ recurring transaction with bi-weekly pattern and any start date, the next occurrence should always be exactly 14 days after the previous occurrence.
**Validates: Requirements 1.6**

### Property 3: Recurring Transaction Persistence Round-Trip

_For any_ valid recurring transaction, serializing it to JSON and then deserializing should produce an equivalent recurring transaction with all fields preserved including recurrence parameters.
**Validates: Requirements 1.7, 6.3, 6.4**

### Property 4: Initial Transaction Generation

_For any_ recurring transaction with a start date that is today or in the past, saving the recurring transaction should immediately generate at least one actual transaction.
**Validates: Requirements 1.8**

### Property 5: Transaction Generation with Template Details

_For any_ recurring transaction with a past due date, the generated transaction should have matching type, description, amount, and category from the template.
**Validates: Requirements 2.2**

### Property 6: Recurring Marker on Generated Transactions

_For any_ transaction generated from a recurring template, the transaction should have a non-null recurringTemplateId field.
**Validates: Requirements 2.3**

### Property 7: Next Occurrence Update After Generation

_For any_ recurring transaction after generating a transaction, the nextOccurrence date should be updated to the next valid date according to the recurrence pattern.
**Validates: Requirements 2.5**

### Property 8: Multiple Missed Occurrences Generation

_For any_ recurring transaction with multiple missed occurrence dates (nextOccurrence is more than one period in the past), the generator should create one transaction for each missed occurrence up to the current date.
**Validates: Requirements 2.6**

### Property 9: Recurrence Indicator Display

_For any_ transaction with a non-null recurringTemplateId, the UI should display the recurrence indicator icon.
**Validates: Requirements 3.1, 3.4**

### Property 10: Recurring Transaction Display Fields

_For any_ recurring transaction displayed in the management screen, the rendered output should contain the recurrence pattern, next occurrence date, description, amount, and category.
**Validates: Requirements 4.2**

### Property 11: Template Edit Isolation

_For any_ recurring transaction template that is edited, previously generated transactions should remain unchanged (their fields should not be modified).
**Validates: Requirements 4.3**

### Property 12: Deletion Stops Future Generation

_For any_ recurring transaction that is deleted, no new transactions should be generated from that template after the deletion, but all previously generated transactions should remain in the transaction list.
**Validates: Requirements 4.4**

### Property 13: Dynamic Date Options by Pattern

_For any_ recurrence pattern selection, the form should display the appropriate date selection options: day-of-month (1-31) for monthly, day-of-week (Mon-Sun) for weekly/biweekly.
**Validates: Requirements 5.3**

### Property 14: Start Date Validation

_For any_ start date more than 365 days in the past, the recurring transaction form should reject it with a validation error.
**Validates: Requirements 5.4**

### Property 15: Occurrence Preview Calculation

_For any_ valid recurrence pattern and start date, the preview should display exactly 3 future occurrence dates calculated according to the pattern rules.
**Validates: Requirements 5.5**

### Property 16: 90-Day Lookback Limit

_For any_ recurring transaction with missed occurrences, the generator should only create transactions for dates within the last 90 days, ignoring any older missed occurrences.
**Validates: Requirements 7.2**

### Property 17: Future Start Date No Generation

_For any_ recurring transaction with a start date in the future, no transactions should be generated until the current date reaches or passes the start date.
**Validates: Requirements 7.4**

## Error Handling

### Validation Errors

- **Missing Required Fields**: Display inline error messages in the recurring form
- **Invalid Date Ranges**: Prevent selection of dates more than 1 year in the past
- **Invalid Day of Month**: For monthly recurrence, validate day is between 1-31

### Generation Errors

- **Storage Failure**: Log error and retry on next app launch
- **Date Calculation Errors**: Fall back to last day of month for invalid monthly dates
- **Concurrent Modification**: Use optimistic locking with version numbers on recurring templates

### Edge Cases

- **Month Boundary**: For day 31 in months with fewer days, use last day of month
- **Leap Year**: Handle February 29th by using February 28th in non-leap years
- **Time Zones**: All dates stored in UTC, converted to local time for display
- **App Not Opened**: Generate up to 90 days of missed transactions on next launch

## Testing Strategy

### Dual Testing Approach

The recurring transactions feature will be validated using both unit tests and property-based tests:

- **Unit Tests**: Verify specific examples, edge cases (month boundaries, leap years), and UI interactions
- **Property Tests**: Verify universal properties across all inputs using randomized test data

### Property-Based Testing Configuration

We will use the `test` package with custom property-based testing utilities for Dart/Flutter. Each property test will:

- Run a minimum of 100 iterations with randomized inputs
- Reference its corresponding design property number
- Use the tag format: **Feature: recurring-transactions, Property {N}: {property_text}**

### Test Coverage Areas

**Unit Tests Focus**:

- Specific date edge cases (Feb 29, day 31 in short months)
- UI component rendering and interaction
- Form validation with specific invalid inputs
- Integration between RecurringTransactionModel and TransactionModel

**Property Tests Focus**:

- Date calculation algorithms across all valid inputs
- Serialization/deserialization round-trips
- Transaction generation logic with random templates
- Validation rules across random invalid inputs

### Example Property Test Structure

```dart
test('Property 3: Recurring Transaction Persistence Round-Trip', () {
  // Feature: recurring-transactions, Property 3: Persistence round-trip
  for (int i = 0; i < 100; i++) {
    // Generate random recurring transaction
    final recurring = generateRandomRecurringTransaction();

    // Serialize and deserialize
    final json = recurring.toJson();
    final deserialized = RecurringTransaction.fromJson(json);

    // Verify equivalence
    expect(deserialized, equals(recurring));
  }
});
```

### Test Data Generators

Create smart generators that produce valid test data:

- Random dates within reasonable ranges
- Valid recurrence patterns
- Realistic amounts and descriptions
- Edge cases (day 31, Feb 29) included in random generation
