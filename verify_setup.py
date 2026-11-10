"""
Verification script to check if all files are in place
Run this to verify the Simple Bible app setup is complete
"""

import os
import sys
import sqlite3
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

def check_file(path, description):
    """Check if a file exists and return status"""
    exists = os.path.exists(path)
    status = "✅" if exists else "❌"
    size = ""
    if exists and os.path.isfile(path):
        size_bytes = os.path.getsize(path)
        if size_bytes > 1024 * 1024:
            size = f" ({size_bytes / (1024 * 1024):.1f} MB)"
        elif size_bytes > 1024:
            size = f" ({size_bytes / 1024:.1f} KB)"
        else:
            size = f" ({size_bytes} bytes)"
    print(f"{status} {description}: {path}{size}")
    return exists

def verify_database(db_path):
    """Verify database structure and content"""
    if not os.path.exists(db_path):
        print("❌ Database not found")
        return False

    print("\n📊 Verifying Database Structure...")
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Check tables
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = [row[0] for row in cursor.fetchall()]

        expected_tables = ['translations', 'books', 'verses', 'fts_verses', 'bookmarks']
        for table in expected_tables:
            if table in tables:
                print(f"  ✅ Table '{table}' exists")
            else:
                print(f"  ❌ Table '{table}' missing")

        # Check counts
        cursor.execute("SELECT COUNT(*) FROM verses")
        verse_count = cursor.fetchone()[0]
        print(f"  📖 Total verses: {verse_count:,}")

        cursor.execute("SELECT COUNT(*) FROM books")
        book_count = cursor.fetchone()[0]
        print(f"  📚 Total books: {book_count}")

        cursor.execute("SELECT COUNT(*) FROM translations")
        translation_count = cursor.fetchone()[0]
        print(f"  🌍 Translations: {translation_count}")

        # Sample verse
        cursor.execute("""
            SELECT b.name_en, v.chapter, v.verse, v.text
            FROM verses v
            JOIN books b ON v.book_num = b.book_num
            WHERE v.verse_uid = 43003016
        """)
        sample = cursor.fetchone()
        if sample:
            print(f"\n  📝 Sample verse (John 3:16):")
            print(f"     {sample[0]} {sample[1]}:{sample[2]}")
            print(f"     {sample[3][:80]}...")

        conn.close()
        return True
    except Exception as e:
        print(f"  ❌ Database error: {e}")
        return False

def main():
    print("=" * 60)
    print("Simple Bible App - Setup Verification")
    print("=" * 60)

    base_dir = Path(__file__).parent
    project_dir = base_dir / "simple_bible"

    all_good = True

    # Check Python script
    print("\n🐍 Python Scripts:")
    all_good &= check_file(base_dir / "convert_to_sqlite.py", "Database converter")

    # Check documentation
    print("\n📄 Documentation:")
    all_good &= check_file(base_dir / "project bb.txt", "Original requirements")
    all_good &= check_file(base_dir / "PROJECT_SETUP.md", "Setup guide")
    all_good &= check_file(base_dir / "QUICK_START.md", "Quick start")
    all_good &= check_file(base_dir / "FEATURES_IMPLEMENTED.md", "Feature list")
    all_good &= check_file(base_dir / "IMPLEMENTATION_COMPLETE.md", "Completion report")

    # Check Flutter project structure
    print("\n📱 Flutter Project Structure:")
    all_good &= check_file(project_dir, "Project directory")
    all_good &= check_file(project_dir / "pubspec.yaml", "Package config")
    all_good &= check_file(project_dir / "lib" / "main.dart", "Main entry point")
    all_good &= check_file(project_dir / "README.md", "Project README")

    # Check models
    print("\n🗂 Models:")
    all_good &= check_file(project_dir / "lib" / "models" / "verse.dart", "Verse model")
    all_good &= check_file(project_dir / "lib" / "models" / "book.dart", "Book model")

    # Check services
    print("\n⚙️ Services:")
    all_good &= check_file(project_dir / "lib" / "services" / "database_service.dart", "Database service")
    all_good &= check_file(project_dir / "lib" / "services" / "settings_service.dart", "Settings service")

    # Check screens
    print("\n🖥 Screens:")
    all_good &= check_file(project_dir / "lib" / "screens" / "home_screen.dart", "Home screen")
    all_good &= check_file(project_dir / "lib" / "screens" / "reader_screen.dart", "Reader screen")
    all_good &= check_file(project_dir / "lib" / "screens" / "search_screen.dart", "Search screen")
    all_good &= check_file(project_dir / "lib" / "screens" / "bookmarks_screen.dart", "Bookmarks screen")
    all_good &= check_file(project_dir / "lib" / "screens" / "settings_screen.dart", "Settings screen")

    # Check widgets
    print("\n🧩 Widgets:")
    all_good &= check_file(project_dir / "lib" / "widgets" / "book_chapter_picker.dart", "Book/Chapter picker")

    # Check assets
    print("\n💾 Assets:")
    db_exists = check_file(project_dir / "assets" / "bible.db", "SQLite database")
    all_good &= db_exists
    all_good &= check_file(project_dir / "assets" / "nkjv.json", "Source JSON data")

    # Verify database if it exists
    if db_exists:
        all_good &= verify_database(project_dir / "assets" / "bible.db")

    # Final summary
    print("\n" + "=" * 60)
    if all_good:
        print("✅ ALL CHECKS PASSED!")
        print("\nYour Simple Bible app is ready to run!")
        print("\nNext steps:")
        print("1. cd simple_bible")
        print("2. flutter pub get")
        print("3. flutter run")
    else:
        print("⚠️ SOME CHECKS FAILED")
        print("\nPlease review the missing files above.")
    print("=" * 60)

if __name__ == '__main__':
    main()
