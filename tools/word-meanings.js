// What a tapped word means when it has no card of its own (三个, 去过, 在家): written out here once, for every such
// word in the course, into Resources/Data/word-meanings.json. The app used to join each character's first meaning
// at run time, which said 一天 was "as soon as + day" (the owner, 2 Nov 2026). Rules for the regular ones, OVER for
// the rest. `node tools/word-meanings.js` writes the file and prints what fell through to plain joining.
const fs = require('fs'), path = require('path');
const dataDir = path.join(__dirname, '../native/Bubu/Resources/Data');
const c = JSON.parse(fs.readFileSync(path.join(dataDir, 'course.json'), 'utf8'));
const OVER = require('./word-meanings-over.js');

// the plain sense of a character inside a longer word, where its card's first meaning is the wrong one
const BASE = { 一: 'one', 上: 'on', 下: 'under', 里: 'in', 家: 'home', 来: 'come', 去: 'go', 看: 'look', 想: 'want to', 要: 'want',
  会: 'can', 能: 'can', 只: 'only', 就: 'just', 有: 'have', 过: 'pass', 分: 'minute', 开: 'open', 走: 'walk', 坐: 'sit', 给: 'give',
  说: 'say', 打: 'hit', 对: 'right', 少: 'few', 多: 'many', 大: 'big', 小: 'small', 点: 'point', 放: 'put', 画: 'draw', 包: 'wrap',
  第: 'number', 地: 'ground', 得: '', 的: '', 了: '', 着: '', 吧: '', 人: 'person', 菜: 'dish', 前: 'before', 后: 'after', 刚: 'just',
  全: 'all', 我: 'I', 你: 'you', 他: 'he', 她: 'she', 您: 'you', 再: 'again', 更: 'more', 最: 'most', 太: 'too', 很: 'very', 真: 'really' };
const WORD = {};
for (const l of c.lessons) for (const w of l.words) if (!(w.hanzi in WORD)) WORD[w.hanzi] = w.short || w.en;
const clean = en => (en || '').replace(/\([^)]*\)?/g, ' ').replace(/\p{Script=Han}\S*/gu, ' ').split(/[,;:]/)[0].replace(/\s+/g, ' ').trim();
const sense = h => h in BASE ? BASE[h] : clean(WORD[h]);
const bare = s => s.replace(/^to /, '');

const DIGIT = { 零: 0, 一: 1, 二: 2, 两: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9 };
const UNIT = { 十: 10, 百: 100, 千: 1000, 万: 10000, 亿: 100000000 };
function number(s) {
  if (!s || !/^[零一二两三四五六七八九十百千万亿]+$/.test(s)) return null;
  let total = 0, part = 0, cur = 0;
  for (const ch of s) {
    if (ch in DIGIT) cur = DIGIT[ch];
    else { const u = UNIT[ch]; if (u >= 10000) { total = (total + part + (cur || (part ? 0 : 1))) * u; part = 0; } else part += (cur || 1) * u; cur = 0; }
  }
  return total + part + cur;
}
// singular, plural; a classifier with nothing to count in English keeps a note in brackets
const M = { 天: 'day', 年: 'year', 分钟: 'minute', 秒: 'second', 度: 'degree', 杯: 'cup', 瓶: 'bottle', 盒: 'box', 碗: 'bowl', 壶: 'pot', 份: 'portion',
  次: 'time', 遍: 'time', 句: 'sentence', 首: 'song', 幅: 'painting', 篇: 'piece of writing', 间: 'room', 种: 'kind', 类: 'kind', 套: 'set', 双: 'pair',
  楼: 'floor', 节: 'lesson', 步: 'step', 片: 'slice', 串: 'string', 段: 'section', 页: 'page', 倍: 'times', 声: 'sound', 块: 'pound', 百块: 'hundred pounds',
  户: 'household', 元: 'yuan', 圈: 'lap', 叠: 'stack', 周: 'week', 星期: 'week', 小时: 'hour', 岁: 'year old', 夜: 'night', 晚: 'night', 代: 'generation', 顿: 'meal', 课: 'lesson' };
const NOTE = { 个: '', 张: '(ticket, sheet…)', 本: '(book)', 件: '(item of clothing, matter)', 条: '(long thing)', 位: '(person, polite)', 名: '(person)',
  家: '(shop, family)', 座: '(mountain, building)', 所: '(school, hospital)', 根: '(thin thing)', 支: '(pen)', 只: '(animal, hand)', 道: '(dish, barrier)', 幢: '(building)',
  场: '(event)', 班: '(train, bus)', 棵: '(tree)', 盏: '(lamp)', 扇: '(door, window)', 门: '(subject, skill)' };
