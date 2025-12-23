# Adding SceneDelegate to Xcode Project

The SceneDelegate.swift file has been created, but it needs to be added to the Xcode project.

## Option 1: Automatic (Recommended)

Run this command from the project root:

```bash
cd ios
open Runner.xcodeproj
```

Then in Xcode:

1. Right-click on the "Runner" folder in the left sidebar
2. Select "Add Files to Runner..."
3. Navigate to and select `SceneDelegate.swift`
4. Make sure "Copy items if needed" is UNCHECKED (file is already in the right place)
5. Make sure "Runner" target is checked
6. Click "Add"

## Option 2: Let Xcode Detect It

1. Open the project in Xcode: `cd ios && open Runner.xcodeproj`
2. Try to build the project (Cmd+B)
3. Xcode may automatically detect and add the file

## Option 3: Clean and Rebuild

If the file still isn't recognized:

```bash
cd ios
rm -rf build
rm -rf Pods
rm Podfile.lock
pod install
open Runner.xcodeproj
```

## Verify It Works

After adding the file, you should no longer see the UIScene lifecycle warning when running the app.

The changes made:

- ✅ `Info.plist` - Added UIApplicationSceneManifest configuration
- ✅ `SceneDelegate.swift` - Created with scene lifecycle methods
- ✅ `AppDelegate.swift` - Updated to support both old and new lifecycle
- ⏳ `Runner.xcodeproj` - Needs SceneDelegate.swift added (manual step)

## What This Fixes

This implements the modern iOS 13+ UIScene lifecycle, which:

- Supports multiple windows on iPad
- Provides better app lifecycle management
- Eliminates the deprecation warning
- Maintains backward compatibility with iOS 12
