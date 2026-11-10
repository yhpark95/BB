"""Add name_fr column to books table with all 66 French book names."""

import sqlite3
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(SCRIPT_DIR, '..', 'assets', 'bible.db')

FRENCH_NAMES = {
    '01': 'Genèse', '02': 'Exode', '03': 'Lévitique', '04': 'Nombres',
    '05': 'Deutéronome', '06': 'Josué', '07': 'Juges', '08': 'Ruth',
    '09': '1 Samuel', '10': '2 Samuel', '11': '1 Rois', '12': '2 Rois',
    '13': '1 Chroniques', '14': '2 Chroniques', '15': 'Esdras', '16': 'Néhémie',
    '17': 'Esther', '18': 'Job', '19': 'Psaumes', '20': 'Proverbes',
    '21': 'Ecclésiaste', '22': 'Cantique des Cantiques', '23': 'Ésaïe',
    '24': 'Jérémie', '25': 'Lamentations', '26': 'Ézéchiel', '27': 'Daniel',
    '28': 'Osée', '29': 'Joël', '30': 'Amos', '31': 'Abdias', '32': 'Jonas',
    '33': 'Michée', '34': 'Nahoum', '35': 'Habacuc', '36': 'Sophonie',
    '37': 'Aggée', '38': 'Zacharie', '39': 'Malachie', '40': 'Matthieu',
    '41': 'Marc', '42': 'Luc', '43': 'Jean', '44': 'Actes', '45': 'Romains',
    '46': '1 Corinthiens', '47': '2 Corinthiens', '48': 'Galates',
    '49': 'Éphésiens', '50': 'Philippiens', '51': 'Colossiens',
    '52': '1 Thessaloniciens', '53': '2 Thessaloniciens', '54': '1 Timothée',
    '55': '2 Timothée', '56': 'Tite', '57': 'Philémon', '58': 'Hébreux',
    '59': 'Jacques', '60': '1 Pierre', '61': '2 Pierre', '62': '1 Jean',
    '63': '2 Jean', '64': '3 Jean', '65': 'Jude', '66': 'Apocalypse',
}

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()

cols = [row[1] for row in cur.execute('PRAGMA table_info(books)').fetchall()]
if 'name_fr' not in cols:
    cur.execute('ALTER TABLE books ADD COLUMN name_fr TEXT')
    print('Added name_fr column')
else:
    print('name_fr column already exists')

updated = 0
for book_num, name_fr in FRENCH_NAMES.items():
    cur.execute('UPDATE books SET name_fr=? WHERE book_num=?', (name_fr, book_num))
    updated += cur.rowcount

conn.commit()
conn.close()
print(f'Updated {updated} books with French names')
print('Done')
