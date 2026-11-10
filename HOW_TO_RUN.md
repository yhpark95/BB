# 🚀 How to Run the Simple Bible App

## Quick Start (3 Steps)

### Step 1: Install Flutter

**Windows:**
1. Download Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extract to `C:\src\flutter` (or any location)
3. Add Flutter to PATH:
   - Search "Environment Variables" in Windows
   - Edit "Path" variable
   - Add: `C:\src\flutter\bin`
4. Restart terminal

**Verify installation:**
```bash
flutter doctor
```

### Step 2: Install Dependencies

```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter pub get
```

### Step 3: Run the App

```bash
flutter run
```

That's it! The app will launch.

---

## Detailed Instructions

### Prerequisites

You need:
1. **Flutter SDK** (includes Dart)
2. **A device** to run on:
   - Android Emulator (recommended for Windows)
   - Physical Android device via USB
   - Chrome browser (web version)

---

## Option A: Run on Chrome (Fastest for Testing)

**Best for quick testing without emulator setup.**

```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter run -d chrome
```

✅ **Pros:** No emulator needed, fast to start
⚠️ **Note:** SQLite works differently on web, may need adjustments

---

## Option B: Run on Android Emulator (Recommended)

### 1. Install Android Studio

Download: https://developer.android.com/studio

**During installation, make sure to install:**
- Android SDK
- Android Virtual Device (AVD)

### 2. Create an Emulator

1. Open Android Studio
2. Click "More Actions" → "Virtual Device Manager"
3. Click "Create Device"
4. Select a phone (e.g., Pixel 7)
5. Download system image (e.g., API 34)
6. Click "Finish"

### 3. Start the Emulator

In Android Studio:
- Click ▶️ next to your virtual device

Or from terminal:
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator_id>
```

### 4. Run the App

```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter run
```

Flutter will detect the emulator and install the app automatically.

---

## Option C: Run on Physical Android Device

### 1. Enable Developer Mode on Phone

**Android:**
1. Settings → About Phone
2. Tap "Build Number" 7 times
3. Go back → Developer Options
4. Enable "USB Debugging"

### 2. Connect via USB

1. Connect phone to computer with USB cable
2. Allow USB debugging on phone

### 3. Verify Device

```bash
flutter devices
```

Should show your phone.

### 4. Run the App

```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter run
```

---

## Troubleshooting

### Issue: "flutter is not recognized"

**Solution:** Flutter not in PATH
```bash
# Check if Flutter is installed
where flutter

# If not found, add to PATH:
# 1. Find flutter.bat location (e.g., C:\src\flutter\bin)
# 2. Add to System Environment Variables
# 3. Restart terminal
```

### Issue: "No devices found"

**Solution:** Need a device to run on

**Option 1 - Use Chrome:**
```bash
flutter run -d chrome
```

**Option 2 - Start Android Emulator:**
```bash
flutter emulators --launch Pixel_7_API_34
```

**Option 3 - Connect physical device via USB**

### Issue: "Unable to load asset: assets/bible.db"

**Solution:** Clean and rebuild
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: "Gradle build failed"

**Solution:** Android SDK issue
```bash
# Run Flutter doctor
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses
```

### Issue: "MissingPluginException"

**Solution:** Hot restart needed
```bash
# In the running app, press 'R' (capital R)
# Or stop and restart:
flutter run
```

---

## First-Time Flutter Installation

### Complete Setup (Windows)

```bash
# 1. Download Flutter
# Go to: https://docs.flutter.dev/get-started/install/windows
# Download the ZIP file

# 2. Extract to C:\src\flutter

# 3. Add to PATH (PowerShell as Admin)
$env:Path += ";C:\src\flutter\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::User)

# 4. Run Flutter Doctor
flutter doctor

# 5. Accept Android licenses (if using Android)
flutter doctor --android-licenses

# 6. Navigate to project
cd C:\Users\yhpark\Desktop\BB\simple_bible

# 7. Get dependencies
flutter pub get

# 8. Run on Chrome (easiest)
flutter run -d chrome

# Or run on Android emulator
flutter emulators --launch <emulator_name>
flutter run
```

---

## Recommended: Visual Studio Code

### 1. Install VS Code
Download: https://code.visualstudio.com/

### 2. Install Flutter Extension
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search "Flutter"
4. Install "Flutter" by Dart Code

### 3. Open Project
```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
code .
```

### 4. Run from VS Code
1. Press F5
2. Or click "Run > Start Debugging"
3. Select device from bottom bar

---

## Quick Test Run (No Installation)

If you just want to see if it works:

```bash
# 1. Install Flutter (Windows)
# Download: https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.0-stable.zip
# Extract to C:\flutter

# 2. Add to PATH temporarily
set PATH=%PATH%;C:\flutter\bin

# 3. Run on Chrome
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter pub get
flutter run -d chrome
```

---

## What You Should See

### Terminal Output:
```
Launching lib\main.dart on Chrome in debug mode...
Building application for the web...
✓ Built build\web

Chrome (web) • chrome • web-javascript • Google Chrome 120.0.0.0
```

### App Window:
1. **Home Screen** with:
   - "Start Reading" or "Continue Reading" card
   - "Select Book & Chapter" button
   - Browse Books section
   - Top bar with Search, Bookmarks, Settings icons

2. **You can:**
   - Tap "Start Reading" to read John 3
   - Tap "Select Book & Chapter" to choose any book/chapter
   - Tap Search icon to search the Bible
   - Tap Settings to customize font/theme

---

## Expected Time

- **Flutter installation:** 10-20 minutes
- **Project setup:** 2 minutes
- **First run:** 3-5 minutes (building)
- **Subsequent runs:** 30 seconds

---

## System Requirements

**Minimum:**
- Windows 10 or higher
- 4GB RAM
- 2GB free disk space
- Internet connection (for initial Flutter download)

**Recommended:**
- Windows 11
- 8GB+ RAM
- SSD storage
- Android Emulator requires: Intel/AMD CPU with virtualization support

---

## Support Links

- **Flutter Installation Guide:** https://docs.flutter.dev/get-started/install/windows
- **Flutter Doctor:** https://docs.flutter.dev/get-started/install/windows#run-flutter-doctor
- **Android Studio:** https://developer.android.com/studio
- **VS Code:** https://code.visualstudio.com/

---

## TL;DR - Absolute Fastest Way

```bash
# Install Flutter first (download and extract)
# Then:

cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter pub get
flutter run -d chrome
```

**Done!** The app will open in Chrome browser.

---

## Still Having Issues?

Run the verification script first:
```bash
cd C:\Users\yhpark\Desktop\BB
python verify_setup.py
```

This will check if all files are in place correctly.

---

**Need Help?**
Check `flutter doctor` output and follow any instructions it gives. The doctor command is very helpful for diagnosing setup issues.
