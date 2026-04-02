# Flutter Mobile App Setup Guide

Complete step-by-step guide to set up and run the Infini-Stock Flutter mobile app.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Flutter Installation](#flutter-installation)
3. [Project Setup](#project-setup)
4. [Running the App](#running-the-app)
5. [Building for Distribution](#building-for-distribution)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- **Windows**: Windows 10 or later
- **macOS**: macOS 10.13 (High Sierra) or later
- **Linux**: Ubuntu 18.04 or later

### Required Tools
- Git (for version control)
- Android Studio (for Android development)
- Xcode (for iOS development on macOS)
- A text editor or IDE (VS Code, Android Studio, IntelliJ)

## Flutter Installation

### Step 1: Download Flutter SDK

1. Visit [Flutter Official Website](https://flutter.dev/docs/get-started/install)
2. Download the appropriate version for your OS
3. Extract to a preferred location (e.g., `C:\flutter` on Windows or `~/flutter` on macOS/Linux)

### Step 2: Update PATH

**Windows:**
1. Press `Win + X` and select "System"
2. Go to "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", click "New"
5. Variable name: `FLUTTER_HOME`, Value: `C:\flutter` (your extraction path)
6. Under "System variables", select `Path` and add `%FLUTTER_HOME%\bin`
7. Click OK and restart your terminal

**macOS/Linux:**
```bash
export PATH="${PATH}:$HOME/flutter/bin"
```

Add this to your `~/.zshrc`, `~/.bashrc`, or `~/.bash_profile` file and run `source ~/.zshrc`.

### Step 3: Verify Installation

```bash
flutter doctor
```

This command will show:
- Flutter version
- Dart version
- Android toolchain status
- iOS toolchain status (macOS only)

Address any issues shown by `flutter doctor`.

## Project Setup

### Step 1: Clone the Repository

```bash
# Navigate to desired location
cd path/to/your/workspace

# Clone the full project or just navigate to the mobile-app folder if already cloned
cd Infini-Stock/mobile-app
```

### Step 2: Install Dependencies

```bash
# Get all Flutter dependencies
flutter pub get

# For native dependencies (Android)
cd android
./gradlew build
cd ..

# For native dependencies (iOS) - macOS only
cd ios
pod install
cd ..
```

### Step 3: Verify Setup

```bash
flutter doctor -v
```

Ensure you see:
- ✓ Flutter SDK
- ✓ Dart SDK
- ✓ Android toolchain
- ✓ Connected devices (or emulator ready)

## Running the App

### Option 1: Using Physical Device

**Android:**
1. Enable Developer Mode: Settings > About > tap Build Number 7 times
2. Enable USB Debugging: Settings > Developer options > USB Debugging
3. Connect device via USB
4. Run:
   ```bash
   flutter run
   ```

**iOS:**
1. Connect device via USB/Lightning
2. Run:
   ```bash
   flutter run
   ```

### Option 2: Using Emulator

**Android Emulator:**
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch emulator_name

# Or create new emulator through Android Studio

# Run app in emulator
flutter run
```

**iOS Simulator (macOS only):**
```bash
# Start simulator
open -a Simulator

# Run app
flutter run
```

### Option 3: Running on Web (Experimental)

```bash
flutter run -d chrome
```

## Running the App with Different Modes

### Development Mode (Default)
```bash
flutter run
```
- Includes debugging
- Hot reload enabled
- Larger app size

### Profile Mode (Performance Testing)
```bash
flutter run --profile
```
- Optimizations enabled
- Debugging still available
- Good for performance testing

### Release Mode (Production)
```bash
flutter run --release
```
- Full optimizations
- No debugging
- Smallest app size
- Production-ready

## Hot Reload & Hot Restart

Once the app is running:

**Hot Reload** (preserves state):
- Press `r` in terminal
- Fast refresh of UI changes

**Hot Restart** (resets state):
- Press `R` in terminal
- Full app restart

**Stop App:**
- Press `q` in terminal

## Building for Distribution

### Android APK

**Debug APK:**
```bash
flutter build apk --debug
# Output: build/app/outputs/apk/debug/app-debug.apk
```

**Release APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

**Android App Bundle (for Google Play):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS App

**iOS build:**
```bash
flutter build ios --release
# Output: build/ios/iphoneos/Runner.app
```

To generate IPA:
```bash
flutter build ios --release

cd build/ios/iphoneos
xcodebuild -exportArchive \
  -archivePath Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath .
```

## Troubleshooting

### Issue: "flutter not recognized"
**Solution:**
- Restart terminal/IDE after PATH changes
- Verify `flutter pub get` ran successfully
- Check Flutter installation path

### Issue: "No connected devices found"
**Solution:**
- For physical device: Enable USB Debugging + reconnect
- For emulator: `flutter emulators --launch <name>`
- Run `flutter devices` to list available devices

### Issue: "Gradle build failed"
**Solution:**
```bash
cd android
./gradlew clean
./gradlew build
cd ..
flutter clean
flutter pub get
```

### Issue: "CocoaPods error" (iOS)
**Solution:**
```bash
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
```

### Issue: "API connection errors"
**Solution:**
1. Verify backend server is running: `http://localhost:5000`
2. Check API base URL in `lib/services/api_client.dart`
3. For physical device: Update API URL to use actual server IP instead of localhost

### Issue: "App crashes on startup"
**Solution:**
- Check logs: `flutter run -v`
- Clear app data: Device Settings > Apps > Infini-Stock > Storage > Clear Data
- Rebuild: `flutter clean && flutter pub get && flutter run`

### Issue: "SharedPreferences empty after restart"
**Solution:**
- Data is persisted automatically
- Check if app has storage permissions
- On Android 11+: May need to request runtime permissions

## Development Workflow

### Daily Development
```bash
# 1. Start emulator/device
flutter emulators --launch emulator_name

# 2. Run app
flutter run

# 3. Edit code and use hot reload (r)

# 4. When done
# Press q to stop
```

### Before Committing
```bash
# Format code
dart format lib/

# Analyze code
flutter analyze

# Run tests
flutter test
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run --no-fast-start
```

## Performance Monitoring

### Frame Rate
```bash
flutter run --profile
# Press 't' in terminal to toggle frame info
```

### Memory Usage
```bash
flutter run --profile
# Use DevTools from terminal output
```

### Building DevTools
```bash
flutter pub global activate devtools
devtools
```

## Next Steps

1. **Run the app** - Complete setup and launch
2. **Test login** - Use demo credentials from README
3. **Explore screens** - Navigate through all pages
4. **Test on device** - Verify on actual hardware
5. **Customize API** - Update API base URL if needed
6. **Build for distribution** - When ready to release

## Getting Help

If you encounter issues:

1. Check Flutter documentation: https://flutter.dev/docs
2. Search Stack Overflow: https://stackoverflow.com/questions/tagged/flutter
3. Check GitHub issues
4. Run `flutter doctor -v` for detailed diagnostics

## Useful Commands Reference

```bash
# General
flutter doctor              # Check environment
flutter upgrade            # Update Flutter
flutter pub get            # Install dependencies

# Running
flutter run                # Run on connected device
flutter run -v             # Verbose output
flutter run --release      # Release mode

# Building
flutter build apk          # Build Android APK
flutter build appbundle    # Build Android Bundle
flutter build ios          # Build iOS app
flutter clean              # Clean build artifacts

# Development
dart format lib/           # Format code
flutter analyze            # Analyze code
flutter test               # Run tests
flutter pub outdated       # Check outdated packages

# Device Management
flutter devices            # List connected devices
flutter emulators          # List emulators
flutter emulators --launch name  # Start emulator
```

---

**Need more help?** Refer to the main [README.md](README.md) for app features and the [Flutter documentation](https://flutter.dev).
