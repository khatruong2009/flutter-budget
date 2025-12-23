# UIScene Lifecycle Migration

## Summary

The iOS app has been updated to support the modern UIScene-based lifecycle (iOS 13+) while maintaining backward compatibility with iOS 12.

## Changes Made

### 1. Info.plist (`ios/Runner/Info.plist`)

Added `UIApplicationSceneManifest` configuration:

- Declares scene support
- Links to SceneDelegate class
- Configures default scene configuration

### 2. SceneDelegate.swift (`ios/Runner/SceneDelegate.swift`) - NEW FILE

Created a new SceneDelegate that handles:

- Scene lifecycle events (connect, disconnect, foreground, background)
- Deep linking via URL contexts
- Flutter engine integration
- Method channel setup for deep links

### 3. AppDelegate.swift (`ios/Runner/AppDelegate.swift`)

Updated to support both lifecycles:

- Lazy Flutter engine initialization for scene-based apps
- Scene configuration methods for iOS 13+
- Backward compatibility for iOS 12 and below
- Conditional compilation using `@available` and `#unavailable`

## Next Step: Add SceneDelegate to Xcode Project

The SceneDelegate.swift file exists but needs to be added to the Xcode project:

```bash
# Open Xcode
cd ios
open Runner.xcodeproj
```

In Xcode:

1. Right-click "Runner" folder → "Add Files to Runner..."
2. Select `SceneDelegate.swift`
3. Uncheck "Copy items if needed"
4. Check "Runner" target
5. Click "Add"

## Verification

After adding the file, run the app:

```bash
flutter run -d ios
```

You should no longer see the warning:

> `UIScene` lifecycle will soon be required

## Benefits

- ✅ Eliminates deprecation warning
- ✅ Supports multiple windows on iPad
- ✅ Modern iOS lifecycle management
- ✅ Backward compatible with iOS 12
- ✅ Maintains all existing functionality (deep links, quick actions)

## Rollback (if needed)

If you encounter issues, you can revert by:

1. Removing SceneDelegate.swift from Xcode
2. Removing the `UIApplicationSceneManifest` section from Info.plist
3. Restoring the original AppDelegate.swift from git history
