"""
Convert Bible JSON data to SQLite database with verse_uid system
Following the project specifications from 'project bb.txt'
"""

import json
import sqlite3
import re
import sys
from pathlib import Path

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

# Book name mapping: English to verse_uid book number (01-66)
BOOK_MAPPING = {
    # Old Testament (01-39)
    'Genesis': '01', 'Exodus': '02', 'Leviticus': '03', 'Numbers': '04', 'Deuteronomy': '05',
    'Joshua': '06', 'Judges': '07', 'Ruth': '08', '1 Samuel': '09', '2 Samuel': '10',
    '1 Kings': '11', '2 Kings': '12', '1 Chronicles': '13', '2 Chronicles': '14',
    'Ezra': '15', 'Nehemiah': '16', 'Esther': '17', 'Job': '18', 'Psalm': '19', 'Psalms': '19',
    'Proverbs': '20', 'Ecclesiastes': '21', 'Song of Solomon': '22', 'Isaiah': '23',
    'Jeremiah': '24', 'Lamentations': '25', 'Ezekiel': '26', 'Daniel': '27',
    'Hosea': '28', 'Joel': '29', 'Amos': '30', 'Obadiah': '31', 'Jonah': '32',
    'Micah': '33', 'Nahum': '34', 'Habakkuk': '35', 'Zephaniah': '36', 'Haggai': '37',
    'Zechariah': '38', 'Malachi': '39',
    # New Testament (40-66)
    'Matthew': '40', 'Mark': '41', 'Luke': '42', 'John': '43', 'Acts': '44',
    'Romans': '45', '1 Corinthians': '46', '2 Corinthians': '47', 'Galatians': '48',
    'Ephesians': '49', 'Philippians': '50', 'Colossians': '51', '1 Thessalonians': '52',
    '2 Thessalonians': '53', '1 Timothy': '54', '2 Timothy': '55', 'Titus': '56',
    'Philemon': '57', 'Hebrews': '58', 'James': '59', '1 Peter': '60', '2 Peter': '61',
    '1 John': '62', '2 John': '63', '3 John': '64', 'Jude': '65', 'Revelation': '66'
}

# Korean book names for the books table
BOOK_NAMES_KO = {
    '01': '창세기', '02': '출애굽기', '03': '레위기', '04': '민수기', '05': '신명기',
    '06': '여호수아', '07': '사사기', '08': '룻기', '09': '사무엘상', '10': '사무엘하',
    '11': '열왕기상', '12': '열왕기하', '13': '역대상', '14': '역대하',
    '15': '에스라', '16': '느헤미야', '17': '에스더', '18': '욥기', '19': '시편',
    '20': '잠언', '21': '전도서', '22': '아가', '23': '이사야',
    '24': '예레미야', '25': '예레미야애가', '26': '에스겔', '27': '다니엘',
    '28': '호세아', '29': '요엘', '30': '아모스', '31': '오바댜', '32': '요나',
    '33': '미가', '34': '나훔', '35': '하박국', '36': '스바냐', '37': '학개',
    '38': '스가랴', '39': '말라기',
    '40': '마태복음', '41': '마가복음', '42': '누가복음', '43': '요한복음', '44': '사도행전',
    '45': '로마서', '46': '고린도전서', '47': '고린도후서', '48': '갈라디아서',
    '49': '에베소서', '50': '빌립보서', '51': '골로새서', '52': '데살로니가전서',
    '53': '데살로니가후서', '54': '디모데전서', '55': '디모데후서', '56': '디도서',
    '57': '빌레몬서', '58': '히브리서', '59': '야고보서', '60': '베드로전서', '61': '베드로후서',
    '62': '요한1서', '63': '요한2서', '64': '요한3서', '65': '유다서', '66': '요한계시록'
}