const plural = (n, s) => n === 1 ? s : s === 'year old' ? 'years old' : s === 'times' ? s : s === 'box' ? 'boxes' : s === 'piece of writing' ? 'pieces of writing' : s + 's';
const unitRe = [...Object.keys(M), ...Object.keys(NOTE)].sort((a, b) => b.length - a.length).join('|');
const MONTHS = [, 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const DAYS = { 一: 'Monday', 二: 'Tuesday', 三: 'Wednesday', 四: 'Thursday', 五: 'Friday', 六: 'Saturday', 天: 'Sunday', 日: 'Sunday' };
const nth = n => { const t = n % 100, e = n % 10; return n + (t > 10 && t < 14 ? 'th' : e === 1 ? 'st' : e === 2 ? 'nd' : e === 3 ? 'rd' : 'th'); };
const counted = (label, m, one, head) => {
  if (m in NOTE) return head ? `${label} ${head}` : NOTE[m] ? `${label} ${NOTE[m]}` : label;
  return `${label} ${plural(one ? 1 : 2, M[m])}${head ? ' of ' + head : ''}`;
};

function rule(w) {
  let x;
  if ((x = w.match(/^星期([一二三四五六天日])$/))) return DAYS[x[1]];
  // a date, a time, a month
  if ((x = w.match(/^([一二三四五六七八九十]+)月$/)) && number(x[1]) <= 12) return MONTHS[number(x[1])];
  if ((x = w.match(/^([一二三四五六七八九十]+)[号日]$/)) && number(x[1]) <= 31) return `the ${nth(number(x[1]))}`;
  if ((x = w.match(/^([一二两三四五六七八九十]+)点(半)?$/))) return x[2] ? `half past ${number(x[1])}` : `${number(x[1])} o'clock`;
  if (/^几点$/.test(w)) return 'what time';
  if (/^几号$/.test(w)) return 'what date';
  if (/^几月$/.test(w)) return 'which month';
  if (/^几岁$/.test(w)) return 'how old';
  // a bare number
  const n0 = number(w);
  if (n0 !== null) return /^[一二三四五六七八九零]{2,}$/.test(w) ? w.split('').map(d => DIGIT[d]).join(' ') : n0.toLocaleString('en-GB');
  // an ordinal
  if ((x = w.match(/^第([一二三四五六七八九十]+)(?:(个))?$/))) return ordinal(number(x[1]));
  const count = new RegExp(`^([零一二两三四五六七八九十百千万亿]+)(多|几|余)?(${unitRe})(.*)$`).exec(w);
  if (count) {
    const n = number(count[1]);
    if (n !== null) {
      const head = count[4] ? meaning(count[4]) : '';
      if (count[4] && !head) return null;
      const label = count[2] === '几' ? `${n} or so` : count[2] ? `over ${n.toLocaleString('en-GB')}` : n === 1 ? 'one' : n.toLocaleString('en-GB');
      return counted(label, count[3], n === 1 && !count[2], head);
    }
  }
  const few = new RegExp(`^(几|十几|几十|几百|好几|每|这|那|哪|半|前|同一|多|整)(个)?(${unitRe})(.*)$`).exec(w);
  if (few) {
    const L = { 几: 'a few', 十几: 'a dozen or so', 几十: 'dozens of', 几百: 'hundreds of', 好几: 'quite a few', 每: 'every', 这: 'this', 那: 'that', 哪: 'which', 半: 'half a', 前: 'the previous', 同一: 'the same', 多: 'many', 整: 'a whole' }[few[1]];
    const head = few[4] ? meaning(few[4]) : '';
    if (few[4] && !head) return null;
    const single = ['每', '这', '那', '哪', '半', '前', '同一', '整'].includes(few[1]);
    return counted(L, few[3], single, head);
  }
  if ((x = w.match(/^第([一二三四五六七八九十]+)(.+)$/))) {
    const rest = x[2] in M ? M[x[2]] : x[2] in NOTE ? NOTE[x[2]] : meaning(x[2]);
    return rest ? `${ordinal(number(x[1]))} ${rest}` : ordinal(number(x[1]));
  }
  if ((x = w.match(/^([上下])个?(月|星期|周)$/))) return `${x[1] === '上' ? 'last' : 'next'} ${x[2] === '月' ? 'month' : 'week'}`;
  // a word doubled: 看看, 想一想
  if ((x = w.match(/^(.)一?\1$/)) && WORD[x[1]] && /^to /.test(clean(WORD[x[1]]))) return `${bare(clean(WORD[x[1]]))} a bit`;
  // little words that lead
  const lead = { 不: 'not', 没: "didn't", 很: 'very', 太: 'too', 真: 'really', 更: 'more', 最: 'most', 别: "don't", 刚: 'just', 常: 'often', 我: 'I', 你: 'you', 他: 'he', 她: 'she', 想: 'want to', 会: 'can', 能: 'can', 要: 'need to', 只: 'only', 还: 'also', 也: 'also', 都: 'all', 先: 'first', 再: 'again', 就: 'just' }[w[0]];
  if (lead && w.length > 1) {
    const rest = w.slice(1), r = rest in WORD || w.length === 2 ? sense(rest) : meaning(rest);
    if (r) {
      const v = bare(r);
      if (w[0] === '不' && rest in WORD && /^to /.test(clean(WORD[rest]))) return `don't ${v}`;
      if (w[0] === '没' && !(rest in WORD && /^to /.test(clean(WORD[rest])))) return `no ${v}`;
      if (w[0] === '再' || w[0] === '先') return `${v} ${w[0] === '再' ? 'again' : 'first'}`;
      if ('我你他她'.includes(w[0])) { if (/family|home/.test(v)) return { 我: 'my home', 你: 'your home', 他: 'his home', 她: 'her home' }[w[0]]; return `${lead} ${v}`; }
      return `${lead} ${v}`;
    }
  }
  // little words that follow
  if ((x = w.match(/^(.+)([里上])$/)) && (x[1] in WORD)) { const n = clean(WORD[x[1]]); if (n && !/^to /.test(n)) return `${x[2] === '里' ? 'in' : 'on'} the ${n}`; }
  if ((x = w.match(/^(.+?)(过|着|了|得|到|完|给|掉|进|回|起|出|下来|上去|下去|起来|出来|进来|回来|来)$/)) && (x[1] in WORD)) {
    const v = clean(WORD[x[1]]);
    if (v) {
      const s = bare(v);
      switch (x[2]) {
        case '过': return `have done: ${s}`;
        case '着': return `${s}, still going`;
        case '了': return `${s} (done)`;
        case '得': return /^to /.test(v) ? `${s} (how well)` : `so ${s} that`;
        case '到': return `${s} to`;
        case '完': return `finish: ${s}`;
        case '给': return `${s} to`;
        case '掉': return `${s} away`;
        case '进': return `${s} in`;
        case '回': return `${s} back`;
        case '起': return `${s} up`;
        case '出': return `${s} out`;
        case '下来': return `${s} down`;
        case '上去': return `${s} up`;
        case '下去': return `${s} down`;
        case '起来': return `${s} up`;
        case '出来': return `${s} out`;
        case '进来': return `${s} in`;
        case '回来': return `${s} back`;
        case '来': return `${s} here`;
      }
    }
  }
  return null;
}
const ordinal = n => ['', 'first', 'second', 'third', 'fourth', 'fifth'][n] || nth(n);
function meaning(w) {
  if (w in OVER) return OVER[w];
  if (w in WORD) return clean(WORD[w]);
  return rule(w);
}

const names = new Set(c.names), cards = new Set(Object.keys(WORD)), seen = new Set();
(function walk(o) {
  if (Array.isArray(o)) return o.forEach(walk);
  if (o && typeof o === 'object') return Object.values(o).forEach(walk);
  if (typeof o === 'string') { const m = o.match(/^([^|]+)\|([^|]+)\|(.+)$/); if (m) seen.add(m[1]); }
})(c);
const out = {}, fell = [];
for (const w of [...seen].filter(k => [...k].length > 1 && !cards.has(k) && !names.has(k)).sort()) {
  const m = meaning(w);
  if (m) { out[w] = m; continue; }
  // what's left: its parts, in their plain senses
  const parts = [...w].map(sense).filter(Boolean);
  fell.push(`${w}=${parts.join(' + ')}`);
}
fs.writeFileSync(path.join(dataDir, 'word-meanings.json'), JSON.stringify(out, null, 0));
console.log(`${Object.keys(out).length} written, ${fell.length} fell through`);
console.log(fell.join('; '));
