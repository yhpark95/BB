# 🔧 Flutter Setup Guide - Fix "Could not find Dart" Error

## Problem
Your Flutter installation is incomplete or corrupted. VS Code can't find Dart.

## Solution: Reinstall Flutter Properly

---

## Method 1: Automatic Installation (Recommended)

### Run PowerShell Script:

1. **Right-click PowerShell** and select **"Run as Administrator"**

2. **Allow script execution:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run the installation script:**
   ```powershell
   cd C:\Users\yhpark\Desktop\BB
   .\install_flutter.ps1
   ```

4. **Wait 10-15 minutes** for download and installation

5. **Restart VS Code completely**

---

## Method 2: Manual Installation (Step by Step)

### Step 1: Download Flutter

1. Go to: **https://docs.flutter.dev/get-started/install/windows**
2. Click **"Download Flutter SDK"** button
3. Save the ZIP file (about 1.5 GB)

### Step 2: Extract Flutter

1. **Create folder:** `C:\src` (if it doesn't exist)
2. **Extract the ZIP** into `C:\src`
3. **Verify path:** You should have `C:\src\flutter\bin\flutter.bat`
   - ❌ NOT: `C:\src\flutter\flutter\bin\flutter.bat`
   - ✅ YES: `C:\src\flutter\bin\flutter.bat`

### Step 3: Add to System PATH

1. Press **Windows key** and type: `environment variables`
2. Click **"Edit the system environment variables"**
3. Click **"Environment Variables"** button
4. Under **"User variables"**, find **Path** and click **"Edit"**
5. Click **"New"**
6. Type: `C:\src\flutter\bin`
7. Click **"OK"** on all windows

### Step 4: Verify Installation

1. **Close ALL terminal/PowerShell/Command Prompt windows**
2. **Close VS Code completely**
3. **Open NEW Command Prompt**
4. **Run:**
   ```bash
   flutter doctor
   ```

You should see:
```
[✓] Flutter (Channel stable, 3.19.6, on Microsoft Windows)
[✓] Chrome - develop for the web
```

### Step 5: Complete Setup

```bash
# Accept licenses (if you see any issues)
flutter doctor --android-licenses

# Check everything is OK
flutter doctor -v
```

---

## Method 3: Quick Fix (If You Have Partial Install)

If Flutter is installed but PATH is wrong:

1. **Find your Flutter installation:**
   - Check: `C:\flutter`
   - Check: `C:\src\flutter`
   - Check: `%LOCALAPPDATA%\flutter`
   - Check: Your Downloads folder

2. **Once found, add the `bin` folder to PATH:**
   - If Flutter is at `C:\flutter`, add `C:\flutter\bin` to PATH
   - Use the PATH instructions from Method 2, Step 3

3. **Restart everything and test:**
   ```bash
   flutter doctor
   ```

---

## After Flutter is Installed

### Step 1: Restart VS Code
**Close ALL VS Code windows and reopen**

### Step 2: Open Your Project
```bash
code C:\Users\yhpark\Desktop\BB\simple_bible
```

### Step 3: Install Dependencies
In VS Code terminal (Ctrl + `):
```bash
flutter pub get
```

### Step 4: Run Your App
```bash
flutter run -d chrome
```

---

## Troubleshooting

### "flutter is not recognized"
**Solution:** PATH not set correctly
- Re-add Flutter to PATH (Method 2, Step 3)
- **Must restart terminal/VS Code after changing PATH**
- Verify: `echo %PATH%` should contain `C:\src\flutter\bin`

### "Could not find Dart in your Flutter SDK"
**Solution:** Corrupted/incomplete installation
- Delete the Flutter folder completely
- Reinstall using Method 1 or Method 2
- Make sure you extract the ENTIRE ZIP file

### "flutter doctor" shows issues
**Solution:** Run the suggested fix commands
```bash
flutter doctor --android-licenses  # If Android issues
flutter config --no-analytics       # If analytics issue
```

### VS Code still doesn't detect Flutter
**Solution:**
1. Close VS Code completely (all windows)
2. Delete VS Code workspace cache:
   - Delete: `C:\Users\yhpark\AppData\Roaming\Code\Cache`
3. Reopen VS Code
4. Reload VS Code: Press `Ctrl+Shift+P` → Type "Reload Window"

---

## Verify Everything Works

After installation, test:

```bash
# 1. Flutter command works
flutter --version

# 2. Doctor shows no major errors
flutter doctor

# 3. Can list devices
flutter devices

# 4. Can create project (optional test)
flutter create test_app
cd test_app
flutter run -d chrome
```

---

## Expected Flutter Doctor Output

Good installation looks like:
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.19.6, on Microsoft Windows 10)
[✓] Windows Version (Installed version of Windows is 10 or higher)
[✓] Chrome - develop for the web
[✓] VS Code (version 1.85.0)
[✓] Connected device (1 available)
[✓] Network resources

! Doctor found issues in 1 category.  <- This is OK if it's just Android warnings
```

---

## Quick Installation Timeline

- **Download:** 5-10 minutes (depends on internet)
- **Extract:** 2-3 minutes
- **PATH setup:** 1 minute
- **First flutter doctor:** 2-3 minutes
- **Total:** ~15-20 minutes

---

## Still Having Problems?

### Contact me with this info:

Run these commands and send me the output:

```bash
# Check if Flutter exists
dir C:\src\flutter\bin\flutter.bat

# Check PATH
echo %PATH%

# Try to run Flutter
flutter --version

# Check VS Code Flutter extension
code --list-extensions | findstr Dart-Code
```

---

## After Setup Works

Once `flutter doctor` works, come back to your Bible app:

```bash
cd C:\Users\yhpark\Desktop\BB\simple_bible
flutter pub get
flutter run -d chrome
```

Your app should launch! 🎉

---

## Important Notes

- ✅ **Must extract to exactly:** `C:\src\flutter` (not nested)
- ✅ **Must add to PATH:** `C:\src\flutter\bin`
- ✅ **Must restart terminal** after PATH changes
- ✅ **Must restart VS Code** after installation
- ⚠️ **Download is 1.5 GB** - needs good internet
- ⚠️ **First run takes 3-5 minutes** to build

---

**Choose Method 1 (PowerShell script) for automatic installation, or Method 2 for manual step-by-step!**
