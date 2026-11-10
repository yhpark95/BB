"""
Replaces the KHG (개역한글) translation in assets/bible.db
with data from the provided .txt file.

Format: 창1:1 태초에 하나님이 천지를 창조하시니라
"""

import sqlite3
import re
import shutil
import sys
import os

BOOK_MAP = {
    '창': '01', '출': '02', '레': '03', '민': '04', '신': '05',
    '수': '06', '삿': '07', '룻': '08', '삼상': '09', '삼하': '10',
    '왕상': '11', '왕하': '12', '대상': '13', '대하': '14', '스': '15',
    '느': '16', '에': '17', '욥': '18', '시': '19', '잠': '20',
    '전': '21', '아': '22', '사': '23', '렘': '24', '애': '25',
    '겔': '26', '단': '27', '호': '28', '욜': '29', '암': '30',
    '옵': '31', '욘': '32', '미': '33', '나': '34', '합': '35',
    '습': '36', '학': '37', '슥': '38', '말': '39', '마': '40',
    '막': '41', '눅': '42', '요': '43', '행': '44', '롬': '45',
    '고전': '46', '고후': '47', '갈': '48', '엡': '49', '빌': '50',
    '골': '51', '살전': '52', '살후': '53', '딤전': '54', '딤후': '55',
    '딛': '56', '몬': '57', '히': '58', '약': '59', '벧전': '60',
    '벧후': '61', '요일': '62', '요이': '63', '요삼': '64', '유': '65',
    '계': '66',
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, '..', 'assets', 'bible.db')
TXT_PATH = r'C:\Users\yhpark\Downloads\개역한글판성경.txt'

# ── 1. Backup ─────────────────────────────────────────────────────────────────
backup = DB_PATH + '.backup'
shutil.copy2(DB_PATH, backup)
print(f'Backed up → {os.path.basename(backup)}')

# ── 2. Parse txt ──────────────────────────────────────────────────────────────
pattern = re.compile(r'^([가-힣]+)(\d+):(\d+)\s+(.+)$')
verses = []
errors = 0

with open(TXT_PATH, 'r', encoding='cp949') as f:
    for line_num, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        m = pattern.match(line)
        if not m:
            print(f'  [SKIP] line {line_num}: {line[:60]}')
            errors += 1
            continue
        abbr, ch, vs, text = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4).strip()
        book_num = BOOK_MAP.get(abbr)
        if not book_num:
            print(f'  [UNKNOWN ABBR] line {line_num}: {abbr}')
            errors += 1
            continue
        book_int = int(book_num)
        verse_uid = book_int * 1000000 + ch * 1000 + vs
        verses.append((verse_uid, book_num, ch, vs, text))

print(f'Parsed {len(verses):,} verses  ({errors} skipped)')

# ── 3. Update DB ──────────────────────────────────────────────────────────────
conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

cur.execute("SELECT id FROM translations WHERE code = 'KHG'")
row = cur.fetchone()
if not row:
    print('ERROR: KHG translation row not found in translations table')
    conn.close()
    sys.exit(1)
translation_id = row[0]
print(f'KHG translation_id = {translation_id}')

cur.execute("DELETE FROM verses WHERE translation_id = ?", (translation_id,))
print(f'Deleted {cur.rowcount:,} old KHG verses')

rows = [(v[0], translation_id, v[1], v[2], v[3], v[4]) for v in verses]
cur.executemany(
    "INSERT INTO verses (verse_uid, translation_id, book_num, chapter, verse, text) VALUES (?,?,?,?,?,?)",
    rows,
)
print(f'Inserted {len(rows):,} new verses')

conn.commit()

# ── 4. Rebuild FTS5 ───────────────────────────────────────────────────────────
print('Rebuilding FTS5 index...')
cur.execute("INSERT INTO fts_verses(fts_verses) VALUES('rebuild')")
conn.commit()
print('FTS5 rebuilt')

conn.close()
print('Done ✓')
