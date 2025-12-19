# Quick Actions Icons Setup Guide

## What's Been Done

✅ **Android**: Vector drawable icons created

- `android/app/src/main/res/drawable/plus.xml` - Plus icon for Add Income
- `android/app/src/main/res/drawable/minus.xml` - Minus icon for Add Expense

✅ **iOS**: Asset catalog structure created

- `ios/Runner/Assets.xcassets/plus.imageset/Contents.json`
- `ios/Runner/Assets.xcassets/minus.imageset/Contents.json`

✅ **Code**: Already configured in `lib/main.dart`

- Add Expense uses `icon: 'minus'`
- Add Income uses `icon: 'plus'`

## What You Need to Do for iOS

You need to add PNG image files to the iOS asset catalogs. Here are your options:

### Option 1: Create Simple Icons (Recommended)

Create simple white + and - symbols on transparent backgrounds:

**For Plus Icon:**

1. Create 3 PNG files with white + symbol:

   - `plus.png` (35x35 pixels)
   - `plus@2x.png` (70x70 pixels)
   - `plus@3x.png` (105x105 pixels)

2. Place them in: `ios/Runner/Assets.xcassets/plus.imageset/`

**For Minus Icon:**

1. Create 3 PNG files with white - symbol:

   - `minus.png` (35x35 pixels)
   - `minus@2x.png` (70x70 pixels)
   - `minus@3x.png` (105x105 pixels)

2. Place them in: `ios/Runner/Assets.xcassets/minus.imageset/`

### Option 2: Use SF Symbols (iOS Native)

Alternatively, you can use iOS system icons by modifying the code in `lib/main.dart`:

```dart
const ShortcutItem(
  type: 'action_add_expense',
  localizedTitle: 'Add Expense',
  icon: 'minus.circle.fill',  // SF Symbol name
),
const ShortcutItem(
  type: 'action_add_income',
  localizedTitle: 'Add Income',
  icon: 'plus.circle.fill',  // SF Symbol name
),
```

Common SF Symbol options:

- `plus.circle.fill` / `minus.circle.fill` - Filled circles with symbols
- `plus.circle` / `minus.circle` - Outlined circles
- `plus` / `minus` - Simple symbols
- `plus.square.fill` / `minus.square.fill` - Filled squares

### Option 3: Use Online Icon Generator

Use a tool like:

- https://www.canva.com (free icon creation)
- https://www.figma.com (design tool)
- https://icon.kitchen (icon generator)

Create simple white + and - symbols on transparent backgrounds at the sizes mentioned above.

## Testing

After adding the iOS images:

1. **Clean build**: `flutter clean`
2. **Get dependencies**: `flutter pub get`
3. **Run on device**: `flutter run -d ios` or `flutter run -d android`
4. **Test quick actions**: Long-press the app icon on your home screen

## Current Status

- ✅ Android will work immediately (vector drawables are ready)
- ⚠️ iOS needs PNG images added to the asset catalogs
- ✅ Code is already configured correctly

Choose Option 2 (SF Symbols) for the quickest solution if you want iOS system icons!
