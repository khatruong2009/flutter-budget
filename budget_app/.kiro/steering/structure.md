# Project Structure

## Root Directory Layout

```
budget_app/
├── lib/                    # Main Dart source code
├── assets/                 # Static assets (icons, images)
├── android/               # Android-specific configuration
├── ios/                   # iOS-specific configuration
├── web/                   # Web-specific configuration
├── macos/                 # macOS-specific configuration
├── linux/                 # Linux-specific configuration
├── windows/               # Windows-specific configuration
├── test/                  # Unit and widget tests
└── .kiro/                 # Kiro AI assistant configuration
```

## Core Application Structure (`lib/`)

### Main Entry Points

- `main.dart` - App initialization, providers setup, quick actions
- `home_page.dart` - Main tab navigation container using CupertinoTabScaffold

### Feature Pages

- `spending_page.dart` - Monthly spending overview and budget tracking
- `transaction_page.dart` - Transaction list and management
- `category_page.dart` - Category-based spending analysis with charts
- `history_page.dart` - Historical transaction data
- `insights_page.dart` - Financial insights and analytics
- `settings_page.dart` - App configuration and preferences

### Data Layer

- `transaction.dart` - Transaction entity/model definitions
- `transaction_model.dart` - Main data model with business logic (ChangeNotifier)
- `transaction_form.dart` - Transaction input forms and validation

### UI Components

- `theme_provider.dart` - Theme management (light/dark mode)
- `common.dart` - Shared UI components and utilities
- `chat.dart` - AI chat integration functionality

## Architecture Patterns

### State Management

- **Provider Pattern**: Uses `ChangeNotifier` classes for state management
- **MultiProvider**: Root-level providers in `main.dart`
- **Consumer/Provider.of**: State access throughout widget tree

### Data Flow

1. **TransactionModel** - Central data store for all transactions
2. **SharedPreferences** - Local persistence layer
3. **Provider.notifyListeners()** - UI updates on data changes

### Navigation

- **CupertinoTabScaffold** - iOS-style tab navigation as main container
- **GlobalKey<NavigatorState>** - Global navigation key for programmatic navigation

## Platform-Specific Directories

### Mobile Platforms

- `android/` - Android manifest, Gradle configs, native code
- `ios/` - iOS Info.plist, Xcode project, native Swift code

### Desktop Platforms

- `macos/` - macOS app bundle configuration
- `windows/` - Windows executable configuration
- `linux/` - Linux desktop integration

### Web Platform

- `web/` - HTML entry point, web manifest, favicon

## File Naming Conventions

- **Snake case**: All Dart files use snake_case naming
- **Descriptive names**: Files named after their primary purpose/feature
- **Page suffix**: UI pages end with `_page.dart`
- **Model suffix**: Data models end with `_model.dart`

## Code Organization Principles

- **Single responsibility**: Each file focuses on one feature/concern
- **Feature-based**: Related functionality grouped together
- **Separation of concerns**: UI, data, and business logic separated
- **Provider pattern**: State management centralized in ChangeNotifier classes
