const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');

// Korean abbreviation → book_num (01-66)
const ABBR_TO_BOOK_NUM = {
  '창': '01', '출': '02', '레': '03', '민': '04', '신': '05',
  '수': '06', '삿': '07', '룻': '08', '삼상': '09', '삼하': '10',
  '왕상': '11', '왕하': '12', '대상': '13', '대하': '14', '스': '15',
  '느': '16', '에': '17', '욥': '18', '시': '19', '잠': '20',
  '전': '21', '아': '22', '사': '23', '렘': '24', '애': '25',
  '겔': '26', '단': '27', '호': '28', '욜': '29', '암': '30',
  '옵': '31', '욘': '32', '미': '33', '나': '34', '합': '35',
  '습': '36', '학': '37', '슥': '38', '말': '39',
  '마': '40', '막': '41', '눅': '42', '요': '43', '행': '44',
  '롬': '45', '고전': '46', '고후': '47', '갈': '48', '엡': '49',
  '빌': '50', '골': '51', '살전': '52', '살후': '53', '딤전': '54',
  '딤후': '55', '딛': '56', '몬': '57', '히': '58', '약': '59',
  '벧전': '60', '벧후': '61', '요일': '62', '요이': '63', '요삼': '64',
  '유': '65', '계': '66',
};

// Sort longest-first so multi-char abbrs match before single-char ones
const ABBRS_SORTED = Object.keys(ABBR_TO_BOOK_NUM).sort((a, b) => b.length - a.length);

function parseKey(key) {
  for (const abbr of ABBRS_SORTED) {
    if (key.startsWith(abbr)) {
      const rest = key.slice(abbr.length);
      const parts = rest.split(':');
      if (parts.length === 2) {
        const chapter = parseInt(parts[0], 10);
        const verse = parseInt(parts[1], 10);
        if (!isNaN(chapter) && !isNaN(verse)) {
          return { bookNum: ABBR_TO_BOOK_NUM[abbr], chapter, verse };
        }
      }
    }
  }
  return null;
}

function verseUid(bookNum, chapter, verse) {
  return parseInt(`${bookNum}${String(chapter).padStart(3, '0')}${String(verse).padStart(3, '0')}`, 10);
}

const KO_NAMES = {
  '01': '창세기', '02': '출애굽기', '03': '레위기', '04': '민수기', '05': '신명기',
  '06': '여호수아', '07': '사사기', '08': '룻기', '09': '사무엘상', '10': '사무엘하',
  '11': '열왕기상', '12': '열왕기하', '13': '역대상', '14': '역대하', '15': '에스라',
  '16': '느헤미야', '17': '에스더', '18': '욥기', '19': '시편', '20': '잠언',
  '21': '전도서', '22': '아가', '23': '이사야', '24': '예레미야', '25': '예레미야애가',
  '26': '에스겔', '27': '다니엘', '28': '호세아', '29': '요엘', '30': '아모스',
  '31': '오바댜', '32': '요나', '33': '미가', '34': '나훔', '35': '하박국',
  '36': '스바냐', '37': '학개', '38': '스가랴', '39': '말라기',
  '40': '마태복음', '41': '마가복음', '42': '누가복음', '43': '요한복음', '44': '사도행전',
  '45': '로마서', '46': '고린도전서', '47': '고린도후서', '48': '갈라디아서', '49': '에베소서',
  '50': '빌립보서', '51': '골로새서', '52': '데살로니가전서', '53': '데살로니가후서',
  '54': '디모데전서', '55': '디모데후서', '56': '디도서', '57': '빌레몬서', '58': '히브리서',
  '59': '야고보서', '60': '베드로전서', '61': '베드로후서', '62': '요한1서', '63': '요한2서',
  '64': '요한3서', '65': '유다서', '66': '요한계시록',
};

const dbPath = path.join(__dirname, 'simple_bible', 'assets', 'bible.db');
const jsonPath = path.join(__dirname, '개역한글.json');

console.log('Reading Korean Bible JSON...');
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
const entries = Object.entries(data);
console.log(`Loaded ${entries.length} entries`);

const db = new DatabaseSync(dbPath);

// Drop FTS5 triggers (we use LIKE search, not FTS5)
db.exec('DROP TRIGGER IF EXISTS verses_ai');
db.exec('DROP TRIGGER IF EXISTS verses_ad');
db.exec('DROP TRIGGER IF EXISTS verses_au');

// Add translation record
db.prepare(`INSERT OR IGNORE INTO translations (id, code, name, language, display_order) VALUES (2, 'KHG', '개역한글', 'ko', 2)`).run();

// Update Korean book names
const updateBook = db.prepare('UPDATE books SET name_ko = ? WHERE book_num = ?');
for (const [num, name] of Object.entries(KO_NAMES)) {
  updateBook.run(name, num);
}
console.log('Updated Korean book names');

// Insert all verses in one transaction
const insert = db.prepare(`
  INSERT OR IGNORE INTO verses (verse_uid, translation_id, book_num, chapter, verse, text)
  VALUES (?, 2, ?, ?, ?, ?)
`);

let inserted = 0, skipped = 0;

db.exec('BEGIN');
for (const [key, text] of entries) {
  const parsed = parseKey(key);
  if (!parsed) { skipped++; continue; }
  const { bookNum, chapter, verse } = parsed;
  insert.run(verseUid(bookNum, chapter, verse), bookNum, chapter, verse, text.trim());
  inserted++;
}
db.exec('COMMIT');

console.log(`Done! Inserted: ${inserted}, Skipped: ${skipped}`);
db.close();