def parse_reference(ref_string):
    """
    Parse reference string like 'nkjv:Genesis:1:1'
    Returns: (book_name, chapter, verse) or None if invalid
    """
    parts = ref_string.split(':')
    if len(parts) >= 4:
        # Format: nkjv:Book:Chapter:Verse
        book = parts[1]
        chapter = int(parts[2])
        verse = int(parts[3])
        return (book, chapter, verse)
    return None

def generate_verse_uid(book_name, chapter, verse):
    """
    Generate verse_uid in format: BBCCCVVV
    Example: Genesis 1:1 -> 01001001
    """
    book_num = BOOK_MAPPING.get(book_name)
    if not book_num:
        return None

    # Format: BB (book) + CCC (chapter) + VVV (verse)
    verse_uid = int(f"{book_num}{chapter:03d}{verse:03d}")
    return verse_uid

def clean_text(text):
    """
    Remove markup indicators from text (e.g., *p, *i, *s, *ld, *pn)
    """
    # Remove all *X markers
    cleaned = re.sub(r'\*[a-z]+', '', text)
    return cleaned

def create_database(db_path):
    """
    Create SQLite database with tables as specified in project requirements
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Table 1: translations - Bible translation information
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS translations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            language TEXT NOT NULL,
            display_order INTEGER DEFAULT 0
        )
    ''')

    # Table 2: books - 66 books of the Bible
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS books (
            book_num TEXT PRIMARY KEY,
            name_en TEXT NOT NULL,
            name_ko TEXT NOT NULL,
            abbr_en TEXT,
            abbr_ko TEXT,
            testament TEXT CHECK(testament IN ('OT', 'NT')),
            display_order INTEGER
        )
    ''')

    # Table 3: verses - Actual Bible text
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_uid INTEGER NOT NULL,
            translation_id INTEGER NOT NULL,
            book_num TEXT NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL,
            FOREIGN KEY (translation_id) REFERENCES translations(id),
            FOREIGN KEY (book_num) REFERENCES books(book_num)
        )
    ''')

    # Create indexes for fast lookup
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_verse_uid ON verses(verse_uid, translation_id)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_book_chapter ON verses(book_num, chapter, verse)')

    # Table 4: FTS5 virtual table for full-text search
    cursor.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS fts_verses USING fts5(
            verse_uid,
            translation_id,
            book_num,
            chapter,
            verse,
            text,
            content=verses,
            content_rowid=id
        )
    ''')

    # Triggers to keep FTS table in sync
    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS verses_ai AFTER INSERT ON verses BEGIN
            INSERT INTO fts_verses(rowid, verse_uid, translation_id, book_num, chapter, verse, text)
            VALUES (new.id, new.verse_uid, new.translation_id, new.book_num, new.chapter, new.verse, new.text);
        END
    ''')

    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS verses_ad AFTER DELETE ON verses BEGIN
            DELETE FROM fts_verses WHERE rowid = old.id;
        END
    ''')

    cursor.execute('''
        CREATE TRIGGER IF NOT EXISTS verses_au AFTER UPDATE ON verses BEGIN
            UPDATE fts_verses SET
                verse_uid = new.verse_uid,
                translation_id = new.translation_id,
                book_num = new.book_num,
                chapter = new.chapter,
                verse = new.verse,
                text = new.text
            WHERE rowid = new.id;
        END
    ''')

    # Table 5: bookmarks - User saved verses
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            verse_uid INTEGER NOT NULL,
            translation_id INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (translation_id) REFERENCES translations(id)
        )
    ''')

    conn.commit()
    return conn

def populate_books_table(conn):
    """
    Populate the books table with all 66 books
    """
    cursor = conn.cursor()

    for book_en, book_num in BOOK_MAPPING.items():
        testament = 'OT' if int(book_num) <= 39 else 'NT'
        book_name_ko = BOOK_NAMES_KO.get(book_num, book_en)

        cursor.execute('''
            INSERT OR IGNORE INTO books (book_num, name_en, name_ko, testament, display_order)
            VALUES (?, ?, ?, ?, ?)
        ''', (book_num, book_en, book_name_ko, testament, int(book_num)))

    conn.commit()
    print(f"✓ Populated books table with 66 books")

def import_json_data(conn, json_file, translation_code='NKJV'):
    """
    Import Bible data from JSON file into the database
    """
    # Add translation if not exists
    cursor = conn.cursor()
    cursor.execute('''
        INSERT OR IGNORE INTO translations (code, name, language, display_order)
        VALUES (?, ?, ?, ?)
    ''', (translation_code, 'New King James Version', 'en', 1))
    conn.commit()

    # Get translation_id
    cursor.execute('SELECT id FROM translations WHERE code = ?', (translation_code,))
    translation_id = cursor.fetchone()[0]

    # Load JSON data
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    print(f"Loading {len(data)} entries from {json_file}...")

    verse_count = 0
    skipped_count = 0

    for entry in data:
        # Skip headings (they have 'h' field)
        if 'h' in entry:
            skipped_count += 1
            continue

        ref = entry.get('r')
        text = entry.get('t')

        if not ref or not text:
            skipped_count += 1
            continue

        parsed = parse_reference(ref)
        if not parsed:
            skipped_count += 1
            continue

        book_name, chapter, verse = parsed

        # Skip verse 0 (chapter headings)
        if verse == 0:
            skipped_count += 1
            continue

        verse_uid = generate_verse_uid(book_name, chapter, verse)
        if not verse_uid:
            print(f"Warning: Could not generate verse_uid for {ref}")
            skipped_count += 1
            continue

        book_num = BOOK_MAPPING[book_name]
        clean_text_content = clean_text(text)

        cursor.execute('''
            INSERT INTO verses (verse_uid, translation_id, book_num, chapter, verse, text)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (verse_uid, translation_id, book_num, chapter, verse, clean_text_content))

        verse_count += 1

    conn.commit()
    print(f"✓ Imported {verse_count} verses")
    print(f"✓ Skipped {skipped_count} entries (headings and metadata)")

def main():
    print("=" * 60)
    print("Bible Database Converter")
    print("Converting JSON to SQLite with verse_uid system")
    print("=" * 60)

    db_path = 'bible.db'
    json_file = 'nkjv.json'

    # Check if JSON file exists
    if not Path(json_file).exists():
        print(f"Error: {json_file} not found!")
        return

    # Create database
    print(f"\n1. Creating database: {db_path}")
    conn = create_database(db_path)
    print("✓ Database schema created")

    # Populate books table
    print("\n2. Populating books table...")
    populate_books_table(conn)

    # Import JSON data
    print("\n3. Importing NKJV data...")
    import_json_data(conn, json_file)

    # Verify data
    print("\n4. Verifying database...")
    cursor = conn.cursor()

    cursor.execute('SELECT COUNT(*) FROM verses')
    verse_count = cursor.fetchone()[0]
    print(f"✓ Total verses in database: {verse_count}")

    cursor.execute('SELECT COUNT(*) FROM books')
    book_count = cursor.fetchone()[0]
    print(f"✓ Total books in database: {book_count}")

    cursor.execute('SELECT COUNT(*) FROM translations')
    translation_count = cursor.fetchone()[0]
    print(f"✓ Total translations in database: {translation_count}")

    # Show sample verse
    cursor.execute('''
        SELECT v.verse_uid, b.name_en, v.chapter, v.verse, v.text
        FROM verses v
        JOIN books b ON v.book_num = b.book_num
        WHERE v.verse_uid = 43003016
    ''')
    sample = cursor.fetchone()
    if sample:
        print(f"\n5. Sample verse (John 3:16):")
        print(f"   verse_uid: {sample[0]}")
        print(f"   Reference: {sample[1]} {sample[2]}:{sample[3]}")
        print(f"   Text: {sample[4]}")

    conn.close()
    print("\n" + "=" * 60)
    print("✓ Database creation completed successfully!")
    print(f"✓ Database file: {db_path}")
    print("=" * 60)

if __name__ == '__main__':
    main()
