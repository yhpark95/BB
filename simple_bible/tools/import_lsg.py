"""
Adds Louis Segond 1910 (French) as a new translation in assets/bible.db.
Source: Sg1910_v11n.csv (tab-separated, with <w strong="..."> markup)
"""

import sqlite3
import csv
import re
import os

BOOK_MAP = {
    'Gen': '01', 'Exod': '02', 'Lev': '03', 'Num': '04', 'Deut': '05',
    'Josh': '06', 'Judg': '07', 'Ruth': '08', '1Sam': '09', '2Sam': '10',
    '1Kgs': '11', '2Kgs': '12', '1Chr': '13', '2Chr': '14', 'Ezra': '15',
    'Neh': '16', 'Esth': '17', 'Job': '18', 'Ps': '19', 'Prov': '20',
    'Eccl': '21', 'Song': '22', 'Isa': '23', 'Jer': '24', 'Lam': '25',
    'Ezek': '26', 'Dan': '27', 'Hos': '28', 'Joel': '29', 'Amos': '30',
    'Obad': '31', 'Jonah': '32', 'Mic': '33', 'Nah': '34', 'Hab': '35',
    'Zeph': '36', 'Hag': '37', 'Zech': '38', 'Mal': '39', 'Matt': '40',
    'Mark': '41', 'Luke': '42', 'John': '43', 'Acts': '44', 'Rom': '45',
    '1Cor': '46', '2Cor': '47', 'Gal': '48', 'Eph': '49', 'Phil': '50',
    'Col': '51', '1Thess': '52', '2Thess': '53', '1Tim': '54', '2Tim': '55',
    'Titus': '56', 'Phlm': '57', 'Heb': '58', 'Jas': '59', '1Pet': '60',
    '2Pet': '61', '1John': '62', '2John': '63', '3John': '64', 'Jude': '65',
    'Rev': '66',
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, '..', 'assets', 'bible.db')
CSV_PATH = r'C:\Users\yhpark\Downloads\Sg1910-csv_v11n\Sg1910_v11n.csv'

def strip_markup(text):
    text = re.sub(r'<[^>]+>', '', text)
    return re.sub(r' +', ' ', text).strip()

# ── 1. Parse CSV ───────────────────────────────────────────────────────────────
verses = []
errors = 0

with open(CSV_PATH, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter='\t')
    for row in reader:
        book_id = row['book_id'].strip()
        book_num = BOOK_MAP.get(book_id)
        if not book_num:
            print(f'  [UNKNOWN] book_id: {book_id}')
            errors += 1
            continue
        ch = int(row['num_chapter'])
        vs = int(row['num_verse'])
        text = strip_markup(row['text'])
        book_int = int(book_num)
        verse_uid = book_int * 1000000 + ch * 1000 + vs
        verses.append((verse_uid, book_num, ch, vs, text))

print(f'Parsed {len(verses):,} verses  ({errors} skipped)')

# ── 2. Insert into DB ─────────────────────────────────────────────────────────
conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

# Remove existing LSG if re-running
cur.execute("SELECT id FROM translations WHERE code='LSG'")
existing = cur.fetchone()
if existing:
    cur.execute("DELETE FROM verses WHERE translation_id=?", (existing[0],))
    cur.execute("DELETE FROM translations WHERE id=?", (existing[0],))
    print(f'Removed existing LSG translation (id={existing[0]})')

cur.execute(
    "INSERT INTO translations (code, name, language, display_order) VALUES (?,?,?,?)",
    ('LSG', 'Louis Segond 1910', 'fr', 3),
)
translation_id = cur.lastrowid
print(f'Created LSG translation (id={translation_id})')

rows = [(v[0], translation_id, v[1], v[2], v[3], v[4]) for v in verses]
cur.executemany(
    "INSERT INTO verses (verse_uid, translation_id, book_num, chapter, verse, text) VALUES (?,?,?,?,?,?)",
    rows,
)
print(f'Inserted {len(rows):,} LSG verses')

conn.commit()

# ── 3. Rebuild FTS5 ───────────────────────────────────────────────────────────
print('Rebuilding FTS5 index...')
cur.execute("INSERT INTO fts_verses(fts_verses) VALUES('rebuild')")
conn.commit()
print('FTS5 rebuilt')

conn.close()
print('Done')
