# Quick Start Guide

## Prerequisites

Before running the app, make sure you have:

1. **Flutter SDK installed**
   - Download: https://flutter.dev/docs/get-started/install
   - Verify: `flutter doctor`

2. **An IDE** (choose one):
   - VS Code with Flutter extension
   - Android Studio with Flutter plugin

3. **A device or emulator**:
   - iOS Simulator (Mac only)
   - Android Emulator
   - Physical device with USB debugging

## Running the App

### Step 1: Install Dependencies

```bash
cd simple_bible
flutter pub get
```

### Step 2: Check Your Setup

```bash
flutter doctor
```

Make sure you have at least one device available.

### Step 3: Run the App

```bash
flutter run
```

Or in VS Code: Press `F5` or click "Run > Start Debugging"

## Project Structure Overview

```
simple_bible/
├── assets/
│   └── bible.db          # 31,117 verses from NKJV
│
├── lib/
│   ├── main.dart         # App entry point
│   │
│   ├── models/           # Data structures
│   │   ├── verse.dart
│   │   └── book.dart
│   │
│   ├── services/         # Business logic
│   │   └── database_service.dart
│   │
│   └── screens/          # UI screens
│       ├── home_screen.dart
│       └── reader_screen.dart
│
└── pubspec.yaml          # Dependencies
```

## Current Features

✅ Browse all 66 books of the Bible
✅ Read any chapter
✅ Navigate between chapters
✅ Long-press verses for actions
✅ Add bookmarks
✅ Dark mode support

## Testing the App

1. **Home Screen**:
   - Tap "Continue Reading" to jump to John 3
   - Expand "New Testament" to see all NT books
   - Tap any book to start reading from chapter 1

2. **Reader Screen**:
   - Scroll through verses
   - Use ← → buttons to navigate chapters
   - Long-press any verse to bookmark it

3. **Database Verification**:
   ```bash
   cd simple_bible/assets
   sqlite3 bible.db "SELECT COUNT(*) FROM verses;"
   # Should show: 31117
   ```

## Common Issues

### Issue: "Unable to load asset"
**Solution**: Make sure `bible.db` is in `simple_bible/assets/` and listed in `pubspec.yaml`

### Issue: "MissingPluginException"
**Solution**: Run `flutter clean` then `flutter pub get`

### Issue: Database file too large
**Solution**: This is normal - the Bible is ~7.8 MB. It's included as an asset.

## Development Tips

### Hot Reload
- Press `r` in terminal (or `Ctrl+S` in VS Code) to hot reload
- Press `R` to hot restart

### Debug Mode
- Press `p` to show performance overlay
- Press `w` to show widget hierarchy

### Useful Commands
```bash
flutter clean          # Clean build cache
flutter pub get        # Install dependencies
flutter build apk      # Build Android APK
flutter build ios      # Build iOS (Mac only)
```

## Next Development Steps

See `PROJECT_SETUP.md` for detailed next steps, including:
- Grid-based book/chapter picker
- Search functionality
- Settings screen
- Bookmarks management

## Need Help?

1. Check `README.md` for features and architecture
2. Check `PROJECT_SETUP.md` for detailed setup info
3. Review Flutter docs: https://flutter.dev/docs
4. Check SQLite database with: `sqlite3 simple_bible/assets/bible.db`

## File Locations

- **Database**: `simple_bible/assets/bible.db`
- **Source JSON**: `simple_bible/assets/nkjv.json`
- **Conversion script**: `convert_to_sqlite.py` (in parent directory)
- **Project plan**: `project bb.txt` (in parent directory)

---

**You're all set!** Run `flutter run` and start reading the Bible.
