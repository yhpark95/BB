"""
Replaces the NKJV translation in assets/bible.db with KJV data.
Format: Genesis 1:1\tIn the beginning God created...
"""

import sqlite3
import re
import os

BOOK_MAP = {
    'Genesis': '01', 'Exodus': '02', 'Leviticus': '03', 'Numbers': '04',
    'Deuteronomy': '05', 'Joshua': '06', 'Judges': '07', 'Ruth': '08',
    '1 Samuel': '09', '2 Samuel': '10', '1 Kings': '11', '2 Kings': '12',
    '1 Chronicles': '13', '2 Chronicles': '14', 'Ezra': '15', 'Nehemiah': '16',
    'Esther': '17', 'Job': '18', 'Psalm': '19', 'Proverbs': '20',
    'Ecclesiastes': '21', 'Song of Solomon': '22', 'Isaiah': '23',
    'Jeremiah': '24', 'Lamentations': '25', 'Ezekiel': '26', 'Daniel': '27',
    'Hosea': '28', 'Joel': '29', 'Amos': '30', 'Obadiah': '31',
    'Jonah': '32', 'Micah': '33', 'Nahum': '34', 'Habakkuk': '35',
    'Zephaniah': '36', 'Haggai': '37', 'Zechariah': '38', 'Malachi': '39',
    'Matthew': '40', 'Mark': '41', 'Luke': '42', 'John': '43',
    'Acts': '44', 'Romans': '45', '1 Corinthians': '46', '2 Corinthians': '47',
    'Galatians': '48', 'Ephesians': '49', 'Philippians': '50', 'Colossians': '51',
    '1 Thessalonians': '52', '2 Thessalonians': '53', '1 Timothy': '54',
    '2 Timothy': '55', 'Titus': '56', 'Philemon': '57', 'Hebrews': '58',
    'James': '59', '1 Peter': '60', '2 Peter': '61', '1 John': '62',
    '2 John': '63', '3 John': '64', 'Jude': '65', 'Revelation': '66',
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, '..', 'assets', 'bible.db')
TXT_PATH = r'C:\Users\yhpark\Downloads\KJV.txt'

# ── 1. Parse txt ──────────────────────────────────────────────────────────────
# Build a pattern that matches any known book name at start of line
book_names_sorted = sorted(BOOK_MAP.keys(), key=len, reverse=True)  # longest first
book_pattern = '|'.join(re.escape(b) for b in book_names_sorted)
pattern = re.compile(rf'^({book_pattern})\s+(\d+):(\d+)\t(.+)$')

verses = []
errors = 0

with open(TXT_PATH, 'r', encoding='utf-8') as f:
    for line_num, line in enumerate(f, 1):
        line = line.strip()
        if not line or line_num <= 2:  # skip header lines
            continue
        m = pattern.match(line)
        if not m:
            print(f'  [SKIP] line {line_num}: {line[:60]}')
            errors += 1
            continue
        book_name, ch, vs, text = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4).strip()
        book_num = BOOK_MAP[book_name]
        book_int = int(book_num)
        verse_uid = book_int * 1000000 + ch * 1000 + vs
        verses.append((verse_uid, book_num, ch, vs, text))

print(f'Parsed {len(verses):,} verses  ({errors} skipped)')

# ── 2. Update DB ──────────────────────────────────────────────────────────────
conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

cur.execute("SELECT id FROM translations WHERE code = 'NKJV'")
row = cur.fetchone()
if not row:
    print('ERROR: NKJV translation row not found')
    conn.close()
    raise SystemExit(1)
translation_id = row[0]
print(f'NKJV translation_id = {translation_id}')

cur.execute("DELETE FROM verses WHERE translation_id = ?", (translation_id,))
print(f'Deleted {cur.rowcount:,} old NKJV verses')

rows = [(v[0], translation_id, v[1], v[2], v[3], v[4]) for v in verses]
cur.executemany(
    "INSERT INTO verses (verse_uid, translation_id, book_num, chapter, verse, text) VALUES (?,?,?,?,?,?)",
    rows,
)
print(f'Inserted {len(rows):,} KJV verses')

# Update translation metadata
cur.execute(
    "UPDATE translations SET code='KJV', name='King James Version' WHERE id=?",
    (translation_id,),
)

conn.commit()

# ── 3. Rebuild FTS5 ───────────────────────────────────────────────────────────
print('Rebuilding FTS5 index...')
cur.execute("INSERT INTO fts_verses(fts_verses) VALUES('rebuild')")
conn.commit()
print('FTS5 rebuilt')

conn.close()
print('Done')
