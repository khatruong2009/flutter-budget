# Technology Stack

## Framework & Language

- **Flutter SDK**: Cross-platform UI framework (SDK >=3.0.5 <4.0.0)
- **Dart**: Primary programming language
- **Provider**: State management pattern using ChangeNotifier

## Key Dependencies

- **UI & Charts**: `fl_chart` (data visualization), `animated_digit` (number animations)
- **Data Persistence**: `shared_preferences` (local storage)
- **File Operations**: `path_provider`, `csv` (data export), `share_plus` (file sharing)
- **Platform Integration**: `quick_actions` (iOS/Android shortcuts)
- **AI Integration**: `dart_openai` (OpenAI API), `http` (network requests)
- **Configuration**: `flutter_dotenv` (environment variables)
- **Internationalization**: `intl` (date/number formatting)
- **Settings UI**: `settings_ui` (native settings screens)

## Development Tools

- **Linting**: `flutter_lints` with standard Flutter recommendations
- **Icons**: `flutter_launcher_icons` for app icon generation
- **Testing**: `flutter_test` framework

## Common Commands

### Development

```bash
# Get dependencies
flutter pub get

# Run app (debug mode)
flutter run

# Run on specific platform
flutter run -d chrome          # Web
flutter run -d macos           # macOS
flutter run -d ios             # iOS Simulator

# Hot reload during development
# Press 'r' in terminal or save files in IDE
```

### Building

```bash
# Build for release
flutter build apk              # Android APK
flutter build ios              # iOS
flutter build web              # Web
flutter build macos            # macOS
flutter build windows          # Windows
flutter build linux            # Linux

# Build app bundle (Android)
flutter build appbundle
```

### Analysis & Testing

```bash
# Static analysis
flutter analyze

# Run tests
flutter test

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade
```

### Asset Management

```bash
# Generate app icons
flutter pub run flutter_launcher_icons:main
```

## Build Configuration

- **Version**: 1.2.0
- **Minimum Android SDK**: 21
- **App Icons**: Generated from `assets/icon.png`
- **Environment Files**: `.env` support (currently commented out in pubspec.yaml)
