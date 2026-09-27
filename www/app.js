/* Bùbù — vanilla JS, no build step, offline.
 * Course data comes from data.js and readings.js, generated from the 起步 · 进步 · 大步
 * books by bubu-course/export_app.py. Progress lives in localStorage. */

(() => {
  "use strict";

  const LS_KEY = "zhBeginnerA.srs.v1";
  const LS_PREFS = "zhBeginnerA.prefs.v1";

  // ---- Build a flat list of cards with stable ids ----
  const LESSONS = VOCAB.lessons;
  const CARDS = [];
  // One card per unique word; first lesson wins. Keyed on hanzi + meaning, so a
  // character re-taught with a genuinely NEW meaning (e.g. 在 "at, in, on" in l3
  // vs the progressive 在 "in the middle of doing" in b7) still earns its own
  // card, while a plain repeat (same meaning) is shown only once.
  const seenHanzi = new Set();
  const normEn = s => (s || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
  LESSONS.forEach(lesson => {
    lesson.words.forEach((w, i) => {
      const dedupKey = w.hanzi + "|" + normEn(w.en);
      if (seenHanzi.has(dedupKey)) return;
      seenHanzi.add(dedupKey);
      CARDS.push({
        id: `${lesson.id}:${i}`,
        lessonId: lesson.id,
        lessonTitle: lesson.title,
        hanzi: w.hanzi,
        pinyin: w.pinyin,
        pos: w.pos || "",
        en: w.en
      });
    });
  });
  const CARD_BY_ID = Object.fromEntries(CARDS.map(c => [c.id, c]));
  const PINYIN_BY_HANZI = Object.fromEntries(CARDS.map(c => [c.hanzi, c.pinyin]));
  const lessonCardCount = id => CARDS.reduce((n, c) => n + (c.lessonId === id ? 1 : 0), 0);

  // ---- Focus directions ----
  /* ---- Icons -----------------------------------------------------------
     Drawn inline rather than loaded from a font: the markup referenced a
     Tabler icon font that was never bundled, so every icon rendered 0px wide.
     These use currentColor, so they inherit whatever colour they sit in.   */
  // Bumped with the app version so replaced artwork is never served stale.
  const ASSET_V = "?v=286";
  const APP_VERSION = ASSET_V.replace("?v=", "v");   // e.g. "v148" — shown in Settings
  const ICON_NS = "http://www.w3.org/2000/svg";
  const rotN = (inner, n) => Array.from({ length: n },
    (_, i) => `<g transform="rotate(${i * 360 / n} 12 12)">${inner}</g>`).join("");
  const ICONS = {
    flame: '<path d="M12 2c.6 3 2.2 4.2 3.6 5.9A6.6 6.6 0 0 1 17.4 12a5.4 5.4 0 1 1-10.8 0c0-1.6.6-2.8 1.5-3.9C9.4 6.6 11.4 5.2 12 2Z"/>'
         + '<path d="M12 12.5c1.3 1.3 2.1 2.1 2.1 3.4a2.1 2.1 0 1 1-4.2 0c0-1.3.8-2.1 2.1-3.4Z" opacity=".42"/>',
    lotus: rotN('<ellipse cx="12" cy="7.6" rx="2.35" ry="4.4"/>', 5) + '<circle cx="12" cy="12" r="2.1"/>',
    chart: '<rect x="3.4" y="13" width="4.3" height="7.4" rx="1.7"/>'
         + '<rect x="9.85" y="8" width="4.3" height="12.4" rx="1.7"/>'
         + '<rect x="16.3" y="3.6" width="4.3" height="16.8" rx="1.7"/>',
    gear:  rotN('<rect x="10.8" y="1.3" width="2.4" height="4.1" rx="1.2"/>', 8)
         + '<circle cx="12" cy="12" r="6.4" fill="none" stroke="currentColor" stroke-width="2.4"/>'
         + '<circle cx="12" cy="12" r="2.4"/>',
    repeat:'<path d="M4 11.5a8 8 0 0 1 13.6-5.7" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/>'
         + '<path d="M20 12.5a8 8 0 0 1-13.6 5.7" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/>'
         + '<path d="M17.8 2.6v3.9h-3.9M6.2 21.4v-3.9h3.9" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
    lock:  '<path d="M8.3 10.3V7.7a3.7 3.7 0 0 1 7.4 0v2.6" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>'
         + '<rect x="4.9" y="10" width="14.2" height="10.1" rx="2.9"/>',
    check: '<path d="M5 12.6l4.4 4.4L19 7.4" fill="none" stroke="currentColor" stroke-width="3.1" stroke-linecap="round" stroke-linejoin="round"/>'
  };
  function icon(name, size) {
    const s = document.createElementNS(ICON_NS, "svg");
    s.setAttribute("viewBox", "0 0 24 24");
    s.setAttribute("width", size || 22);
    s.setAttribute("height", size || 22);
    s.setAttribute("fill", "currentColor");
    s.setAttribute("aria-hidden", "true");
    s.classList.add("ico");
    s.innerHTML = ICONS[name] || "";
    return s;
  }
  // fill in any <span data-icon="name"> placeholders sitting in the markup
  function hydrateIcons(root) {
    (root || document).querySelectorAll("[data-icon]").forEach(sp => {
      if (sp.dataset.iconDone) return;
      sp.dataset.iconDone = "1";
      sp.appendChild(icon(sp.dataset.icon, +sp.dataset.size || 22));
    });
  }

  const FOCUSES = [
    { key: "recognize", ico: "i-eye",        name: "Read characters",     desc: "See 汉字, recall the meaning" },
    { key: "recall",    ico: "i-type",       name: "Recall from English", desc: "English → produce the 汉字" },
    { key: "pinyin",    ico: "i-languages",  name: "Pinyin",              desc: "Pick the correct pinyin — tones matter" },
    { key: "listen",    ico: "i-headphones", name: "Listen",              desc: "Hear it, then pick what it means" },
    { key: "write",     ico: "i-pencil",     name: "Write it",            desc: "Draw the character stroke by stroke" },
    { key: "sentence",  ico: "i-blocks",     name: "Build sentences",     desc: "Tap word tiles to assemble a sentence" },
    { key: "speak",     ico: "i-mic",        name: "Speak it",            desc: "Say the word aloud and get it checked" }
  ];
  const PRESETS = [
    { name: "Everything", keys: ["recognize", "recall", "pinyin", "listen", "write", "sentence", "speak"] },
    { name: "Reading",    keys: ["recognize", "recall", "pinyin"] },
    { name: "Writing",    keys: ["write", "recognize"] },
    { name: "Speaking",   keys: ["speak", "pinyin", "listen"] }
  ];

  // ---- Persistence ----
  function loadSRS() {
    let s;
    try { s = JSON.parse(localStorage.getItem(LS_KEY)) || {}; }
    catch { return {}; }
    return migrateOldSRS(s);
  }
  /* Progress saved by the JIC edition is keyed by its old card ids (l3:4, c12:0…).
     The first time the new course loads (and again after a sync brings old ids
     back), move each old card's history to the new card with the same word. The
     untouched original is kept under LS_KEY_OLD. */
  const LS_KEY_OLD = "zhBeginnerA.srs.jicEdition.v1";
  function migrateOldSRS(s) {
    const OLD = window.OLD_CARDS || {};
    const inS = Object.keys(s).filter(k => !CARD_BY_ID[k] && OLD[k]);
    let kept = {};
    try { kept = JSON.parse(localStorage.getItem(LS_KEY_OLD)) || {}; } catch {}
    inS.forEach(k => { if (!kept[k] || (s[k].last || 0) > (kept[k].last || 0)) kept[k] = s[k]; });
    if (inS.length) localStorage.setItem(LS_KEY_OLD, JSON.stringify(kept));
    // Every load: any old card whose word the course now teaches (a later book may add
    // it) gives that card its history, unless the new card has been studied since.
    const byHanzi = {};
    CARDS.forEach(c => { if (!byHanzi[c.hanzi]) byHanzi[c.hanzi] = c.id; });
    let changed = inS.length > 0;
    Object.keys(kept).forEach(k => {
      const to = byHanzi[OLD[k]], rec = kept[k];
      if (to && (!s[to] || (rec.last || 0) > (s[to].last || 0))) { s[to] = rec; changed = true; }
    });
    inS.forEach(k => delete s[k]);
    if (changed) localStorage.setItem(LS_KEY, JSON.stringify(s));
    return s;
  }

  function saveSRS(s) { localStorage.setItem(LS_KEY, JSON.stringify(s)); }

  function loadPrefs() {
    try { return JSON.parse(localStorage.getItem(LS_PREFS)) || {}; }
    catch { return {}; }
  }
  function savePrefs(p) { localStorage.setItem(LS_PREFS, JSON.stringify(p)); }

  const LS_ACTIVITY = "zhBeginnerA.activity.v1";
  let srs = loadSRS();          // id -> { ease, interval(days), due(ts), reps }
  let prefs = loadPrefs();      // { lessons, focuses, theme, rate, dailyGoal, checkStrokes }

  const NOW = () => Date.now();
  const DAY = 24 * 60 * 60 * 1000;

  // ---- Appearance ----
  function applyTheme() {
    const t = prefs.theme || "system";
    if (t === "system") document.documentElement.removeAttribute("data-theme");
    else document.documentElement.setAttribute("data-theme", t);
  }
  const audioRate = () => (typeof prefs.rate === "number" ? prefs.rate : 0.85);
  // The daily goal is XP now (10 / 20 / 30 / 50). Older prefs held a card count
  // with the same three numbers, so they carry across unchanged.
  const dailyGoal = () => (typeof prefs.dailyGoal === "number" ? prefs.dailyGoal : 20);

  // ---- Activity log (streak + daily goal) ----
  function loadActivity() { try { return JSON.parse(localStorage.getItem(LS_ACTIVITY)) || { days: {} }; } catch { return { days: {} }; } }
  let activity = loadActivity();
  const dateStr = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  const todayStr = () => dateStr(new Date());
  // Cards reviewed per day. Kept for the stats; the streak and the goal run on XP.
  function recordReview(n = 1) {
    queueSync();
    const t = todayStr();
    activity.days[t] = (activity.days[t] || 0) + n;
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
  }
  /* ---- XP and levels ----------------------------------------------------
     Every right answer earns XP, sessions and finished lessons earn more, and
     hitting the daily goal adds a bonus. Earned per day (so it merges across
     devices like the activity count does); the total is the sum. Levels get
     further apart as they go: reaching level L+1 takes 50·L·(L+1) XP in all.

     Two bars, both in XP. LIT_XP keeps the streak alive: one finished session
     or a handful of right answers. The daily goal is the bigger, optional
     target with its own bonus and celebration. */
  const XP = { correct: 2, combo: 3, perfect: 5, session: 10, lesson: 25, goal: 15 };
  const LIT_XP = 10;
  const COMBO_AT = 5;                 // from the fifth right answer in a row, each is worth XP.combo
  const BOOST_MS = 15 * 60 * 1000;    // finishing a lesson doubles XP for a quarter of an hour
  let sessionXP = 0, combo = 0;
  const boostLeft = () => Math.max(0, (activity.boostUntil || 0) - Date.now());
  const boostOn = () => boostLeft() > 0;
  function startBoost() {
    activity.boostUntil = Date.now() + BOOST_MS;
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    renderBoost();
  }
  // The right-answer reward: more on a combo, doubled during a boost.
  function answerXP(correct) {
    if (!correct) { combo = 0; renderCombo(); return; }
    combo++; renderCombo();
    if (combo === COMBO_AT) setTimeout(() => sfx("combo"), 180);
    earnXP(combo >= COMBO_AT ? XP.combo : XP.correct);
  }
  function earnXP(n) {
    if (!n) return;
    if (boostOn()) n *= 2;
    const t = todayStr();
    activity.xpDays = activity.xpDays || {};
    const before = activity.xpDays[t] || 0, after = before + n;
    activity.xpDays[t] = after;
    sessionXP += n;
    const goal = dailyGoal();
    // the goal moment fires exactly once, the instant the day's XP crosses the line
    const crossed = before < goal && after >= goal && activity.celebrated !== t;
    if (crossed) activity.celebrated = t;
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    queueSync();
    if (crossed) { earnXP(XP.goal); celebrateGoal(); if ($(".streak-card")) renderHomeTop(); }
    checkQuests();
    const lv = levelInfo().level;
    if (lv > (activity.levelSeen || 1)) {
      activity.levelSeen = lv; localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
      setTimeout(() => celebrateLevel(lv), crossed ? 3600 : 300);
    }
  }
  function celebrateLevel(lv) {
    const next = levelInfo().next;
    const o = el("div", { className: "goal-burst level-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <svg class="gb-crown"><use href="#i-crown"/></svg>
         <div class="gb-big">${lv}</div>
         <div class="gb-title">Level ${lv}!</div>
         <div class="gb-sub">${next} XP to level ${lv + 1}</div>
         <div class="gb-actions"><button class="primary" id="lvOk">Nice</button></div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    o.querySelector("#lvOk").addEventListener("click", close);
    sfx("levelup"); buzz(true); confetti(100);
  }

  /* ---- Streak moments ----------------------------------------------------
     Finishing a session lights the day's fire and the streak grows by one.
     The completion screen carries the moment; milestones add a full screen
     on top of it. Embers arrive at their own milestones, once per streak, so
     a streak that restarts can earn them again. */
  const MILESTONES = [3, 7, 14, 30, 50, 100, 200, 365];
  const EMBER_AT = [3, 7, 14, 30, 60, 100];
  function lightFire() {
    const t = todayStr();
    activity.lit = activity.lit || {};
    if (activity.lit[t]) return null;                        // already lit today
    activity.lit[t] = true;
    const s = computeStreak();
    const start = dayKeyOffset(1 - s);                       // the day this streak began
    activity.emberFor = activity.emberFor || {};
    let ember = false;
    for (const m of EMBER_AT) {
      if (s < m || (activity.emberFor[m] && activity.emberFor[m] >= start)) continue;
      activity.emberFor[m] = todayStr();
      if (embers() < 3) { activity.embers = embers() + 1; ember = true; }
    }
    if (s > (activity.best || 0)) activity.best = s;
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    queueSync();
    if ($(".streak-card")) renderHomeTop();
    return { streak: s, ember, milestone: MILESTONES.includes(s) };
  }

  /* ---- Daily quests ------------------------------------------------------
     Three small targets a day, drawn from a pool by the date so every device
     agrees on them: one XP quest, one about how you practised, one about a
     skill you have turned on. Finishing all three opens a chest of bonus XP,
     and every fifth chest holds an ember. Quests count toward a monthly
     badge. Progress is read from the day's counters, so nothing is stored
     but the day's picks and what was already claimed. */
  const QUESTS = {
    xp30:      { title: "Earn 30 XP",                     icon: "i-star",       target: 30, prog: () => todayXP() },
    xp50:      { title: "Earn 50 XP",                     icon: "i-star",       target: 50, prog: () => todayXP() },
    combo5:    { title: "Get 5 right in a row",           icon: "i-target",     target: 5,  prog: () => qcToday().comboMax || 0 },
    combo10:   { title: "Get 10 right in a row",          icon: "i-target",     target: 10, prog: () => qcToday().comboMax || 0 },
    review15:  { title: "Review 15 words",                icon: "i-cards",      target: 15, prog: () => todayCount() },
    review30:  { title: "Review 30 words",                icon: "i-cards",      target: 30, prog: () => todayCount() },
    lesson1:   { title: "Finish a lesson",                icon: "i-flag",       target: 1,  prog: () => qcToday().lessons || 0 },
    session2:  { title: "Finish 2 sessions",              icon: "i-check",      target: 2,  prog: () => qcToday().sessions || 0 },
    perfect1:  { title: "Finish a session with no mistakes", icon: "i-crown",   target: 1,  prog: () => qcToday().perfect || 0 },
    listen5:   { title: "Get 5 listening exercises right", icon: "i-headphones", target: 5, prog: () => qcToday().listen || 0, dir: "listen" },
    write3:    { title: "Write 3 characters",             icon: "i-pencil",     target: 3,  prog: () => qcToday().write || 0, dir: "write" },
    speak3:    { title: "Say 3 words aloud",              icon: "i-mic",        target: 3,  prog: () => qcToday().speak || 0, dir: "speak" },
    sentence2: { title: "Build 2 sentences",              icon: "i-chat",       target: 2,  prog: () => qcToday().sentence || 0, dir: "sentence" }
  };
  const QUEST_SETS = [["xp30", "xp50"], ["combo5", "combo10", "review15", "review30", "lesson1", "session2", "perfect1"], ["listen5", "write3", "speak3", "sentence2"]];
  const CHEST_XP = 20;
  // today's counters: right-answer combo, sessions, lessons, perfect runs, and per-skill tallies
  function qcToday() {
    const t = todayStr();
    activity.qc = activity.qc || {};
    if (!activity.qc[t]) activity.qc = { [t]: {} };            // yesterday's counters are no longer needed
    return activity.qc[t];
  }
  function seededPick(list, seed) {
    let h = 2166136261;
    for (const ch of seed) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; }
    return list[h % list.length];
  }
  function todayQuests() {
    const t = todayStr();
    if (!activity.quests || activity.quests.date !== t) {
      const skills = QUEST_SETS[2].filter(id => selectedFocuses.has(QUESTS[id].dir) && (id !== "write3" || HW_OK));
      const second = seededPick(QUEST_SETS[1], t + "b");
      const third = skills.length ? seededPick(skills, t + "c") : seededPick(QUEST_SETS[1].filter(x => x !== second), t + "c");
      activity.quests = { date: t, ids: [seededPick(QUEST_SETS[0], t + "a"), second, third], done: {}, chest: false };
      localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    }
    return activity.quests;
  }
  // Called after every answer and every finished session or quiz.
  function questEvent(kind, correct, extra = {}) {
    const c = qcToday();
    if (kind === "session") {
      c.sessions = (c.sessions || 0) + 1;
      if (extra.lesson) c.lessons = (c.lessons || 0) + 1;
      if (extra.perfect) c.perfect = (c.perfect || 0) + 1;
    } else {
      c.combo = correct ? (c.combo || 0) + 1 : 0;
      if (c.combo > (c.comboMax || 0)) c.comboMax = c.combo;
      if (correct && ["listen", "write", "speak", "sentence"].includes(kind)) c[kind] = (c[kind] || 0) + 1;
    }
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    checkQuests();
  }
  function checkQuests() {
    const q = todayQuests();
    let newly = [];
    q.ids.forEach(id => {
      if (q.done[id]) return;
      if (QUESTS[id].prog() >= QUESTS[id].target) { q.done[id] = true; newly.push(id); }
    });
    if (!newly.length) return;
    const m = todayStr().slice(0, 7);
    activity.questMonths = activity.questMonths || {};
    activity.questMonths[m] = (activity.questMonths[m] || 0) + newly.length;
    const all = q.ids.every(id => q.done[id]);
    let ember = false;
    if (all && !q.chest) {
      q.chest = true;
      activity.chests = (activity.chests || 0) + 1;
      if (activity.chests % 5 === 0 && embers() < 3) { activity.embers = embers() + 1; ember = true; }
    }
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    queueSync();
    if (all) { earnXP(CHEST_XP); setTimeout(() => celebrateChest(ember), 400); }
    else newly.forEach((id, i) => setTimeout(() => toast(`Quest done: ${QUESTS[id].title}`), 300 + i * 1500));
    if ($("#questRows")) renderQuests();
  }
  function celebrateChest(ember) {
    const o = el("div", { className: "goal-burst chest-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <img src="images/panda-celebrate.png${ASSET_V}" alt="">
         <div class="gb-title">All quests done!</div>
         <div class="gb-sub">+${CHEST_XP} XP from the chest</div>
         ${ember ? `<div class="gb-note"><svg class="licon licon-sm"><use href="#i-ember"/></svg> and an ember</div>` : ""}
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    setTimeout(close, 3200);
    o.addEventListener("click", close);
    sfx("chest"); confetti(80);
  }
  function renderQuests() {
    const rows = $("#questRows"); if (!rows) return;
    const q = todayQuests();
    const done = questRowsInto(rows, q);
    renderQuestsHeader(rows, q, done);
  }
  function questRowsInto(rows, q) {
    rows.innerHTML = "";
    let done = 0;
    q.ids.forEach(id => {
      const d = QUESTS[id], n = Math.min(d.target, d.prog()), ok = !!q.done[id];
      if (ok) done++;
      const it = el("div", { className: "q-item" + (ok ? " ok" : "") });   // not "done": that class styles the session-complete screen
      it.innerHTML = `<div class="qi-ico">${svgUse(ok ? "i-tick" : d.icon)}</div>
        <div class="qi-body"><b>${d.title}</b><div class="qi-bar"><i style="width:${Math.round((ok ? 1 : n / d.target) * 100)}%"></i></div></div>
        <span class="qi-n">${ok ? "Done" : `${n}/${d.target}`}</span>`;
      rows.appendChild(it);
    });
    return done;
  }
  function renderQuestsHeader(rows, q, done) {
    const chest = $("#qcChest");
    chest.textContent = done === 3 ? (q.chest ? "Chest opened" : "3/3") : `${done}/3`;
    chest.classList.toggle("full", done === 3);
    // once the chest is open the card folds to its header line
    const opened = done === 3 && q.chest;
    rows.closest(".quest-card").classList.toggle("opened", opened);
    rows.classList.toggle("hidden", opened);
  }
  const xpTotal = () => Object.values(activity.xpDays || {}).reduce((s, n) => s + (n || 0), 0);
  const xpOn = key => (activity.xpDays || {})[key] || 0;
  function levelInfo() {
    const total = xpTotal();
    let L = 1;
    while (total >= 50 * L * (L + 1)) L++;
    const floor = 50 * (L - 1) * L, ceil = 50 * L * (L + 1);
    return { level: L, total, into: total - floor, span: ceil - floor, next: ceil - total };
  }

  /* ---- Embers: relighting a streak that went out --------------------------
     Miss a day and the fire goes out. An ember relights it: the missed day is
     marked as covered and the streak carries on. You start with one, and earn
     more at streak milestones (three at most). Only the most recent single
     missed day can be relit, and only until the end of the day after it. */
  const embers = () => (typeof activity.embers === "number" ? activity.embers : 1);
  const dayKeyOffset = n => { const d = new Date(); d.setDate(d.getDate() + n); return dateStr(d); };
  // The date the fire went out, if it can still be relit: yesterday was missed
  // and the day before was met. Today's own miss is not a miss until midnight.
  function outSince() {
    const y = dayKeyOffset(-1);
    if (litOn(y)) return null;
    let d = new Date(); d.setDate(d.getDate() - 2);
    let run = 0;
    while (litOn(dateStr(d))) { run++; d.setDate(d.getDate() - 1); }
    return run > 0 ? { date: y, lost: run } : null;
  }
  function relight() {
    const out = outSince();
    if (!out || embers() < 1) return false;
    activity.embers = embers() - 1;
    activity.relit = activity.relit || {};
    activity.relit[out.date] = true;
    localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
    queueSync();
    return true;
  }
  /* When the app opens after a missed day: an ember relights the fire by
     itself (unless turned off in Settings) and the moment is a celebration,
     not a decision. With no ember, the fire is out and the screen says so once.
     With auto-relight off, the old ask card is shown instead. */
  function protectStreak() {
    const out = outSince();
    if (!out || activity.relightAsked === out.date) return;
    if (embers() >= 1 && prefs.autoRelight !== false) {
      activity.relightAsked = out.date;
      if (relight()) { renderHomeTop(); celebrateRelight(computeStreak(), embers()); }
    } else if (embers() >= 1) askRelight(true);
    else {
      activity.relightAsked = out.date; localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity));
      showFireOut(out.lost);
    }
  }
  function celebrateRelight(streak, left) {
    const o = el("div", { className: "goal-burst relight-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <svg class="gb-flame ignite"><use href="#i-flame-solid"/></svg>
         <div class="gb-title">Your ember kept the fire lit</div>
         <div class="gb-big small">${streak}</div>
         <div class="gb-sub">day streak carries on</div>
         <div class="gb-note"><svg class="licon licon-sm"><use href="#i-ember"/></svg> ${left} ember${left === 1 ? "" : "s"} left</div>
         <div class="gb-actions"><button class="primary" id="rlOk">Keep going</button></div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    setTimeout(() => { sfx("relight"); buzz(true); confetti(70); }, 500);
    o.querySelector("#rlOk").addEventListener("click", close);
  }
  function showFireOut(lost) {
    const o = el("div", { className: "goal-burst relight-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <svg class="gb-flame out"><use href="#i-flame-solid"/></svg>
         <div class="gb-title">Your fire went out</div>
         <div class="gb-sub">${lost}-day streak. No ember was left to relight it.</div>
         <div class="gb-note"><svg class="licon licon-sm"><use href="#i-ember"/></svg> Reach 3 days to earn one</div>
         <div class="gb-actions"><button class="primary" id="foOk">Start fresh</button></div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    o.querySelector("#foOk").addEventListener("click", close);
  }
  // The manual relight card, used when automatic relighting is turned off,
  // or from the streak card and the profile.
  function askRelight(auto = false) {
    const out = outSince();
    if (!out) return;
    const n = embers();
    if (n < 1) { if (!auto) toast("No embers left. Reach 3, 7, 14 or 30 days to earn one."); return; }
    if (auto) { if (activity.relightAsked === out.date) return; activity.relightAsked = out.date; localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity)); }
    const o = el("div", { className: "goal-burst relight-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <svg class="gb-flame out"><use href="#i-flame-solid"/></svg>
         <div class="gb-title">Your fire went out</div>
         <div class="gb-sub">${out.lost}-day streak. Use an ember to relight it?</div>
         <div class="gb-note"><svg class="licon licon-sm"><use href="#i-ember"/></svg> You have ${n} ember${n === 1 ? "" : "s"}</div>
         <div class="gb-actions"><button class="primary" id="rlYes">Relight the fire</button><button class="ghost" id="rlNo">Let it go</button></div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    o.querySelector("#rlNo").addEventListener("click", close);
    o.querySelector("#rlYes").addEventListener("click", () => {
      close();
      if (relight()) { sfx("complete"); toast(`Relit! ${computeStreak()}-day streak carries on.`); renderHomeTop(); if (typeof renderDashboard === "function") renderDashboard(); }
    });
  }

  // A day is LIT once it has LIT_XP (one finished session) or was relit. The
  // streak is the run of lit days ending today or yesterday. The daily goal is
  // the separate XP target. Days from before XP existed count if they met the
  // old card goal, so nobody's streak resets on the change.
  const LIT_CUTOFF = "2026-09-19";   // from this day a finished session lights the fire; before it, XP did
  const litOn = key => !!(activity.lit && activity.lit[key]) || !!(activity.relit && activity.relit[key])
    || (key < LIT_CUTOFF && (xpOn(key) >= LIT_XP || (activity.days[key] || 0) >= 20));
  const goalMetOn = key => xpOn(key) >= dailyGoal();
  function computeStreak() {
    let d = new Date();
    if (!litOn(dateStr(d))) d.setDate(d.getDate() - 1);
    let streak = 0;
    while (litOn(dateStr(d))) { streak++; d.setDate(d.getDate() - 1); }
    return streak;
  }
  const todayCount = () => activity.days[todayStr()] || 0;
  const todayXP = () => xpOn(todayStr());
  const goalDone = () => todayXP() >= dailyGoal();

  // ---- Progress stats over all cards ----
  const MASTER_INTERVAL = 7;   // days; a word is "mastered" once spaced this far
  // Directions that count as PRODUCING the word (recalling/writing/saying it),
  // not merely recognising it. A word must be produced at least once to master.
  const PRODUCTION_DIRS = new Set(["recall", "write", "speak"]);
  const isMastered = s => !!(s && s.interval >= MASTER_INTERVAL && s.prod);
  function progressStats(cardList) {
    let mastered = 0, learning = 0, fresh = 0;
    for (const c of cardList) {
      const s = srs[c.id];
      if (!s) fresh++;
      else if (isMastered(s)) mastered++;
      else learning++;
    }
    return { mastered, learning, fresh, total: cardList.length };
  }

  // ---- Spaced repetition (SM-2 lite) ----
  /* ---- Review timing: FSRS ------------------------------------------------
     FSRS (the scheduler modern Anki uses) models each word's memory with a
     stability S (days until recall drops to 90%) and a difficulty D (1-10),
     and schedules the next review for when you are 90% likely to remember
     it. Default FSRS-5 weights. The older fields (reps, interval, due,
     lapses) are kept up to date, so everything that reads them still works.
     Words reviewed under the old scheduler are converted the first time they
     come up again; the old history was copied aside first. */
  const FSRS_W = [0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
    1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621];
  const FSRS_DECAY = -0.5, FSRS_FACTOR = 19 / 81, RETENTION = 0.9;
  const fsrsClampD = d => Math.min(10, Math.max(1, d));
  const fsrsD0 = g => fsrsClampD(FSRS_W[4] - Math.exp(FSRS_W[5] * (g - 1)) + 1);
  const fsrsR = (days, S) => Math.pow(1 + FSRS_FACTOR * days / S, FSRS_DECAY);
  const fsrsInterval = S => S / FSRS_FACTOR * (Math.pow(RETENTION, 1 / FSRS_DECAY) - 1);
  function fsrsNextD(D, g) {
    const d = D - FSRS_W[6] * (g - 3) * (10 - D) / 9;
    return fsrsClampD(FSRS_W[7] * fsrsD0(4) + (1 - FSRS_W[7]) * d);
  }
  function fsrsRecall(D, S, R, g) {
    return S * (Math.exp(FSRS_W[8]) * (11 - D) * Math.pow(S, -FSRS_W[9]) * (Math.exp(FSRS_W[10] * (1 - R)) - 1)
      * (g === 2 ? FSRS_W[15] : 1) * (g === 4 ? FSRS_W[16] : 1) + 1);
  }
  function fsrsForget(D, S, R) {
    return Math.min(S, FSRS_W[11] * Math.pow(D, -FSRS_W[12]) * (Math.pow(S + 1, FSRS_W[13]) - 1) * Math.exp(FSRS_W[14] * (1 - R)));
  }
  // An old-scheduler word: its interval was roughly its stability, and its ease maps onto difficulty.
  function fsrsFromLegacy(s) {
    s.S = Math.max(0.5, s.interval || 1);
    s.D = fsrsClampD(5 + (2.4 - (s.ease || 2.4)) * 4.4);
    s.last = s.last || Math.max(0, (s.due || NOW()) - (s.interval || 0) * DAY);
  }
  // Copy the review history aside once, before FSRS touches any of it.
  const LS_SRS_OLD = "zhBeginnerA.srs.beforeFSRS.v1";
  function backupBeforeFsrs() {
    try { if (!localStorage.getItem(LS_SRS_OLD)) localStorage.setItem(LS_SRS_OLD, JSON.stringify({ at: NOW(), srs })); } catch (e) {}
  }
  function schedule(id, grade) {
    backupBeforeFsrs();
    const s = srs[id] || { ease: 2.4, interval: 0, due: 0, reps: 0 };
    const g = grade === "again" ? 1 : grade === "easy" ? 4 : grade === "hard" ? 2 : 3, now = NOW();
    if (s.S == null && (s.reps || 0) >= 1) fsrsFromLegacy(s);
    if (s.S == null) { s.S = FSRS_W[g - 1]; s.D = fsrsD0(g); }       // first ever review
    else {
      const days = s.last ? (now - s.last) / DAY : 0;
      if (days < 0.5) s.S = s.S * Math.exp(FSRS_W[17] * (g - 3 + FSRS_W[18]));   // again the same day
      else { const R = fsrsR(days, s.S); s.S = g === 1 ? fsrsForget(s.D, s.S, R) : fsrsRecall(s.D, s.S, R, g); }
      s.D = fsrsNextD(s.D, g);
    }
    s.S = Math.max(0.1, s.S); s.last = now;
    if (g === 1) {
      s.reps = 0; s.interval = 0;
      s.lapses = (s.lapses || 0) + 1;   // how often you've missed it — powers "trouble words"
      s.due = now + 60 * 1000;          // ~1 min: comes back this session
    } else {
      s.reps = (s.reps || 0) + 1;
      // a touch of fuzz so words learnt together don't all fall due on the same day
      const iv = fsrsInterval(s.S), fuzz = iv > 3 ? 1 + (Math.random() - 0.5) * 0.1 : 1;
      s.interval = Math.max(1, Math.min(365, Math.round(iv * fuzz)));
      s.due = now + s.interval * DAY;
    }
    srs[id] = s;
    saveSRS(srs);
  }

  function dueCountForLesson(lessonId) {
    return CARDS.filter(c => c.lessonId === lessonId).reduce((n, c) => {
      const s = srs[c.id];
      return n + (!s || s.due <= NOW() ? 1 : 0);
    }, 0);
  }

  // ---- Small helpers ----
  const $ = sel => document.querySelector(sel);
  const el = (tag, props = {}, kids = []) => {
    const n = document.createElement(tag);
    // `style` needs special handling: Object.assign(n, { style: "..." }) is a
    // silent no-op, because .style is a read-only CSSStyleDeclaration. Every
    // inline style passed to el() was being dropped.
    const { style, ...rest } = props;
    Object.assign(n, rest);
    if (style) n.style.cssText = style;
    (Array.isArray(kids) ? kids : [kids]).forEach(k =>
      n.appendChild(typeof k === "string" ? document.createTextNode(k) : k));
    return n;
  };
  // A line-icon element from the sprite (returns the <svg> node).
  const licon = (id, extra) => {
    const t = document.createElement("template");
    t.innerHTML = `<svg class="licon${extra ? " " + extra : ""}"><use href="#${id}"/></svg>`;
    return t.content.firstChild;
  };
  function shuffle(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }
  function sample(arr, n, exclude) {
    return shuffle(arr.filter(x => x !== exclude)).slice(0, n);
  }

  function show(sectionId) {
    if (typeof closeHint === "function") closeHint();
    if (window.__updateReady && ["home", "path", "progress"].includes(sectionId)) { window.__updateReady(); return; }
    ["path", "home", "progress", "study", "quiz", "browse", "done", "sheet", "converse", "pick", "flash", "match", "avatar", "chars", "read", "tones", "guide"].forEach(id =>
      $("#" + id).classList.toggle("hidden", id !== sectionId));
    // Reset the window scroll BEFORE the new view applies its body scroll-lock.
    // The done screen is normal flow, so scrolling down to "Back to path" scrolls
    // the BODY; the path then locks body overflow. On iOS a body that's scrolled
    // and THEN locked keeps its offset and can't be scrolled back — the whole UI
    // sits pushed up. So reset first (on every scrolling element) while the body
    // is still scrollable, then lock; the rAF pass repeats it once layout settles.
    const resetScroll = () => { window.scrollTo(0, 0); document.documentElement.scrollTop = 0; document.body.scrollTop = 0; };
    resetScroll();
    document.body.dataset.view = sectionId;   // lets CSS give sessions a fixed-height layout
    if (sectionId === "done") $("#doneHome").textContent = returnView === "home" ? "← Back to home" : "← Back to path";
    // Keep the bottom-nav highlight in sync with the view HERE (a stale one left
    // Path showing with Home lit after a session).
    document.querySelectorAll(".bottomnav button").forEach(x => x.classList.toggle("on", x.dataset.nav === sectionId));
    requestAnimationFrame(resetScroll);
  }

  // Gentle inline message instead of a browser alert().
  let toastTimer = null;
  function toast(msg, ms = 2400) {
    const t = $("#toast");
    t.textContent = msg;
    t.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove("show"), ms);
  }

  // A short burst of confetti over whatever is on screen. Skipped when the
  // system asks for reduced motion.
  function confetti(n = 90) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const c = document.createElement("canvas"); c.className = "confetti";
    c.width = innerWidth * (devicePixelRatio || 1); c.height = innerHeight * (devicePixelRatio || 1);
    document.body.appendChild(c);
    const x = c.getContext("2d"), s = devicePixelRatio || 1;
    const cs = ["#f0b429", "#f0742f", "#4ce1ad", "#6c9dfc", "#e39aae", "#fde68a"];
    const ps = Array.from({ length: n }, () => ({ x: c.width / 2 + (Math.random() - .5) * c.width * .5, y: c.height * .45,
      vx: (Math.random() - .5) * 14 * s, vy: (-8 - Math.random() * 9) * s, w: (5 + Math.random() * 6) * s, h: (3 + Math.random() * 5) * s,
      r: Math.random() * 6.28, vr: (Math.random() - .5) * .3, col: cs[Math.floor(Math.random() * cs.length)] }));
    const t0 = performance.now();
    const step = now => {
      const k = (now - t0) / 1600;
      x.clearRect(0, 0, c.width, c.height);
      x.globalAlpha = k > .75 ? Math.max(0, 1 - (k - .75) / .25) : 1;
      ps.forEach(p => {
        p.x += p.vx; p.y += p.vy; p.vy += .35 * s; p.vx *= .99; p.r += p.vr;
        x.save(); x.translate(p.x, p.y); x.rotate(p.r); x.fillStyle = p.col; x.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); x.restore();
      });
      if (k < 1) requestAnimationFrame(step); else c.remove();
    };
    requestAnimationFrame(step);
  }
  // Full-screen moment when the daily goal is reached.
  function celebrateGoal() {
    const o = el("div", { className: "goal-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <img src="images/panda-celebrate.png${ASSET_V}" alt="">
         <div class="gb-title">Daily goal reached!</div>
         <div class="gb-sub">+${XP.goal} XP bonus</div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    setTimeout(close, 2800);
    o.addEventListener("click", close);
    sfx("goal");
  }
  // Full-screen moment at a streak milestone.
  const MILESTONE_WORDS = { 3: "Three days. It's a habit now.", 7: "A whole week on fire.", 14: "Two weeks. Unstoppable.", 30: "A month. Seriously impressive.",
    50: "Fifty days of Chinese.", 100: "One hundred days.", 200: "Two hundred days.", 365: "A full year. 太厉害了!" };
  function celebrateMilestone(s, ember) {
    const o = el("div", { className: "goal-burst milestone-burst" });
    o.innerHTML =
      `<div class="gb-card">
         <svg class="gb-flame"><use href="#i-flame-solid"/></svg>
         <div class="gb-big">${s}</div>
         <div class="gb-title">day streak!</div>
         <div class="gb-sub">${MILESTONE_WORDS[s] || "Keep the fire lit."}</div>
         ${ember ? `<div class="gb-note"><svg class="licon licon-sm"><use href="#i-ember"/></svg> You earned an ember</div>` : ""}
         <div class="gb-actions"><button class="primary" id="msOk">Keep going</button></div>
       </div>`;
    document.body.appendChild(o);
    const close = () => { o.classList.remove("show"); setTimeout(() => o.remove(), 350); };
    setTimeout(() => o.classList.add("show"), 20);
    o.querySelector("#msOk").addEventListener("click", close);
    sfx("milestone"); confetti(120);
  }

  // ---- Sound effects ----
  // Plays warm synthesized chime FILES (sounds/*.mp3) through WebAudio, which is
  // reliable on iOS and lets rapid answers overlap. Falls back to live-oscillator
  // tones for any file that hasn't loaded, so sound never silently disappears.
  let audioCtx = null;
  const soundOn = () => prefs.sound !== false;   // default on
  let masterGain = null, audioWarmed = false;
  function ensureAudio() {
    if (!soundOn()) return null;
    if (!audioCtx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      audioCtx = new AC();
      masterGain = audioCtx.createGain();
      masterGain.gain.value = 0.7;        // one knob to tame overall loudness
      masterGain.connect(audioCtx.destination);
      // Keep the context AWAKE with a silent loop. iOS suspends an idle context
      // between sounds, and resume() is async — so every chime was waiting on it
      // (that's the "delayed" correct/wrong sound). A looping silent source stops
      // the auto-suspend, so sfx() finds the context running and plays instantly.
      try {
        const keep = audioCtx.createBufferSource();
        keep.buffer = audioCtx.createBuffer(1, audioCtx.sampleRate, audioCtx.sampleRate); // 1s of silence
        keep.loop = true; keep.connect(audioCtx.destination); keep.start();
      } catch (e) {}
    }
    if (audioCtx.state === "suspended") audioCtx.resume();
    return audioCtx;
  }
  // Coming back from the background re-suspends the context; resume it as soon
  // as the app is visible again so the first tap's chime doesn't pay the wait.
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden && audioCtx && audioCtx.state === "suspended") audioCtx.resume();
  });
  // On iOS the FIRST WebAudio output can jump in loud (ignoring the media volume)
  // until the audio route settles — so spend that first sound on 120ms of silence.
  function warmAudio() {
    if (audioWarmed) return;
    const ctx = ensureAudio(); if (!ctx || !masterGain) return;
    audioWarmed = true;
    try {
      const buf = ctx.createBuffer(1, Math.max(1, Math.ceil(ctx.sampleRate * 0.12)), ctx.sampleRate);
      const src = ctx.createBufferSource(); src.buffer = buf;
      src.connect(masterGain); src.start();
    } catch (e) {}
  }
  // Same story for the spoken voice: the first utterance on iOS activates the
  // audio session and can blast in loud. Fire one silent utterance on unlock so
  // the first word you actually hear plays at the settled volume.
  let speechWarmed = false;
  function warmSpeech() {
    if (speechWarmed || !("speechSynthesis" in window)) return;
    speechWarmed = true;
    try {
      const u = new SpeechSynthesisUtterance("​");   // zero-width space
      u.volume = 0; u.rate = 2;
      speechSynthesis.speak(u);
    } catch (e) {}
  }

  const SFX_KINDS = ["correct", "wrong", "complete", "goal"];
  const sfxBuffers = {};
  let sfxLoadStarted = false;
  function loadSfx() {
    const ctx = ensureAudio();
    if (!ctx || sfxLoadStarted) return;
    sfxLoadStarted = true;
    SFX_KINDS.forEach(kind => {
      fetch(`sounds/${kind}.mp3${ASSET_V}`)
        .then(r => (r.ok ? r.arrayBuffer() : Promise.reject()))
        .then(b => ctx.decodeAudioData(b))
        .then(buf => { sfxBuffers[kind] = buf; })
        .catch(() => {});   // missing/undecodable → keeps the synth fallback
    });
  }
  // iOS only unlocks WebAudio inside a user gesture — prime + preload + warm the
  // route on first tap, so the first real chime plays at a settled volume.
  ["pointerdown", "keydown"].forEach(ev =>
    window.addEventListener(ev, () => { if (soundOn()) { ensureAudio(); loadSfx(); warmAudio(); } warmSpeech(); }, { passive: true }));

  function tone(ctx, freq, start, dur, opts = {}) {
    const type = opts.type || "sine", gain = opts.gain == null ? 0.16 : opts.gain;
    const t0 = ctx.currentTime + start;
    const osc = ctx.createOscillator(), g = ctx.createGain();
    osc.type = type; osc.frequency.value = freq;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.linearRampToValueAtTime(gain, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g).connect(masterGain || ctx.destination);
    osc.start(t0); osc.stop(t0 + dur + 0.03);
  }
  function synthSfx(ctx, kind) {
    if (kind === "correct") { tone(ctx, 660, 0, 0.12); tone(ctx, 990, 0.09, 0.16); }
    else if (kind === "wrong") { tone(ctx, 200, 0, 0.22, { type: "sawtooth", gain: 0.11 }); tone(ctx, 160, 0.09, 0.26, { type: "sawtooth", gain: 0.09 }); }
    else if (kind === "complete") { [523, 659, 784, 1047].forEach((f, i) => tone(ctx, f, i * 0.09, 0.22)); }
    else if (kind === "goal") { [523, 659, 784, 1047, 1319].forEach((f, i) => tone(ctx, f, i * 0.1, 0.3, { gain: 0.18 })); }
    else if (kind === "tap") { tone(ctx, 430, 0, 0.05, { gain: 0.07 }); }
    else if (kind === "combo") { tone(ctx, 880, 0, 0.08, { gain: 0.12 }); tone(ctx, 1175, 0.06, 0.1, { gain: 0.12 }); tone(ctx, 1568, 0.12, 0.14, { gain: 0.1 }); }
    else if (kind === "chest") { tone(ctx, 784, 0, 0.18, { gain: 0.16 }); tone(ctx, 1568, 0.12, 0.35, { gain: 0.14 }); tone(ctx, 2093, 0.2, 0.4, { gain: 0.08 }); tone(ctx, 2637, 0.28, 0.45, { gain: 0.05 }); }
    else if (kind === "milestone") { [659, 784, 988, 1319, 1568].forEach((f, i) => tone(ctx, f, i * 0.11, 0.38, { gain: 0.19 })); tone(ctx, 330, 0, 0.9, { type: "triangle", gain: 0.08 }); }
    else if (kind === "levelup") { [523, 659, 784, 1047].forEach((f, i) => tone(ctx, f, i * 0.07, 0.2, { gain: 0.16 })); [1319, 1568, 2093].forEach((f, i) => tone(ctx, f, 0.32 + i * 0.09, 0.5, { gain: 0.14 })); }
    else if (kind === "relight") { [220, 330, 440, 660].forEach((f, i) => tone(ctx, f, i * 0.05, 0.25, { type: "triangle", gain: 0.09 })); tone(ctx, 1319, 0.24, 0.5, { gain: 0.16 }); tone(ctx, 1760, 0.34, 0.6, { gain: 0.1 }); }
  }
  let lastGoalAt = 0;
  function sfx(kind) {
    const ctx = ensureAudio();
    if (!ctx) return;
    // The daily-goal fanfare fires on the answer that crosses the goal. When that
    // answer is also a lesson's last card, the done screen's "complete" chime
    // would land on top of it — two fanfares at once. The goal fanfare already IS
    // the celebration, so let "complete" yield to it.
    if (kind === "goal") lastGoalAt = Date.now();
    else if (kind === "complete" && Date.now() - lastGoalAt < 1500) return;
    const play = () => {
      const buf = sfxBuffers[kind];
      if (buf) {
        const src = ctx.createBufferSource(), g = ctx.createGain();
        src.buffer = buf; g.gain.value = 0.85;
        src.connect(g).connect(masterGain || ctx.destination);
        try { src.start(); } catch (e) {}
      } else synthSfx(ctx, kind);
    };
    // iOS suspends the audio context after inactivity / backgrounding. resume() is
    // async, so starting a sound before it resolves plays SILENTLY — which is why
    // the correct/wrong chime only fired sometimes. Resume first, THEN play.
    if (ctx.state === "suspended") ctx.resume().then(play).catch(play);
    else play();
  }

  // ---- Text to speech ----
  let zhVoice = null, voicesSeen = false;
  const isZhVoice = v => {
    const s = ((v.lang || "") + " " + (v.name || "")).toLowerCase();
    return /(^|[^a-z])zh([^a-z]|$)|zh[-_]|cmn|chinese|mandarin|中文|普通话|國語|国语|台湾|táiwān/.test(s);
  };
  // Rank a Chinese voice for naturalness. Default system voices ("compact" on
  // iOS, "eSpeak" on Android) sound robotic; the Siri / Enhanced / Premium /
  // network voices sound close to human. Score so the best available one wins.
  function voiceQuality(v) {
    const s = ((v.name || "") + " " + (v.voiceURI || "")).toLowerCase();
    let q = 0;
    if (/^zh[-_]?cn/i.test(v.lang)) q += 3;             // Mainland Mandarin dialect
    else if (/^(zh|cmn)/i.test(v.lang)) q += 1;
    if (/siri/.test(s)) q += 10;                        // iOS Siri voices — best
    if (/(premium|enhanced|neural|natural|网络|wǎngluò)/.test(s)) q += 8;
    if (/google/.test(s)) q += 6;                       // Android/Chrome network voice
    if (v.localService === false) q += 2;               // network (usually higher quality)
    if (/(compact|espeak|微软|中英文)/.test(s)) q -= 2;   // known low-fi engines
    // named Chinese voices, roughly better than the bare compact default
    if (/(tingting|ting-ting|婷婷|meijia|美佳|sinji|語嫣|yu-shu|yushu|li-mu|panpan)/.test(s)) q += 4;
    return q;
  }
  function zhVoices() {
    const voices = speechSynthesis.getVoices();
    return voices.filter(v => /^(zh|cmn)/i.test(v.lang) || isZhVoice(v));
  }
  function pickVoice() {
    const voices = speechSynthesis.getVoices();
    if (!voices.length) return;              // not loaded yet — try again later
    voicesSeen = true;
    const zh = zhVoices();
    if (!zh.length) { zhVoice = null; return; }
    // An explicit choice from Settings wins, if it's still installed.
    if (prefs.voiceURI) {
      const chosen = zh.find(v => v.voiceURI === prefs.voiceURI);
      if (chosen) { zhVoice = chosen; return; }
    }
    zh.sort((a, b) => voiceQuality(b) - voiceQuality(a));   // else the best available
    zhVoice = zh[0];
  }
  if ("speechSynthesis" in window) {
    pickVoice();
    speechSynthesis.onvoiceschanged = pickVoice;
    // Some engines (notably iOS Safari) populate voices late and may never fire
    // voiceschanged — poll a few times so we don't miss the Chinese voice.
    [150, 500, 1200, 2500].forEach(t => setTimeout(pickVoice, t));
  }
  function warnNoVoiceOnce() {
    try {
      if (localStorage.getItem("zhBeginnerA.noVoice.v1")) return;
      localStorage.setItem("zhBeginnerA.noVoice.v1", "1");
    } catch (e) {}
    toast("No Chinese voice on this device, so audio is silent. Add one in your system's spoken-content / voice settings.");
  }
  // The best iOS voices must be downloaded by the user — suggest it once, the
  // first time we're stuck on a low-quality (robotic) voice.
  function suggestBetterVoiceOnce() {
    try {
      if (localStorage.getItem("zhBeginnerA.voiceTip.v1")) return;
      if (!zhVoice || voiceQuality(zhVoice) >= 8) return;   // already on a good one
      localStorage.setItem("zhBeginnerA.voiceTip.v1", "1");
    } catch (e) { return; }
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent);
    toast(ios
      ? "Tip: for a far more natural voice, go to Settings → Accessibility → Spoken Content → Voices → Chinese and download an “Enhanced” voice."
      : "Tip: install a higher-quality Chinese text-to-speech voice in your system settings for a more natural voice.");
  }
  function speak(text, opts = {}) {
    if (!("speechSynthesis" in window)) return;
    if (!zhVoice) pickVoice();               // re-resolve at play time — voices may have loaded since boot
    const ss = speechSynthesis;
    const u = new SpeechSynthesisUtterance(text);
    u.lang = "zh-CN";
    if (zhVoice) u.voice = zhVoice;
    u.rate = opts.rate != null ? opts.rate : audioRate();
    u.pitch = opts.pitch != null ? opts.pitch : 1;
    if (opts.onEnd) u.onend = opts.onEnd;
    try { ss.resume(); } catch (e) {}        // iOS can leave the synth paused/stuck — unstick it
    ss.cancel();                             // stop anything mid-utterance
    // iOS/Safari drops an utterance queued in the SAME tick as cancel(); deferring
    // one tick (and resuming again) makes playback reliable, incl. the listen card.
    setTimeout(() => { try { ss.resume(); ss.speak(u); } catch (e) {} }, 0);
    // If the voice list hasn't populated yet (common on a cold iOS launch), the
    // utterance can fall silent — re-fire once the voices arrive.
    if (!voicesSeen && !speakRetried) {
      speakRetried = true;
      setTimeout(() => { pickVoice(); if (voicesSeen) speak(text, opts); }, 500);
    }
    // Voices have loaded but none are Chinese → tell the user once why it's silent.
    if (voicesSeen && !zhVoice) warnNoVoiceOnce();
    else if (zhVoice) suggestBetterVoiceOnce();
  }
  let speakRetried = false;
  function speakerBtn(text) {
    const b = el("button", { className: "speaker", title: "Play audio", type: "button" });
    b.innerHTML = `<svg class="licon licon-sm"><use href="#i-volume"/></svg>`;
    b.addEventListener("click", e => { e.stopPropagation(); speak(text); });
    return b;
  }
  // Slow (🐢) playback for careful listening.
  function slowSpeakerBtn(text) {
    const b = el("button", { className: "speaker speaker-slow", title: "Play slowly", type: "button" });
    b.innerHTML = `<svg class="licon licon-sm"><use href="#i-volume"/></svg><span class="spd">½×</span>`;
    b.addEventListener("click", e => { e.stopPropagation(); speak(text, { rate: 0.5 }); });
    return b;
  }

  // ---- Speech recognition (you speak → it checks) ----
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  // Inside the iPhone app (Capacitor) the web speech API isn't there, so Apple's own
  // recogniser is used through the speech-recognition plugin instead.
  const NSR = window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform()
    && window.Capacitor.Plugins && window.Capacitor.Plugins.SpeechRecognition;
  const canRecognize = () => !!(NSR || SR);
  // Same contract as the web version below: onEnd fires exactly once, however it ends.
  function recognizeNative({ onStart, onResult, onInterim, onError, onEnd, acceptEarly }) {
    let delivered = false, ended = false, last = [], watchdog = null, quiet = null;
    const handles = [];
    const done = () => {
      if (ended) return; ended = true;
      clearTimeout(watchdog); clearTimeout(quiet);
      handles.forEach(h => { try { h.remove(); } catch {} });
      NSR.stop().catch(() => {});
      onEnd && onEnd();
    };
    const deliver = alts => { if (delivered) return; delivered = true; onResult && onResult(alts); done(); };
    const settle = () => { if (last.length) deliver(last); else { onError && onError("no-speech"); done(); } };
    (async () => {
      try {
        const p = await NSR.checkPermissions();
        if (p.speechRecognition !== "granted") {
          const r = await NSR.requestPermissions();
          if (r.speechRecognition !== "granted") { onError && onError("not-allowed"); return done(); }
        }
        handles.push(await NSR.addListener("partialResults", d => {
          const alts = (d && d.matches) || [];
          if (!alts.length || ended) return;
          last = alts;
          onInterim && onInterim(alts);
          if (acceptEarly && acceptEarly(alts)) return deliver(alts);
          // Apple's recogniser doesn't stop on silence: settle once you've paused
          clearTimeout(quiet); quiet = setTimeout(settle, 1400);
        }));
        handles.push(await NSR.addListener("listeningState", d => {
          if (d && d.status === "started") onStart && onStart();
          else if (d && d.status === "stopped") settle();
        }));
        await NSR.start({ language: "zh-CN", maxResults: 8, partialResults: true, popup: false });
        watchdog = setTimeout(settle, 12000);
      } catch (e) { onError && onError("start-failed"); done(); }
    })();
    return { stop: settle, abort: done };
  }
  // onInterim(alts)  – live partial guesses while you're still speaking
  // acceptEarly(alts) – return true to settle NOW without waiting for the engine
  //                     to time out on silence (the main source of the lag)
  function recognizeOnce({ onStart, onResult, onInterim, onError, onEnd, acceptEarly }) {
    if (NSR) return recognizeNative({ onStart, onResult, onInterim, onError, onEnd, acceptEarly });
    if (!SR) { onError && onError("unsupported"); onEnd && onEnd(); return null; }
    const rec = new SR();
    rec.lang = "zh-CN";
    rec.interimResults = true;   // stream partial results — the exercise feels live, not frozen
    rec.maxAlternatives = 8;     // more candidates = more chances the right one is in there
    let delivered = false, ended = false, watchdog = null;
    // onEnd must fire EXACTLY once, no matter how recognition terminates — a normal
    // end, an error, a failed start, or the engine simply hanging. Callers re-enable
    // the mic button in onEnd, so if it never fired the button stuck on "Listening…".
    const done = () => { if (ended) return; ended = true; if (watchdog) clearTimeout(watchdog); onEnd && onEnd(); };
    const altsOf = r => { const a = []; for (let i = 0; i < r.length; i++) a.push(r[i].transcript); return a; };
    const deliver = alts => { if (delivered) return; delivered = true; onResult && onResult(alts); try { rec.stop(); } catch {} };
    rec.onstart = () => onStart && onStart();
    rec.onresult = e => {
      const r = e.results[e.results.length - 1];
      const alts = altsOf(r);
      if (r.isFinal) return deliver(alts);
      onInterim && onInterim(alts);
      if (acceptEarly && acceptEarly(alts)) deliver(alts);   // heard it — don't make them wait
    };
    rec.onerror = e => { onError && onError(e.error || "error"); done(); };
    rec.onend = () => done();
    try { rec.start(); } catch (e) { onError && onError("start-failed"); done(); return null; }
    // Watchdog: some engines (mobile Safari especially) can stall with neither a
    // result nor an end event — force a reset so you can just tap and try again.
    watchdog = setTimeout(() => { try { rec.abort(); } catch (e) {} done(); }, 12000);
    return rec;
  }
  const cleanHan = s => (s || "").replace(/[，。！？、,.!?\s·…"'“”]/g, "");
  // For acceptEarly: has a live partial ALREADY contained the whole target? Only
  // then have you actually finished the line — a prefix ("你好…" of "你好吗") must
  // NOT settle, or the mic cuts you off mid-sentence. (scoreSpeech scores a prefix
  // at .95 via exp.includes(t), which is what made early-accept too eager.)
  function saidWhole(expectedHanzi, alts) {
    const exp = cleanHan(expectedHanzi);
    if (!exp) return false;
    return alts.some(a => { const t = cleanHan(a); return t && t.includes(exp); });
  }
  // `keyword` is the word actually being practised. The recogniser often mangles
  // part of a phrase while still nailing the target word — hearing the keyword
  // back is a pass even if the rest of the transcript drifts.
  function scoreSpeech(expectedHanzi, alts, keyword) {
    const exp = cleanHan(expectedHanzi);
    let best = { level: "no", heard: alts[0] || "", ratio: 0 };
    for (const a of alts) {
      const t = cleanHan(a); if (!t) continue;
      if (t === exp) return { level: "exact", heard: a, ratio: 1 };
      if (t.includes(exp) || exp.includes(t)) { best = { level: "close", heard: a, ratio: .95 }; continue; }
      const set = new Set(t.split(""));
      const hit = [...exp].filter(c => set.has(c)).length / (exp.length || 1);
      if (hit > best.ratio) best = { level: hit >= 0.7 ? "close" : "no", heard: a, ratio: hit };
    }
    if (best.level !== "exact" && keyword) {
      const k = cleanHan(keyword);
      for (const a of alts) if (k && cleanHan(a).includes(k)) return { level: "close", heard: a, ratio: .9 };
    }
    return best;
  }
  // A "🎤 Say it & check" control (used on the pinyin flashcard).
  function pronunciationControl(hanzi) {
    const wrap = el("div", { className: "hint-wrap" });
    if (!canRecognize()) return wrap;    // gracefully absent where unsupported
    const micLabel = `<svg class="licon licon-sm"><use href="#i-mic"/></svg> Say it &amp; check`;
    const btn = el("button", { className: "hint-btn mic-btn", type: "button" });
    btn.innerHTML = micLabel;
    const fb = el("div", { className: "conv-feedback", style: "font-size:.85rem" });
    btn.addEventListener("click", e => {
      e.stopPropagation();
      fb.textContent = ""; btn.disabled = true; btn.textContent = "● Listening…"; btn.classList.add("listening");
      recognizeOnce({
        onResult: alts => {
          const r = scoreSpeech(hanzi, alts);
          fb.innerHTML = r.level === "exact" ? `<span class="ok">✓ Perfect!</span>`
            : r.level === "close" ? `<span class="ok">✓ Close</span> — heard “${r.heard}”`
            : `<span class="bad">Try again</span> — heard “${r.heard || "…"}”`;
        },
        onError: err => { fb.textContent = err === "not-allowed" ? "Allow mic access to use this." : "Didn't catch that — try again."; },
        onEnd: () => { btn.disabled = false; btn.innerHTML = micLabel; btn.classList.remove("listening"); }
      });
    });
    wrap.append(btn, fb);
    return wrap;
  }

  // Training wheels: show pinyin under characters by default (a beginner can't
  // read bare 汉字). Turn it off in Settings for a tougher, pinyin-free test.
  const showPinyin = () => prefs.showPinyin !== false;

  // A pinyin aid. With "Show pinyin" on it's just visible; off, it hides behind
  // a "Show pinyin 👀" button you tap to reveal.
  function pinyinHint(pinyin) {
    pinyin = prettyPinyin(pinyin);
    const wrap = el("div", { className: "hint-wrap" });
    if (showPinyin()) {
      wrap.appendChild(el("span", { className: "pinyin hint-text" }, pySpans(pinyin)));
      return wrap;
    }
    const btn = el("button", { className: "hint-btn", type: "button" });
    btn.innerHTML = `Show pinyin <svg class="licon licon-sm"><use href="#i-eye"/></svg>`;
    const txt = el("span", { className: "pinyin hint-text hidden" }, pinyin);
    btn.addEventListener("click", e => {
      e.stopPropagation();
      txt.classList.remove("hidden");
      btn.classList.add("hidden");
    });
    wrap.append(btn, txt);
    return wrap;
  }

  // A row of optional study aids: hear it (🔊) and/or reveal pinyin.
  function aidsRow(c, { speaker = false, pinyin = false } = {}) {
    const row = el("div", { className: "aids-row" });
    if (speaker) row.appendChild(speakerBtn(c.hanzi));
    if (pinyin) row.appendChild(pinyinHint(c.pinyin));
    return row;
  }

  // ---- Hanzi Writer (stroke order + writing) ----
  const HANZI = window.HANZI_DATA || {};
  const HW_OK = typeof window.HanziWriter !== "undefined";
  const cjkOnly = s => [...s].filter(c => /[一-鿿]/.test(c));
  const hasStrokes = ch => !!HANZI[ch];
  const wordWritable = hanzi => { const c = cjkOnly(hanzi); return c.length > 0 && c.every(hasStrokes); };

  function makeWriter(target, char, opts = {}) {
    return HanziWriter.create(target, char, Object.assign({
      width: 160, height: 160, padding: 6,
      showOutline: true,
      strokeAnimationSpeed: 1.2,
      delayBetweenStrokes: 180,
      strokeColor: getComputedStyle(document.body).getPropertyValue("--ink").trim() || "#2b2620",
      radicalColor: getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d",
      drawingColor: getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d",
      charDataLoader: (c, onComplete) => onComplete(HANZI[c])
    }, opts));
  }

  // Character modal: browse each character's strokes and practise writing.
  let modalWriters = [];
  let modalWord = null;
  const enForHanzi = hanzi => (CARDS.find(c => c.hanzi === hanzi) || {}).en || "";
  function openCharModal(hanzi, pinyin) {
    const chars = cjkOnly(hanzi);
    modalWord = { hanzi, pinyin: pinyin || "", en: enForHanzi(hanzi) };
    $("#charModalTitle").textContent = `${hanzi}${pinyin ? "  ·  " + pinyin : ""}`;
    const grid = $("#charTargets");
    grid.innerHTML = "";
    modalWriters = [];
    $("#charHint").textContent = "";

    if (!HW_OK || chars.length === 0) {
      grid.appendChild(el("div", { className: "hanzi" }, hanzi));
      $("#charAnimate").classList.add("hidden");
      $("#charPractice").classList.add("hidden");
    } else {
      $("#charAnimate").classList.remove("hidden");
      $("#charPractice").classList.remove("hidden");
      const accent = getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d";
      chars.forEach(ch => {
        const box = el("div", { className: "hz-box" });
        const lbl = el("div", { className: "lbl" });
        grid.appendChild(el("div", { className: "hz-cell" }, [box, lbl]));
        if (hasStrokes(ch)) {
          // Red strokes + a thicker pen so your writing is clearly visible.
          const w = makeWriter(box, ch, {
            strokeColor: accent, radicalColor: accent, drawingColor: accent,
            drawingWidth: Math.round(7 * 1024 / 160)
          });
          modalWriters.push({ w, box, lbl, ch });
        } else {
          box.appendChild(el("div", { className: "hanzi", style: "font-size:5rem;line-height:160px" }, ch));
          lbl.textContent = "no stroke data";
        }
      });
    }
    $("#charModal").classList.remove("hidden");
  }
  function closeCharModal() {
    $("#charModal").classList.add("hidden");
    $("#charTargets").innerHTML = "";
    modalWriters = [];
  }
  async function animateAll(writers) {
    for (const { w } of writers) {
      await new Promise(res => w.animateCharacter({ onComplete: res }));
      await new Promise(res => setTimeout(res, 150));
    }
  }
  function practiceAll(writers, hintEl) {
    let i = 0;
    const runOne = () => {
      if (i >= writers.length) { if (hintEl) hintEl.textContent = "Done. Well written."; return; }
      const { w, lbl } = writers[i];
      if (lbl) lbl.textContent = "your turn…";
      if (hintEl) hintEl.textContent = `Draw character ${i + 1} of ${writers.length}. A hint appears after a couple of misses.`;
      w.quiz({
        leniency: 1.4,
        showHintAfterMisses: 2,
        onComplete: () => { if (lbl) lbl.textContent = "✓"; i++; runOne(); }
      });
    };
    writers.forEach(({ w }) => w.hideCharacter());
    runOne();
  }
  // Small "strokes/write" button used in lists and cards.
  function strokeBtn(hanzi, pinyin) {
    const b = el("button", { className: "speaker", title: "Stroke order & writing", type: "button" });
    b.innerHTML = `<svg class="licon licon-sm"><use href="#i-pencil"/></svg>`;
    b.addEventListener("click", e => { e.stopPropagation(); openCharModal(hanzi, pinyin); });
    return b;
  }

  $("#charClose").addEventListener("click", closeCharModal);
  $("#charModal").addEventListener("click", e => { if (e.target.id === "charModal") closeCharModal(); });
  $("#charAnimate").addEventListener("click", () => animateAll(modalWriters));
  $("#charPractice").addEventListener("click", () => practiceAll(modalWriters, $("#charHint")));
  $("#charSheet").addEventListener("click", () => {
    const info = modalWord;
    closeCharModal();
    openWritingSheet(info.hanzi, info.pinyin, info.en);
  });

  /* ==================================================================== */
  /*  WRITING SHEET (字帖 copybook)                                        */
  /* ==================================================================== */

  const SVGNS = "http://www.w3.org/2000/svg";
  // Draw a character statically from its stroke paths, using Hanzi Writer's
  // coordinate transform (1024 grid, y-flipped).
  function charOutlineSVG(ch, size, color, opts = {}) {
    const data = HANZI[ch];
    const svg = document.createElementNS(SVGNS, "svg");
    svg.setAttribute("width", size);
    svg.setAttribute("height", size);
    svg.setAttribute("viewBox", `0 0 ${size} ${size}`);
    if (!data) return svg;
    const pad = size * 0.06;
    const s = (size - 2 * pad) / 1024;
    const g = document.createElementNS(SVGNS, "g");
    g.setAttribute("transform", `translate(${pad}, ${size - pad}) scale(${s}, ${-s})`);
    if (opts.opacity != null) g.setAttribute("opacity", opts.opacity);
    const strokes = opts.maxStrokes != null ? data.strokes.slice(0, opts.maxStrokes) : data.strokes;
    strokes.forEach(d => {
      const p = document.createElementNS(SVGNS, "path");
      p.setAttribute("d", d);
      p.setAttribute("fill", color);
      g.appendChild(p);
    });
    svg.appendChild(g);
    return svg;
  }

  // Copybook fade schedule: earlier rows show more strokes at higher opacity;
  // the last row is blank (write from memory).
  function copybookRowStyle(rowIdx, rows, totalStrokes) {
    const t = rows > 1 ? rowIdx / (rows - 1) : 0;      // 0 (first) .. 1 (last)
    return {
      opacity: +(0.7 - 0.7 * t).toFixed(3),
      maxStrokes: Math.round(totalStrokes * (1 - t))
    };
  }

  // A transparent canvas laid over a grid so you can trace with mouse/finger.
  function attachInkCanvas(gridEl, cell) {
    const w = gridEl.clientWidth, h = gridEl.clientHeight;
    const dpr = window.devicePixelRatio || 1;
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, w * dpr);
    canvas.height = Math.max(1, h * dpr);
    canvas.style.position = "absolute";
    canvas.style.left = "0"; canvas.style.top = "0";
    canvas.style.width = w + "px"; canvas.style.height = h + "px";
    canvas.style.touchAction = "none";
    canvas.style.cursor = "crosshair";
    const ctx = canvas.getContext("2d");
    ctx.scale(dpr, dpr);
    ctx.lineCap = "round"; ctx.lineJoin = "round";
    const color = getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d";
    const lw = Math.max(3, cell * 0.06);   // ~25% thinner than before
    ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = lw;

    const strokes = [];       // history of finished strokes (each an array of points)
    let cur = null;
    const at = e => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };
    function drawStroke(pts) {
      if (pts.length === 1) { ctx.beginPath(); ctx.arc(pts[0][0], pts[0][1], lw / 2, 0, 7); ctx.fill(); return; }
      ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1]);
      for (let i = 1; i < pts.length - 1; i++) {
        const mx = (pts[i][0] + pts[i + 1][0]) / 2, my = (pts[i][1] + pts[i + 1][1]) / 2;
        ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my);   // smoothed curve
      }
      ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
      ctx.stroke();
    }
    function redraw() { ctx.clearRect(0, 0, w, h); strokes.forEach(drawStroke); }
    canvas.addEventListener("pointerdown", e => { cur = [at(e)]; strokes.push(cur); canvas.setPointerCapture(e.pointerId); });
    canvas.addEventListener("pointermove", e => { if (!cur) return; cur.push(at(e)); redraw(); });
    const end = () => { cur = null; };
    canvas.addEventListener("pointerup", end);
    canvas.addEventListener("pointercancel", end);
    gridEl.appendChild(canvas);
    return {
      clear: () => { strokes.length = 0; redraw(); },
      undo: () => { strokes.pop(); redraw(); }
    };
  }

  // Build a 6-row fading copybook (workbook style) into `host`, with a single
  // tracing canvas over it. Returns the ink handle ({ clear }).
  function buildCopybook(host, chars, { rows = 6, cols, cell, tight = false }) {
    const ink = getComputedStyle(document.body).getPropertyValue("--ink").trim() || "#2b2620";
    const nCols = cols || (chars.length === 1 ? 6 : chars.length);
    const grid = el("div", { className: "copybook" + (tight ? " tight" : "") });
    host.appendChild(grid);
    for (let r = 0; r < rows; r++) {
      const row = el("div", { className: "writing-inline", style: tight ? "gap:0" : "gap:6px" });
      grid.appendChild(row);
      for (let col = 0; col < nCols; col++) {
        const ch = chars.length === 1 ? chars[0] : chars[col % chars.length];
        const box = el("div", { className: "tzg-cell" });
        box.style.width = box.style.height = cell + "px";
        row.appendChild(box);
        if (hasStrokes(ch)) {
          const st = copybookRowStyle(r, rows, HANZI[ch].strokes.length);
          if (st.maxStrokes > 0) {
            const svg = charOutlineSVG(ch, cell, ink, { maxStrokes: st.maxStrokes, opacity: st.opacity });
            svg.style.position = "absolute";
            svg.style.inset = "0";
            box.appendChild(svg);
          }
        } else {
          box.appendChild(el("div", { className: "hanzi", style: `font-size:2rem;line-height:${cell}px` }, ch));
        }
      }
    }
    return attachInkCanvas(grid, cell);
  }

  // Validated version: each box is a Hanzi Writer quiz — wrong strokes don't
  // register and a hint flashes after 2 misses. Top row shows a faint outline
  // to trace; lower rows are from memory.
  /* Writing help fades as a word is learnt. Stage 0, new: full outline, the
     strokes animate once, then you trace. Stage 1, learning: no outline, only
     the character's first part (its radical) shown faintly. Stage 2, known:
     a blank box, hints only after mistakes. */
  function writeStage(c) {
    const s = c && srs[c.id];
    if (!s || s.reps < 1) return 0;
    return s.interval >= MASTER_INTERVAL ? 2 : 1;
  }
  const STAGE_INFO = [
    { chip: "New", note: "Watch the strokes, then trace over them.", hint: 1 },
    { chip: "Learning", note: "The first part is shown. Write the whole character.", hint: 2 },
    { chip: "From memory", note: "Write it from memory. A hint shows after a few misses.", hint: 3 }
  ];
  // The first part of a character (its radical, or the first third of its
  // strokes) drawn faintly as a guide, in the same box as the writer.
  function partGuide(ch, cell) {
    const d = HANZI[ch]; if (!d) return null;
    const idx = d.radStrokes && d.radStrokes.length && d.radStrokes.length < d.strokes.length
      ? d.radStrokes : d.strokes.map((_, i) => i).slice(0, Math.max(1, Math.ceil(d.strokes.length / 3)));
    const pad = 6 * 1024 / Math.max(40, cell - 12);
    const ns = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", `${-pad} ${-pad} ${1024 + 2 * pad} ${1024 + 2 * pad}`);
    svg.setAttribute("class", "part-guide");
    const g = document.createElementNS(ns, "g");
    g.setAttribute("transform", "translate(0, 900) scale(1, -1)");
    idx.forEach(i => { const p = document.createElementNS(ns, "path"); p.setAttribute("d", d.strokes[i]); g.appendChild(p); });
    svg.appendChild(g);
    return svg;
  }
  function buildCheckGrid(host, chars, { rows, cols, cell, tight = false, onAllDone = null, stage = 0 }) {
    const accent = getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d";
    // drawingWidth is in the 1024-unit glyph space, so scale it up for small
    // cells to keep the pen ~7px on screen regardless of box size.
    const pen = Math.round(7 * 1024 / cell);
    const grid = el("div", { className: "copybook" + (tight ? " tight" : "") });
    host.appendChild(grid);
    // Gate: every distinct character must be written correctly at least once
    // (extra boxes are optional practice). Fires onAllDone when that's satisfied.
    const need = new Set(chars.filter(c => hasStrokes(c)));
    const written = new Set();
    const markWritten = ch => {
      written.add(ch);
      if (onAllDone && written.size >= need.size) onAllDone();
    };
    if (onAllDone && need.size === 0) onAllDone();   // no stroke data — nothing to gate on
    for (let r = 0; r < rows; r++) {
      const row = el("div", { className: "writing-inline", style: tight ? "gap:0" : "gap:6px" });
      grid.appendChild(row);
      for (let col = 0; col < cols; col++) {
        const ch = chars.length === 1 ? chars[0] : chars[col % chars.length];
        const box = el("div", { className: "tzg-cell" });
        box.style.width = box.style.height = cell + "px";
        row.appendChild(box);
        if (!hasStrokes(ch)) { box.appendChild(el("div", { className: "hanzi", style: `line-height:${cell}px` }, ch)); continue; }
        if (stage === 1 && r === 0) { const guide = partGuide(ch, cell); if (guide) box.appendChild(guide); }
        const w = makeWriter(box, ch, {
          width: cell, height: cell, showOutline: stage === 0 && r === 0, showCharacter: false,
          drawingWidth: pen, drawingColor: accent,
          // Completed strokes in red (like the pen) so it's obvious they registered.
          strokeColor: accent, radicalColor: accent
        });
        const quiz = () => w.quiz({ leniency: 1.4, showHintAfterMisses: STAGE_INFO[stage].hint, onComplete: () => markWritten(ch) });
        // a new character plays its strokes once in the box before you trace it
        if (stage === 0 && r === 0 && col === 0) w.animateCharacter({ onComplete: () => setTimeout(quiz, 350) });
        else quiz();
      }
    }
  }

  // Other vocabulary words that contain this character (like 组词 examples).
  function exampleWords(ch, excludeHanzi) {
    const seen = new Set();
    const out = [];
    for (const c of CARDS) {
      if (c.hanzi === excludeHanzi) continue;
      if (c.hanzi.length > 1 && c.hanzi.includes(ch) && !seen.has(c.hanzi)) {
        seen.add(c.hanzi);
        out.push(c);
        if (out.length >= 4) break;
      }
    }
    return out;
  }

  let sheetChars = [], sheetIdx = 0, sheetWord = null, sheetInk = null;

  function openWritingSheet(hanzi, pinyin, en) {
    sheetWord = { hanzi, pinyin, en };
    sheetChars = cjkOnly(hanzi).filter(hasStrokes);
    sheetIdx = 0;
    if (sheetChars.length === 0) { toast("No stroke data for this word yet."); return; }
    $("#sheetTitle").textContent = `Writing sheet · ${hanzi}`;
    // Character tabs (only when the word has more than one character)
    const tabs = $("#sheetTabs");
    tabs.innerHTML = "";
    if (sheetChars.length > 1) {
      sheetChars.forEach((ch, i) => {
        const t = el("button", { className: "sheet-tab" + (i === 0 ? " on" : "") }, ch);
        t.addEventListener("click", () => { sheetIdx = i; renderSheetChar(); });
        tabs.appendChild(t);
      });
    }
    show("sheet");
    renderSheetChar();
  }

  function renderSheetChar() {
    const ch = sheetChars[sheetIdx];
    [...$("#sheetTabs").children].forEach((t, i) => t.classList.toggle("on", i === sheetIdx));

    // Header: big character, pinyin, meaning, stroke count, example words.
    const strokes = (HANZI[ch] && HANZI[ch].strokes.length) || "?";
    const examples = exampleWords(ch, sheetWord.hanzi);
    const header = $("#sheetHeader");
    header.innerHTML = "";
    // Big animated character (tap to watch the strokes).
    const big = el("div", { className: "big-char" });
    big.style.cssText = "cursor:pointer;width:96px;height:96px;";
    header.appendChild(big);
    const bigW = makeWriter(big, ch, { width: 96, height: 96, showCharacter: true });
    big.addEventListener("click", () => bigW.animateCharacter());
    const meta = el("div", { className: "meta" }, [
      el("div", { className: "py" }, prettyPinyin(sheetWord.pinyin)),
      el("div", { className: "en" }, sheetWord.en),
      el("div", { className: "facts" }, `笔画 (strokes): ${strokes}`)
    ]);
    if (examples.length)
      meta.appendChild(el("div", { className: "facts" },
        "组词: " + examples.map(e => `${e.hanzi} (${prettyPinyin(e.pinyin)})`).join("，")));
    header.appendChild(meta);

    // Validated 田字格 grid: draw each box and correct strokes fill in red.
    // First row shows a faint outline to trace; the rest are from memory.
    const grid = $("#sheetGrid");
    grid.innerHTML = "";
    sheetInk = null;
    const avail = (grid.clientWidth || 340) - 4;   // fit the card width on any screen
    const cell = Math.max(64, Math.min(110, Math.floor(avail / 4)));
    buildCheckGrid(grid, [ch], { rows: 4, cols: 4, cell, tight: true });
  }

  // Printable copybook: rows of 田字格, fading from full outline to blank.
  function printSheet() {
    const ch = sheetChars[sheetIdx];
    const area = $("#printArea");
    area.innerHTML = "";
    const strokes = (HANZI[ch] && HANZI[ch].strokes.length) || "?";
    area.appendChild(el("h1", { className: "print-title" },
      `${ch}   ${prettyPinyin(sheetWord.pinyin)}`));
    area.appendChild(el("div", { className: "print-sub" },
      `${sheetWord.en}   ·   笔画 (strokes): ${strokes}`));

    const COLS = 9, ROWS = 6;
    const MM = 68; // px used for the SVG raster inside each 18mm cell (crisp enough)
    const total = (HANZI[ch] && HANZI[ch].strokes.length) || 0;
    for (let r = 0; r < ROWS; r++) {
      const st = copybookRowStyle(r, ROWS, total);   // fades + fewer strokes each row
      const row = el("div", { className: "print-row" });
      for (let c = 0; c < COLS; c++) {
        const cell = el("div", { className: "print-cell" });
        if (st.maxStrokes > 0) {
          const shade = r === 0 ? "#e2001a" : "#222";  // first row pink, rest grey
          const svg = charOutlineSVG(ch, MM, shade,
            { maxStrokes: st.maxStrokes, opacity: r === 0 ? 0.6 : Math.max(0.2, st.opacity + 0.1) });
          svg.setAttribute("width", "100%");
          svg.setAttribute("height", "100%");
          cell.appendChild(svg);
        }
        row.appendChild(cell);
      }
      area.appendChild(row);
    }

    area.classList.remove("hidden");
    window.print();
  }

  $("#sheetBack").addEventListener("click", () => { show("path"); renderPath(); });
  $("#sheetReset").addEventListener("click", renderSheetChar);
  $("#sheetPrint").addEventListener("click", printSheet);

  /* ==================================================================== */
  /*  CONVERSE (roleplay + speaking)                                      */
  /* ==================================================================== */

  const DIALOGUES = window.DIALOGUES || [];
  let convDlg = null, convTurn = 0;

  function openConverse() {
    show("converse");
    $("#convTitle").textContent = "Converse";
    $("#convBubbles").innerHTML = "";
    $("#convControls").innerHTML = "";
    // Dialogue picker. The label lives OUTSIDE the horizontal-scroll row — inside
    // it, the edge-fade mask clipped "…to roleplay:".
    const picker = $("#convPicker");
    picker.innerHTML = "";
    DIALOGUES.forEach(d => {
      const b = el("button", { className: "chip" }, `${d.title}  ·  ${d.lesson}`);
      b.addEventListener("click", () => startConversation(d));
      picker.appendChild(b);
    });
    if (!canRecognize())
      $("#convControls").appendChild(el("div", { className: "muted", style: "font-size:.8rem" },
        "Tip: the speaking-check needs Chrome or Edge. You can still roleplay by tapping “I said it”."));
  }

  function startConversation(d) {
    convDlg = d; convTurn = 0;
    const picker = $("#convPicker");
    let onChip = null;
    [...picker.querySelectorAll(".chip")].forEach(c => {
      const on = c.textContent.startsWith(d.title);
      c.classList.toggle("on", on); if (on) onChip = c;
    });
    // bring the chosen chip fully into view (never half-clipped at an edge)
    if (onChip) picker.scrollTo({ left: Math.max(0, onChip.offsetLeft - 16), behavior: "smooth" });
    $("#convTitle").textContent = `Converse · ${d.title}`;
    $("#convBubbles").innerHTML = "";
    stepConversation();
  }

  function addBubble(turn) {
    const b = el("div", { className: "bubble " + turn.who }, [
      el("div", { className: "b-han" }, turn.hanzi),
      el("div", { className: "b-py" }, prettyPinyin(turn.pinyin)),
      el("div", { className: "b-en" }, turn.en)
    ]);
    const acts = el("div", { className: "b-acts" }, [speakerBtn(turn.hanzi), slowSpeakerBtn(turn.hanzi)]);
    b.appendChild(acts);
    const box = $("#convBubbles");
    box.appendChild(b);
    box.scrollTop = box.scrollHeight;
    return b;
  }

  function stepConversation() {
    const ctrl = $("#convControls");
    ctrl.innerHTML = "";
    if (!convDlg || convTurn >= convDlg.turns.length) {
      ctrl.appendChild(el("div", { className: "muted", style: "text-align:center" }, "End of conversation."));
      const again = el("button", { className: "primary" }, "↻ Start over");
      again.addEventListener("click", () => startConversation(convDlg));
      ctrl.appendChild(again);
      return;
    }
    const turn = convDlg.turns[convTurn];
    if (turn.who === "app") {
      addBubble(turn);
      speak(turn.hanzi);
      convTurn++;
      setTimeout(stepConversation, 1100);   // let the line be heard, then continue
    } else {
      renderYourTurn(turn);
    }
  }

  function renderYourTurn(turn) {
    const ctrl = $("#convControls");
    ctrl.innerHTML = "";
    const goal = el("div", { className: "your-goal" }, [
      el("div", { className: "muted", style: "font-size:.78rem;letter-spacing:1px" }, "YOUR TURN — SAY:"),
      el("div", { className: "b-py", style: "font-size:1.25rem" }, prettyPinyin(turn.pinyin)),
      el("div", { className: "b-en" }, turn.en)
    ]);
    const chars = el("div", { className: "b-han hidden", style: "font-size:1.6rem;margin-top:4px" }, turn.hanzi);
    goal.appendChild(chars);
    ctrl.appendChild(goal);

    const feedback = el("div", { className: "conv-feedback" });
    const advance = () => { addBubble(turn); convTurn++; stepConversation(); };

    const btns = el("div", { className: "conv-btns" });
    const hear = el("button", { className: "ghost" });
    hear.innerHTML = `<svg class="licon licon-sm"><use href="#i-volume"/></svg> Hear it`;
    hear.addEventListener("click", () => speak(turn.hanzi));
    const showCh = el("button", { className: "ghost" }, "Show characters");
    showCh.addEventListener("click", () => chars.classList.remove("hidden"));
    btns.appendChild(hear);
    btns.appendChild(showCh);

    if (canRecognize() && !turn.free) {
      const micLbl = `<svg class="licon licon-sm"><use href="#i-mic"/></svg> Speak`;
      const mic = el("button", { className: "primary mic-btn" });
      mic.innerHTML = micLbl;
      mic.addEventListener("click", () => {
        feedback.textContent = "";
        mic.disabled = true; mic.textContent = "● Listening…"; mic.classList.add("listening");
        recognizeOnce({
          // Show what it's hearing live, and settle the instant the line lands —
          // otherwise it waits for the engine to time out on silence, which is
          // the delay you feel after you've finished speaking.
          onInterim: alts => { if (alts[0]) feedback.innerHTML = `<span class="muted">heard: ${alts[0]}…</span>`; },
          // settle only once you've said the WHOLE line — never mid-sentence
          acceptEarly: alts => saidWhole(turn.hanzi, alts),
          onResult: alts => {
            const r = scoreSpeech(turn.hanzi, alts);
            if (r.level === "exact" || r.level === "close") {
              feedback.innerHTML = `<span class="ok">✓ ${r.level === "exact" ? "Perfect" : "Close enough"}</span> — heard “${r.heard}”`;
              setTimeout(advance, 900);
            } else {
              feedback.innerHTML = `<span class="bad">Not quite</span> — heard “${r.heard || "…"}”. Try again, or tap “I said it”.`;
            }
          },
          onError: err => { feedback.textContent = err === "not-allowed"
            ? "Microphone blocked — allow mic access, or tap “I said it”." : "Didn't catch that — try again."; },
          onEnd: () => { mic.disabled = false; mic.innerHTML = micLbl; mic.classList.remove("listening"); }
        });
      });
      btns.appendChild(mic);
    }
    const said = el("button", { className: canRecognize() && !turn.free ? "ghost" : "primary" },
      turn.free ? "I said it →" : "Skip / I said it →");
    said.addEventListener("click", advance);
    btns.appendChild(said);

    ctrl.appendChild(btns);
    ctrl.appendChild(feedback);
  }

  $("#convBack").addEventListener("click", () => { speechSynthesis.cancel(); goBack(); });

  /* ==================================================================== */
  /*  HOME                                                                */
  /* ==================================================================== */

  const selectedLessons = new Set(prefs.lessons && prefs.lessons.length ? prefs.lessons : LESSONS.map(l => l.id));
  const selectedFocuses = new Set(prefs.focuses && prefs.focuses.length ? prefs.focuses : FOCUSES.map(f => f.key));

  function persistPrefs() {
    prefs.lessons = [...selectedLessons];
    prefs.focuses = [...selectedFocuses];
    savePrefs(prefs);
  }

  function lessonMastered(lessonId) {
    return CARDS.reduce((n, c) => n + (c.lessonId === lessonId && isMastered(srs[c.id]) ? 1 : 0), 0);
  }

  // Progress screen: per-chapter mastery bars, to fill the page with something useful.
  function renderProgressBreakdown() {
    const box = $("#progBreak");
    if (!box) return;
    box.innerHTML = "";
    let curUnit = null;
    CHAPTERS.forEach(ch => {
      if (ch.unit !== curUnit) {
        curUnit = ch.unit;
        box.appendChild(el("div", { className: "pb-unit" }, `${ch.unit}`));
      }
      let total = 0, mastered = 0;
      ch.lessons.forEach(id => { total += lessonCardCount(id); mastered += lessonMastered(id); });
      const pct = total ? Math.round(mastered / total * 100) : 0;
      const row = el("div", { className: "pb-row" + (total && mastered === total ? " done" : "") }, [
        el("div", { className: "pb-name" }, ch.title),
        el("div", { className: "pb-count" }, `${mastered} / ${total}`),
        el("div", { className: "pb-bar" }, el("i", { style: `width:${pct}%` }))
      ]);
      box.appendChild(row);
    });
  }

  /* ---- Avatar --------------------------------------------------------------
     The modular wardrobe: every option is a full-canvas Photoshop layer listed
     in avatar-modular-data.js, resolved by makeModularAvatar and stacked in
     drawAvatar. Saved avatars from the two earlier systems (the first canvas
     engine, and the v2 "complete look" catalogue) are migrated on read; the
     v2 outfit ids need this table to become a top, bottom and shoes. */
  const LEGACY_OUTFITS = [
    {"id":"hoodie_trousers","top":"Cream hoodie","bottom":"Blue trousers","shoes":"Cream trainers"},
    {"id":"jacket","top":"Yellow jacket","bottom":"Blue trousers","shoes":"Cream trainers"},
    {"id":"shorts","top":"Cream hoodie","bottom":"Teal shorts","shoes":"Cream trainers"},
    {"id":"skirt","top":"Cream hoodie","bottom":"Coral skirt","shoes":"Cream trainers"},
    {"id":"shoes","top":"Cream hoodie","bottom":"Blue trousers","shoes":"Charcoal trainers"},
    {"id":"teal_tan","top":"Teal hoodie","bottom":"Tan trousers","shoes":"Cream trainers"},
    {"id":"blue_charcoal","top":"Blue sweatshirt","bottom":"Charcoal shorts","shoes":"Cream trainers"},
    {"id":"striped_blue","top":"Striped top","bottom":"Blue shorts","shoes":"Cream trainers"},
    {"id":"dark_hoodie","top":"Dark hoodie","bottom":"Blue trousers","shoes":"Cream trainers"},
    {"id":"coral_sweatshirt","top":"Coral sweatshirt","bottom":"Blue trousers","shoes":"Cream trainers"},
    {"id":"cream_cardigan","top":"Cream cardigan","bottom":"Blue trousers","shoes":"Cream trainers"},
    {"id":"tan_shorts","top":"Cream hoodie","bottom":"Tan shorts","shoes":"Cream trainers"},
    {"id":"dark_trousers","top":"Cream hoodie","bottom":"Charcoal trousers","shoes":"Cream trainers"},
    {"id":"cream_skirt","top":"Cream hoodie","bottom":"Cream skirt","shoes":"Cream trainers"},
    {"id":"brown_shoes","top":"Cream hoodie","bottom":"Blue trousers","shoes":"Brown shoes"}
  ];
  const modular = makeModularAvatar(MODULAR_AVATAR_DATA);
  const avatarCfg = () => modular.migrate(prefs.avatar, LEGACY_OUTFITS);
  const wardrobeImages = new Map(), avatarDrawTokens = new WeakMap();
  function wardrobeImage(path) {
    if (!wardrobeImages.has(path)) {
      const request = new Promise((resolve,reject) => {
        const image = new Image(); image.onload = () => resolve(image);
        image.onerror = () => { wardrobeImages.delete(path); reject(new Error('Connect to load this look, then try again.')); };
        image.src = path + ASSET_V;
      });
      wardrobeImages.set(path,request);
      // Keep thumbnail browsing from retaining the entire catalogue in memory.
      if (wardrobeImages.size>40) wardrobeImages.delete(wardrobeImages.keys().next().value);
    }
    return wardrobeImages.get(path);
  }
  async function drawAvatar(canvas,cfg,opts={}) {
    if (!canvas) return false;
    const token={};avatarDrawTokens.set(canvas,token);
    canvas.setAttribute('aria-busy','true');
    try {
      const images=await Promise.all(modular.paths(cfg).map(wardrobeImage));
      if (avatarDrawTokens.get(canvas)!==token) return false;
      const full=document.createElement('canvas');full.width=full.height=1024;
      const fx=full.getContext('2d');images.forEach(image=>fx.drawImage(image,0,0,1024,1024));
      const crop=opts.crop||[0,0,1,1],size=Math.min(1024,Math.round((opts.size||512)*Math.min(3,window.devicePixelRatio||1)));
      canvas.width=Math.round(size*crop[2]/Math.max(crop[2],crop[3]));canvas.height=Math.round(size*crop[3]/Math.max(crop[2],crop[3]));
      const x=canvas.getContext('2d');x.imageSmoothingQuality='high';
      x.drawImage(full,crop[0]*1024,crop[1]*1024,crop[2]*1024,crop[3]*1024,0,0,canvas.width,canvas.height);
      canvas.removeAttribute('data-error');return true;
    } catch(error) {
      if (avatarDrawTokens.get(canvas)!==token) return false;
      canvas.getContext('2d').clearRect(0,0,canvas.width,canvas.height);
      canvas.dataset.error=error.message;
      if (canvas.id==='avPreview') $('#avStatus').textContent=error.message;
      if (canvas.id==='profAvatar') canvas.setAttribute('aria-label','Avatar unavailable offline; connect to load it.');
      return false;
    } finally { if(avatarDrawTokens.get(canvas)===token) canvas.setAttribute('aria-busy','false'); }
  }
  let wardrobeRender=0, wardrobePick=0;
  let modularCategory='top', modularSection='Outfit', avatarDraft=null;
  const modularSections={Face:['tone','eyes','brows','mouth'],Hair:['hair','hairColour'],Outfit:['top','bottom','shoes'],Extras:['accessory']};
  function renderModularBuilder(cfg) {
    const generation=++wardrobeRender;
    $('#avStatus').textContent='';
    const banner=$('#avMigration');banner.replaceChildren();
    drawAvatar($('#avPreview'),cfg,{size:640});
    const categories=[['top','Tops'],['bottom','Bottoms'],['shoes','Shoes'],['accessory','Accessories'],['hair','Hair'],['hairColour','Hair colour'],['tone','Skin'],['eyes','Eyes'],['brows','Brows'],['mouth','Mouth']];
    const main=$('#avMain');main.replaceChildren();
    for(const [name,icon] of [['Face','i-avatar-face'],['Hair','i-avatar-hair'],['Outfit','i-avatar-shirt'],['Extras','i-star']]){const b=el('button',{type:'button',className:name===modularSection?'on':''});b.innerHTML=svgUse(icon)+'<span>'+name+'</span>';b.setAttribute('aria-pressed',String(name===modularSection));b.onclick=()=>{modularSection=name;modularCategory=modularSections[name][0];renderAvatarBuilder();};main.append(b);}
    const cats=$('#avCats');cats.replaceChildren();
    for(const [key,label] of categories.filter(([key])=>modularSections[modularSection].includes(key))){
      const b=el('button',{type:'button',className:'chip'+(modularCategory===key?' on':'')},label);
      b.setAttribute('aria-pressed',String(modularCategory===key));b.onclick=()=>{modularCategory=key;renderAvatarBuilder();};cats.append(b);
    }
    const box=$('#avOpts');box.replaceChildren();box.className='av-opts '+(modularCategory==='tone'?'swatches':'tiles');
    for(const option of modular.options(cfg,modularCategory)){
      const b=el('button',{type:'button',className:(option.swatch?'swatch':'av-tile')+(option.on?' on':'')});
      b.setAttribute('aria-label',option.label);b.setAttribute('aria-pressed',String(option.on));b.disabled=!option.next;
      if(option.swatch)b.style.background=option.swatch;
      else {
        const state=option.next,key=modularCategory;
        const path=key==='hair'||key==='hairColour'?MODULAR_AVATAR_DATA.hair[state.hair][state.hairColour]:MODULAR_AVATAR_DATA[key]?.[state[key]];
        if(path){const img=el('img',{src:MODULAR_AVATAR_DATA.thumbnails[path],alt:'',width:80,height:80});img.loading='lazy';img.decoding='async';b.append(img);}
        if(!['top','bottom','shoes'].includes(modularCategory))b.append(el('span',{},option.label));
      }
      b.onclick=async()=>{const pick=++wardrobePick;b.setAttribute("aria-busy","true");try{
        await Promise.all(modular.paths(option.next).map(wardrobeImage));
        if(generation!==wardrobeRender||pick!==wardrobePick)return;
        avatarDraft={...option.next};renderAvatarBuilder();
      }catch(e){if(generation===wardrobeRender)$('#avStatus').textContent=e.message;}finally{b.removeAttribute('aria-busy');}};box.append(b);
    }
    $('#avHelp').textContent=modularSection==='Extras'?'More accessories are coming soon.':'';
  }

  function renderAvatarBuilder() { if(!avatarDraft)avatarDraft={...avatarCfg()};renderModularBuilder(avatarDraft); }
  $("#avReset").onclick=()=>{++wardrobePick;avatarDraft={...avatarCfg()};renderAvatarBuilder();};
  $("#avSave").onclick=()=>{++wardrobePick;prefs.avatar={...(avatarDraft||avatarCfg())};savePrefs(prefs);avatarDraft=null;renderDashboard();show("progress");toast("Avatar saved");};

  $("#avBack").addEventListener("click", () => { ++wardrobePick;avatarDraft=null;renderDashboard(); show("progress"); });
  $("#actSeg").querySelectorAll("button").forEach(b => b.addEventListener("click", () => {
    $("#actSeg").querySelectorAll("button").forEach(x => x.classList.toggle("on", x === b));
    $("#actMonth").classList.toggle("hidden", b.dataset.act !== "month");
    $("#actWeek").classList.toggle("hidden", b.dataset.act !== "week");
    $("#actChars").classList.toggle("hidden", b.dataset.act !== "chars");
  }));
  // every character from your lessons as a small square, darker when stronger
  function renderCharGrid() {
    const g = $("#charGridP"); if (!g) return;
    g.innerHTML = "";
    let known = 0, learning = 0, due = 0;
    allChars().forEach(({ ch }) => {
      const lv = charLevel(ch), d = lv > 0 && charDue(ch);
      if (lv >= 2) known++; else if (lv === 1) learning++;
      if (d) due++;
      const i = el("i", { className: "k" + lv + (d ? " due" : ""), title: `${ch} ${charPy(ch)} · ${charEn(ch)}` });
      g.appendChild(i);
    });
    $("#charGridSum").textContent = `${known} strong · ${learning} learning · ${due} due`;
  }
  $("#profCharsStat").addEventListener("click", openChars);
  $("#charGridOpen").addEventListener("click", openChars);

  /* ---- Achievements ------------------------------------------------------
     Derived from what is already tracked, so nothing new to save except the
     day each was first seen (kept in the activity log, for ordering). */
  const learnedCount = () => CARDS.filter(c => srs[c.id] && srs[c.id].reps >= 1).length;
  // Built when asked for: the chapter table is defined further down the file.
  const achievementDefs = () => [
    { id: "streak-7", icon: "i-flame-solid", tint: "red", title: "7-day streak", sub: "Keep it going!", test: () => computeStreak() >= 7 },
    { id: "streak-30", icon: "i-flame-solid", tint: "red", title: "30-day streak", sub: "A whole month", test: () => computeStreak() >= 30 },
    { id: "words-50", icon: "i-seed", tint: "green", title: "First words", sub: "Learned 50 words", test: () => learnedCount() >= 50 },
    { id: "words-200", icon: "i-seed", tint: "green", title: "Growing", sub: "Learned 200 words", test: () => learnedCount() >= 200 },
    { id: "lessons-10", icon: "i-flag", tint: "teal", title: "On a roll", sub: "10 lessons", test: () => doneLessons.size >= 10 },
    { id: "level-5", icon: "i-crown", tint: "gold", title: "Level 5", sub: "1,000 XP", test: () => levelInfo().level >= 5 },
    { id: "level-10", icon: "i-crown", tint: "gold", title: "Level 10", sub: "5,500 XP", test: () => levelInfo().level >= 10 },
    { id: "quests-20", icon: "i-target", tint: "teal", title: "Quest month", sub: "20 quests in a month", test: () => Object.values(activity.questMonths || {}).some(n => n >= 20) },
    { id: "chests-10", icon: "i-target", tint: "gold", title: "Treasure hunter", sub: "10 chests opened", test: () => (activity.chests || 0) >= 10 },
    ...CHAPTERS.map((ch, i) => ({ id: "chapter-" + i, icon: "i-book", tint: "blue", title: `Chapter ${i + 1} complete`, sub: ch.title,
      test: () => ch.lessons.every(id => doneLessons.has(id)) }))
  ];
  let ACHIEVEMENTS = null;
  let achShowAll = false;
  function renderAchievements() {
    const row = $("#achRow"); if (!row) return;
    if (!ACHIEVEMENTS) ACHIEVEMENTS = achievementDefs();
    activity.achv = activity.achv || {};
    let changed = false;
    ACHIEVEMENTS.forEach(d => { if (!activity.achv[d.id] && d.test()) { activity.achv[d.id] = todayStr(); changed = true; } });
    if (changed) { localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity)); queueSync(); }
    const earned = ACHIEVEMENTS.filter(d => activity.achv[d.id]).sort((x, y) => activity.achv[y.id].localeCompare(activity.achv[x.id]));
    const locked = ACHIEVEMENTS.filter(d => !activity.achv[d.id]);
    const list = achShowAll ? [...earned, ...locked] : [...earned, ...locked].slice(0, 4);
    row.classList.toggle("all", achShowAll);
    row.innerHTML = "";
    list.forEach(d => {
      const t = el("div", { className: "ach" + (activity.achv[d.id] ? "" : " locked") });
      t.innerHTML = `<div class="ai ${d.tint}">${svgUse(d.icon)}</div><b>${d.title}</b><span>${d.sub}</span>`;
      row.appendChild(t);
    });
    $("#achAll").textContent = achShowAll ? "Show fewer" : "See all ›";
  }

  // The learning-path card: the chapter you are in, and how far through it.
  function renderProfilePath() {
    const card = $("#profPath"); if (!card) return;
    const curId = currentLessonId();
    const ci = CHAPTERS.findIndex(ch => ch.lessons.includes(curId));
    const ch = CHAPTERS[ci >= 0 ? ci : CHAPTERS.length - 1];
    const done = ch.lessons.filter(id => doneLessons.has(id)).length, total = ch.lessons.length;
    const unitCh = CHAPTERS.slice(0, (ci >= 0 ? ci : CHAPTERS.length - 1) + 1).filter(c => c.unit === ch.unit).length;
    card.innerHTML =
      `<div class="hc-body"><div class="eyebrow">Learning path</div>` +
      `<div class="hc-title">${ch.unit} · Chapter ${unitCh}</div><div class="hc-en">${ch.title}</div>` +
      `<div class="hc-bar"><i style="width:${Math.round(done / total * 100)}%"></i></div>` +
      `<div class="hc-row">${done} / ${total} lessons</div></div>` +
      `<span class="hc-go" aria-label="Open the path">${svgUse("i-chevron")}</span>`;
    card.onclick = () => { show("path"); renderPath(); };
  }

  // This month as a grid: lit days filled, goal days gold, relit days marked
  // with an ember, plus the longest streak ever recorded.
  function renderStreakCal() {
    const cal = $("#streakCal"); if (!cal) return;
    const now = new Date(), y = now.getFullYear(), m = now.getMonth();
    const first = new Date(y, m, 1), days = new Date(y, m + 1, 0).getDate();
    const today = todayStr();
    $("#calTitle").textContent = first.toLocaleDateString(undefined, { month: "long", year: "numeric" });
    const best = Math.max(activity.best || 0, computeStreak());
    $("#calBest").textContent = `Longest ${best} day${best === 1 ? "" : "s"}`;
    cal.innerHTML = "";
    ["M", "T", "W", "T", "F", "S", "S"].forEach(n => cal.appendChild(el("span", { className: "cal-h" }, n)));
    for (let i = 0; i < (first.getDay() + 6) % 7; i++) cal.appendChild(el("span"));
    for (let d = 1; d <= days; d++) {
      const key = dateStr(new Date(y, m, d));
      const cls = ["cal-d"];
      if (litOn(key)) cls.push("lit");
      if (goalMetOn(key)) cls.push("goal");
      if (activity.relit && activity.relit[key]) cls.push("relit");
      if (key === today) cls.push("today");
      if (key > today) cls.push("future");
      const c = el("span", { className: cls.join(" ") }, String(d));
      if (cls.includes("relit")) c.innerHTML = svgUse("i-ember");
      cal.appendChild(c);
    }
  }
  function renderXpWeek() {
    const wk = $("#xpWeek"); if (!wk) return;
    wk.innerHTML = "";
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const monday = new Date(today); monday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
    const vals = [];
    for (let i = 0; i < 7; i++) { const d = new Date(monday); d.setDate(monday.getDate() + i); vals.push(xpOn(dateStr(d))); }
    const max = Math.max(20, ...vals);
    const names = ["M", "T", "W", "T", "F", "S", "S"];
    vals.forEach((v, i) => {
      const d = new Date(monday); d.setDate(monday.getDate() + i);
      wk.appendChild(el("div", { className: "xw" + (d.getTime() === today.getTime() ? " today" : "") + (d > today ? " future" : "") }, [
        el("b", {}, v ? String(v) : ""), el("i", { style: `height:${Math.max(4, Math.round(v / max * 100))}%` }), el("span", {}, names[i])
      ]));
    });
  }

  function renderDashboard() {
    renderProgressBreakdown();
    const streak = computeStreak(), out = outSince();
    $("#streakNum").textContent = out ? out.lost : streak;
    $("#streakSub").textContent = out ? "Went out" : "Day streak";
    $(".prof-stats").classList.toggle("out", !!out);
    const rl = $("#relightBtn");
    rl.classList.toggle("hidden", !out); rl.disabled = embers() < 1; rl.textContent = embers() < 1 ? "No embers to relight" : "Relight the fire";
    $("#emberNum").textContent = embers();
    $("#emberSub").textContent = embers() === 1 ? "ember" : "embers";
    const lv = levelInfo();
    $("#profName").textContent = displayName() || "Learner";
    $("#profXpTotal").textContent = lv.total.toLocaleString();
    $("#profLessons").textContent = charsKnown();
    renderCharGrid();
    $("#profLevelNum").textContent = lv.level;
    $("#profXp").textContent = `Level ${lv.level} · ${lv.next} XP to go`;
    drawAvatar($("#profAvatar"), avatarCfg(), { size: 768 });
    renderProfilePath(); renderAchievements(); renderXpWeek(); renderStreakCal();
    // Panel summary
    const nL = selectedLessons.size, nF = selectedFocuses.size;
    if ($("#panelSummary")) $("#panelSummary").textContent =
      `· ${nL === LESSONS.length ? "all lessons" : nL + " lesson" + (nL === 1 ? "" : "s")}, ${nF} focus${nF === 1 ? "" : "es"}`;
    const foot = $("#backupFoot");
    if (foot) {
      foot.textContent = backupAgeText();
      foot.classList.toggle("stale", !lastBackupAt() || (NOW() - lastBackupAt()) / DAY >= STALE_DAYS);
    }
  }

  function chapterLabelFor(id) {
    const unitCh = {};
    for (const ch of CHAPTERS) {
      unitCh[ch.unit] = (unitCh[ch.unit] || 0) + 1;
      if (ch.lessons.includes(id)) return `${ch.unit} · CHAPTER ${unitCh[ch.unit]}`;
    }
    return "";
  }
  const svgUse = id => `<svg class="licon licon-sm"><use href="#${id}"/></svg>`;

  // The Home landing: greeting, the Continue card, and the Review link.
  // A friendly name for the greeting: what you set in Settings, else a tidied-up
  // version of your sign-in email, else nothing.
  function displayName() {
    if (prefs.name && prefs.name.trim()) return prefs.name.trim();
    const e = (typeof userEmail === "function") ? userEmail() : "";
    if (!e) return "";
    const local = e.split("@")[0].split(/[._+-]/)[0].replace(/\d+/g, "");
    return local ? local.charAt(0).toUpperCase() + local.slice(1) : "";
  }

  // Time-of-day greeting, as in the mock ("Good morning!"), with the name if we have one.
  function greetingWord() {
    const h = new Date().getHours();
    return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
  }
  // This week's seven days, Monday first. Filled = the fire was lit that day; gold = the goal was met too.
  function renderWeekStrip(strip = $("#weekStrip")) {
    if (!strip) return;
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const monday = new Date(today); monday.setDate(today.getDate() - ((today.getDay() + 6) % 7));
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    strip.innerHTML = "";
    for (let i = 0; i < 7; i++) {
      const d = new Date(monday); d.setDate(monday.getDate() + i);
      const key = dateStr(d);
      const cls = ["wd"];
      if (litOn(key)) cls.push("met");
      if (goalMetOn(key)) cls.push("goal");
      if (d.getTime() === today.getTime()) cls.push("today");
      if (d > today) cls.push("future");
      const ring = el("i"); ring.innerHTML = svgUse("i-tick");
      strip.appendChild(el("div", { className: cls.join(" ") }, [ring, el("span", {}, names[i])]));
    }
  }

  function renderHomeTop() {
    const name = displayName();
    $("#greetH").textContent = `${greetingWord()}${name ? ", " + name : ""}!`;
    const streak = computeStreak(), goal = dailyGoal(), xp = todayXP(), lit = litOn(todayStr());
    const out = outSince();
    // from six in the evening an unlit day with a streak behind it is at risk
    const hoursLeft = 24 - new Date().getHours(), risk = !out && !lit && streak > 0 && hoursLeft <= 6;
    $(".streak-card").classList.toggle("out", !!out);
    $(".streak-card").classList.toggle("lit", lit && !out);
    $(".streak-card").classList.toggle("risk", risk);
    $("#scNum").textContent = out ? out.lost : streak;
    $("#scSub").textContent = "day streak";
    const n = embers();
    $("#scEmbers").innerHTML = `${svgUse("i-ember")}<b>${n}</b>`; $("#scEmbers").title = `${n} ember${n === 1 ? "" : "s"}`;
    // Kept short: the bubble shares the row with the panda on a narrow phone.
    $("#scBubble").classList.toggle("relight", !!out && embers() > 0 && prefs.autoRelight === false);
    $("#scBubble").classList.toggle("risk", risk);
    $("#scBubble").textContent = out ? (embers() && prefs.autoRelight === false ? "Relight it?" : "Went out")
      : risk ? `${hoursLeft}h left to keep it` : xp >= goal ? "Goal done!" : lit ? `${goal - xp} XP to goal`
      : streak > 0 ? "Keep it lit!" : "Let's start!";
    renderWeekStrip();
    renderQuests();
    renderBoost();

    const cont = $("#homeContinue");
    const curId = currentLessonId();
    const allDone = LESSONS.every(l => doneLessons.has(l.id));
    if (allDone) {
      cont.innerHTML =
        `<div class="hc-body"><div class="eyebrow">Course complete</div>` +
        `<div class="hc-title">You've finished every lesson</div>` +
        `<div class="hc-en">Keep your words sharp with a review.</div>` +
        `<div class="hc-row">Review your words</div></div>` +
        `<span class="hc-go">${svgUse("i-check")}</span>`;
      cont.onclick = () => startReview();
    } else {
      const l = LESSONS.find(x => x.id === curId);
      const parts = l.title.split("·");
      const after = (parts.length > 1 ? parts.slice(1).join("·") : parts[0]).trim();
      const i = after.search(/[A-Za-z(]/);
      const hz = i > 0 ? after.slice(0, i).trim() : after;
      const en = i > 0 ? after.slice(i).replace(/^[(\s]+|[)\s]+$/g, "").trim() : "";
      const total = lessonCardCount(curId);
      const cleared = CARDS.filter(c => c.lessonId === curId && srs[c.id] && srs[c.id].reps >= 1).length;
      const studied = lessonStudied(curId);
      cont.innerHTML =
        `<div class="hc-body"><div class="eyebrow">${chapterLabelFor(curId)}</div>` +
        `<div class="hc-title">${hz}</div>` +
        (en ? `<div class="hc-en">${en}</div>` : "") +
        `<div class="hc-bar"><i style="width:${total ? Math.round(cleared / total * 100) : 0}%"></i></div>` +
        `<div class="hc-row">${cleared} / ${total} words learned</div></div>` +
        `<span class="hc-go" aria-label="${studied ? "Continue" : "Start"}">${svgUse("i-chevron")}</span>`;
      cont.onclick = () => launchLesson(curId, null);
    }

    renderHub();
  }

  // The practice hub on Home: your mistakes, words due, and weak words.
  function renderHub() {
    const row = (btn, n, subEl, nEl, some, none) => {
      $(btn).classList.toggle("empty", !n);
      $(subEl).textContent = n ? some(n) : none;
      $(nEl).textContent = n ? String(n) : "";
    };
    const s = n => (n === 1 ? "" : "s");
    row("#hubMistakes", mistakeCards().length, "#hubMistakesSub", "#hubMistakesN",
      n => `${n} word${s(n)} to get right again`, "Nothing to fix. Mistakes you make land here");
    row("#homeReview", dueReviewCards().length, "#homeReviewTxt", "#homeReviewN",
      n => `${n} word${s(n)} ready to review`, "All caught up");
    row("#homeTrouble", troubleCards().length, "#homeTroubleTxt", "#homeTroubleN",
      n => `${n} word${s(n)} you often miss`, "No weak words yet");
  }

  function renderHome() {
    if ($("#ptCharsSub")) $("#ptCharsSub").textContent = `${charsKnown()} known`;
    if ($("#ptReadSub")) {
      const fresh = READS.filter(r => chapterDone(r.chapter) && !readDone(r.id)).length;
      $("#ptReadSub").textContent = fresh ? `${fresh} new ${fresh > 1 ? "stories" : "story"}` : "Chapter stories";
      $("#ptReadSub").classList.toggle("pt-new", !!fresh);
    }
    document.body.classList.toggle("tones", tonesOn());
    renderDashboard();
    renderHomeTop();

    const list = $("#lessonList");
    list.innerHTML = "";
    LESSONS.forEach(lesson => {
      const count = lessonCardCount(lesson.id);
      const due = dueCountForLesson(lesson.id);
      const mastered = lessonMastered(lesson.id);
      const cb = el("input", { type: "checkbox", checked: selectedLessons.has(lesson.id) });
      const bar = el("span", { className: "bar" }, el("i", { style: `width:${count ? Math.round(mastered / count * 100) : 0}%` }));
      const row = el("label", { className: "lesson-row" }, [
        cb,
        el("span", { className: "name" }, lesson.title),
        due ? el("span", { className: "due" }, `${due} due`) : el("span", { className: "count" }, `${count}`),
        bar
      ]);
      cb.addEventListener("change", () => {
        cb.checked ? selectedLessons.add(lesson.id) : selectedLessons.delete(lesson.id);
        persistPrefs();
        renderDashboard();
      });
      list.appendChild(row);
    });

    renderFocuses();
  }

  const focusesMatch = keys => keys.length === selectedFocuses.size && keys.every(k => selectedFocuses.has(k));
  function renderFocuses() {
    // Quick-set presets
    const pr = $("#focusPresets");
    pr.innerHTML = "";
    PRESETS.forEach(p => {
      const chip = el("button", { className: "chip" + (focusesMatch(p.keys) ? " on" : "") }, p.name);
      chip.addEventListener("click", () => {
        selectedFocuses.clear();
        p.keys.forEach(k => selectedFocuses.add(k));
        persistPrefs(); renderFocuses(); renderDashboard();
      });
      pr.appendChild(chip);
    });
    // Individual skill toggles
    const fr = $("#focusRow");
    fr.innerHTML = "";
    FOCUSES.forEach(f => {
      const on = selectedFocuses.has(f.key);
      const row = el("div", { className: "focus-toggle" + (on ? " on" : "") }, [
        el("div", { className: "ft-ic" }, licon(f.ico)),
        el("div", { className: "ft-txt" }, [
          el("div", { className: "ft-name" }, f.name),
          el("div", { className: "ft-desc" }, f.desc)
        ]),
        el("div", { className: "switch" + (on ? " on" : "") }, el("span", {}))
      ]);
      row.addEventListener("click", () => {
        if (selectedFocuses.has(f.key)) {
          if (selectedFocuses.size === 1) { toast("Keep at least one skill switched on."); return; }
          selectedFocuses.delete(f.key);
        } else selectedFocuses.add(f.key);
        persistPrefs(); renderFocuses(); renderDashboard();
      });
      fr.appendChild(row);
    });
  }

  // When launched from a lesson node these scope the session to one lesson /
  // one skill; null means "use the global selection".
  let scopeLessons = null, scopeFocuses = null;
  function activeCards() {
    const ls = scopeLessons || selectedLessons;
    return CARDS.filter(c => ls.has(c.lessonId));
  }

  $("#toggleAll").addEventListener("click", () => {
    const all = selectedLessons.size === LESSONS.length;
    selectedLessons.clear();
    if (!all) LESSONS.forEach(l => selectedLessons.add(l.id));
    persistPrefs();
    renderHome();
  });

  // A session returns to wherever it was started from: the home page's practice
  // tiles and links, or the lesson path. Every Back and Done button goes there.
  let returnView = "path";
  function goBack() {
    if (returnView === "home") { renderHome(); show("home"); }
    else { show("path"); renderPath(); }
  }
  function runMode(mode) {
    returnView = "home";
    scopeLessons = null; scopeFocuses = null;   // global (stats) study uses the full selection
    if (mode === "converse") { openConverse(); return; }   // doesn't need lessons
    if (mode === "pick") { openPicker(); return; }         // choose your own words
    if (mode === "read") { openReadings(); return; }       // unlocks by chapter
    if (mode === "tones") { startTones(); return; }        // uses the words you've met
    if (selectedLessons.size === 0) {
      toast("Pick at least one lesson — open “What to study”.");
      $("#studyPanel").open = true;
      return;
    }
    if (mode === "study") startStudy();
    else if (mode === "quiz") startQuiz();
    else if (mode === "browse") startBrowse();
    else if (mode === "chars") openChars();
    else if (mode === "read") openReadings();
    else if (mode === "tones") startTones();
    else if (mode === "listen") startListening();
    else if (mode === "write") startWriting();
  }
  // Writing practice: stroke-by-stroke drills over the words you've met that have
  // stroke data. Mirrors startListening so the two tiles behave alike.
  function startWriting() {
    reviewMode = false;
    scopeLessons = null;
    if (!HW_OK) { toast("Writing practice needs the stroke engine, which didn't load."); return; }
    const cards = activeCards().filter(c => wordWritable(c.hanzi));
    const studied = cards.filter(c => srs[c.id]);
    const pool = studied.length ? studied : cards;
    if (!pool.length) { toast("Pick at least one lesson — open “What to study”."); $("#studyPanel").open = true; return; }
    scopeFocuses = new Set(["write"]);
    beginStudySession(shuffle(pool).slice(0, 12));
    $("#studyTitle").textContent = "Writing";
  }
  document.querySelectorAll(".practice-list button").forEach(btn =>
    btn.addEventListener("click", () => runMode(btn.dataset.mode)));
  $("#homeContLabel").addEventListener("click", () => { show("path"); renderPath(); });
  $("#scBubble").addEventListener("click", () => { if (outSince()) askRelight(); else if ($(".streak-card").classList.contains("risk")) $("#homeContinue").click(); });
  $("#relightBtn") && $("#relightBtn").addEventListener("click", askRelight);
  $("#achAll").addEventListener("click", () => { achShowAll = !achShowAll; renderAchievements(); });
  $("#profSettings").addEventListener("click", () => document.querySelector(".bottomnav [data-nav=settings]").click());
  $("#editAvatar").addEventListener("click", () => { avatarDraft=null;$("#avatar").classList.remove("preview-compact");show("avatar"); renderAvatarBuilder(); });
  $("#homeReview").addEventListener("click", () => { if ($("#homeReview").classList.contains("empty")) return; returnView = "home"; startReview(); });
  $("#homeTrouble").addEventListener("click", () => { if ($("#homeTrouble").classList.contains("empty")) return; returnView = "home"; startTrouble(); });
  $("#hubMistakes").addEventListener("click", () => { if ($("#hubMistakes").classList.contains("empty")) return; returnView = "home"; startMistakes(); });

  function resetProgress() {
    const ids = new Set(activeCards().map(c => c.id));
    const n = [...ids].filter(id => srs[id]).length;
    if (!confirm(`Reset spaced-repetition memory for ${ids.size} words in the selected lessons? (${n} have progress)`)) return;
    ids.forEach(id => delete srs[id]);
    doneLessons = new Set(); saveDone();
    saveSRS(srs);
    renderHome(); renderPath();
    toast("Progress reset for the selected lessons.");
  }

  /* ==================================================================== */
  /*  PATH (lesson journey home)                                          */
  /* ==================================================================== */

  // Chapters carry a `unit`: the book they belong to (起步 1, 起步 2 …), which the
  // path, labels and placement group by. Generated by bubu-course/export_app.py.
  const CHAPTERS = [
    {
      "unit": "起步 1",
      "title": "Nice to meet you!",
      "lessons": [
        "qibu1-s0-1",
        "qibu1-u1-1",
        "qibu1-u1-2",
        "qibu1-u1-3",
        "qibu1-u1-4"
      ]
    },
    {
      "unit": "起步 1",
      "title": "Where are you from?",
      "lessons": [
        "qibu1-u2-1",
        "qibu1-u2-2",
        "qibu1-u2-3",
        "qibu1-u2-4"
      ]
    },
    {
      "unit": "起步 1",
      "title": "Where do you work?",
      "lessons": [
        "qibu1-u3-1",
        "qibu1-u3-2",
        "qibu1-u3-3"
      ]
    },
    {
      "unit": "起步 1",
      "title": "Let's add each other on WeChat!",
      "lessons": [
        "qibu1-u4-1",
        "qibu1-u4-2",
        "qibu1-u4-3",
        "qibu1-u4-4",
        "qibu1-u4-5"
      ]
    },
    {
      "unit": "起步 1",
      "title": "I'm studying Chinese!",
      "lessons": [
        "qibu1-u5-1",
        "qibu1-u5-2",
        "qibu1-u5-3"
      ]
    },
    {
      "unit": "起步 2",
      "title": "Let's go at the weekend!",
      "lessons": [
        "qibu2-u1-1",
        "qibu2-u1-2",
        "qibu2-u1-3",
        "qibu2-u1-4",
        "qibu2-u1-5"
      ]
    },
    {
      "unit": "起步 2",
      "title": "What time shall we meet?",
      "lessons": [
        "qibu2-u2-1",
        "qibu2-u2-2",
        "qibu2-u2-3",
        "qibu2-u2-4",
        "qibu2-u2-5",
        "qibu2-u2-6"
      ]
    },
    {
      "unit": "起步 2",
      "title": "One bubble tea, please!",
      "lessons": [
        "qibu2-u3-1",
        "qibu2-u3-2",
        "qibu2-u3-3",
        "qibu2-u3-4",
        "qibu2-u3-5",
        "qibu2-u3-6"
      ]
    },
    {
      "unit": "起步 2",
      "title": "Happy Mid-Autumn!",
      "lessons": [
        "qibu2-u4-1",
        "qibu2-u4-2",
        "qibu2-u4-3"
      ]
    },
    {
      "unit": "起步 3",
      "title": "How do you get to work?",
      "lessons": [
        "qibu3-u1-1",
        "qibu3-u1-2",
        "qibu3-u1-3",
        "qibu3-u1-4"
      ]
    },
    {
      "unit": "起步 3",
      "title": "London's colder than Chengdu!",
      "lessons": [
        "qibu3-u2-1",
        "qibu3-u2-2",
        "qibu3-u2-3",
        "qibu3-u2-4",
        "qibu3-u2-5"
      ]
    },
    {
      "unit": "起步 3",
      "title": "Excuse me, how do I get to Chinatown?",
      "lessons": [
        "qibu3-u3-1",
        "qibu3-u3-2",
        "qibu3-u3-3",
        "qibu3-u3-4",
        "qibu3-u3-5"
      ]
    },
    {
      "unit": "起步 3",
      "title": "What's wrong?",
      "lessons": [
        "qibu3-u4-1",
        "qibu3-u4-2",
        "qibu3-u4-3",
        "qibu3-u4-4",
        "qibu3-u4-5"
      ]
    },
    {
      "unit": "起步 4",
      "title": "Waiter, the bill please!",
      "lessons": [
        "qibu4-u1-1",
        "qibu4-u1-2",
        "qibu4-u1-3",
        "qibu4-u1-4",
        "qibu4-u1-5",
        "qibu4-u1-6",
        "qibu4-u1-7",
        "qibu4-u1-8"
      ]
    },
    {
      "unit": "起步 4",
      "title": "Can you play badminton?",
      "lessons": [
        "qibu4-u2-1",
        "qibu4-u2-2",
        "qibu4-u2-3",
        "qibu4-u2-4"
      ]
    },
    {
      "unit": "起步 4",
      "title": "I need a new phone",
      "lessons": [
        "qibu4-u3-1",
        "qibu4-u3-2",
        "qibu4-u3-3",
        "qibu4-u3-4",
        "qibu4-u3-5"
      ]
    },
    {
      "unit": "起步 4",
      "title": "Hello, is that the sports hall?",
      "lessons": [
        "qibu4-u4-1",
        "qibu4-u4-2",
        "qibu4-u4-3",
        "qibu4-u4-4",
        "qibu4-u4-5"
      ]
    },
    {
      "unit": "起步 5",
      "title": "How was the show?",
      "lessons": [
        "qibu5-u1-1",
        "qibu5-u1-2",
        "qibu5-u1-3",
        "qibu5-u1-4",
        "qibu5-u1-5"
      ]
    },
    {
      "unit": "起步 5",
      "title": "Your Chinese is so good!",
      "lessons": [
        "qibu5-u2-1",
        "qibu5-u2-2",
        "qibu5-u2-3",
        "qibu5-u2-4",
        "qibu5-u2-5"
      ]
    },
    {
      "unit": "起步 5",
      "title": "What took you so long?",
      "lessons": [
        "qibu5-u3-1",
        "qibu5-u3-2",
        "qibu5-u3-3",
        "qibu5-u3-4",
        "qibu5-u3-5"
      ]
    },
    {
      "unit": "起步 5",
      "title": "Dear Xiaoyu,",
      "lessons": [
        "qibu5-u4-1",
        "qibu5-u4-2",
        "qibu5-u4-3",
        "qibu5-u4-4",
        "qibu5-u4-5",
        "qibu5-u4-6"
      ]
    },
    {
      "unit": "进步 1",
      "title": "I'd like to book a room",
      "lessons": [
        "jinbu1-u1-1",
        "jinbu1-u1-2",
        "jinbu1-u1-3",
        "jinbu1-u1-4",
        "jinbu1-u1-5",
        "jinbu1-u1-6",
        "jinbu1-u1-7"
      ]
    },
    {
      "unit": "进步 1",
      "title": "Change at Chunxi Road",
      "lessons": [
        "jinbu1-u2-1",
        "jinbu1-u2-2",
        "jinbu1-u2-3",
        "jinbu1-u2-4",
        "jinbu1-u2-5",
        "jinbu1-u2-6"
      ]
    },
    {
      "unit": "进步 1",
      "title": "It's too small. Can I change it?",
      "lessons": [
        "jinbu1-u3-1",
        "jinbu1-u3-2",
        "jinbu1-u3-3",
        "jinbu1-u3-4",
        "jinbu1-u3-5",
        "jinbu1-u3-6",
        "jinbu1-u3-7"
      ]
    },
    {
      "unit": "进步 1",
      "title": "Thank you for having me",
      "lessons": [
        "jinbu1-u4-1",
        "jinbu1-u4-2",
        "jinbu1-u4-3",
        "jinbu1-u4-4",
        "jinbu1-u4-5",
        "jinbu1-u4-6"
      ]
    },
    {
      "unit": "进步 2",
      "title": "Hang the painting up!",
      "lessons": [
        "jinbu2-u1-1",
        "jinbu2-u1-2",
        "jinbu2-u1-3",
        "jinbu2-u1-4",
        "jinbu2-u1-5",
        "jinbu2-u1-6",
        "jinbu2-u1-7"
      ]
    },
    {
      "unit": "进步 2",
      "title": "Qipao or hanfu?",
      "lessons": [
        "jinbu2-u2-1",
        "jinbu2-u2-2",
        "jinbu2-u2-3",
        "jinbu2-u2-4",
        "jinbu2-u2-5",
        "jinbu2-u2-6"
      ]
    },
    {
      "unit": "进步 2",
      "title": "How is Chinese painting different from oil painting?",
      "lessons": [
        "jinbu2-u3-1",
        "jinbu2-u3-2",
        "jinbu2-u3-3",
        "jinbu2-u3-4",
        "jinbu2-u3-5",
        "jinbu2-u3-6"
      ]
    },
    {
      "unit": "进步 2",
      "title": "All done!",
      "lessons": [
        "jinbu2-u4-1",
        "jinbu2-u4-2",
        "jinbu2-u4-3",
        "jinbu2-u4-4",
        "jinbu2-u4-5",
        "jinbu2-u4-6"
      ]
    },
    {
      "unit": "进步 3",
      "title": "Happy New Year!",
      "lessons": [
        "jinbu3-u1-1",
        "jinbu3-u1-2",
        "jinbu3-u1-3",
        "jinbu3-u1-4",
        "jinbu3-u1-5",
        "jinbu3-u1-6",
        "jinbu3-u1-7",
        "jinbu3-u1-8"
      ]
    },
    {
      "unit": "进步 3",
      "title": "It sounds beautiful!",
      "lessons": [
        "jinbu3-u2-1",
        "jinbu3-u2-2",
        "jinbu3-u2-3",
        "jinbu3-u2-4",
        "jinbu3-u2-5",
        "jinbu3-u2-6"
      ]
    },
    {
      "unit": "进步 3",
      "title": "Have you read Dream of the Red Chamber?",
      "lessons": [
        "jinbu3-u3-1",
        "jinbu3-u3-2",
        "jinbu3-u3-3",
        "jinbu3-u3-4",
        "jinbu3-u3-5",
        "jinbu3-u3-6",
        "jinbu3-u3-7"
      ]
    },
    {
      "unit": "进步 3",
      "title": "You're not a hero till you've climbed the Great Wall",
      "lessons": [
        "jinbu3-u4-1",
        "jinbu3-u4-2",
        "jinbu3-u4-3",
        "jinbu3-u4-4",
        "jinbu3-u4-5"
      ]
    },
    {
      "unit": "进步 4",
      "title": "My phone's been stolen!",
      "lessons": [
        "jinbu4-u1-1",
        "jinbu4-u1-2",
        "jinbu4-u1-3",
        "jinbu4-u1-4",
        "jinbu4-u1-5",
        "jinbu4-u1-6",
        "jinbu4-u1-7",
        "jinbu4-u1-8"
      ]
    },
    {
      "unit": "进步 4",
      "title": "My proposal's been approved!",
      "lessons": [
        "jinbu4-u2-1",
        "jinbu4-u2-2",
        "jinbu4-u2-3",
        "jinbu4-u2-4",
        "jinbu4-u2-5",
        "jinbu4-u2-6",
        "jinbu4-u2-7"
      ]
    },
    {
      "unit": "进步 4",
      "title": "Let's get together some time",
      "lessons": [
        "jinbu4-u3-1",
        "jinbu4-u3-2",
        "jinbu4-u3-3",
        "jinbu4-u3-4",
        "jinbu4-u3-5"
      ]
    },
    {
      "unit": "进步 4",
      "title": "The secret of learning Chinese",
      "lessons": [
        "jinbu4-u4-1",
        "jinbu4-u4-2",
        "jinbu4-u4-3",
        "jinbu4-u4-4",
        "jinbu4-u4-5"
      ]
    },
    {
      "unit": "进步 5",
      "title": "Melbourne or London?",
      "lessons": [
        "jinbu5-u1-1",
        "jinbu5-u1-2",
        "jinbu5-u1-3",
        "jinbu5-u1-4",
        "jinbu5-u1-5",
        "jinbu5-u1-6",
        "jinbu5-u1-7",
        "jinbu5-u1-8"
      ]
    },
    {
      "unit": "进步 5",
      "title": "How were characters made?",
      "lessons": [
        "jinbu5-u2-1",
        "jinbu5-u2-2",
        "jinbu5-u2-3",
        "jinbu5-u2-4",
        "jinbu5-u2-5",
        "jinbu5-u2-6",
        "jinbu5-u2-7"
      ]
    },
    {
      "unit": "进步 5",
      "title": "What makes a good present?",
      "lessons": [
        "jinbu5-u3-1",
        "jinbu5-u3-2",
        "jinbu5-u3-3",
        "jinbu5-u3-4",
        "jinbu5-u3-5",
        "jinbu5-u3-6"
      ]
    },
    {
      "unit": "进步 5",
      "title": "Thank you for the present!",
      "lessons": [
        "jinbu5-u4-1",
        "jinbu5-u4-2",
        "jinbu5-u4-3",
        "jinbu5-u4-4",
        "jinbu5-u4-5"
      ]
    },
    {
      "unit": "大步 1",
      "title": "On the other side of the table",
      "lessons": [
        "dabu1-u1-1",
        "dabu1-u1-2",
        "dabu1-u1-3",
        "dabu1-u1-4",
        "dabu1-u1-5",
        "dabu1-u1-6",
        "dabu1-u1-7",
        "dabu1-u1-8",
        "dabu1-u1-9"
      ]
    },
    {
      "unit": "大步 1",
      "title": "Working late",
      "lessons": [
        "dabu1-u2-1",
        "dabu1-u2-2",
        "dabu1-u2-3",
        "dabu1-u2-4",
        "dabu1-u2-5",
        "dabu1-u2-6",
        "dabu1-u2-7"
      ]
    },
    {
      "unit": "大步 1",
      "title": "A quick meeting",
      "lessons": [
        "dabu1-u3-1",
        "dabu1-u3-2",
        "dabu1-u3-3",
        "dabu1-u3-4",
        "dabu1-u3-5",
        "dabu1-u3-6"
      ]
    },
    {
      "unit": "大步 1",
      "title": "Move on or stay put?",
      "lessons": [
        "dabu1-u4-1",
        "dabu1-u4-2",
        "dabu1-u4-3",
        "dabu1-u4-4",
        "dabu1-u4-5"
      ]
    },
    {
      "unit": "大步 2",
      "title": "A room with a tree",
      "lessons": [
        "dabu2-u1-1",
        "dabu2-u1-2",
        "dabu2-u1-3",
        "dabu2-u1-4",
        "dabu2-u1-5",
        "dabu2-u1-6",
        "dabu2-u1-7",
        "dabu2-u1-8",
        "dabu2-u1-9"
      ]
    },
    {
      "unit": "大步 2",
      "title": "Which bin?",
      "lessons": [
        "dabu2-u2-1",
        "dabu2-u2-2",
        "dabu2-u2-3",
        "dabu2-u2-4",
        "dabu2-u2-5",
        "dabu2-u2-6",
        "dabu2-u2-7",
        "dabu2-u2-8"
      ]
    },
    {
      "unit": "大步 2",
      "title": "The village in the bamboo",
      "lessons": [
        "dabu2-u3-1",
        "dabu2-u3-2",
        "dabu2-u3-3",
        "dabu2-u3-4",
        "dabu2-u3-5"
      ]
    },
    {
      "unit": "大步 2",
      "title": "My Shanghai",
      "lessons": [
        "dabu2-u4-1",
        "dabu2-u4-2",
        "dabu2-u4-3",
        "dabu2-u4-4",
        "dabu2-u4-5"
      ]
    },
    {
      "unit": "大步 3",
      "title": "Life without cash",
      "lessons": [
        "dabu3-u1-1",
        "dabu3-u1-2",
        "dabu3-u1-3",
        "dabu3-u1-4",
        "dabu3-u1-5",
        "dabu3-u1-6",
        "dabu3-u1-7",
        "dabu3-u1-8"
      ]
    },
    {
      "unit": "大步 3",
      "title": "Just one more video",
      "lessons": [
        "dabu3-u2-1",
        "dabu3-u2-2",
        "dabu3-u2-3",
        "dabu3-u2-4",
        "dabu3-u2-5",
        "dabu3-u2-6"
      ]
    },
    {
      "unit": "大步 3",
      "title": "Will AI replace us?",
      "lessons": [
        "dabu3-u3-1",
        "dabu3-u3-2",
        "dabu3-u3-3",
        "dabu3-u3-4",
        "dabu3-u3-5",
        "dabu3-u3-6"
      ]
    },
    {
      "unit": "大步 3",
      "title": "Reading the news",
      "lessons": [
        "dabu3-u4-1",
        "dabu3-u4-2",
        "dabu3-u4-3",
        "dabu3-u4-4",
        "dabu3-u4-5",
        "dabu3-u4-6",
        "dabu3-u4-7"
      ]
    },
    {
      "unit": "大步 4",
      "title": "So when are you getting married?",
      "lessons": [
        "dabu4-u1-1",
        "dabu4-u1-2",
        "dabu4-u1-3",
        "dabu4-u1-4",
        "dabu4-u1-5",
        "dabu4-u1-6",
        "dabu4-u1-7"
      ]
    },
    {
      "unit": "大步 4",
      "title": "The race to the exam",
      "lessons": [
        "dabu4-u2-1",
        "dabu4-u2-2",
        "dabu4-u2-3",
        "dabu4-u2-4",
        "dabu4-u2-5",
        "dabu4-u2-6"
      ]
    },
    {
      "unit": "大步 4",
      "title": "Who looks after Mum and Dad?",
      "lessons": [
        "dabu4-u3-1",
        "dabu4-u3-2",
        "dabu4-u3-3",
        "dabu4-u3-4",
        "dabu4-u3-5",
        "dabu4-u3-6",
        "dabu4-u3-7",
        "dabu4-u3-8"
      ]
    },
    {
      "unit": "大步 4",
      "title": "Two generations",
      "lessons": [
        "dabu4-u4-1",
        "dabu4-u4-2",
        "dabu4-u4-3",
        "dabu4-u4-4",
        "dabu4-u4-5",
        "dabu4-u4-6",
        "dabu4-u4-7"
      ]
    },
    {
      "unit": "大步 5",
      "title": "Keeping well in the dog days",
      "lessons": [
        "dabu5-u1-1",
        "dabu5-u1-2",
        "dabu5-u1-3",
        "dabu5-u1-4",
        "dabu5-u1-5",
        "dabu5-u1-6",
        "dabu5-u1-7",
        "dabu5-u1-8"
      ]
    },
    {
      "unit": "大步 5",
      "title": "What travel is for",
      "lessons": [
        "dabu5-u2-1",
        "dabu5-u2-2",
        "dabu5-u2-3",
        "dabu5-u2-4",
        "dabu5-u2-5",
        "dabu5-u2-6"
      ]
    },
    {
      "unit": "大步 5",
      "title": "A basket for the world",
      "lessons": [
        "dabu5-u3-1",
        "dabu5-u3-2",
        "dabu5-u3-3",
        "dabu5-u3-4",
        "dabu5-u3-5",
        "dabu5-u3-6",
        "dabu5-u3-7",
        "dabu5-u3-8"
      ]
    },
    {
      "unit": "大步 5",
      "title": "Back where it started",
      "lessons": [
        "dabu5-u4-1",
        "dabu5-u4-2",
        "dabu5-u4-3",
        "dabu5-u4-4"
      ]
    }
  ];

  // Short grammar/pattern notes, shown on the "meet the new words" screen and on
  // the lesson sheet, for the lessons that introduce a pattern worth a sentence.
  const LESSON_NOTES = {
    "qibu1-s0-1": [
      {
        "title": "是 — to be",
        "body": "是 links two nouns. To say 'not', put 不 in front: 不是. Don't use 是 with adjectives: say 我很高兴, not 我是高兴. 我是马克。 (I'm Mark.)"
      }
    ],
    "qibu1-u1-1": [
      {
        "title": "吗 — yes/no questions",
        "body": "Add 吗 to the end of a statement to turn it into a question. Answer by repeating the verb: 是 / 不是, 喝 / 不喝. 你是学生吗？ (Are you a student?)"
      }
    ],
    "qibu1-u1-2": [
      {
        "title": "呢 — and you?",
        "body": "呢 bounces the same question back, so you don't need to repeat it. 我是学生，你呢？ (I'm a student. And you?)"
      }
    ],
    "qibu1-u1-3": [
      {
        "title": "也 — also, too",
        "body": "也 always goes before the verb, never at the start of the sentence. 我也是学生。 (I'm a student too.)"
      }
    ],
    "qibu1-u1-4": [
      {
        "title": "姓 and 叫 — names",
        "body": "姓 is for the surname only. 叫 is for your full name or given name. Chinese surnames come first: 林小雨 is Lin (surname) Xiaoyu. The polite way to ask a surname is 您贵姓？ (nín guì xìng). 我姓林。 (My surname is Lin.)"
      },
      {
        "title": "Sounds · Two third tones in a row",
        "body": "When two third tones meet, the first one rises like a second tone. You write nǐ hǎo but say ní hǎo. This book always prints the original tones."
      }
    ],
    "qibu1-u2-1": [
      {
        "title": "哪国人 and 哪里人",
        "body": "哪国人 asks for a nationality. 哪里人 asks which city or region someone comes from. 你是哪国人？ (What nationality are you?)"
      }
    ],
    "qibu1-u2-2": [
      {
        "title": "Country + 人 · country + 语",
        "body": "Add 人 for the people and 语 for the language. Chinese is usually 中文 or 汉语, and Japanese is 日语 (not 日本语). 法国人会说法语。 (French people speak French.)"
      }
    ],
    "qibu1-u2-3": [
      {
        "title": "从 … 来 — to come from",
        "body": "The place goes between 从 and 来. 我从中国来。 (I'm from China.)"
      }
    ],
    "qibu1-u2-4": [
      {
        "title": "住在 — to live in",
        "body": "在 marks the place, and the place comes after it. 我住在伦敦。 (I live in London.)"
      },
      {
        "title": "会 — can (a learned skill)",
        "body": "Use 会 for things you've learned, like languages. 一点儿 goes before the thing: 一点儿中文. 我会说法语。 (I can speak French.)"
      },
      {
        "title": "Sounds · zh ch sh · z c s",
        "body": "For zh ch sh, curl the tongue tip back. For z c s, keep it flat behind your teeth. Say each pair slowly, then quickly."
      }
    ],
    "qibu1-u3-1": [
      {
        "title": "Asking about jobs",
        "body": "You can also answer with where you work. 你做什么工作？ (What do you do?)"
      }
    ],
    "qibu1-u3-2": [
      {
        "title": "在 + place + verb",
        "body": "The place comes before the verb, never after it. Say 我在医院工作, not 我工作在医院. 我在设计公司工作。 (I work at a design company.)"
      }
    ],
    "qibu1-u3-3": [
      {
        "title": "的 — 's",
        "body": "的 shows who something belongs to. You can drop the thing when it's clear: 是我的. With family and close friends, 的 is usually left out: 我表哥, 我朋友. 陈明的饭馆 (Chen Ming's restaurant)"
      },
      {
        "title": "这 and 那 — this and that",
        "body": "这 is near you, 那 is further away. You met 哪 (which) in Unit 2: the three belong together. 这是我表哥。 (This is my cousin.)"
      },
      {
        "title": "谁 — who",
        "body": "谁 goes where the answer would go. 他是谁？ (Who is he?)"
      },
      {
        "title": "Sounds · j q x, and ü",
        "body": "j q x are always followed by i or ü. After j q x (and y), ü loses its dots, so xue is really xüe. To say ü, say 'ee' and round your lips."
      }
    ],
    "qibu1-u4-1": [
      {
        "title": "Numbers to 1,000",
        "body": "Build numbers like a calculator reads them: 21 is 'two ten one'. When a zero sits in the middle, say 零 once: 105 is 一百零五. 九十九 (99)"
      }
    ],
    "qibu1-u4-2": [
      {
        "title": "Measure words",
        "body": "Between a number and a noun you need a measure word. 个 is the most common one. You'll meet more in 起步 2. 三个厨师 (three chefs)"
      }
    ],
    "qibu1-u4-3": [
      {
        "title": "二 or 两?",
        "body": "Use 二 when counting and in longer numbers (十二, 二十二). Before a measure word on its own, use 两. 两个服务员 (two waiters)"
      }
    ],
    "qibu1-u4-4": [
      {
        "title": "几 or 多少?",
        "body": "几 expects a small number, about ten or under, and needs a measure word. 多少 works for any number, and is what you use for phone numbers. 你有几个孩子？ (How many children do you have?)"
      }
    ],
    "qibu1-u4-5": [
      {
        "title": "Asking someone's age",
        "body": "Ask a child 你几岁？ and an adult 你多大？. For older people, 您多大年纪？ is politer. In the answer you don't need 是. 我三十二岁。 (I'm 32.)"
      },
      {
        "title": "吧 — let's",
        "body": "吧 at the end makes a friendly suggestion. 我们加个微信吧！ (Let's add each other on WeChat!)"
      },
      {
        "title": "Sounds · 一 and 不 change their tones",
        "body": "一 is yī when counting. Before a fourth tone it becomes yí; before any other tone, yì. 不 is bù, but becomes bú before a fourth tone. This book prints the original tones, so watch for these."
      }
    ],
    "qibu1-u5-1": [
      {
        "title": "在 — doing it right now",
        "body": "在 before a verb means the action is happening now. 呢 at the end makes it sound natural and chatty. For 'not doing', use 没在. 我在学中文呢。 (I'm studying Chinese.)"
      }
    ],
    "qibu1-u5-2": [
      {
        "title": "Two kinds of 在",
        "body": "在 + place says where. 在 + verb says it's happening now. With a place and a verb together, the place comes first. 我在家。 (I'm at home.)"
      }
    ],
    "qibu1-u5-3": [
      {
        "title": "要 and 想 — plans and wishes",
        "body": "要 is for plans: 'going to'. 想 is 'would like to'. For 'don't want to', say 不想. (不要 on its own means 'don't!') 明天我要去饭馆。 (I'm going to the restaurant tomorrow.)"
      },
      {
        "title": "去 + place + verb",
        "body": "Say where you're going, then what you'll do there. 我们去饭馆吃饺子。 (We're going to the restaurant for dumplings.)"
      },
      {
        "title": "Time words come early",
        "body": "Put time words at the start or just after the subject, never at the end. 明天晚上我要去饭馆。 (Tomorrow evening I'm going to the restaurant.)"
      },
      {
        "title": "Sounds · The 儿 sound, and light syllables",
        "body": "In the north, 儿 curls onto the end of a word: 哪儿 nǎr, 一点儿 yīdiǎnr. In the south people often say 哪里 and 一点 instead. Some syllables are said light and short, with no tone: 什么, 朋友, 晚上."
      }
    ],
    "qibu2-u1-1": [
      {
        "title": "喜欢 — to like (doing)",
        "body": "喜欢 can take a thing or a whole activity. 很喜欢 means 'really like'. The noun for 'hobby' is 爱好: 我的爱好是唱歌. 我喜欢做饭。 (I like cooking.)"
      }
    ],
    "qibu2-u1-2": [
      {
        "title": "Inviting someone",
        "body": "Check they're free, then make the suggestion with 吧. Put 怎么样？ after a plan to ask what they think. 星期六你有空吗？ (Are you free on Saturday?)"
      }
    ],
    "qibu2-u1-3": [
      {
        "title": "Saying no politely",
        "body": "A bare 不 sounds blunt. Say 不好意思, give a reason, and offer another time if you can. 要 here means 'have to'. 不好意思，我要工作。 (Sorry, I have to work.)"
      }
    ],
    "qibu2-u1-4": [
      {
        "title": "那 — in that case",
        "body": "At the start of a sentence, 那 means 'then' or 'in that case'. It picks up what the other person has just said. 可以 on its own is a handy 'that's fine'. 那星期天呢？ (What about Sunday, then?)"
      }
    ],
    "qibu2-u1-5": [
      {
        "title": "了 — it's done",
        "body": "了 after a verb shows the action is complete. The object usually has a number, 一些 or 很多 with it. Just 我买了面包 sounds unfinished. 我买了一些面包。 (I bought some bread.)"
      },
      {
        "title": "没 — didn't",
        "body": "For 'didn't', put 没 before the verb and drop the 了. Don't say 没买了. 她没买东西。 (She didn't buy anything.)"
      },
      {
        "title": "Sounds · The half third tone",
        "body": "Before another third tone, a third tone rises (you met this in 你好). Before any other tone, it just dips low and stays there. This 'half third' is how you'll say most third tones."
      }
    ],
    "qibu2-u2-1": [
      {
        "title": "Telling the time",
        "body": "点 is o'clock and 分 is minutes. Two o'clock is 两点, not 二点. 半 is half past and 一刻 quarter past. 三刻 is quarter to, though many people just say 四十五. 八点 (8:00)"
      }
    ],
    "qibu2-u2-2": [
      {
        "title": "差 — to the hour",
        "body": "差 means 'short of', so 差五分三点 is 'five minutes short of three': 2:55. Use it for the last few minutes before the hour. 差五分三点 (2:55)"
      }
    ],
    "qibu2-u2-3": [
      {
        "title": "The time goes before the verb",
        "body": "Clock times go before the verb, like 明天 and 晚上 in 起步 1. When there are several, the biggest comes first: 星期六下午两点. 我七点半起床。 (I get up at half past seven.)"
      }
    ],
    "qibu2-u2-4": [
      {
        "title": "以前 and 以后 — before and after",
        "body": "These come after the event, the other way round from English. With an amount of time, 以后 means 'in': 二十分钟以后 is 'in twenty minutes'. 睡觉以前，我看书。 (Before bed, I read.)"
      }
    ],
    "qibu2-u2-5": [
      {
        "title": "每天 … 都 — every day",
        "body": "With 每天 and other 'every' words, add 都 before the verb. 我每天都跑步。 (I go running every day.)"
      }
    ],
    "qibu2-u2-6": [
      {
        "title": "几点 or 什么时候?",
        "body": "几点 asks for a clock time. 什么时候 is any 'when': a day, a time, or just 'later'. 你几点起床？ (What time do you get up?)"
      },
      {
        "title": "Sounds · 四 and 十",
        "body": "With times, 四 sì and 十 shí are easy to mix up, and 十四 (14) and 四十 (40) even more so. For 十, curl your tongue back and let the tone rise. For 四, keep the tongue behind your teeth and let it fall."
      }
    ],
    "qibu2-u3-1": [
      {
        "title": "Measure words for containers: 杯 瓶 盒",
        "body": "For food and drink, the measure word is often the container, just like 'a cup of' or 'a bottle of' in English. 一杯绿茶 (a cup of green tea)"
      }
    ],
    "qibu2-u3-2": [
      {
        "title": "Measure words for shapes: 张 条 本 件",
        "body": "张 is for flat things, 条 for long, thin things, 本 for books and 件 for clothes and presents. Shops and restaurants take 家. 个 works for lots of things, but the right word sounds much more natural. 一张票 (a ticket)"
      }
    ],
    "qibu2-u3-3": [
      {
        "title": "这个, 那个, 哪个",
        "body": "With a noun, 这, 那 and 哪 need a measure word: 这张卡, not 这卡. When it's clear what you mean, drop the noun: 这个, 哪个. 这张卡怎么样？ (What do you think of this card?)"
      }
    ],
    "qibu2-u3-4": [
      {
        "title": "要 — ordering",
        "body": "In cafés and shops, 要 is the simplest way to order. Staff will ask 还要别的吗？ When you've finished, say 不要了，谢谢. 我要一杯珍珠奶茶。 (I'll have a pearl milk tea.)"
      }
    ],
    "qibu2-u3-5": [
      {
        "title": "还是 — or? (in questions)",
        "body": "Use 还是 to offer a choice in a question. Answer with just the one you want. 大杯、中杯还是小杯？ (Large, medium or small?)"
      }
    ],
    "qibu2-u3-6": [
      {
        "title": "送 and 给 — presents",
        "body": "送 is 'to give as a present', and the person comes before the thing. 是给…的 says who something is for. 别 + verb means 'don't'. 送她一张唱片吧！ (Get her a record!)"
      },
      {
        "title": "Sounds · -n or -ng?",
        "body": "Lots of measure words end in -n or -ng, and the difference changes the word. For -n, the tip of the tongue touches behind the top teeth. For -ng, the back of the tongue rises and the sound comes out through the nose."
      },
      {
        "title": "Culture · Bubble tea",
        "body": "Bubble tea, 珍珠奶茶 or 'pearl milk tea', started in Taiwan in the 1980s and is now sold all over the world, including on almost every corner of London's Chinatown. The 'pearls' are chewy balls of tapioca."
      }
    ],
    "qibu2-u4-1": [
      {
        "title": "Dates: biggest first",
        "body": "Chinese dates go from the biggest unit to the smallest. Read the year digit by digit: 2026年 is èr líng èr liù nián. In speech the day is 号; in writing it's 日, and the year may be written in characters: 二〇二六年九月二十五日. 2026年9月25号 (25 September 2026)"
      }
    ],
    "qibu2-u4-2": [
      {
        "title": "星期几 — days of the week",
        "body": "Monday to Saturday are numbered: 星期一 is 'week one'. Sunday is 星期天 (星期日 in writing). To ask which day, say 星期几. 今天星期几？ (What day is it today?)"
      }
    ],
    "qibu2-u4-3": [
      {
        "title": "Asking about birthdays",
        "body": "Put 几 where the numbers go in the answer. In the answer you can drop 是. 你的生日是几月几号？ (When's your birthday?)"
      },
      {
        "title": "上, 这, 下 — last, this, next",
        "body": "上 is last and 下 is next, with 个 before 星期 and 月. Years work differently: 去年, 今年, 明年. 下个星期五是中秋节。 (Next Friday is Mid-Autumn.)"
      },
      {
        "title": "打算 — to plan to",
        "body": "打算 is for plans you've thought about, a bit firmer than 想. It's also a noun: 你有什么打算？ What are your plans? 明年我打算回成都。 (I'm planning to go back to Chengdu next year.)"
      },
      {
        "title": "快乐 — wishes",
        "body": "Add 快乐 to an occasion for a greeting. 祝 (wish) makes it warmer, and 祝大家 wishes everyone. 生日快乐！ (Happy birthday!)"
      },
      {
        "title": "Sounds · One character, two readings",
        "body": "A few characters have two readings, and the word tells you which. You've met several already, so learn them as whole words."
      },
      {
        "title": "Culture · Mid-Autumn and mooncakes",
        "body": "The Mid-Autumn Festival (中秋节) falls on the fifteenth day of the eighth month of the Chinese calendar, when the moon is at its fullest. In the Western calendar it moves around between mid-September and early October: in 2026 it's on 25 September."
      }
    ],
    "qibu3-u1-1": [
      {
        "title": "怎么 + verb — how?",
        "body": "You met 怎么 in 怎么过 and 怎么说. Put it before any verb to ask how something is done. 怎么去 asks how you get somewhere. 你怎么去上班？ (How do you get to work?)"
      }
    ],
    "qibu3-u1-2": [
      {
        "title": "坐, 骑, 开 and 走路",
        "body": "坐 is for anything you ride in as a passenger: the Tube, a bus, a train, a plane. 骑 is for anything you sit astride, like a bike. 开 is to drive. The way you travel goes before 去, never after it. 我坐地铁去上班。 (I take the Tube to work.)"
      }
    ],
    "qibu3-u1-3": [
      {
        "title": "从 … 到 … — from … to …",
        "body": "从 marks the start and 到 the end. The whole phrase comes before the verb or at the start of the sentence. 从我家到公司 (from my place to the office)"
      }
    ],
    "qibu3-u1-4": [
      {
        "title": "要多长时间？ — how long does it take?",
        "body": "要 here means 'to take'. 左右 after an amount means 'about', like 差不多 before it. 只要 means 'it only takes'. 从你家到公司要多长时间？ (How long does it take from your place to the office?)"
      },
      {
        "title": "过 — have you ever …?",
        "body": "过 after a verb means you've done it at some time in your life. For 'never', use 没 and keep the 过. Add 还 for 'not yet'. 你去过牛津吗？ (Have you been to Oxford?)"
      },
      {
        "title": "Sounds · q or ch?",
        "body": "q is said with the tongue flat and the lips spread, like the 'ch' in 'cheese' but further forward. ch curls the tongue back. Both are said with a strong puff of air. Transport words are full of them."
      }
    ],
    "qibu3-u2-1": [
      {
        "title": "比 — comparing",
        "body": "Put 比 between the two things, then the adjective. Don't add 很: say 伦敦比成都冷, not 伦敦比成都很冷. With people, 大 and 小 mean older and younger. 成都比伦敦暖和。 (Chengdu is warmer than London.)"
      }
    ],
    "qibu3-u2-2": [
      {
        "title": "A bit more: 比 … 一点儿",
        "body": "To say the difference is small, add 一点儿 after the adjective. 今天比昨天暖和一点儿。 (Today's a bit warmer than yesterday.)"
      }
    ],
    "qibu3-u2-3": [
      {
        "title": "没有 … 那么 — not as … as",
        "body": "This is the everyday way to say 'not as … as'. Don't use 不比 for this: 成都没有北京那么冷 is what people say. 成都没有北京那么冷。 (Chengdu isn't as cold as Beijing.)"
      }
    ],
    "qibu3-u2-4": [
      {
        "title": "更 — even more",
        "body": "更 compares with something already mentioned. It goes before the adjective. 北京的冬天更冷。 (Winters in Beijing are even colder.)"
      }
    ],
    "qibu3-u2-5": [
      {
        "title": "一样 — the same",
        "body": "一样 on its own means 'the same'. Add an adjective for 'just as …'. 上海和伦敦一样冷。 (Shanghai is as cold as London.)"
      },
      {
        "title": "有点儿 or 一点儿?",
        "body": "有点儿 goes before an adjective and usually means 'a bit too', so it's often a complaint. 一点儿 goes after an adjective, in comparisons and requests. 一点儿也不 means 'not at all'. 今天有点儿冷，多穿一点儿衣服。 (It's a bit cold today. Put on some more clothes.)"
      },
      {
        "title": "Sounds · The e in 热",
        "body": "Pinyin e on its own is not the English 'e'. Start with your mouth as for 'o', then spread your lips without moving your tongue: it sounds a bit like the 'u' in 'fur'. In 冷 and 更, eng is closer to the 'ung' in 'lung'."
      },
      {
        "title": "Culture · Chengdu: tea, sun and chilli",
        "body": "Chengdu is the capital of Sichuan province, in the south-west of China. It sits in a basin surrounded by mountains, so the sky is often grey and misty. An old saying claims that Sichuan's dogs bark when the sun comes out, because they so rarely see it."
      }
    ],
    "qibu3-u3-1": [
      {
        "title": "Asking the way",
        "body": "怎么走 asks for directions on foot. Start with 请问 to be polite. Use 您 for older people. 请问，唐人街怎么走？ (Excuse me, how do I get to Chinatown?)"
      }
    ],
    "qibu3-u3-2": [
      {
        "title": "往 + direction",
        "body": "往 means 'towards'. 一直走 is 'keep going straight'. 第 makes an order: 第二个路口 is the second crossing. 往前一直走。 (Go straight on.)"
      }
    ],
    "qibu3-u3-3": [
      {
        "title": "离 — how far?",
        "body": "离 measures the distance between two places. Here and there are 这儿 and 那儿. 唐人街离这儿很近。 (Chinatown is very close to here.)"
      }
    ],
    "qibu3-u3-4": [
      {
        "title": "Where things are",
        "body": "The place word comes after the landmark, the other way round from English: 银行旁边 is 'next to the bank'. 就在 means 'right there'. 超市在银行旁边。 (The supermarket is next to the bank.)"
      }
    ],
    "qibu3-u3-5": [
      {
        "title": "有没有? 远不远? — yes or no",
        "body": "Another way to ask a yes/no question is to say the verb or adjective twice, with 不 in between (没 for 有). Don't add 吗. 附近有没有超市？ (Is there a supermarket nearby?)"
      },
      {
        "title": "Sounds · zou or zuo? ou and uo",
        "body": "ou starts with an 'o' and glides to 'u', like the 'o' in 'go'. uo starts with a 'u' and opens to 'o', like the 'wa' in 'water'. Mix them up and 走 (walk) becomes 左 (left)."
      },
      {
        "title": "Culture · London's Chinatown",
        "body": "London's first Chinatown grew up in Limehouse, by the docks in the East End, where Chinese sailors settled in the late 1800s. After the Second World War, Chinese restaurants started opening around Gerrard Street in Soho, and by the 1970s it was known as Chinatown."
      }
    ],
    "qibu3-u4-1": [
      {
        "title": "Saying what's wrong",
        "body": "怎么了 asks what's the matter. 不舒服 means 'not feeling well'. Put 疼 after the part that hurts. 你哪儿不舒服？ (Where does it hurt? / What's wrong?)"
      }
    ],
    "qibu3-u4-2": [
      {
        "title": "应该 — should",
        "body": "应该 gives advice or says what's right. It goes before the verb. 你应该去看医生。 (You should see a doctor.)"
      }
    ],
    "qibu3-u4-3": [
      {
        "title": "得 děi — must, have to",
        "body": "得 is said děi when it means 'must'. It's very common in speech. For 'don't have to', say 不用, never 不得. 我得工作。 (I have to work.)"
      }
    ],
    "qibu3-u4-4": [
      {
        "title": "Asking prices",
        "body": "多少钱 is 'how much?'. In shops and markets, 怎么卖 asks the price of something sold by weight or number. The price can come first or last: 多少钱一盒 or 一盒多少钱. 多少钱一盒？ (How much is a box?)"
      }
    ],
    "qibu3-u4-5": [
      {
        "title": "Money: 块, 毛, 元, 英镑",
        "body": "In speech, 块 is the everyday word for a unit of money: a pound in London, a yuan in China. A number after 块 is the tenths: 六块五 is 6.50. The written word for yuan is 元, and 毛 is a tenth in speech. China's money is 人民币, and the pound is 英镑. 六块五 (£6.50)"
      },
      {
        "title": "Softer asking: 能 … 吗? and 试试",
        "body": "能…吗？ asks if something is possible. Saying a verb twice, like 试试, makes it light and casual: 'have a try'. 能便宜一点儿吗？ (Could you do it a bit cheaper?)"
      },
      {
        "title": "Sounds · One character, two readings (again)",
        "body": "Some characters change their reading with their meaning. Learn these as whole words."
      },
      {
        "title": "Culture · 多喝热水: drink more hot water",
        "body": "Tell a Chinese friend you have a cold, a headache or a stomach ache, and the first thing you'll probably hear is 多喝热水 (duō hē rè shuǐ): 'drink more hot water'. It's such a common reply that it has become a friendly joke online."
      }
    ],
    "qibu4-u1-1": [
      {
        "title": "来 — ordering",
        "body": "In a restaurant, 来 is the everyday way to order, a bit more casual than 要. Dishes take 个 or 份 (a portion). 再来 means 'and we'd also like'. 来一个水煮鱼。 (One boiled fish, please.)"
      }
    ],
    "qibu4-u1-2": [
      {
        "title": "几位？ — how many of you?",
        "body": "位 is a polite measure word for people. Staff use it for you, and you use it for guests or strangers. Don't use it about yourself: say 我们三个人, or just 三位 when answering. 几位？ (How many of you?)"
      }
    ],
    "qibu4-u1-3": [
      {
        "title": "别放 … — leave it out",
        "body": "You met 别 in 别告诉小雨. When ordering, 别放 or 不要放 says what to leave out, and 少放 means 'go easy on it'. 别 + verb + 了 means 'stop doing it'. 别放辣椒！ (No chilli!)"
      }
    ],
    "qibu4-u1-4": [
      {
        "title": "的 with no noun",
        "body": "When it's clear what you mean, drop the noun after 的: 不辣的 is 'one that isn't spicy'. 有没有不辣的？ (Is there anything that isn't spicy?)"
      }
    ],
    "qibu4-u1-5": [
      {
        "title": "Paying the bill",
        "body": "Call 服务员，买单！ for the bill. 我请客 means 'it's on me', and 我来 is 'let me (pay)'. Among friends, especially younger people, 我们 AA 吧 means splitting the bill or everyone paying their own. It's written with the English letters. 服务员，买单！ (Waiter, the bill please!)"
      }
    ],
    "qibu4-u1-6": [
      {
        "title": "Sounds · s, sh and x",
        "body": "s keeps the tongue flat behind the teeth, sh curls it back, and x spreads the lips with the tongue flat and forward, as in 'she' said with a smile. The menu is full of all three."
      }
    ],
    "qibu4-u1-7": [
      {
        "title": "Culture · Who pays? Fighting over the bill",
        "body": "At the end of a meal in China, you'll often see two or three people on their feet, each trying to push their card or phone at the waiter first. This is 抢着买单 (qiǎngzhe mǎidān), 'fighting to pay', and it's a way of showing warmth and respect. The oldest person, the host, or whoever invited everyone usually expects to win, and the loser says 下次我请！, 'next time it's on me'. A quiet trip to the counter halfway through the meal is a classic move."
      }
    ],
    "qibu4-u2-1": [
      {
        "title": "会, 能 or 可以?",
        "body": "All three can be 'can'. 会 is a skill you've learned. 能 is being able to, because of your body or the situation. 可以 is permission, or saying something is fine. For 'not allowed', say 不可以 or 不能. 我会踢足球，不会打羽毛球。 (I can play football, but not badminton.)"
      }
    ],
    "qibu4-u2-2": [
      {
        "title": "打, 踢 and 游 — playing sport",
        "body": "Games you play with your hands or a racket take 打, 'hit'. Football takes 踢, 'kick'. 游泳 is to swim, and 游 on its own is the verb. 打球 and 踢球 mean 'play' when the game is clear. 打羽毛球 (play badminton)"
      }
    ],
    "qibu4-u2-3": [
      {
        "title": "一边 … 一边 … — at the same time",
        "body": "Put 一边 before each of the two actions. The subject comes first, before the first 一边. 他一边跑步一边听音乐。 (He listens to music while he runs.)"
      }
    ],
    "qibu4-u2-4": [
      {
        "title": "过 — have you ever?",
        "body": "You met 过 in 起步 3. It asks about experience. The short answer repeats the verb with 过: 打过 or 没打过. 你打过羽毛球吗？ (Have you ever played badminton?)"
      },
      {
        "title": "这样 — like this",
        "body": "这样 before a verb means 'this way'. On its own, with a question mark, it checks: 'like this?' 球拍要这样拿。 (Hold the racket like this.)"
      },
      {
        "title": "Sounds · yu, you and yong",
        "body": "yu is really ü: round your lips as if to whistle and say 'ee'. you sounds like 'yo' in 'yoga'. yong starts like 'yo' and ends in -ng. Sport words have all three."
      },
      {
        "title": "Culture · Morning in a Chinese park",
        "body": "Walk through a Chinese park at seven in the morning and it's already busy. Older people do tai chi (太极拳 tàijíquán) in slow, quiet groups, others walk backwards or clap their hands for their health, and someone is always practising calligraphy on the path with a big brush and water."
      }
    ],
    "qibu4-u3-1": [
      {
        "title": "比 … 多了 — much more",
        "body": "For a big difference, add 多了 after the adjective. For a small one, add 一点儿, as in 起步 3. Still no 很 in a 比 sentence. 新的比去年的贵多了。 (The new one is much more expensive than last year's.)"
      }
    ],
    "qibu4-u3-2": [
      {
        "title": "最 — the most",
        "body": "最 before an adjective makes 'the most' or '-est'. It also goes before 喜欢: 'like best'. Don't add 很. 拍照最重要。 (The camera is the most important thing.)"
      }
    ],
    "qibu4-u3-3": [
      {
        "title": "又 … 又 … — both … and …",
        "body": "Two things about the same thing, usually both good or both bad. Each adjective gets its own 又. 又轻又好看 (light and good-looking)"
      }
    ],
    "qibu4-u3-4": [
      {
        "title": "还是 or 或者?",
        "body": "Both mean 'or'. 还是 is for questions that offer a choice. 或者 is for statements, when either will do. 你喜欢黑色还是白色？ (Do you prefer black or white?)"
      }
    ],
    "qibu4-u3-5": [
      {
        "title": "不 … 了 — not any more",
        "body": "了 at the end of a negative sentence shows a change: it used to be so, but not now. 不能再 + adjective + 了 means 'can't go any further'. 我的手机不能用了。 (My phone doesn't work any more.)"
      },
      {
        "title": "Sounds · ui is really uei",
        "body": "Pinyin ui is short for uei: 最 zuì sounds like 'zway', and 贵 guì like 'gway'. Glide from u to the 'ay' in 'day'."
      },
      {
        "title": "Culture · A phone for everything",
        "body": "In Chinese cities, the phone is your wallet. People pay for almost everything with WeChat Pay (微信支付) or Alipay (支付宝) by scanning a QR code, from a meal in a restaurant to a bunch of vegetables at a market stall. Many young people hardly carry cash at all, and some street sellers just tape a printed QR code to their stall."
      }
    ],
    "qibu4-u4-1": [
      {
        "title": "On the phone",
        "body": "Start every call with 喂. When you answer at work, add the name of the place. To ask for someone, use 请问…在吗？ 哪位 is the polite way to ask 'who?'. 喂，您好，陈家饺子。 (Hello, Chen Family Dumplings.)"
      }
    ],
    "qibu4-u4-2": [
      {
        "title": "打错了 and 找",
        "body": "打错了 is 'wrong number'. 找 means 'look for', and on the phone it's 'want to speak to'. 我一会儿再打 means 'I'll call back later'. 您打错了。 (You've got the wrong number.)"
      }
    ],
    "qibu4-u4-3": [
      {
        "title": "跟 … 一起 — with",
        "body": "跟 means 'with'. The whole 跟…一起 phrase goes before the verb. 和 works the same way, but 跟 is more common in speech. 我想跟你一起去打羽毛球。 (I'd like to go and play badminton with you.)"
      }
    ],
    "qibu4-u4-4": [
      {
        "title": "预订 and 订 — booking",
        "body": "预订 is the full word, used by staff and on websites. In speech people usually say 订. Put the day and time first, and the number of people last. 我想预订一个羽毛球场。 (I'd like to book a badminton court.)"
      }
    ],
    "qibu4-u4-5": [
      {
        "title": "很会 — good at it",
        "body": "会 means you can do something. 很会 means you're good at it, and 不太会 means you're not much good. 他很会打乒乓球。 (He's really good at table tennis.)"
      },
      {
        "title": "给 + person + 打电话",
        "body": "The person you ring goes after 给, before 打电话. Don't say 打电话给他 in a simple sentence, though you'll hear it. 我给她打电话。 (I'll ring her.)"
      },
      {
        "title": "Sounds · 喂 on the phone",
        "body": "喂 is wèi in the dictionary, and that's how you'd shout 'hey!'. On the phone, most people say it with a rising tone, wéi, which sounds friendlier. This book prints wèi. Say these phone and sport words aloud."
      },
      {
        "title": "Culture · Table tennis: China's national game",
        "body": "Table tennis is often called China's 国球 (guóqiú), its 'national ball game'. China has won most of the Olympic table-tennis gold medals since the sport joined the Games in 1988, and players like Deng Yaping and Ma Long are household names."
      }
    ],
    "qibu5-u1-1": [
      {
        "title": "觉得 — I think, I feel",
        "body": "觉得 gives your opinion or says how you feel. To ask what someone thought, use 你觉得…怎么样？ Don't use 想 for opinions: 想 is 'would like to'. 你觉得演出怎么样？ (What did you think of the show?)"
      }
    ],
    "qibu5-u1-2": [
      {
        "title": "挺 … 的 — pretty, quite",
        "body": "挺 is spoken and friendly, a little weaker than 很 or 真. The 的 at the end is usual but not a must. 挺好的！ (Pretty good!)"
      }
    ],
    "qibu5-u1-3": [
      {
        "title": "From great to so-so",
        "body": "还可以 is 'OK, not bad', without much excitement. 一般 is 'so-so', and it's the polite way to say you weren't impressed. People soften criticism, so 一般 can mean quite bad. 演出怎么样？——太棒了！ (How was the show? Brilliant!)"
      }
    ],
    "qibu5-u1-4": [
      {
        "title": "了 — what happened",
        "body": "To report what happened, put 了 after the verb, usually with an amount. For 'didn't', use 没 and drop the 了. 了 at the end of a sentence marks a change: 后来就好了, 'then she was fine'. 她唱了六首歌。 (She sang six songs.)"
      }
    ],
    "qibu5-u1-5": [
      {
        "title": "首 and 句 — songs and lines",
        "body": "首 counts songs and poems, and 句 counts lines and sentences. 第 + number is 'first, second …', and 最后 is 'last'. 一句也没听懂 means 'didn't understand a single word'. 她唱错了一句。 (She got a line wrong.)"
      },
      {
        "title": "Sounds · 听 or 挺? The tone makes the word",
        "body": "tīng is 'listen' and tǐng is 'quite'. 挺好听的 has both, and only the tones keep them apart: a low dip, then high and level. Remember the two third tones in 挺好: say tíng hǎo."
      },
      {
        "title": "Culture · A night at KTV",
        "body": "In China, you don't need a stage to sing. KTV (karaoke) is one of the most popular nights out: a group of friends or colleagues hires a private room with a big screen, sofas, a menu of snacks and drinks, and two microphones that never stop being passed round. Birthdays, work dinners and the end of exams all tend to finish at KTV."
      }
    ],
    "qibu5-u2-1": [
      {
        "title": "Verb + 得 — how it's done",
        "body": "To say how well someone does something, put 得 (said de) after the verb, then the comment. 不 goes after 得, not before the verb. To ask, say 说得怎么样？ or 说得好不好？ 你学得真快！ (You learn really fast!)"
      }
    ],
    "qibu5-u2-2": [
      {
        "title": "With an object: say the verb twice",
        "body": "得 can't come straight after an object. Either say the verb again, or put the object first and drop the first verb. 你切菜切得真快！ (You chop really fast!)"
      }
    ],
    "qibu5-u2-3": [
      {
        "title": "哪里哪里 — taking a compliment",
        "body": "The traditional reply to praise plays it down. 哪里哪里 is 'oh, not at all', and 还差得远呢 is 'I've still got a long way to go'. Passing the credit on is even better. Among friends, a simple 谢谢 is fine too. 你的中文真好！——哪里哪里。 (Your Chinese is so good! Oh, not really.)"
      }
    ],
    "qibu5-u2-4": [
      {
        "title": "越来越 — more and more",
        "body": "越来越 shows something changing over time. It goes straight before the adjective, with no 很. 了 at the end is common. 你的中文越来越好了！ (Your Chinese is getting better and better!)"
      }
    ],
    "qibu5-u2-5": [
      {
        "title": "多 + verb + 点儿 — have some more!",
        "body": "Every host's favourite line is 多吃点儿！ 多 before a verb means 'more', as in 多喝热水. 少 before a verb means 'less'. 多吃点儿！ (Have some more!)"
      },
      {
        "title": "Sounds · Light de, and děi",
        "body": "得 in 说得好 and 的 in 我的 are both said de, light and short, so you only tell them apart in writing. When 得 means 'must', it's děi. 哪里哪里 sounds like ná li ná li in quick speech."
      },
      {
        "title": "Culture · Modesty: 哪里哪里",
        "body": "Say 你好 to someone in China and you may well hear 你的中文说得真好！ Chinese people are generous with praise for learners. But there's a catch: the traditional reply to a compliment isn't 'thank you'. Accepting praise too readily can sound like boasting, so people play it down with 哪里哪里 (literally 'where? where?'), 还差得远呢 or 过奖了 (guòjiǎng le, 'you flatter me')."
      }
    ],
    "qibu5-u3-1": [
      {
        "title": "就 — early or quick",
        "body": "就 after a time says it happened earlier or faster than you'd expect. 了 usually comes at the end. 我七点半就到了。 (I got here at half past seven.)"
      }
    ],
    "qibu5-u3-2": [
      {
        "title": "才 — late or slow",
        "body": "才 says it happened later than expected, or took longer. Don't add 了. 你怎么才来？ means 'what took you so long?' 我八点才醒。 (I didn't wake up till eight.)"
      }
    ],
    "qibu5-u3-3": [
      {
        "title": "就 or 才?",
        "body": "The same time can be early or late. It depends on what you expected, and how you feel about it. 我们七点半就到了，你九点才来！ (We were here at half seven, and you didn't come till nine!)"
      }
    ],
    "qibu5-u3-4": [
      {
        "title": "一 … 就 … — as soon as",
        "body": "The second thing happens straight after the first. 一 and 就 both go before verbs, never before the subject. 我一醒就出门了。 (I left as soon as I woke up.)"
      }
    ],
    "qibu5-u3-5": [
      {
        "title": "Days and weeks either side",
        "body": "Days count out from today. Weeks and months double 上 and 下: 上上个星期 is the week before last, and 下下个月 is the month after next. 前天吃饭，你也来晚了。 (You were late for dinner the day before yesterday too.)"
      },
      {
        "title": "Sounds · c or z?",
        "body": "c sounds like the 'ts' in 'cats', with a strong puff of air. z is like the 'ds' in 'beds', with no puff. Hold your hand in front of your mouth: you should feel 才, but not 在."
      },
      {
        "title": "Culture · China by high-speed train",
        "body": "China has the world's biggest high-speed rail network, over 45,000 kilometres of it. Trains called 高铁 (gāotiě) run at up to 350 km/h: Beijing to Shanghai takes about four and a half hours, and Chengdu to Chongqing about an hour."
      }
    ],
    "qibu5-u4-1": [
      {
        "title": "Opening and closing an email",
        "body": "An email to a friend opens with 亲爱的 and the name, then a colon, with 你好！ on the next line. It closes with a wish, 祝你…, then 你的朋友 and your name, with the date last. For someone you don't know well, just start with the name and 你好. 亲爱的小雨： (Dear Xiaoyu,)"
      }
    ],
    "qibu5-u4-2": [
      {
        "title": "Writing a diary",
        "body": "A Chinese diary entry puts the date, the day and the weather on the first line. In writing, the day of the month is 日, not 号. Tell the day with 了, and say how you felt with 觉得 or 心里. 六月二十六日　星期六　晴天 (Saturday 26 June, sunny)"
      }
    ],
    "qibu5-u4-3": [
      {
        "title": "会 … 的 — I'm sure it will",
        "body": "You know 会 as 'can'. It also means 'will', for something that's likely to happen. 的 at the end makes it sound sure and warm. 我们会想你的。 (We'll miss you.)"
      }
    ],
    "qibu5-u4-4": [
      {
        "title": "就 … 了 and 才 — soon, and not until",
        "body": "With a future time, 就…了 means 'soon, already by then', and it sounds close. 才 means 'not until', and it sounds a long way off. 你下个星期就回成都了？ (So you're going back to Chengdu next week?)"
      }
    ],
    "qibu5-u4-5": [
      {
        "title": "用 — in Chinese, by phone",
        "body": "用 means 'to use'. Put 用中文 before the verb for 'in Chinese', and 用手机 for 'on your phone'. 用中文写邮件 (write emails in Chinese)"
      }
    ],
    "qibu5-u4-6": [
      {
        "title": "Sounds · ie and üe",
        "body": "写 xiě and 学 xué are easy to mix up. xie spreads the lips; for xue, round them as if to whistle before you open to e. After j, q, x and y, ü is written u, so xue is really xüe, and 月 yuè is yüe."
      },
      {
        "title": "Culture · Dear …: letters and emails in Chinese",
        "body": "A Chinese letter has a fixed shape. The name goes top left, followed by a colon, and 你好！ gets a line of its own, indented. The letter ends with a wish, 祝你… ('wishing you …'): 身体健康 (good health) for older people, 学习进步 (progress in your studies) for students, 工作顺利 (gōngzuò shùnlì, 'that work goes well') for colleagues, or just 快乐 for friends. Your name and the date go bottom right, with the date last."
      }
    ],
    "jinbu1-u1-1": [
      {
        "title": "打算 and 计划 — plans",
        "body": "You met 打算 in 起步 2: 'plan to', always before a verb. It can be a noun too: 有什么打算？ 'what are your plans?'. 计划 is a firmer, more organised plan, and it's the word for a written itinerary. 你打算在成都待几天？ (How many days are you planning to stay in Chengdu?)"
      }
    ],
    "jinbu1-u1-2": [
      {
        "title": "先 … 再 … — first this, then that",
        "body": "For a plan, 先 goes before the first action and 再 before the next one. 再 is for things that haven't happened yet; 然后 works for both future and past. 我先去成都，再去北京。 (I'll go to Chengdu first, then Beijing.)"
      }
    ],
    "jinbu1-u1-3": [
      {
        "title": "住几晚？ — nights and dates",
        "body": "Hotels count nights with 晚 or 个晚上. The length goes after the verb: 住五晚, not 五晚住. Dates go before it, with 号 in speech: 十九号入住. 我想住五晚。 (I'd like to stay five nights.)"
      }
    ],
    "jinbu1-u1-4": [
      {
        "title": "包括 — including",
        "body": "包括 means 'to include'. It's the key word for what's in the price: breakfast, tax, a ticket. The answer is 包括 or 不包括. 房费包括早餐吗？ (Does the room rate include breakfast?)"
      }
    ],
    "jinbu1-u1-5": [
      {
        "title": "Verb + 好 — done and ready",
        "body": "好 after a verb says the job is done properly and ready to go. 订好了 is 'all booked', and 还没想好 is 'I haven't decided yet'. 带好 is 'make sure you've got'. 机票订好了。 (The flights are booked.)"
      }
    ],
    "jinbu1-u1-6": [
      {
        "title": "还是 … 吧 — I'd better",
        "body": "You know 还是 as 'or' and 'still'. With 吧 at the end it means 'I'd better' or 'let's just': a polite way to settle on something after thinking it over. 太麻烦你们了，我还是住酒店吧。 (It's too much trouble for you. I'd better stay in a hotel.)"
      }
    ],
    "jinbu1-u1-7": [
      {
        "title": "Sounds · Prices the short way",
        "body": "In speech, prices drop the last unit: 四百八 is 480, and 四百零八 is 408. Say the numbers as one smooth phrase with the stress on the first number. Remember the tone changes: 一晚 is said yì wǎn, and 一百 is yì bǎi."
      },
      {
        "title": "Culture · Checking in, Chinese style",
        "body": "At a Chinese hotel, check-in starts with your passport. Hotels must register foreign guests with the police, so the front desk will scan it, and not every hotel can take foreigners: when you book online, look for a note saying it accepts overseas guests. Chinese guests use their ID card (身份证)."
      }
    ],
    "jinbu1-u2-1": [
      {
        "title": "Getting around by metro",
        "body": "Lines are numbered: 二号线, 三号线. 坐到 is 'ride as far as', and 站 counts stops. To change, say 在 + station + 换乘 (or just 换) + the next line. 你先坐二号线，到春熙路换乘三号线。 (Take Line 2 to Chunxi Road, and change to Line 3.)"
      }
    ],
    "jinbu1-u2-2": [
      {
        "title": "Topic first — 春熙路我去过",
        "body": "Chinese often puts what you're talking about first, then says something about it. The object moves to the front, and the rest of the sentence stays in its usual order. It's very common in speech, especially to pick up something already mentioned. 春熙路我去过。 (Chunxi Road, I've been there.)"
      }
    ],
    "jinbu1-u2-3": [
      {
        "title": "Getting it wrong: 坐反, 坐错, 坐过站",
        "body": "Put the result straight after the verb. 坐反了 is going the wrong way, 坐错了 is taking the wrong line, and 坐过站了 is missing your stop. 别 … 了 warns someone not to. 别坐反了！ (Don't go the wrong way!)"
      }
    ],
    "jinbu1-u2-4": [
      {
        "title": "Being a host — 快坐，别客气",
        "body": "Hosts hurry guests along with 快: 快进来, 快坐. 别客气 here means 'don't be shy', and 就当在自己家 is 'make yourself at home'. When you hand over a present, say 一点儿小礼物, and expect 你太客气了 in return. 快进来，快进来！ (Come in, come in!)"
      }
    ],
    "jinbu1-u2-5": [
      {
        "title": "叔叔 and 阿姨 — your friend's parents",
        "body": "Call a friend's parents 叔叔 and 阿姨, just as you do older strangers. Using their given names would sound rude. When you mention them to your friend, say 你爸爸 and 你妈妈, or 叔叔阿姨. 叔叔好！阿姨好！ (Hello! (to a friend's father and mother))"
      }
    ],
    "jinbu1-u2-6": [
      {
        "title": "Sounds · A Sichuan accent",
        "body": "Chengdu people speak Sichuanese at home, and their Mandarin often has a Sichuan flavour. The curled-tongue sounds zh, ch, sh flatten to z, c, s, so 是 and 四 can sound the same, and n and l often swap. You'll also hear a few local words."
      },
      {
        "title": "Culture · Mid-Autumn at home",
        "body": "Mid-Autumn Festival (中秋节) is about 团圆: the family together. People travel home if they can, there's a public holiday, and the big meal is at home, not in a restaurant. In the evening everyone goes out onto the balcony or into a park to look at the moon (赏月), which is said to be at its roundest and brightest that night."
      }
    ],
    "jinbu1-u3-1": [
      {
        "title": "跟 … 一样 — the same as",
        "body": "跟 … 一样 says two things are the same. Add an adjective for the way they're the same: 跟我一样高. For 'not the same', put 不 before 一样, not before 跟. 一模一样 is 'identical'. 你的衬衫怎么跟马克的一样？ (How come your shirt is the same as Mark's?)"
      }
    ],
    "jinbu1-u3-2": [
      {
        "title": "像 — like, look like",
        "body": "像 compares things that aren't really the same: 'like'. 像 … 一样 is 'just like', and 长得像 is for faces and looks. Don't say 很一样; say 很像. 你们俩像父子一样！ (You two look like father and son!)"
      }
    ],
    "jinbu1-u3-3": [
      {
        "title": "差不多 — about the same",
        "body": "You know 差不多 as 'about' before a number. After 跟, it means 'about the same': there's a difference, but not much. 差不多 on its own is also a handy reply: 'more or less'. 你们俩个子差不多。 (You two are about the same height.)"
      }
    ],
    "jinbu1-u3-4": [
      {
        "title": "大一号 — one size up",
        "body": "号 means 'size'. 大一号 is one size up, and 小一号 one size down: the number goes after the adjective, as in 大一点儿. Clothes in China tend to be sized smaller than in Britain. 能换大一号的吗？ (Could I change it for one a size up?)"
      }
    ],
    "jinbu1-u3-5": [
      {
        "title": "退 or 换? — returns, exchanges and 要是",
        "body": "换 is swapping for something else, and 退 is taking it back for your money. 退换 covers both. 要是 means 'if' and is common in speech; 就 often starts the second half. 这件太小了，能换吗？ (This is too small. Can I change it?)"
      }
    ],
    "jinbu1-u3-6": [
      {
        "title": "Sounds · Stress for contrast",
        "body": "When you correct someone or compare two things, stress the word that makes the difference, and say it a little longer and louder. The rest of the sentence gets lighter."
      }
    ],
    "jinbu1-u3-7": [
      {
        "title": "Culture · Hotpot, Chengdu style",
        "body": "Hotpot (火锅) is Chengdu's great night out. A pot of broth bubbles in the middle of the table, and everyone cooks their own food in it: thin slices of beef and lamb, tripe (毛肚), duck intestines, tofu, mushrooms, potato and greens. The spicy red broth (红锅) is thick with dried chillies and Sichuan pepper (花椒), which gives the famous numbing tingle called 麻. If that's too much, order a split pot (鸳鸯锅) with a clear, mild broth on the other side."
      }
    ],
    "jinbu1-u4-1": [
      {
        "title": "让 — made me feel",
        "body": "让 means 'to let', and also 'to make someone feel'. The cause comes first, then 让, the person, and the feeling. It's warmer and more natural than saying 'I feel … because …'. 你们让我觉得像在自己家一样。 (You made me feel completely at home.)"
      }
    ],
    "jinbu1-u4-2": [
      {
        "title": "难忘 and 好找 — hard to, easy to",
        "body": "难 before a verb means 'hard to', and 好 means 'easy to'. You know 好吃, 好看, 难吃 and 难过. The same pattern gives 难忘 (hard to forget, unforgettable), 好找 (easy to find) and 难找 (hard to find). 这是我最难忘的一个中秋节。 (It's the most memorable Mid-Autumn I've ever had.)"
      }
    ],
    "jinbu1-u4-3": [
      {
        "title": "Writing to older people",
        "body": "Start with the family name and 叔叔 or 阿姨, then a colon. 亲爱的 is for friends. Thank them first (首先), then give details, then thank them again (再次感谢) and finish with a wish. 身体健康 and 万事如意 suit older people. 林叔叔、林阿姨：你们好！ (Dear Mr and Mrs Lin, hello!)"
      }
    ],
    "jinbu1-u4-4": [
      {
        "title": "不是 … 而是 … — not this, but that",
        "body": "而是 is the written partner of 不是. It corrects the first idea and stresses the second. In speech, people often just say 不是 A，是 B. 你们让我觉得自己不是客人，而是家里人。 (You made me feel I wasn't a guest, but one of the family.)"
      }
    ],
    "jinbu1-u4-5": [
      {
        "title": "Thanks and replies",
        "body": "Chinese thanks often apologise for the trouble: 太麻烦你们了. The host waves it away with 麻烦什么！ or 不麻烦. When you've helped someone, reply to their thanks with 应该的, 'it was the least I could do'. 这几天真是太麻烦你们了。 (I've put you to so much trouble these last few days.)"
      }
    ],
    "jinbu1-u4-6": [
      {
        "title": "Sounds · Reading a letter aloud",
        "body": "Read in chunks, not word by word. Pause at each comma, a little longer at each full stop, and keep 的, 了 and 们 light and short. The stress falls on the words that carry the feeling: 非常, 最, 一直."
      },
      {
        "title": "Culture · Being a guest, and saying thank you",
        "body": "Chinese hospitality can be overwhelming. Hosts meet you at the station, pay for everything, fill your bowl before it's empty and pack you off with food for the journey. Arguing too hard can seem cold, so accept graciously, and repay the kindness later: a present from home, a meal when they visit you, or photos and news."
      }
    ],
    "jinbu2-u1-1": [
      {
        "title": "把 — doing something to something",
        "body": "把 brings the object forward, before the verb, when you do something to it: move it, hang it, turn it off. The verb can't stand alone at the end: it needs something after it, like 上去, 好, 在门口 or 了. 别 and 没 go before 把. 快帮我把这幅画挂上去。 (Quick, help me hang this painting up.)"
      }
    ],
    "jinbu2-u1-2": [
      {
        "title": "来 and 去 — towards you, away from you",
        "body": "来 means towards the speaker and 去 means away. So someone downstairs calls 下来！ and someone upstairs says 我下去！. A place goes before 来 or 去: 回饭馆去, 进教室来. In speech 来 and 去 are usually light. 快下来帮我拿！ (Come down and help me carry it!)"
      }
    ],
    "jinbu2-u1-3": [
      {
        "title": "Verb + direction — 挂上去, 拿过来",
        "body": "Put the direction straight after the verb to show which way the thing moves. 挂上去 is 'hang up there', 拿过来 is 'bring it over here', 搬下去 is 'carry it downstairs'. With 把, the object comes before the verb. 地上那幅你帮我拿过来。 (Bring me the one on the floor.)"
      }
    ],
    "jinbu2-u1-4": [
      {
        "title": "把 … 在 / 到 — putting things somewhere",
        "body": "To say where something ends up, use 把 with 在 (where it stays) or 到 (where it goes to). You can't say 搬桌子到门口 without 把: say 把桌子搬到门口. 我们把这张桌子搬到门口去吧。 (Let's move this table to the door.)"
      }
    ],
    "jinbu2-u1-5": [
      {
        "title": "挂高一点儿 — adjusting",
        "body": "To fine-tune something, put an adjective after the verb and 一点儿 after that: 挂高一点儿, 放低一点儿. 再 means 'a bit more'. For a direction, use 往: 再往左一点儿. 有点儿低，再挂高一点儿。 (It's a bit low. Hang it a bit higher.)"
      }
    ],
    "jinbu2-u1-6": [
      {
        "title": "Sounds · Light directions",
        "body": "来 and 去 after a verb are usually said lightly, in the neutral tone, and so is the 上, 下 or 过 in front of them in a longer phrase. Put the stress on the main verb: GUÀ shang qu, NÁ guo lai."
      }
    ],
    "jinbu2-u1-7": [
      {
        "title": "Culture · Opening day, Chinese style",
        "body": "In China, an opening (开幕) is a proper event. Shops, restaurants and exhibitions often start with a ribbon-cutting (剪彩), and the entrance fills up with tall flower baskets (花篮) sent by friends and business partners, each with a red ribbon carrying the sender's name and good wishes."
      }
    ],
    "jinbu2-u2-1": [
      {
        "title": "比 … + how much — 大两岁",
        "body": "To say exactly how big the difference is, put the amount after the adjective: 大两岁, 贵五十镑, 高一点儿. Don't put it before: not 比我两岁大. 这件唐装比我还大两岁！ (This Tang jacket is two years older than me!)"
      }
    ],
    "jinbu2-u2-2": [
      {
        "title": "得多 and 多了 — much more",
        "body": "For a big difference, add 得多 or 多了 after the adjective. They mean the same. In a 比 sentence you can't use 很 or 非常 before the adjective: not 比旗袍很早. 汉服比旗袍早得多。 (Hanfu is much older than the qipao.)"
      }
    ],
    "jinbu2-u2-3": [
      {
        "title": "比 … 还 / 更 — even more",
        "body": "还 and 更 both mean 'even more'. 还 often sounds surprised or teasing: the jacket is even older than Chen Ming! 更 is more neutral, and can be used without 比 when the comparison is clear. 这件唐装比我还大！ (This jacket is even older than me!)"
      }
    ],
    "jinbu2-u2-4": [
      {
        "title": "没有 … 那么 — not as … as",
        "body": "没有 … 那么 says A doesn't reach B's level. It's softer than 比 with a negative. Use 这么 for something here and now. Don't put an amount after it: for 'two years younger', use 比 … 小两岁. 汉服没有旗袍那么方便。 (Hanfu isn't as practical as a qipao.)"
      }
    ],
    "jinbu2-u2-5": [
      {
        "title": "穿 or 戴? — wearing",
        "body": "穿 is for things you get into: clothes, shoes, socks. 戴 is for things you put on or attach: hats, glasses, a watch, a necklace. 穿上 and 戴上 are 'put on'. 开幕那天我穿旗袍。 (I'm wearing the qipao on opening night.)"
      }
    ],
    "jinbu2-u2-6": [
      {
        "title": "Sounds · Stress the difference",
        "body": "In a comparison, the most important part is how big the difference is, so that's where the stress goes. Say the amount a little louder and longer, and keep 比 and the names light."
      },
      {
        "title": "Culture · Three kinds of Chinese clothes",
        "body": "The qipao (旗袍) is the dress most people picture when they think of Chinese clothes: close-fitting, with a high collar and fastenings of knotted cloth. Its modern form grew popular in Shanghai in the 1920s and 30s. Today it's worn for weddings, parties and formal events, and red is the favourite colour for a celebration."
      }
    ],
    "jinbu2-u3-1": [
      {
        "title": "用 … 来 … — using something to do something",
        "body": "用 names the tool or the method, and 来 leads into what you do with it. 来 can be left out in speech, but 用…来… sounds clear and complete, especially when explaining. 国画用毛笔和墨来画。 (Chinese painting is done with a brush and ink.)"
      }
    ],
    "jinbu2-u3-2": [
      {
        "title": "之一 — one of the …",
        "body": "之一 goes at the very end, after the whole group: 最有名的画家之一 is 'one of the most famous painters'. It's the natural way to avoid saying 'the most' when there are others too. 齐白石是中国最有名的画家之一。 (Qi Baishi is one of China's most famous painters.)"
      }
    ],
    "jinbu2-u3-3": [
      {
        "title": "好像 and 跟 … 一样 — as if, just like",
        "body": "好像 means something seems or looks a certain way. 跟活的一样 is 'just like the real thing', a favourite way to praise a picture. You can put both together: 好像跟真的一样. 这些虾好像在水里游。 (These shrimps look like they're swimming.)"
      }
    ],
    "jinbu2-u3-4": [
      {
        "title": "到底 — what exactly?",
        "body": "到底 in a question means 'exactly' or 'after all', when you really want a clear answer. It goes before the verb or the question word, never at the end. 国画和油画到底有什么不同？ (What exactly is the difference between Chinese painting and oil painting?)"
      }
    ],
    "jinbu2-u3-5": [
      {
        "title": "是 … 的 — talking about how it was done",
        "body": "When something has already happened and you want to know who did it, when, where or how, put the detail between 是 and 的. It's how people talk about paintings: 是谁画的？ 是在哪儿学的？ 这是谁画的？ (Who painted this?)"
      }
    ],
    "jinbu2-u3-6": [
      {
        "title": "Sounds · Two third tones",
        "body": "When two third tones come together, the first one rises and becomes a second tone. The characters keep their third-tone marks in writing, so watch out for them. With three or more, group the words and change all but the last in each group."
      },
      {
        "title": "Culture · Ink, brush and empty space",
        "body": "Chinese painting (国画) uses the same tools as calligraphy, often called the 'four treasures of the study': the brush, the ink, the paper and the inkstone, where solid ink is ground with water. A painter controls everything with the brush: thick or thin lines, dark or watery ink, fast or slow strokes. Mistakes can't be painted over, so the work is quick and sure."
      }
    ],
    "jinbu2-u4-1": [
      {
        "title": "Verb + 完 — finished",
        "body": "完 after a verb says the action has come to an end: there's nothing left to do. The negative is 没 … 完, 'not finished yet'. To ask, add 了没有 or 了吗. 菜单做完了没有？ (Have you finished the menu yet?)"
      }
    ],
    "jinbu2-u4-2": [
      {
        "title": "完 or 好? — finished, or done right",
        "body": "完 just says you've come to the end. 好 says it's been done properly and is ready. 写完了 means you stopped writing; 写好了 means it's ready to send. Often both work. 英文菜名我都写好了。 (I've done all the English names of the dishes.)"
      }
    ],
    "jinbu2-u4-3": [
      {
        "title": "到, 见 and 懂 — getting there",
        "body": "These say the action worked. 见 is for seeing and hearing: 看见, 听见. 到 is for reaching or getting what you wanted: 找到, 收到, 买到. 懂 is for understanding: 看懂, 听懂. The negative uses 没: 没看见, 没看懂. 我发给你的照片，你看见了吗？ (Did you see the photos I sent you?)"
      }
    ],
    "jinbu2-u4-4": [
      {
        "title": "看看, 试一试 — just a bit",
        "body": "Saying a verb twice makes it light and casual: 'have a look', 'give it a try', 'have a rest'. One-syllable verbs can take 一 in the middle (试一试). Two-syllable verbs repeat as a pair: 休息休息. For the past, put 了 in the middle: 看了看. 我们去看看吧。 (Let's go and have a look.)"
      }
    ],
    "jinbu2-u4-5": [
      {
        "title": "聊聊天, 散散步 — relaxing with verb + object",
        "body": "When a verb has its own object, like 聊天 or 散步, only the verb part repeats: 聊聊天, not 聊天聊天. It makes plans sound easy and unhurried, perfect for a lazy Sunday. 找个地方喝喝咖啡，聊聊天。 (Find somewhere for a coffee and a chat.)"
      }
    ],
    "jinbu2-u4-6": [
      {
        "title": "Sounds · Light repeats",
        "body": "In a repeated verb, the second one is said lightly, in the neutral tone, and the 一 in the middle is light too. It's part of what makes these phrases sound so relaxed. Say the first syllable clearly and let the rest fall away."
      },
      {
        "title": "Culture · What's on the menu?",
        "body": "Chinese dish names can be poetic, practical or just puzzling. Many simply list what's in them: 西红柿炒鸡蛋 is tomato fried with egg. Others describe how a dish looks or where it comes from, and some tell a story. 蚂蚁上树, 'ants climbing a tree', is minced pork on glass noodles. 夫妻肺片, 'husband and wife lung slices', is a cold Sichuan beef dish with no lungs in it at all, and it's famous for bad English translations."
      }
    ],
    "jinbu3-u1-1": [
      {
        "title": "除了 … 以外，还 / 也 — besides",
        "body": "With 还 or 也 in the second half, 除了…以外 adds something: 'besides A, there's also B'. 以外 can be dropped in speech. 还 and 也 go after the subject, before the verb. 除了饺子以外，今天晚上还有鱼、有鸡、有肉。 (Besides dumplings, tonight there's fish, chicken and meat.)"
      }
    ],
    "jinbu3-u1-2": [
      {
        "title": "除了 … 以外，都 — except",
        "body": "With 都 in the second half, 除了…以外 leaves something out: 'everything except A'. 别的 (the others) often comes before 都. Watch the difference: 还 adds, 都 excludes. 除了相声以外，别的都看懂了。 (I understood everything except the comic dialogues.)"
      }
    ],
    "jinbu3-u1-3": [
      {
        "title": "谁 … 谁 … — whoever",
        "body": "A question word used twice, once in each half, means 'whoever' (or 'whatever', 'wherever'). Both halves point to the same person or thing. 就 often comes before the second verb. 谁吃到硬币，谁明年就有福气。 (Whoever gets a coin will have good luck next year.)"
      }
    ],
    "jinbu3-u1-4": [
      {
        "title": "New Year wishes",
        "body": "过年好 and 新年好 are the everyday greetings for the whole holiday. 给您拜年了 is warm and respectful, for older people. 恭喜发财 wishes someone wealth, and is great for shopkeepers and friends. For older people, add 身体健康 and 万事如意. 叔叔、阿姨，过年好！ (Happy New Year!)"
      }
    ],
    "jinbu3-u1-5": [
      {
        "title": "不让 and …的话 — rules and ifs",
        "body": "不让 + verb is a spoken way to say something isn't allowed: 'they don't let you'. The formal word on signs is 禁止. …的话 at the end of a condition means 'if'. It can go with 要是 or stand alone. 现在城里不让放鞭炮了。 (You can't set off firecrackers in town any more.)"
      }
    ],
    "jinbu3-u1-6": [
      {
        "title": "Sounds · Beijing 儿",
        "body": "In Beijing, lots of words end with 儿, which curls the tongue back at the end of the syllable. When the syllable ends in -n or -i, that sound drops out: 馅儿 sounds like xiàr and 一块儿 like yí kuàr. You don't need to copy it, but you'll hear it all the time in the north."
      }
    ],
    "jinbu3-u1-7": [
      {
        "title": "Culture · Spring Festival in Beijing",
        "body": "Spring Festival (春节) starts on the first day of the lunar year, between late January and mid-February, and it's the biggest holiday in China. Hundreds of millions of people travel home, and the most important meal of the year is the New Year's Eve dinner (年夜饭). In the north, that means dumplings, shaped like old gold ingots (元宝) for wealth, with a coin hidden in one or two. Fish is always on the table too, because 鱼 sounds like 余, 'plenty left over'."
      }
    ],
    "jinbu3-u2-1": [
      {
        "title": "Can or can't: 听得懂, 听不懂",
        "body": "Put 得 or 不 between a verb and its result to say whether you can or can't manage it. 听懂 is 'understand by listening'; 听得懂 is 'can understand', 听不懂 is 'can't understand'. For 'can't', this is much more natural than 不能听懂. 他们唱的，您听得懂吗？ (Can you understand what they're singing?)"
      }
    ],
    "jinbu3-u2-2": [
      {
        "title": "Asking with 得 and 不",
        "body": "Ask with 吗 at the end, or put the 'can' and 'can't' forms side by side. Answer with just the 得 or 不 form: 听得懂 or 听不懂. 字幕你看得清楚吗？ (Can you see the subtitles?)"
      }
    ],
    "jinbu3-u2-3": [
      {
        "title": "看不出来 — can't tell",
        "body": "出来 after 看, 听 or 吃 means 'make out, tell': 看不出来 is 'can't tell by looking', 听得出来 is 'can tell by listening'. It's the natural way to say you can't work something out. 谁也看不出来是怎么变的。 (Nobody can work out how he does it.)"
      }
    ],
    "jinbu3-u2-4": [
      {
        "title": "听起来, 看起来 — it sounds, it looks",
        "body": "起来 after a verb of the senses says how something seems when you hear it, see it or taste it. 听起来 can also be about an idea: 听起来不错 is 'sounds good'. 二胡听起来有点儿难过。 (The erhu sounds a bit sad.)"
      }
    ],
    "jinbu3-u2-5": [
      {
        "title": "一会儿 … 一会儿 … — now this, now that",
        "body": "Two 一会儿 in a row describe something that keeps switching between two things. It's perfect for face-changing, and for the weather. 他的脸一会儿红，一会儿黑。 (His face is red one moment, black the next.)"
      }
    ],
    "jinbu3-u2-6": [
      {
        "title": "Sounds · Light 得 and 不",
        "body": "In 听得懂 and 听不懂, the 得 or 不 in the middle is said lightly, in the neutral tone, and quickly. The stress falls on the result at the end. That's why 不 in 听不懂 doesn't change tone the way it does in 不是: it's too light to carry one."
      },
      {
        "title": "Culture · Beijing opera and face-changing",
        "body": "Beijing opera (京剧) took shape in Beijing about two hundred years ago, when opera troupes from the south came to the capital and mixed their styles. It combines singing, speech, acting, dance and acrobatics, and every movement has a meaning. There are four main kinds of role: men, women, painted faces and clowns. The colours of a painted face (脸谱) tell you about the character: red is loyal and brave, black is honest and fierce, and white often means sly. The band sits at the side, led by drums and a small, high fiddle called the jinghu."
      }
    ],
    "jinbu3-u3-1": [
      {
        "title": "虽然 … 但是 … — although",
        "body": "虽然 gives one side, and 但是 or 可是 gives the other. Unlike English, Chinese uses both words. 虽然 can go before or after the subject. In speech you'll often hear just one of the pair. 虽然看了这么多遍，但是每次看都想哭。 (Although I've seen it so many times, I still want to cry every time.)"
      }
    ],
    "jinbu3-u3-2": [
      {
        "title": "不但 … 而且 … — not only … but also",
        "body": "不但…而且… adds a second point that goes further than the first. With one subject, put it before 不但. 也 or 还 often comes after 而且 too. 林黛玉不但长得漂亮，而且特别有才。 (Lin Daiyu isn't only beautiful, she's really talented too.)"
      }
    ],
    "jinbu3-u3-3": [
      {
        "title": "连 … 也 / 都 … — even",
        "body": "连 picks out the most surprising example, and 也 or 都 goes before the verb. It can pick out the subject (连小学生也知道) or the object (连一个字也不认识). With a negative, it means 'not even'. 在中国，连小学生也知道《红楼梦》。 (In China, even primary school children know Dream of the Red Chamber.)"
      }
    ],
    "jinbu3-u3-4": [
      {
        "title": "讲的是 … — it's about …",
        "body": "讲 means 'tell' or 'explain', and 讲的是 is the everyday way to say what a book, film or series is about. 给我讲讲 is 'tell me about it'. 《红楼梦》讲的是什么故事？ (What's Dream of the Red Chamber about?)"
      }
    ],
    "jinbu3-u3-5": [
      {
        "title": "看了十几遍了 — so far",
        "body": "With 了 after the verb and another 了 at the end, you count up to now, and it's still going on. With only the first 了, it's finished. Compare 我学了两年中文 (and stopped) with 我学了两年中文了 (and I'm still learning). 这部电视剧您看了多少遍了？ (How many times have you seen this series?)"
      }
    ],
    "jinbu3-u3-6": [
      {
        "title": "Sounds · Pairs in long sentences",
        "body": "When a sentence has two halves joined by a pair of words, pause after the first half and let your voice stay up, so people know more is coming. Stress the linking words a little: 虽然, 但是, 不但, 而且, 连."
      }
    ],
    "jinbu3-u3-7": [
      {
        "title": "Culture · The four great classical novels",
        "body": "Four novels, all written between the 14th and the 18th centuries, are known in China as the 'four great classical novels' (四大名著). Journey to the West follows the Monkey King and a monk on their way to India to fetch Buddhist scriptures. Romance of the Three Kingdoms tells of war and clever generals after the fall of the Han dynasty. Water Margin is about a band of 108 outlaws. And Dream of the Red Chamber (红楼梦) follows the rise and fall of the rich Jia family."
      }
    ],
    "jinbu3-u4-1": [
      {
        "title": "越 … 越 … — the more … the more",
        "body": "越…越… links two changes: as one grows, so does the other. With one subject, you can say 越爬越累. With two, each goes after its own 越: 越往上爬，台阶越陡. 越来越 is the simple version, for one thing changing over time. 我越爬越累！ (The more I climb, the more tired I get!)"
      }
    ],
    "jinbu3-u4-2": [
      {
        "title": "终于 — at last",
        "body": "终于 says something finally happened after a long wait or a lot of effort, and it sounds relieved. 才 is about being late, and often sounds cross: 你怎么才来？ 'what took you so long?' 终于到了！ (We're finally here!)"
      }
    ],
    "jinbu3-u4-3": [
      {
        "title": "累死了, 美极了 — so, so …",
        "body": "死了 after an adjective means 'incredibly', 'to death'. It's very spoken, and usually for bad things: 累死了, 冷死了, 饿死了. 极了 means 'extremely' and works for good things too: 美极了, 好吃极了. Don't add 很 before either. 累死了！ (I'm exhausted!)"
      }
    ],
    "jinbu3-u4-4": [
      {
        "title": "不到长城非好汉 — how a saying works",
        "body": "Many sayings are short and written-style. Here 到 is 'reach', 非 is the written word for 不是, and the two halves make an 'if not… then not…' sentence. 非 also appears in 非要, 'insist on', and 非常. 不到长城非好汉。 (You're not a hero till you've climbed the Great Wall.)"
      }
    ],
    "jinbu3-u4-5": [
      {
        "title": "走不了, 爬不上去 — can't manage it",
        "body": "不了 (liǎo) after a verb means you can't do it at all, because of time, tiredness or circumstances. 得了 is the 'can' form. You can also put 得 or 不 before a direction: 爬得上去, 走不下来. 明天我可能走不了路了。 (Tomorrow I might not be able to walk.)"
      },
      {
        "title": "Sounds · 不 and 一 on the Wall",
        "body": "不 changes to bú before a fourth tone, and 一 changes to yí before a fourth tone and yì before the other tones. The word tables keep bù and yī, so watch for them when you read aloud. In 不到长城非好汉, 不到 is said bú dào."
      },
      {
        "title": "Culture · The Great Wall",
        "body": "The Great Wall (长城) isn't one wall but many, built and rebuilt by different dynasties over more than two thousand years to keep out raiders from the north. Most of what visitors see today was built in the Ming dynasty, in brick and stone, with watchtowers (烽火台) where soldiers lit fires to send warnings along the Wall. Altogether it runs for over twenty thousand kilometres. And no, you can't see it from space with the naked eye."
      }
    ],
    "jinbu4-u1-1": [
      {
        "title": "被 — it happened to me",
        "body": "被 turns the sentence round: the thing that suffered comes first, and 被 introduces who did it. You can leave out who did it, as in 我的手机被偷了. In conversation, 被 is mostly for bad luck. The verb can't stand alone at the end: it needs 了, a result or a 'how much' after it. 我的手机被偷了！ (My phone's been stolen!)"
      }
    ],
    "jinbu4-u1-2": [
      {
        "title": "叫 and 让 — the spoken passive",
        "body": "In everyday speech, 叫 and 让 work just like 被, but they always need the 'who', even if it's only 人 (someone). 让你说对了 and 叫你说对了 are fixed ways of saying 'you were right', often when you wish they weren't. 我的自行车叫人偷了。 (My bike got nicked.)"
      }
    ],
    "jinbu4-u1-3": [
      {
        "title": "没被, 别被 — not, and don't let it",
        "body": "Negative words and 不会 go before 被, never after it. To ask when or where something happened, use 是…的 around the whole thing: 是在哪儿被偷的？ 还好，我的钱包没被偷。 (Luckily my wallet wasn't stolen.)"
      }
    ],
    "jinbu4-u1-4": [
      {
        "title": "被 or 把? — two ways round",
        "body": "把 starts with the person who did it, and 被 starts with the thing it happened to. Choose by what you're talking about. If it's your phone, start with the phone and use 被. 小偷把我的手机偷了。 (A thief stole my phone.)"
      }
    ],
    "jinbu4-u1-5": [
      {
        "title": "得要命 — terribly",
        "body": "得要命 after an adjective means 'unbearably, like mad'. Like 死了, it's very spoken and usually for bad things. Don't put 很 in front of the adjective. 下班的时候人多得要命。 (It was absolutely packed after work.)"
      }
    ],
    "jinbu4-u1-6": [
      {
        "title": "Sounds · Say it with feeling",
        "body": "A good complaint puts the stress on the word that hurts: the verb after 被, or the adjective before 得要命. 被 and 了 stay light and quick. 别提了 falls away at the end, with a sigh."
      }
    ],
    "jinbu4-u1-7": [
      {
        "title": "Culture · When your phone goes",
        "body": "In China, losing your phone is almost like losing your wallet, your keys and your ID at once. People pay for almost everything with WeChat or Alipay, show QR codes to get into buildings, and keep tickets and travel records on their phones. If a phone is stolen, the first job is to freeze the payment accounts, which both apps let you do from another phone, and to report any bank cards lost (挂失)."
      }
    ],
    "jinbu4-u2-1": [
      {
        "title": "对 … 感兴趣 — interested in",
        "body": "The thing you're interested in goes after 对, before 感兴趣. Adverbs like 很, 特别 and 不太 go before 感兴趣. Don't say 我感兴趣中文. 你对中文这么感兴趣。 (You're so interested in Chinese.)"
      }
    ],
    "jinbu4-u2-2": [
      {
        "title": "通过 — getting through",
        "body": "通过 is for getting through something that someone has to approve: a proposal (方案通过了), an interview (通过了面试), a probation period (通过了试用期). The thing can come first, as in 方案通过了, or after it, as in 通过了面试. 通过 can also mean 'through, by way of': 通过朋友认识的. 我们的方案通过了！ (Our proposal's been approved!)"
      }
    ],
    "jinbu4-u2-3": [
      {
        "title": "为了 — in order to, for",
        "body": "为了 puts the goal first and what you did for it second. It usually starts the sentence. Compare 因为, which gives a reason, not a goal. 为了明天，我每天背生词。 (For tomorrow, I've been learning new words every day.)"
      }
    ],
    "jinbu4-u2-4": [
      {
        "title": "进步 and 经验 — progress and experience",
        "body": "进步 is both a verb and a noun: 你进步了, 你的进步很大. 经验 is what you've learned from doing something, so 有什么经验 means 'any tips?'. For 'I've experienced something', use 经历, not 经验. 你进步真大！ (You've come so far!)"
      }
    ],
    "jinbu4-u2-5": [
      {
        "title": "Taking praise — 哪里哪里",
        "body": "When someone praises you, it's polite to play it down, especially about your own work. 哪里哪里 and 还差得远呢 are the classics. Younger people often just say 谢谢 and add something modest. 你的中文太好了！——哪里哪里，还差得远呢。 (Your Chinese is great! Oh, not really, I've a long way to go.)"
      }
    ],
    "jinbu4-u2-6": [
      {
        "title": "Sounds · Modest replies",
        "body": "哪里 is nǎ lǐ, but two third tones together make the first one rise, and in 哪里哪里 the 里 goes light: ná li ná li, said quickly with a smile. 还差得远呢 falls away gently at the end. In 过奖了, stress 奖 and keep 了 short."
      }
    ],
    "jinbu4-u2-7": [
      {
        "title": "Culture · Face at work, and taking a compliment",
        "body": "面子, face, is the respect you have in other people's eyes, and in Chinese business it matters a great deal. You give face (给面子) by addressing people by their title, like 王经理 or 沈总, by using 您, and by never making a client or a senior colleague look wrong in front of others. If you disagree, you say so privately, or wrap it in a suggestion. Making an effort also gives face: a foreign designer who presents in Chinese, even imperfectly, is showing the client real respect."
      }
    ],
    "jinbu4-u3-1": [
      {
        "title": "约 — making it happen",
        "body": "约 means to arrange to meet. 约个时间 is 'let's fix a time', 约好了 means it's agreed, and 我有约 means 'I've got plans'. 约 can also take a person: 我约了大卫 is 'I've arranged to see David'. 我们现在就约个时间吧。 (Let's fix a time right now.)"
      }
    ],
    "jinbu4-u3-2": [
      {
        "title": "改天, 有空再说 — maybe, maybe not",
        "body": "改天 means 'another day', and 改天聚聚吧 sounds warm. But without a date, it often never happens. 有空再说 and 再说吧 mean 'we'll see', and are often a polite way of saying no. If you really mean it, name a day. 我们好久没聚了，改天聚聚吧！ (We haven't got together for ages. Let's meet up some time!)"
      }
    ],
    "jinbu4-u3-3": [
      {
        "title": "不见不散, 回头见 — see you there",
        "body": "不见不散 means 'we won't leave until we've met', so be there! It's for friends, once a time and place are fixed. 回头见 is a relaxed 'see you later', and 到时候见 is 'see you then'. 一言为定 seals a deal. 七点，老成都，不见不散！ (Seven o'clock, Lao Chengdu. Be there!)"
      }
    ],
    "jinbu4-u3-4": [
      {
        "title": "着 — how things are",
        "body": "着 after a verb describes a state that lasts: the door is open, the food is on the table. To say what's somewhere, start with the place: 门口站着一个服务员 'there's a waiter standing at the door'. The negative is 没 + verb + 着. 包间的门开着。 (The private room's door is open.)"
      }
    ],
    "jinbu4-u3-5": [
      {
        "title": "看着, 拿着 — while you're doing it",
        "body": "着 can also describe how you are while you do something else: 笑着说 'say with a smile', 站着吃 'eat standing up'. And 你们看着我干什么？ is 'why are you looking at me?' 你们都看着我干什么？ (Why are you all staring at me?)"
      },
      {
        "title": "Sounds · Four-syllable phrases",
        "body": "Set phrases of four syllables fall into two pairs, with a tiny break in the middle and the stress on the last syllable. Watch 不 before a fourth tone: it becomes bú, so 不见不散 is said bú jiàn bú sàn."
      },
      {
        "title": "Culture · Some other time",
        "body": "Chinese is full of friendly phrases that don't quite mean what they say. 改天请你吃饭 ('I'll take you out for a meal some day') and 有空来我家玩儿 ('come round when you're free') are often ways of ending a conversation warmly, not real invitations. 有空再说 ('let's see when I'm free') and 再说吧 ('we'll see') can mean 'probably not'. None of this is rude: it saves both sides from a direct no."
      }
    ],
    "jinbu4-u4-1": [
      {
        "title": "Complements at a glance",
        "body": "A complement comes after the verb and adds to it. Result: what the action achieved (写错, 记住, 考过). Degree: how well or how much, with 得 (说得很好). Potential: can or can't, with 得 or 不 in the middle (听得懂, 记不住). Direction: which way (走过来, 写出来). Quantity: how long or how many times (学了两年, 听了三遍). 我写错了一个字。 (Result: I wrote a character wrong.)"
      }
    ],
    "jinbu4-u4-2": [
      {
        "title": "记住, 记得住, 记不住 — did, can, can't",
        "body": "A result complement says what happened: 记住了 'I've memorised it'. Put 得 or 不 in the middle and it becomes about ability: 记得住 'can remember', 记不住 'can't remember'. The negative of the plain result is 没: 没记住. 这个字我记住了。 (I've memorised this character.)"
      }
    ],
    "jinbu4-u4-3": [
      {
        "title": "紧张得说不出话来 — so … that",
        "body": "After 得, you can put a whole phrase to say how far something went: 'so nervous that he couldn't speak'. It's more vivid than 很紧张. You'll also hear 得要命 and 得不得了. 那天他紧张得说不出话来。 (He was so nervous that day he couldn't get a word out.)"
      }
    ],
    "jinbu4-u4-4": [
      {
        "title": "学了两年, 听了三遍 — how long, how often",
        "body": "How long and how many times go after the verb. With an object, either put it after the time (学了两年中文) or repeat the verb (学中文学了两年). 了 at the end means it's still going on. 你学了三个星期中文了？ (You've been learning Chinese for three weeks?)"
      }
    ],
    "jinbu4-u4-5": [
      {
        "title": "了, 过, 着, 正在 — aspect at a glance",
        "body": "了 after a verb: it happened, it's done. 过: you've had the experience at some time (从来没…过 is 'never ever'). 着: a state that lasts. 正在 (often with 呢): in the middle of it right now. English uses tenses for this; Chinese uses these little words. 上个月，我们的方案通过了。 (了: last month our proposal was approved.)"
      },
      {
        "title": "Sounds · Light middles, strong ends",
        "body": "In a complement, the stress usually falls on the end. 得 and 不 in the middle are light, and so are 来 and 去 at the end of a direction. So: tīng bu DǑNG, jì de ZHÙ, xiě chu lai with the stress on 写. Reading a passage aloud, pause after each 第一, 第二 and at every comma."
      },
      {
        "title": "Culture · Face, praise and mistakes",
        "body": "Many learners are held back by the fear of losing face (丢面子) by saying something wrong. The good news is that most Chinese speakers are delighted to hear foreigners try, and will praise your Chinese after the smallest effort: 你的中文说得真好！ Take it with a modest 哪里哪里, and keep going."
      }
    ],
    "jinbu5-u1-1": [
      {
        "title": "我认为, 在我看来 — giving your opinion",
        "body": "我觉得 is the everyday 'I think'. 我认为 sounds more considered, so it's good for a discussion or for writing. 在我看来 means 'the way I see it'. Keep 以为 for something you thought but turned out to be wrong. 我认为两个城市各有各的好。 (I think each city has its good points.)"
      }
    ],
    "jinbu5-u1-2": [
      {
        "title": "比如, 拿 … 来说 — for example",
        "body": "比如 (or 比如说) brings in one or more examples, like 'such as' or 'for instance'. 拿…来说 picks out one example and then talks about it: 'take …'. Both make an opinion sound fair, because you're giving evidence. 墨尔本人对咖啡特别讲究，比如牛奶多热、咖啡多浓。 (Melbourne people are fussy about coffee: how hot the milk is, how strong the coffee is.)"
      }
    ],
    "jinbu5-u1-3": [
      {
        "title": "最 and 比 … 都 … — the best of all",
        "body": "最 is 'most', '-est'. Another way to say something is the best is to compare it with a question word and add 都: 比谁都 'more than anyone', 比哪儿都 'more than anywhere'. 这是我在墨尔本最喜欢的咖啡馆。 (This is my favourite café in Melbourne.)"
      }
    ],
    "jinbu5-u1-4": [
      {
        "title": "没有比 … 更 … 的了 — nothing beats it",
        "body": "Literally 'there's nothing more … than A'. It's a strong, slightly dramatic superlative, good for complaints and for boasting. The 的了 at the end is spoken and can be left out after 没有什么比. 没有比这更让人头疼的了。 (Nothing's more of a headache than that.)"
      }
    ],
    "jinbu5-u1-5": [
      {
        "title": "再 … 不过了 — couldn't be more",
        "body": "Literally 'nothing goes beyond it'. 那再好不过了 or 那最好不过了 is a warm way of saying 'that's perfect'. Don't put 很 in front of the adjective. 免费的？那再好不过了！ (Free? That couldn't be better!)"
      }
    ],
    "jinbu5-u1-6": [
      {
        "title": "Sounds · Stress in a friendly argument",
        "body": "When you give an opinion, the frame is quick and light: 我认为, 在我看来, 拿…来说. The stress goes on the words that carry your point. In 比哪儿都好, stress 哪儿. After 拿…来说, keep your voice up: more is coming."
      }
    ],
    "jinbu5-u1-7": [
      {
        "title": "Culture · Melbourne: coffee, trams and gold",
        "body": "Melbourne, the capital of the state of Victoria, is Australia's second-biggest city, and Melbourne people will happily tell you it's the best. Its coffee culture goes back to the Italian and Greek immigrants who arrived after the Second World War and brought espresso machines with them. Today the city is known for small cafés tucked down narrow lanes, and the flat white is so linked with Australia that in China it's often called 澳白, 'Australian white'."
      }
    ],
    "jinbu5-u2-1": [
      {
        "title": "电 + 脑 — compound words",
        "body": "Most Chinese words have two characters, and each one usually means something. Knowing the parts helps you remember the word and guess new ones. The last character often says what kind of thing it is: 电车 is a kind of 车, and 手机 is a kind of 机. But not always: a 熊猫 is a bear! 电 + 脑 → 电脑 (electric + brain: computer)"
      }
    ],
    "jinbu5-u2-2": [
      {
        "title": "日 月 山 人 木 — from pictures to characters",
        "body": "A few hundred characters began as pictures (象形字). Many more were made by putting characters together, and most characters today have a meaning part and a sound part (形声字). Spotting the parts makes characters much easier to remember. “日”像太阳，“月”像月亮。 (日 looks like the sun, 月 like the moon.)"
      }
    ],
    "jinbu5-u2-3": [
      {
        "title": "老- and 小- — not always old or small",
        "body": "With a surname, 老 is a friendly way to address a colleague or friend of your own age or older (老周), and 小 is for someone younger (小周). In words like 老师, 老板, 老虎, 老鼠 and 老外, 老 is just a prefix and doesn't mean old. 同事都叫他“老周”。 (His colleagues all call him 'Lao Zhou'.)"
      }
    ],
    "jinbu5-u2-4": [
      {
        "title": "-家 and -者 — people",
        "body": "家 after a field makes an expert or professional: 画家, 作家, 音乐家, 科学家, 艺术家. 者 after a verb or phrase means 'someone who does it': 作者, 读者, 记者, 初学者, 爱好者. Neither is used for ordinary jobs: a cook is a 厨师, not a 做饭家! 齐白石是有名的画家。 (Qi Baishi was a famous painter.)"
      }
    ],
    "jinbu5-u2-5": [
      {
        "title": "-化 and -性 — making new words",
        "body": "化 is like '-ise' or '-isation': something is becoming that way (现代化, 国际化, 全球化). 性 is like '-ness' or '-ity': it turns a quality into a thing you can talk about (重要性, 可能性, 安全性). 墨尔本是一个很国际化的城市。 (Melbourne is a very international city.)"
      }
    ],
    "jinbu5-u2-6": [
      {
        "title": "Sounds · Two third tones in a row",
        "body": "When two third tones come together, the first one rises (it's said like a second tone). Lots of 老- and 小- words start this way. The tone mark in the word list doesn't change, but your voice does."
      }
    ],
    "jinbu5-u2-7": [
      {
        "title": "Culture · How characters are made",
        "body": "The oldest Chinese writing we have was carved on bones and shells more than three thousand years ago, and many of those characters are clearly pictures: a sun, a moon, a mountain, a person. But only a few hundred characters began as pictures (象形字). Some were made by combining ideas, like 休 (a person by a tree: rest) and 明 (sun and moon: bright). The great majority are 形声字, with one part that hints at the meaning and another that hints at the sound, like 妈, 吗 and 骂."
      }
    ],
    "jinbu5-u3-1": [
      {
        "title": "送 or 给? — giving",
        "body": "送 means to give as a present (and also to see someone off, or take them somewhere). 给 is the everyday 'give', for anything that passes from hand to hand; red envelopes are usually 给, or 发. You can't use 送 for 'pass me the salt'. 这是我们送您和叔叔的。 (This is from us, for you and your husband.)"
      }
    ],
    "jinbu5-u3-2": [
      {
        "title": "A 听起来像 B — it sounds like…",
        "body": "Many New Year customs and taboos are about words that sound alike. Some are exact (钟 and 终 are both zhōng); others are just close (伞 sǎn, 散 sàn). Close is enough. “送钟”听起来像“送终”。 (送钟 sounds like 送终.)"
      }
    ],
    "jinbu5-u3-3": [
      {
        "title": "千万别, 可不能, 最好别 — strong advice",
        "body": "千万别 is 'whatever you do, don't'. 可不能 is just as firm: 'you really mustn't'. 最好别 is gentler: 'better not'. 千万 also works with a positive: 路上千万小心 'do be careful on the way'. 你千万别送钟！ (Whatever you do, don't give a clock!)"
      }
    ],
    "jinbu5-u3-4": [
      {
        "title": "当着 … 的面 — in front of someone",
        "body": "当着…的面 means 'with someone there to see'. It often goes with things you shouldn't do in front of people, but not always. 当面 on its own means 'in person, to someone's face'. 不能当着客人的面打开红包。 (You mustn't open a red envelope in front of the guests.)"
      }
    ],
    "jinbu5-u3-5": [
      {
        "title": "看 — it depends",
        "body": "看 at the start of an answer means 'it depends on'. 看情况 is 'it depends', 看你 is 'it's up to you'. 红包里放多少钱？——看关系。 (How much goes in a red envelope? It depends on the relationship.)"
      }
    ],
    "jinbu5-u3-6": [
      {
        "title": "Sounds · Words that sound alike",
        "body": "Lucky and unlucky gifts come from sounds. Some pairs are exact homophones, some differ only in tone, and that's close enough for a pun. Say each pair and listen to how near they are."
      },
      {
        "title": "Culture · Presents and red envelopes",
        "body": "A few presents are best avoided in Chinese culture, mostly because of their sound. A clock (钟) is the famous one, because 送钟 sounds like 送终, being with someone as they die. An umbrella (伞) sounds like 散, splitting up, and a pear (梨) like 离, parting; friends shouldn't even share a pear (分梨 sounds like 分离). Knives and scissors suggest cutting a relationship. Anything in fours is avoided because 四 sounds like 死. White and black are colours for funerals, so wrap presents in red or gold."
      }
    ],
    "jinbu5-u4-1": [
      {
        "title": "让你破费了 — thanking for a present",
        "body": "When you're given a present, a plain 谢谢 can sound thin. Say the giver shouldn't have (你太客气了), that they've spent too much (让你破费了), or that they've been thoughtful (你真是太有心了). Then accept: 那我就不客气了, or 那我就收下了. 你们太客气了！让你们破费了。 (You shouldn't have! You've spent far too much.)"
      }
    ],
    "jinbu5-u4-2": [
      {
        "title": "一点儿小心意 — giving modestly",
        "body": "When you give a present, play it down, however much it cost: it's 'a little token' or 'nothing much'. The other person protests, you insist, and then they accept. 这是我们全家的一点儿心意。 (This is a little something from all of us.)"
      }
    ],
    "jinbu5-u4-3": [
      {
        "title": "… 就好 — that's all that matters",
        "body": "就好 after something means 'as long as …, that's fine'. 喜欢就好 is the classic reply when someone thanks you for a present. 你喜欢就好。 (As long as you like it.)"
      }
    ],
    "jinbu5-u4-4": [
      {
        "title": "至少, 最多 — at least, at most",
        "body": "至少 is 'at least' and 最多 is 'at most'. Both go before the amount, or before the verb. 公司要派我去上海，至少一年。 (The company wants to send me to Shanghai for at least a year.)"
      }
    ],
    "jinbu5-u4-5": [
      {
        "title": "最 … 之一, 再好不过的 … — the very best",
        "body": "最…之一 is 'one of the most …', a fair and polite superlative. 再…不过了 can also describe a noun: 再好不过的机会 'the best chance you could ask for'. 这是我这次收到的最好的礼物之一。 (It's one of the best presents I've had this trip.)"
      },
      {
        "title": "Sounds · 一 and 不 in polite phrases",
        "body": "Polite phrases are full of 一 and 不, and their tones change: before a fourth tone they become second tones, and 一 before other tones becomes a fourth tone. Say the phrases warmly, with the stress on the last word: 客气, 心意, 有心."
      },
      {
        "title": "Culture · Receiving a present",
        "body": "Traditionally, a Chinese present isn't accepted straight away. The receiver protests (你太客气了, 让你破费了), the giver insists (一点儿心意), and the present may be pushed back and forth a couple of times before it's accepted, ideally with both hands. The giver plays it down, and the receiver praises the thought behind it: 你真是太有心了."
      }
    ],
    "dabu1-u1-1": [
      {
        "title": "对于 and 对 — about, regarding",
        "body": "对于 brings in the topic you're talking about, and sounds more formal than 对. Wherever 对于 works, 对 works too, but not the other way round: for how people treat each other (对我很好, 对客人很热情) only 对 will do. 对于…来说 means 'for …, as far as … is concerned'. 对于这一点，你怎么看？ (What's your view on that?)"
      }
    ],
    "dabu1-u1-2": [
      {
        "title": "通过 — through, by means of",
        "body": "You know 通过 as 'to get through' or 'be approved' (方案通过了). At the start of a sentence it means 'through' or 'by means of': how you learned, met or achieved something. It's a favourite in interviews and cover letters, because it links an experience to what you got out of it. 通过这次实习，我对品牌设计有了更深的了解。 (Through this internship I came to understand brand design much better.)"
      }
    ],
    "dabu1-u1-3": [
      {
        "title": "负责, 具备, 经验丰富 — the language of job adverts",
        "body": "These three turn up in every advert and interview. 负责 is 'be in charge of'. 具备 is a formal 'have', used with abilities and qualities, never with things you own. 经验丰富 is 'rich in experience': 他经验丰富, or 一位经验丰富的设计师. 我主要负责海报和社交媒体的设计。 (I was mainly responsible for posters and social media design.)"
      }
    ],
    "dabu1-u1-4": [
      {
        "title": "Formal register — 贵公司, 曾, 者, 及, 因, 现",
        "body": "CVs, interviews and job adverts use a more formal register. Swap everyday words for written ones: 你们公司 → 贵公司, 上大学的时候 → 在校期间, 过 → 曾, 的人 → 者, 和 → 及, 因为 → 因, 现在 → 现. Don't carry it into ordinary conversation, though: it sounds like reading out a document, as Mark notices. 我上大学的时候在广告公司实习过。→ 在校期间，我曾在广告公司实习。 (While at university I did an internship at an ad agency.)"
      }
    ],
    "dabu1-u1-5": [
      {
        "title": "Culture · Job hunting in China",
        "body": "Chinese students start job hunting early. Big companies recruit final-year students in the autumn (秋招) and again in the spring (春招), and an 应届毕业生, someone graduating this year, has a special status: many posts are open only to them. A Chinese CV (简历) is usually a single page and often includes a photo, date of birth and home town, which a British CV would leave out. Job adverts list 岗位职责 (duties) and 任职要求 (requirements), and 五险一金, five kinds of social insurance plus a housing fund, is a standard part of the package."
      }
    ],
    "dabu1-u2-1": [
      {
        "title": "一方面 … 另一方面 … — on the one hand, on the other",
        "body": "Use it to set out two sides of something: two reasons, or a good point and a bad one. The second half often takes 也 or 又. It's more structured than just listing, and it's at home in discussions and essays. Don't confuse it with 一边…一边…, which is two actions at the same time. 那两年我一方面学到了很多东西，另一方面身体真的吃不消。 (In those two years I learned a lot, but my health couldn't take it.)"
      }
    ],
    "dabu1-u2-2": [
      {
        "title": "不仅 … 还 / 也 / 而且 … — not only … but also",
        "body": "不仅 is the written cousin of 不但 (进步 3). The second half takes 还, 也 or 而且. When the two halves have different subjects, 不仅 goes before the first subject: 不仅许诺在加班，老顾也…. 多吃点儿苦，不仅能学到更多东西，还能更快地升职加薪。 (Putting up with hardship not only teaches you more, but gets you promoted faster.)"
      }
    ],
    "dabu1-u2-3": [
      {
        "title": "难免 — bound to happen",
        "body": "难免 says something is hard to avoid, and so understandable. It often takes 会. It's a kind way to excuse a mistake, your own or someone else's. It can also stand alone at the end: 加班难免. 我们这一行，加班难免。 (In our line of work, some overtime's unavoidable.)"
      }
    ],
    "dabu1-u2-4": [
      {
        "title": "则 and 甚至 — writing a balanced argument",
        "body": "A balanced piece gives both sides before its own view. 则 is a written 'whereas, on the other hand'. It goes after the second subject, never before it. In speech you'd use 可是 instead. 甚至 'even' pushes a point one step further. 支持的人认为年轻人应该多吃点儿苦，反对的人则认为健康更重要。 (Supporters say the young should put up with hardship; opponents say health matters more.)"
      }
    ],
    "dabu1-u2-5": [
      {
        "title": "Culture · 996, and the words around it",
        "body": "The number 996 became a household word in China in 2019, when programmers started an online campaign against companies that expected staff to work from 9 am to 9 pm, six days a week. Some business leaders defended long hours as the price of success; many more people criticised them, and the debate has never really stopped. Under China's labour law, a schedule like that goes well beyond the limits on working hours and overtime, and the authorities have said more than once that overtime must follow the law. Many companies have publicly dropped such schedules, though long hours remain common in some industries."
      }
    ],
    "dabu1-u3-1": [
      {
        "title": "按照 or 根据? — according to",
        "body": "Both translate as 'according to'. 按照 means following something: a rule, a request, a plan. 根据 means basing something on evidence: a survey, figures, the situation. With 要求 and 规定, choose 按照; with 调查, 结果 and 情况, choose 根据. In speech, 按 alone is common too: 按他们说的改. 我们可以按照他们的要求调一下颜色。 (We can tweak the colour the way they asked.)"
      }
    ],
    "dabu1-u3-2": [
      {
        "title": "于 and 将 — two words that make it formal",
        "body": "于 is a written 在 before times and places, and it's built into words like 位于 and 关于. 将 is a written 会 or 要 for the future, and also a written 把. Both belong in emails, reports and notices. In a WeChat message they sound like a press release. 感谢您于4月6日提出的宝贵意见。 (Thank you for your valuable comments of 6 April.)"
      }
    ],
    "dabu1-u3-3": [
      {
        "title": "请查收, 如有问题 — formal email phrases",
        "body": "A formal Chinese email is built from set phrases, and using them is expected, not stiff. Open with 尊敬的 + surname + title and a colon, then 您好！ on its own line. At the end, 此致 goes on a line of its own and 敬礼！ on the next, followed by your name and the date. 修改后的方案请见附件，请查收。 (Please find the revised design attached.)"
      }
    ],
    "dabu1-u3-4": [
      {
        "title": "WeChat or email? — one message, two registers",
        "body": "The same message changes a lot between a chat and an email. WeChat drops subjects and uses 你, 了 and 吧. Email uses 您, full sentences and written words: 已 for 已经, 如 for 要是, 与 for 跟, 将 for 会. 方案发你了，你看一下。→ 方案已发送，请查收。 (Sent you the design, have a look. → The design has been sent. Please check your inbox.)"
      }
    ],
    "dabu1-u3-5": [
      {
        "title": "Culture · Meetings, WeChat and email",
        "body": "In most Chinese offices, day-to-day work happens on WeChat, in 工作群 (work group chats) that often include the client. Messages are short, fast and friendly, full of 好的 and 收到 ('got it'), and people are expected to reply quickly, often even after hours. Email is kept for things that need a record: proposals, contracts, quotes and meeting minutes (会议纪要). A common habit is to send the email and then post a quick WeChat message to say so: 邮件已发，请查收."
      }
    ],
    "dabu1-u4-1": [
      {
        "title": "与其 … 不如 … — rather than",
        "body": "'Rather than A, better to B.' The speaker has weighed up both and rejects A. It's for advice and decisions, and works in speech and writing alike. Both halves are usually verb phrases. 与其为了钱去做自己不喜欢的事，不如留下来。 (Rather than doing something you don't like for the money, why not stay?)"
      }
    ],
    "dabu1-u4-2": [
      {
        "title": "宁可 … 也 … — I'd rather",
        "body": "The thing after 宁可 is a cost you're willing to pay: 'I'd rather A, so as to B' (也要), or 'I'd rather A than B' (也不). That's the difference from 与其…不如…, where A is the option you turn down. 宁愿 means the same as 宁可. 我宁可少挣一点儿，也要做自己喜欢的事。 (I'd rather earn a bit less and do what I love.)"
      }
    ],
    "dabu1-u4-3": [
      {
        "title": "成语 — four-character idioms",
        "body": "成语 are set phrases, most of them four characters long, and many come from old stories. Each works like one word. 半途而废 is a verb phrase: 'give up halfway'. 三心二意 and 一心一意 describe how someone does something, and can take 地 before a verb. 一举两得 usually comes after 就是, 真是 or 那就…了. One or two in a paragraph adds polish; more sounds showy. 现在走，半途而废，多可惜。 (Leaving now would mean giving up halfway. What a shame.)"
      }
    ],
    "dabu1-u4-4": [
      {
        "title": "趁 and 至于 — while you can; as for",
        "body": "趁 means 'while the chance is there': 趁年轻 while you're young, 趁热吃 eat it while it's hot. 至于 turns to a related topic, 'as for', often to give your own case last. 趁年轻，多挣点儿钱。 (Earn as much as you can while you're young.)"
      }
    ],
    "dabu1-u4-5": [
      {
        "title": "Culture · Idioms, and the spring job-hop",
        "body": "成语 are fixed expressions, usually of four characters, and there are thousands of them. Many sum up an old story. 半途而废 comes from a tale about a woman who cut through the cloth on her loom to show her husband what it meant to give up his studies halfway. Others are simply vivid: 三心二意 is 'three hearts and two minds'. Educated speakers use them in speeches, essays and everyday chat, so a few, learned with how they're used, go a long way."
      }
    ],
    "dabu2-u1-1": [
      {
        "title": "倒是 … 就是 … — fine, it's just that",
        "body": "A very spoken way to weigh something up: grant one point with 倒是, then give the real problem with 就是 (or 不过, 可是). It sounds fair and a little tentative, which makes it good for turning something down gently. You can also flip it: 我倒是不怕没有电梯 'I don't mind about the lift', with the worry coming next. 房间倒是挺大的，就是离地铁站太远了。 (The room's big enough, it's just too far from the metro.)"
      }
    ],
    "dabu2-u1-2": [
      {
        "title": "算下来 and 不到哪里去 — adding up, playing down",
        "body": "算下来 means 'when you add it all up', and is the natural way to give a total or a conclusion after some sums. The pattern verb + 下来 also works with time: 一年下来 'over a whole year'. Adjective + 不到哪里去 plays something down: 'it won't be all that ….' It's reassuring and very spoken. 押一付三，这样算下来，一开始就得交一万八。 (One down and three up front: all told, that's eighteen thousand to start with.)"
      }
    ],
    "dabu2-u1-3": [
      {
        "title": "由 … 承担, 须, 不得 — the language of contracts",
        "body": "Contracts use a register of their own. 由 says who does or pays something: 由乙方承担 'borne by Party B'. 须 is a written 必须 'must', 应 a written 应该 'shall', and 不得 a written 不能 or 不可以 'may not'. Dates run 自…起至…止 'from … to …'. In a lease, 甲方 is the landlord and 乙方 the tenant. 水电费由乙方承担。 (Water and electricity are paid by the tenant.)"
      }
    ],
    "dabu2-u1-4": [
      {
        "title": "Spoken → written: the same deal, two ways",
        "body": "What 钱阿姨 says at the door and what the contract says are the same deal in two registers. Swap 你 and 我 for 甲方 and 乙方, 得 and 要 for 须 and 应, 大概 for 约, 就是 'that is' for 即, and 从…到… for 自…起至…止. Don't bring these into conversation: 乙方须付清租金 at the dinner table would get a laugh. 房间大概十六平米。→ 面积约十六平方米。 (The room's about sixteen square metres.)"
      }
    ],
    "dabu2-u1-5": [
      {
        "title": "Culture · Renting in Shanghai",
        "body": "Most young people in Shanghai rent, and many share. 整租 means renting a whole flat; 合租 means taking a room in a shared one, with a shared kitchen and bathroom and a flatmate you may not choose. The standard terms are 押一付三: a month's rent as deposit, plus three months paid in advance, so moving in costs four months' rent at once. Agents (中介) usually charge a fee too, often around a month's rent, which is why a room found through a friend or a colleague's neighbour is such a prize. Bills are 水电煤, water, electricity and gas, and rent is almost always paid by phone."
      }
    ],
    "dabu2-u2-1": [
      {
        "title": "必须 and 不必 — must and needn't",
        "body": "必须 'must' is strong and a little formal; in speech people often say 得 děi instead. Its negative is not 不必须 but 不必 or 不用, 'needn't'. For 'mustn't', use 不能, 不许 or, in writing, 不得. 必须 can also stand as the predicate: 这是必须的 'that's a must'. 吃剩的饭菜和用过的纸巾必须分开扔。 (Leftover food and used tissues must go in separately.)"
      }
    ],
    "dabu2-u2-2": [
      {
        "title": "否则 — otherwise",
        "body": "否则 means 'otherwise, if not': A is what should happen, B the consequence if it doesn't. It starts the second clause, often with 就 or 会 after it. It's a little formal; in speech 不然 or 要不然 is more common, and 钱阿姨 uses both. 必须分开扔，否则我这个志愿者不是白当了？ (It has to go in separately, otherwise what am I volunteering for?)"
      }
    ],
    "dabu2-u2-3": [
      {
        "title": "由于 — because of (in writing)",
        "body": "由于 is a more formal 因为. It usually comes in the first clause, and pairs well with 因此 'therefore'. Unlike 因为, it doesn't normally come after the result: say 由于下雨，比赛取消了, not 比赛取消了，由于下雨. It can also go straight before a noun: 由于时间关系 'for reasons of time'. 以前由于不分类，大部分垃圾只能埋掉、烧掉。 (Before, because nothing was sorted, most rubbish could only be buried or burned.)"
      }
    ],
    "dabu2-u2-4": [
      {
        "title": "以便 — so that (in writing)",
        "body": "以便 introduces the purpose of the first clause: 'so that, in order to'. It always comes at the start of the second clause, never the first. It belongs in notices, reports and articles; in speech, say 好 or 这样 instead: 带个杯子，这样就不用一次性的了. 出门带上自己的杯子，以便少用一次性用品。 (Take your own cup when you go out, so that you use fewer disposable things.)"
      }
    ],
    "dabu2-u2-5": [
      {
        "title": "Culture · Shanghai sorts its rubbish",
        "body": "On 1 July 2019 Shanghai's regulations on household waste took effect, and the city became one of the first in China to make sorting compulsory. Households must separate four kinds of rubbish, each with its own colour of bin: 可回收物 (recyclables, blue), 有害垃圾 (hazardous waste such as rechargeable batteries, old medicine and fluorescent tubes, red), 湿垃圾 (wet rubbish, food waste, brown) and 干垃圾 (dry rubbish, everything else, black). The national standard, used in other cities, calls the last two 厨余垃圾 and 其他垃圾. Residents who don't sort can be fined."
      }
    ],
    "dabu2-u3-1": [
      {
        "title": "随着 — as, along with",
        "body": "随着 links two changes: as one thing develops, another follows. The part after 随着 is a noun phrase, often ending in 的发展, 的变化 or 的增加, and the second clause usually has 越来越, 也 or 开始. It's common in writing and in thoughtful speech. 随着城市化的发展，越来越多的人离开乡村。 (As urbanisation goes on, more and more people are leaving the countryside.)"
      }
    ],
    "dabu2-u3-2": [
      {
        "title": "不是 … 而是 … — not A, but B",
        "body": "Use it to correct a mistaken idea and put the right one in its place. It's stronger and neater than 不是A，是B, and more at home in writing and discussion. Both halves should be the same kind of thing: two nouns, two verbs or two clauses. 问题不是东西不好，而是没有人帮他们把故事讲好。 (The problem isn't that the baskets aren't good; it's that nobody's helping them tell their story.)"
      }
    ],
    "dabu2-u3-3": [
      {
        "title": "一 … 就是 … — once you start, it's a lot",
        "body": "This pattern stresses that an amount is large, or a time long: once the action starts, it goes on for that long. 一走就是十年 'left, and was gone for ten years'. The amount after 就是 is the point of the sentence, so say it with some weight. 我去杭州上大学，一走就是十年。 (I went off to university in Hangzhou, and was away for ten years.)"
      }
    ],
    "dabu2-u3-4": [
      {
        "title": "变, 变成, 变得 and -化 — talking about change",
        "body": "变 goes straight before a short adjective: 变小, 变老. 变成 is 'turn into' and takes a noun: 变成一个篮子. 变得 takes a fuller description: 变得更安静. The suffix 化, which you met in 进步 5, turns a word into a process: 城市化 'urbanisation', 现代化 'modernisation'. 城市在长大，乡村却在变老。 (The cities are growing up, but the villages are growing old.)"
      }
    ],
    "dabu2-u3-5": [
      {
        "title": "Culture · Leaving home, going home",
        "body": "In 1980 about one in five people in China lived in towns and cities; today it's about two in three. Much of that change was made by migrant workers (农民工), nearly three hundred million of them, who left villages to work in factories, on building sites and in restaurants. Under the household registration system (户口), many could not easily bring their children to the city's schools, so millions of children grew up with grandparents at home: the 留守儿童, 'left-behind children'. Their parents' wages paid for houses, school fees and university, and the cost was measured in years apart."
      }
    ],
    "dabu2-u4-1": [
      {
        "title": "仿佛 — as if",
        "body": "仿佛 is a literary 好像: 'as if, it seemed'. It goes before the verb or the whole clause, and can close with 一样 or 似的. Use it for impressions and comparisons in descriptive writing. In conversation, 好像 or 像…一样 sounds more natural, but Mark uses 仿佛 once, carefully, and it works. 走在梧桐树下面，我仿佛回到了伦敦。 (Walking under the plane trees, it's as if I'm back in London.)"
      }
    ],
    "dabu2-u4-2": [
      {
        "title": "不禁 and 忍不住 — can't help it",
        "body": "不禁 means a reaction happened by itself: you found yourself laughing, stopping or remembering. It's written and a little literary, and goes before the verb. 忍不住 means the same and is used in speech too; it can also mean you tried not to and failed, and it can take a negative after it (忍不住不看). 我不禁停下来看了半天。 (I couldn't help stopping to stare.)"
      }
    ],
    "dabu2-u4-3": [
      {
        "title": "既 … 又 … — both at once",
        "body": "You met 既…又… in 大步 1. It joins two qualities, or two roles, of one person or thing, and it's tidier and more written than 又…又…. It's good for showing that something is two things at once: 既像一个租客，又像一个孙子. 又…又… is commoner in speech, especially with short adjectives: 又闷又热. 在她面前，我既像一个租客，又像一个孙子。 (With her, I'm part tenant, part grandson.)"
      }
    ],
    "dabu2-u4-4": [
      {
        "title": "Doubled words — making a description come alive",
        "body": "Doubling makes a description warmer and more vivid. A doubled adjective takes 的 (高高的, 软软的) or 地 before a verb (慢慢地). Some adjectives come in fixed ABB forms: 热乎乎 'nice and hot'. And 一片一片 or 一条条 means 'one by one' or 'row upon row'. Don't double adjectives that already have 很 or 非常 in front of them. 路两边的梧桐树高高的。 (The plane trees along the roads stand tall.)"
      }
    ],
    "dabu2-u4-5": [
      {
        "title": "Culture · A little Shanghainese",
        "body": "Shanghainese (上海话) belongs to the Wu family of Chinese, and a Mandarin speaker who hasn't learned it can understand very little. You don't need it to live in Shanghai: everyone speaks Mandarin, and many younger people now speak Shanghainese less than their grandparents do. But a few words will make an auntie smile. 侬好 (roughly 'nong ho') is 'hello', 阿拉 ('ah-lah') is 'we' or 'I', 侬 ('nong') is 'you', and 谢谢侬 ('shia-shia nong') is 'thank you'. 侬晓得伐？ is 'Did you know?', with 伐 as the question particle, like 吗. 嗲 ('dia') means lovely or charming, and has made its way into Mandarin."
      }
    ],
    "dabu3-u1-1": [
      {
        "title": "…的同时: while, at the same time as",
        "body": "的同时 joins two things that come together, very often a benefit and its cost: 'while A, B too'. A is a verb phrase or clause before 的同时, and the second half usually has 也 or 还. With 在 in front it sounds more written. It's the natural way to be fair in an argument: grant the good side, then add the other. 方便的同时，也要留个心眼。 (Enjoy the convenience, but keep your wits about you.)"
      }
    ],
    "dabu3-u1-2": [
      {
        "title": "靠, 全靠 and 离不开: depending on something",
        "body": "靠 means 'rely on, depend on', and can go straight before a second verb to say how something is done: 靠直播卖竹篮 'sell baskets by livestream'. 全靠 is 'depend entirely on'. 离不开 'can't do without' is the everyday way to say how much you need something. 依赖 is the formal word, common in articles and often a little critical. 再…也… 'however …, still …' often comes with them. 手机再方便，也不能全靠它。 (However handy your phone is, you can't rely on it for everything.)"
      }
    ],
    "dabu3-u1-3": [
      {
        "title": "不见得 and 未必: not necessarily",
        "body": "Both soften a claim to 'not necessarily'. 不见得 is spoken and a little sceptical; 未必 is more written. Use them to push back gently on a generalisation without claiming the opposite: 年纪大不见得就学不会 doesn't say old people learn easily, only that age isn't the whole story. They often take 就 after them. 老人需要的，不见得是更先进的技术。 (What older people need isn't necessarily more advanced technology.)"
      }
    ],
    "dabu3-u1-4": [
      {
        "title": "扫, 刷, 转, 付: paying in Shanghai",
        "body": "Shanghai pays by phone, and the verbs are short. 扫 is 'scan': 我扫你 means 'I'll scan your code'. 刷 is 'swipe', for bank cards, travel cards and even your face. 转 is 'transfer': 我转给你. In speech you 付钱; on a sign, a bill or in an article you 支付 or 付款, and send money by 转账. 我扫你还是你扫我？ (Shall I scan you, or will you scan me?)"
      }
    ],
    "dabu3-u1-5": [
      {
        "title": "Culture · Paying by phone",
        "body": "Since the mid-2010s China has become one of the most cashless places on earth. Almost every shop and market stall shows a payment QR code (收款码), and customers scan it with WeChat Pay or Alipay and type in the amount; in bigger shops the till scans a code on the customer's phone instead. Metro gates, bills, hospital fees and red envelopes all work the same way, and friends split the bill by transferring money in a chat."
      }
    ],
    "dabu3-u2-1": [
      {
        "title": "即使 … 也 …: even if",
        "body": "即使 introduces a condition, real or imagined, and 也 says the result holds anyway: 'even if'. It's a touch more formal than 就算…也…, and different from 虽然…但是…, which is about facts. 即使 can come before or after the subject, but 也 always goes after the subject of the second clause. 即使…再… 'however much' is common too. 即使没有算法，我也会刷。 (Even without the algorithm, I'd still scroll.)"
      }
    ],
    "dabu3-u2-2": [
      {
        "title": "所谓: what's known as, so-called",
        "body": "所谓 introduces a term and explains it: 所谓X，就是Y 'X means Y'. 这就是所谓的X 'this is what's called X' names something you've just described. New terms usually go in quotation marks. Said with a raised eyebrow, 所谓的 can sound sceptical, like English 'so-called'. 这就是所谓的“碎片化”。 (That's what they call 'fragmentation'.)"
      }
    ],
    "dabu3-u2-3": [
      {
        "title": "不在于 … 而在于 …: where the point really lies",
        "body": "在于 'lies in, rests on' is written and thoughtful. 关键在于 'the key lies in' names what matters most. 不在于A，而在于B corrects a wrong idea of where a problem lies. It's a more formal cousin of 不是…而是… from 大步 2, and good for the turn in an argument. 问题不在于短视频，而在于我们还能不能控制自己。 (The problem doesn't lie in short video, but in whether we can still control ourselves.)"
      }
    ],
    "dabu3-u2-4": [
      {
        "title": "何况: besides, let alone",
        "body": "何况 adds a further, often stronger reason: 'besides, what's more'. After 连…都… or a negative, (更)何况 means 'let alone', often as a rhetorical question. It's a little bookish, and very useful in writing and careful argument. 何况，短视频本身并不是坏东西。 (Besides, short video isn't a bad thing in itself.)"
      }
    ],
    "dabu3-u2-5": [
      {
        "title": "Culture · Short video and 'traffic'",
        "body": "China's short-video apps, led by Douyin (the Chinese sister of TikTok) and Kuaishou, have more than a billion users between them, and the average user spends over two hours a day watching. Feeds are driven by recommendation algorithms (算法) that learn from every swipe, which is why one cooking video can fill your screen with cooking."
      }
    ],
    "dabu3-u3-1": [
      {
        "title": "我不同意 and 这一点我同意: agreeing and disagreeing",
        "body": "In a discussion, disagree with the idea, not the person: 我不同意这种说法 or 我不同意这种看法 sounds far better than a flat 你错了. 这一点我同意 grants one point before you add your own. 我不完全同意 is softer still. 同意 takes a person, an idea or a clause directly: say 我同意你, never 我同意跟你. 我不同意“AI会取代设计师”这种说法。 (I don't agree that AI will replace designers.)"
      }
    ],
    "dabu3-u3-2": [
      {
        "title": "话虽如此: that may be so, but",
        "body": "话虽如此 'though that is so' accepts what has just been said, then pushes back. It's more formal than 话是这么说 from 大步 1, and works in discussion, essays and speeches alike. The second half often has 但是, 也 or 还是. 话虽如此，这次不一样。 (That may be so, but this time it's different.)"
      }
    ],
    "dabu3-u3-3": [
      {
        "title": "反过来说: looked at the other way round",
        "body": "反过来说 turns an argument round: 'conversely, on the other hand'. Use it to show that the same fact has another side, or to state the reverse of what's just been said. It isn't a flat contradiction, so it keeps a debate friendly. 反过来说，如果基础工作交给AI，新人就能把时间花在更重要的地方。 (Look at it the other way round: if the groundwork goes to AI, new people can spend their time on more important things.)"
      }
    ],
    "dabu3-u3-4": [
      {
        "title": "归根结底: when all's said and done",
        "body": "归根结底 'going back to the root' sums up an argument: 'in the final analysis, at the end of the day'. It opens the closing sentence, or goes before the verb. Save it for your conclusion: used every other line, it sounds pompous. 客户要的归根结底不是一百张图，而是一个对的想法。 (At the end of the day, what the client wants isn't a hundred images but one right idea.)"
      }
    ],
    "dabu3-u3-5": [
      {
        "title": "与其 … 不如 … again, with 取代 and 代替",
        "body": "You met 与其…不如… in 大步 1. In an argument or a speech it's a strong way to recommend: reject one course, propose another. 取代 is 'replace, take the place of', usually for good and on a big scale: jobs, technologies. 代替 is lighter and can be temporary, and can take a verb after it: 老顾代替她开会 'Lao Gu went to the meeting in her place'. 与其担心被取代，不如想清楚哪些事只有人能做。 (Rather than worrying about being replaced, be clear about what only people can do.)"
      }
    ],
    "dabu3-u3-6": [
      {
        "title": "Culture · AI and the people who make things",
        "body": "Generative AI (生成式人工智能) arrived in a rush in China after 2022. Chinese tech companies launched dozens of large models, and design, advertising and online-shopping firms were among the first to use AI images for product photos, posters and first drafts. Freelance illustrators and junior designers felt the change first, and 'AI will replace you' became a joke and a worry at the same time."
      }
    ],
    "dabu3-u4-1": [
      {
        "title": "据报道, 据悉, 据了解: giving a source",
        "body": "News gives its sources with 据 'according to'. 据报道 is 'it is reported', 据悉 'it is understood' (the source isn't named), 据了解 'we understand', and 据…介绍 'according to …'. They open the sentence and are followed by a comma. In speech you'd say 听说 or 新闻上说 instead. 据报道，最近网上流传“商家可以不收现金”的说法。 (According to reports, a claim that 'shops can refuse cash' has been going round online.)"
      }
    ],
    "dabu3-u4-2": [
      {
        "title": "表示 and 称: what people said",
        "body": "Reports rarely use 说. 表示 'stated' is neutral and formal: it's what officials, managers and experts do. 称 'said, claimed' is shorter, common after a name and in headlines, and can suggest the paper is only passing the claim on. 介绍 'explained' is for background. A comma or a colon comes after them. 有关部门表示，这是谣言。 (The authorities stated that it was a rumour.)"
      }
    ],
    "dabu3-u4-3": [
      {
        "title": "截至, 余, 近 and 超过: numbers in the news",
        "body": "截至 'as of, up to' gives the date a figure is counted to. Don't confuse it with 截止 'to close', as in 截止日期 'deadline'. 余 is a written 多 'more than' and comes straight after the number: 八千余件. 近 means 'nearly': 近一个月. 超过 is 'more than, over'. 截至1月20日，合作社共卖出竹编产品八千余件。 (As of 20 January, the co-operative had sold more than 8,000 bamboo items.)"
      }
    ],
    "dabu3-u4-4": [
      {
        "title": "Headlines: reading them like a telegram",
        "body": "Headlines are short and dense. They drop 了, 的 and most measure words, prefer one-character written verbs like 获 'win' and 将 'will', and often set two phrases side by side, with a space or a colon between. Read the headline as a telegram, then find the full sentence in the first paragraph. 竹编年货走俏　山村直播一月卖出八千件 → 竹编年货卖得很好，一个山村一个月在直播中卖出了八千件。 (Bamboo New Year goods sell well: a village sells eight thousand in a month by livestream.)"
      }
    ],
    "dabu3-u4-5": [
      {
        "title": "Culture · Reading the news, and the family group chat",
        "body": "Chinese news has a register of its own. A report opens with a dense first paragraph that answers who, what, when and how many, and a newspaper marks its own reporting with 本报讯, 'this paper reports'. Sources come with 据: 据报道, 据悉, 据了解. Officials 表示; people making a claim 称. Headlines often come in two parts and drop the small grammatical words."
      }
    ],
    "dabu4-u1-1": [
      {
        "title": "说到底: when it comes down to it",
        "body": "说到底 'if you talk it through to the bottom' strips a question down to its real cause or core. It's the spoken cousin of 归根结底 from 大步 3, warmer and less formal, and it often opens the sentence that says what someone really feels. Use it once, at the point where you get to the heart of things. 说到底，还是怕。 (When it comes down to it, it's fear.)"
      }
    ],
    "dabu4-u1-2": [
      {
        "title": "何必 and 难道: making a point with a question",
        "body": "Both turn a question into an argument. 何必 'why must, what's the point of' says something is unnecessary: 何必呢？ on its own means 'why bother?'. 难道 'surely you don't mean' challenges an assumption and expects the answer no; the sentence usually ends with 吗. Both can sound sharp, so soften them with a smile, or with 其实 before your next point. 为了结婚而结婚，何必呢？ (Why marry just for the sake of it?)"
      }
    ],
    "dabu4-u1-3": [
      {
        "title": "为了 … 而 …: for the sake of",
        "body": "In 为了A而B, A is the purpose and B the action taken for it; 而 links them. It's more written than plain 为了…, and it's the natural way to criticise an action done for the wrong reason: 为了结婚而结婚 'marrying for the sake of marrying'. 因为A而B works the same way for causes. 不能为了完成任务而随便找个人。 (You can't just pick anyone for the sake of getting it done.)"
      }
    ],
    "dabu4-u1-4": [
      {
        "title": "毕竟 and 话说回来: being fair to the other side",
        "body": "毕竟 'after all' gives the fact that explains or excuses something, and it goes before the verb or at the start of the clause. 话说回来 'that said, mind you' turns the conversation back to the other side of the argument. Together they let you disagree with someone without being unfair to them. 毕竟是两代人，想法不一样很正常。 (You're two generations, after all; it's normal to think differently.)"
      }
    ],
    "dabu4-u1-5": [
      {
        "title": "Culture · Pressure to marry, and a contested label",
        "body": "催婚, 'hurrying someone to marry', peaks at Spring Festival and other holidays, when young people go home and parents, aunts and uncles ask the same question: 有对象了吗? 'Are you seeing anyone?' For many parents, marriage is simply the next stage of life, and behind the nagging is a real fear: who will look after their child when they are gone?"
      }
    ],
    "dabu4-u2-1": [
      {
        "title": "不得不 and 只好: no choice",
        "body": "不得不 'can't not' is a double negative: you have no choice but to, usually because of pressure from outside. It's stronger than 必须 and carries a note of reluctance. 只好 'have to, can only' is milder, for making the best of a situation after something has happened. Don't put 不 after 不得不: say 不得不去, not 不得不不去. 好的初中竞争那么激烈，我不得不早做准备。 (Competition for the good schools is so fierce that I've no choice but to prepare early.)"
      }
    ],
    "dabu4-u2-2": [
      {
        "title": "非 … 不可: simply have to",
        "body": "非…不可 'unless …, it won't do' means something must happen. It's emphatic, and often a little exasperated. With 要, 非要…不可 means someone insists on doing something, usually against advice; in speech the 不可 is often dropped: 他非要去. 孩子想上好大学，就非从小打好基础不可。 (If a child wants to get into a good university, they simply have to build the foundations early.)"
      }
    ],
    "dabu4-u2-3": [
      {
        "title": "尽管 … 还是 / 但是 …: even though",
        "body": "尽管 is a more written 虽然 'although', and it stresses that B happens in spite of A. The second clause usually has 但是 or 可是, and often 还是 or 也 before the verb. It's the natural way to concede a point in an essay before you make your own. 尽管国家出台了“双减”政策，家长还是很焦虑。 (Although the government introduced the 'double reduction' policy, parents are still anxious.)"
      }
    ],
    "dabu4-u2-4": [
      {
        "title": "凭 and 靠: on the strength of",
        "body": "凭 'on the strength of, by virtue of' names what you can rightfully count on: your score, your skill, your own work. 靠 from 大步 3 is broader, 'rely on', and can mean help from others. 凭什么？ 'on what grounds?' is a sharp challenge, and can sound rude, so save it for arguments you mean. 我能凭的，只有自己的分数。 (All I had to go on was my own score.)"
      }
    ],
    "dabu4-u2-5": [
      {
        "title": "Culture · The gaokao, and the race that leads up to it",
        "body": "The 高考, the national university entrance exam, starts every year on 7 June and lasts two to four days, depending on the province. In 2025 about 13.4 million people sat it. For most, the score decides which university, and often which city, they go to. Streets near exam halls go quiet, police escort latecomers, and parents wait outside the gates, some wearing red for luck. In 高三, the final year, many students study from early morning until late at night under a countdown on the classroom board."
      }
    ],
    "dabu4-u3-1": [
      {
        "title": "与其说 … 不如说 …: it's not so much A as B",
        "body": "与其说A，不如说B re-describes something: 'rather than calling it A, it would be truer to call it B'. It corrects a label, not a choice, so it's different from 与其A，不如B 'better to do B than A' from 大步 1, which recommends an action. It's thoughtful and a little literary, and very useful when you want to change how someone sees a situation. 与其说姨父是怕花钱，不如说他是怕自己没用了。 (It isn't so much that Uncle's afraid of the cost as that he's afraid of being useless.)"
      }
    ],
    "dabu4-u3-2": [
      {
        "title": "固然 … 但是 …: admittedly",
        "body": "固然 grants a point fully, 'it's true that, of course', before the real argument comes with 但是 or 可是. It goes after the subject. It's written and measured, and it makes an argument sound fair, because you've shown you've thought about the other side first. 专业的护理固然代替不了儿女的陪伴，但是累垮了的儿女也照顾不好父母。 (Professional nursing can't take the place of children's company, of course, but children who are worn out can't care for their parents well either.)"
      }
    ],
    "dabu4-u3-3": [
      {
        "title": "哪怕 … 也 …: even if",
        "body": "哪怕 'even if, even though' is like 即使 from 大步 3, but more emotional and more common in speech: it often introduces an extreme or a small, humble case. 也 or 都 follows in the second clause. 哪怕是 + noun is common too: 哪怕是一个电话 'even just a phone call'. 哪怕不能天天在身边，多打一个电话也是孝顺。 (Even if you can't be there every day, one more phone call is duty too.)"
      }
    ],
    "dabu4-u3-4": [
      {
        "title": "照顾, 照料, 护理 and 陪: caring for someone",
        "body": "照顾 is the everyday word for looking after someone, and also for keeping an eye out for them. 照料 is its written twin, common in notices and reports (日间照料 'day care'). 护理 is nursing care, done by professionals. 陪 and 陪伴 are about company, being with someone, and that's what many older people want most. 她一个人照顾生病的丈夫。 (She's looking after her sick husband on her own.)"
      }
    ],
    "dabu4-u3-5": [
      {
        "title": "Culture · Filial piety, and who cares for the old",
        "body": "孝, filial piety, has been at the heart of Chinese ethics for more than two thousand years. 孝顺 joins respect (孝) with going along with your parents' wishes (顺), and the old saying 养儿防老, 'raise children to provide for old age', assumed that sons and daughters would care for their parents at home. 'Face' (面子) matters too: for many older people, being seen to be looked after by their own children is a sign of a life well lived."
      }
    ],
    "dabu4-u4-1": [
      {
        "title": "Reporting speech in writing",
        "body": "A profile mixes direct and indirect speech. Quote someone word for word with a colon and quotation marks, and keep their voice. Report them indirectly without quotation marks, changing 我 to 她 and 现在 to 那时. 据她回忆 'as she remembers it' marks her memory as the source; 用她的话说 introduces a phrase too good to paraphrase; 在她看来 gives her opinion. “那时候买什么都要票，”她说。 ('Back then you needed coupons for everything,' she says.)"
      }
    ],
    "dabu4-u4-2": [
      {
        "title": "回想起来 and 现在想想: looking back",
        "body": "回想起来 'thinking back on it' opens a reflection on the past from the present, and often leads to a judgement or a feeling you didn't have at the time. It's reflective and a little written. 现在想想 'thinking about it now' is its everyday equivalent. Both are followed by a comma. 现在回想起来，那是我最开心的时候。 (Looking back now, those were my happiest days.)"
      }
    ],
    "dabu4-u4-3": [
      {
        "title": "不由得 and 不禁: can't help it",
        "body": "不由得 'not up to you' means a reaction happens by itself, like 不禁 from 大步 2. 不由得 is a little more spoken, and it has a second use that 不禁 doesn't: 不由得你不信 'you can't help but believe it', with a person and 不 after it. Use either one sparingly: once in an essay is plenty. 我不由得想，这间厨房里曾经有过五个煤炉。 (I couldn't help thinking that this kitchen once had five coal stoves.)"
      }
    ],
    "dabu4-u4-4": [
      {
        "title": "与此同时: meanwhile",
        "body": "与此同时 'at the same time as this' links two things happening in parallel, usually one personal and one larger. It's written, and it opens the second sentence, followed by a comma. 同时 alone is more flexible and can go inside a clause. In a profile, 与此同时 is how you set one life against the history around it. 她进了纺织厂。与此同时，这座城市正在发生巨大的变化。 (She went into the textile mill. Meanwhile, the city was changing enormously.)"
      }
    ],
    "dabu4-u4-5": [
      {
        "title": "Culture · Oral history, and Shanghai since the 1960s",
        "body": "In the 1960s and 1970s most Shanghai families lived in crowded lane houses, often several households in a house built for one. Kitchens were shared, coal stoves (煤炉) were lit at the door each morning, and many homes had no toilet, so the day began with emptying the chamber pot (倒马桶) at the lane's collection point. Rice, oil, meat and cloth were rationed with coupons (票) from the 1950s until the early 1990s, and grain coupons were finally abolished in 1993. From 1968 until the late 1970s, over a million young Shanghainese were sent to the countryside as 知青, 'educated youth'."
      }
    ],
    "dabu5-u1-1": [
      {
        "title": "Evidence or hearsay? 研究表明, 数据显示, 据说, 老话说",
        "body": "When you talk about health, show how you know. 研究表明 'research shows' and 数据显示 'the data show' are for evidence, and belong in writing and careful speech. 据说 'it's said' and 听说 'I've heard' pass on something you haven't checked; 老话说 'as the old saying goes' quotes tradition. Mixing them up is how rumours sound like facts, so choose on purpose. 研究表明，骨头汤里的钙其实很少。 (Research shows there's very little calcium in bone soup.)"
      }
    ],
    "dabu5-u1-2": [
      {
        "title": "并非: it isn't so",
        "body": "并非 is the written form of 并不是: 'is not at all, is by no means'. It corrects an assumption firmly but calmly, which is why columns and reports love it. 也并非如此 'that isn't the case either' answers a question you've just raised. 并非都 means 'not all': 老话并非都是错的 'not all old sayings are wrong'. In speech, say 并不是 or 也不是. 老话并非都是错的。 (Not all old sayings are wrong.)"
      }
    ],
    "dabu5-u1-3": [
      {
        "title": "适当, 适量 and 过度: in moderation",
        "body": "适当 'appropriate, suitable' goes before verbs to mean 'a reasonable amount, when it's right': 适当运动, 适当休息. 适量 'a moderate amount' is for things you consume: food, drink, medicine, sun. 过度 'too much, excessive' is the opposite, and often comes before 劳累, 使用 or 治疗. All three are a little formal: a doctor's words. 空调开到二十六度，适当开窗通风。 (Set the air conditioning to twenty-six, and open the windows now and then.)"
      }
    ],
    "dabu5-u1-4": [
      {
        "title": "以…为主 and 因人而异",
        "body": "以A为主 'take A as the main thing' says what something mostly consists of: 饮食以清淡为主 'eat mostly light food'. It's neat and written, and very common in advice. 因人而异 'differs from person to person' is a four-character phrase for results that vary: use it to be honest about uncertain evidence. 夏天的饮食，最好以清淡为主。 (In summer, it's best to eat mostly light food.)"
      }
    ],
    "dabu5-u1-5": [
      {
        "title": "Culture · The dog days, and the art of 'nourishing life'",
        "body": "养生, literally 'nourishing life', is an old idea: that you stay well through daily habits of eating, sleeping, moving and keeping calm, rather than waiting to be cured. It runs through traditional Chinese medicine (中医) and everyday speech. Older people swap tips in parks and group chats, and young office workers joke about 朋克养生, 'punk wellness': staying up till three, but with goji berries (枸杞) in the flask."
      }
    ],
    "dabu5-u2-1": [
      {
        "title": "以偏概全 and 一概而论: don't generalise",
        "body": "Two useful four-character phrases for pushing back on stereotypes. 以偏概全 'take a part for the whole' criticises a conclusion drawn from too little: one rude waiter, so all Londoners are rude. 一概而论 'treat everything the same way' is almost always negative: 不能一概而论 'you can't generalise'. Soften them with 有点儿 or 也, and they sound thoughtful rather than rude. “英国人都很冷漠”，就有点儿以偏概全了。 ('The English are all cold' is a bit of a sweeping generalisation.)"
      }
    ],
    "dabu5-u2-2": [
      {
        "title": "对…而言: as far as … is concerned",
        "body": "对…而言 means 'for, as far as … is concerned', and is the written twin of 对…来说. It sets up whose point of view you're giving, often before a judgement about meaning or difficulty. 就…而言 is similar but narrows a topic rather than a person: 就价格而言 'in terms of price'. 对我而言，旅行最大的意义，就是把标签撕下来。 (For me, the biggest point of travelling is peeling off the labels.)"
      }
    ],
    "dabu5-u2-3": [
      {
        "title": "以为 or 认为?",
        "body": "Both translate as 'think', but 以为 usually means you thought something that turned out to be wrong: 我以为中国菜都是甜的. 认为 states a considered opinion, and is more formal: 我认为旅行的意义在于交流. Don't use 以为 for a view you still hold, or it sounds as though you've changed your mind. 我以为中国人都很严肃，结果不是。 (I thought Chinese people were all serious, but they're not.)"
      }
    ],
    "dabu5-u2-4": [
      {
        "title": "…而已: that's all",
        "body": "而已 at the end of a sentence means 'and that's all, merely', and plays something down. It usually pairs with 只是, 不过 or 仅仅 earlier in the sentence. It's a little more written than 罢了, and it's a graceful way to be modest or to shrink an argument down to size. 其实，只是我听不懂而已。 (In fact, I just couldn't understand them, that's all.)"
      }
    ],
    "dabu5-u2-5": [
      {
        "title": "Culture · Dunhuang and the Silk Road",
        "body": "Dunhuang stands on the edge of the Gobi desert in Gansu, at the point where the old routes west divided to pass north and south of the Taklamakan. For more than a thousand years, merchants, monks, soldiers and envoys passed through it on the roads later named the Silk Road (丝绸之路). Silk, paper and porcelain went west; horses, glass, grapes, musical instruments like the pipa, and Buddhism came east."
      }
    ],
    "dabu5-u3-1": [
      {
        "title": "一方面 … 另一方面 …: on the one hand, on the other",
        "body": "一方面…另一方面… sets out two aspects of one thing. In English 'on the one hand … on the other' usually contrasts; in Chinese the two sides often point the same way, adding one reason to another, though they can contrast too. The second half often takes 也 or 又. It's formal and balanced, and at home in essays, reports and meetings. 一方面，订单稳定；另一方面，也能学学人家的管理。 (On the one hand, the orders are steady; on the other, we can learn from how they're run.)"
      }
    ],
    "dabu5-u3-2": [
      {
        "title": "不可否认 and 然而: granting a point, then turning",
        "body": "不可否认 'it can't be denied' grants a point fully, and is stronger than 固然 from 大步 4. 然而 'however' is the written 可是: it opens a sentence or clause and turns the argument. Used together, they make a formal essay sound fair before it criticises. In speech you'd say 确实… and 可是…. 不可否认，这是个大机会。 (There's no denying it's a big opportunity.)"
      }
    ],
    "dabu5-u3-3": [
      {
        "title": "由此可见 and 总而言之: drawing a conclusion, and closing",
        "body": "由此可见 'from this it can be seen' draws a conclusion from the example or evidence just given; 可见 alone is lighter and can go mid-sentence. 总而言之 'to sum up' opens the final paragraph of an essay or the last point of a speech; 总之 is its everyday form. Don't use 由此可见 unless something really does follow. 由此可见，交流并不一定意味着失去自己。 (It follows that exchange doesn't necessarily mean losing yourself.)"
      }
    ],
    "dabu5-u3-4": [
      {
        "title": "以…为代价: at the cost of",
        "body": "以A为代价 'taking A as the price' says what is sacrificed to get something. It's written and usually critical, and often comes with 换取 'get in exchange' or 来. Use it to name the hidden cost of a gain: health for money, the environment for growth. 不少工厂以牺牲环境为代价，换取订单。 (Many factories win orders at the expense of the environment.)"
      }
    ],
    "dabu5-u3-5": [
      {
        "title": "Culture · From 'Made in China' to the story behind it",
        "body": "Since China opened up to world trade in the 1980s, and especially after it joined the World Trade Organization in 2001, 中国制造 'Made in China' has been printed on a large share of the world's goods. China became the world's biggest exporter of goods in 2009, and now accounts for around 14 per cent of global goods exports."
      }
    ],
    "dabu5-u4-1": [
      {
        "title": "Opening a speech: 尊敬的…, 亲爱的…, 大家好",
        "body": "A Chinese speech opens by addressing the audience, most senior first, followed by a colon: 尊敬的 'respected' for guests, teachers or leaders, 亲爱的 'dear' for friends, and 各位 + group for everyone else. Then comes the greeting, and usually 首先 with a thank-you to whoever invited you. At an informal event, 各位朋友，大家好 is plenty. 尊敬的各位老师，亲爱的朋友们：大家下午好！ (Teachers, dear friends: good afternoon!)"
      }
    ],
    "dabu5-u4-2": [
      {
        "title": "如果说 … 那么 …: if A, then B",
        "body": "如果说A，那么B is not a real condition. It sets two things side by side, usually to build to the bigger one: 'if the first year gave me friends, then later it gave me homes'. It's a favourite of speeches and essays because it moves the argument up a step. Keep A and B parallel in shape. 如果说第一年，中文给了我几个朋友，那么后来，它给了我好几个家。 (If in the first year Chinese gave me a few friends, then later it gave me several homes.)"
      }
    ],
    "dabu5-u4-3": [
      {
        "title": "Closing a speech: 最后, 感谢, 谢谢大家",
        "body": "最后 'finally' signals the end, and it's usually where the thanks go: 我要感谢 A，感谢 B…, with 感谢 repeated for each person. End with 谢谢大家 or 谢谢 on its own line, and at a festival or a party, a wish with 祝. 我的话就说到这里 'that's all from me' is a modest way to finish. 最后，我要感谢小雨，她是我的第一位中文老师。 (Finally, I'd like to thank Xiaoyu, my first Chinese teacher.)"
      }
    ],
    "dabu5-u4-4": [
      {
        "title": "成语 and sayings in a speech",
        "body": "A 成语 or an old saying is at its best at a turning point: when it sums up what you've just said, or opens what you're about to say. Introduce a longer saying with 中国有句老话 or the person who said it, and put it in quotation marks. One or two in a speech is plenty. Some, like 一步一个脚印, work as adverbs with 地 before a verb. 中国有句老话：“千里之行，始于足下。” (There's an old Chinese saying: 'A journey of a thousand miles begins with a single step.')"
      },
      {
        "title": "Culture · Sayings that open doors",
        "body": "The first saying of the 《论语》, the Analects of Confucius, is about learning and friendship: 学而时习之，不亦说乎？有朋自远方来，不亦乐乎？ 'To learn, and practise what you have learned: is that not a pleasure? To have friends come from afar: is that not a joy?' Chinese hosts still quote the second line to welcome visitors, and it's printed on banners at airports, conferences and graduations."
      }
    ]
  };
  // A lesson carries one note or a list of them (grammar, sounds, culture).
  const notesFor = id => { const n = LESSON_NOTES[id]; return !n ? [] : Array.isArray(n) ? n : [n]; };
  // One mascot sprite per chapter; chapter N uses sprite N (wraps around).
  // The panda in six scenes. Sprites cycle through this list to fill the wave's
  // open pockets, so adding one here just appears on the path. All sit on a
  // 690x690 canvas at the same height, so a single CSS width renders them alike.
  const CHAPTER_SPRITES = [
    "sprite-reading.png", "sprite-baozi.png", "sprite-writing.png", "sprite-listening.png",
    "sprite-puzzled.png", "sprite-sleeping.png"
  ];
  // Where the lamplight sits inside each night cluster, measured from the art.
  const PATH_LIGHTS = {
    "cluster-left-bamboo": { x: 17.1, y: 69.9 },
    "cluster-left-waterfall": { x: 15.2, y: 71.2 },
    "cluster-left-bridge": { x: 18.2, y: 72.0 },
    "cluster-right-temple": { x: 73.1, y: 35.8 },
    "land-pagoda": { x: 56.0, y: 59.7 },
    "fol-blossom": { x: 67.4, y: 49.6 }
  };
  // Scenery clusters, alternating down the path and mirrored so a short list of
  // pieces does not read as a repeating tile.
  /* The arrangement settled in the path composer, as percentages of a 390x844
     screen. `ar` is each piece's height over its width. `y` is the base of the
     piece. This band covers five lessons and repeats down the path. */
  const BAND_LESSONS = 5;
  const BAND_TOP = 200;              // where the first lesson sat in the composer
  const BAND_H = 844;                // the screen the arrangement was composed on
  const PATH_TEMPLATE = [
    { art: "cluster-right-temple", x: 69, y: 35.6, w: 65, ar: 0.738, family: "landmark" },
    { art: "cluster-left-bamboo", x: 26.7, y: 98.2, w: 66, ar: 1.689, family: "left" },
    { art: "cluster-right-bamboo", x: 98, y: 112, w: 44, ar: 1.470, family: "right" }
  ];
  /* Every piece of scenery: how wide it is drawn (percent of the screen), its
     height over its width, and the side it was drawn for. The first band uses
     the template's own pieces; later bands rotate through each slot's family
     so the path does not repeat. The foliage was drawn with a flat left edge,
     so it is flipped when it sits on the right. */
  const ART = {
    "cluster-right-temple": { w: 65, ar: 0.738, side: "right" },
    "cluster-left-bamboo": { w: 66, ar: 1.689, side: "left" },
    "cluster-left-waterfall": { w: 66, ar: 1.546, side: "left" },
    "cluster-left-bridge": { w: 66, ar: 1.451, side: "left" },
    "cluster-left-steps": { w: 66, ar: 1.478, side: "left" },
    "cluster-right-bamboo": { w: 44, ar: 1.470, side: "right" },
    "panda-walking": { w: 22, ar: 1.352, side: "any" },
    "fol-bamboo": { w: 60, ar: 1.532, side: "left" },
    "fol-pine": { w: 60, ar: 1.349, side: "left" },
    "fol-blossom": { w: 60, ar: 1.462, side: "left" },
    "fol-banana": { w: 60, ar: 1.439, side: "left" },
    "land-torii": { w: 65, ar: 0.624, side: "any" },
    "land-pagoda": { w: 65, ar: 0.841, side: "any" },
    "land-pavilion": { w: 65, ar: 0.711, side: "any" },
    "land-house": { w: 65, ar: 0.617, side: "any" },
    "fol-oak": { w: 60, ar: 1.31, side: "left" },
    "land-bridge": { w: 65, ar: 0.58, side: "any" },
    "land-bridge-red": { w: 65, ar: 0.558, side: "any" },
    "land-pavilion-pond": { w: 65, ar: 0.577, side: "any" },
    "land-hall": { w: 65, ar: 0.547, side: "any" },
    "land-waterfall": { w: 65, ar: 0.688, side: "any" },
    "grass-1": { w: 13, ar: 0.962, side: "any" },
    "grass-2": { w: 13, ar: 0.642, side: "any" },
    "grass-3": { w: 13, ar: 0.809, side: "any" },
    "land-cliff": { w: 65, ar: 0.895, side: "left" },
    "panda-celebrate": { w: 22, ar: 1.143, side: "any" },
    "panda-idle": { w: 22, ar: 1.531, side: "any" },
    "panda-peek": { w: 22, ar: 0.703, side: "any" },
    "panda-sad": { w: 22, ar: 1.079, side: "any" },
    "panda-teacher": { w: 22, ar: 1.202, side: "any" },
    "panda-waving": { w: 22, ar: 1.321, side: "any" },
    "panda-reading": { w: 22, ar: 1.349, side: "any" },
    "panda-baozi": { w: 22, ar: 1.267, side: "any" },
    "panda-writing": { w: 22, ar: 0.978, side: "any" },
    "panda-listening": { w: 22, ar: 1.125, side: "any" },
    "panda-puzzled": { w: 22, ar: 1.297, side: "any" },
    "panda-sleeping": { w: 22, ar: 0.845, side: "any" }
  };
  const FAMILIES = {
    landmark: ["cluster-right-temple", "land-torii", "land-pagoda", "land-pavilion", "land-house", "land-bridge", "land-waterfall", "land-cliff", "land-bridge-red", "land-pavilion-pond", "land-hall"],
    left: ["cluster-left-bamboo", "cluster-left-waterfall", "cluster-left-bridge", "cluster-left-steps", "fol-bamboo", "fol-pine", "fol-blossom", "fol-banana", "fol-oak"],
    right: ["cluster-right-bamboo", "fol-bamboo", "fol-pine", "fol-blossom", "fol-banana", "fol-oak"]
  };
  /* The path as composed by hand in the path editor, phone edition. Each
     piece is placed against a lesson's stone (dx, dy from the stone's centre
     to the piece's centre-bottom, w as a share of the screen width), so it
     follows that stone when a START bubble or a new chapter shifts the path.
     Headers may be sent to a chosen side. Stones past the last composed one
     fall back to the automatic bands below. */
  const PATH_LAYOUT = {
    version: 1,
    phone: true,
    headers: { "qibu2-u3-1": "right", "qibu3-u2-1": "left" },
    pieces: [
      { art: "cluster-right-temple", stone: "qibu1-u1-1", dx: 145.1, dy: -38.5, w: 65, flip: false, behind: true },
      { art: "panda-walking", stone: "qibu1-u1-2", dx: 114.9, dy: -38.2, w: 22, flip: true, behind: false },
      { art: "cluster-left-bamboo", stone: "qibu1-u1-4", dx: -202.2, dy: 58.8, w: 66, flip: false, behind: true },
      { art: "panda-sleeping", stone: "qibu1-u2-1", dx: -176, dy: 62.3, w: 36, flip: false, behind: false },
      { art: "land-pagoda", stone: "qibu1-u2-4", dx: 237.4, dy: 91.6, w: 95, flip: false, behind: true },
      { art: "panda-writing", stone: "qibu1-u4-2", dx: -171.1, dy: -22, w: 36, flip: false, behind: false },
      { art: "land-torii", stone: "qibu1-u4-5", dx: 241.1, dy: 71.4, w: 88.7, flip: false, behind: true },
      { art: "panda-listening", stone: "qibu2-u1-2", dx: -166.1, dy: -10.6, w: 31.5, flip: false, behind: false },
      { art: "cluster-right-bamboo", stone: "qibu2-u1-5", dx: 193.2, dy: 59.9, w: 72.6, flip: false, behind: false },
      { art: "panda-reading", stone: "qibu2-u2-4", dx: -209.2, dy: 47.4, w: 27.9, flip: false, behind: false },
      { art: "panda-celebrate", stone: "qibu2-u3-3", dx: 163.5, dy: -40.9, w: 36.9, flip: false, behind: false },
      { art: "cluster-left-waterfall", stone: "qibu2-u3-6", dx: -192.3, dy: 70.7, w: 66, flip: false, behind: true },
      { art: "panda-teacher", stone: "qibu3-u1-2", dx: 162.4, dy: 36.5, w: 35.1, flip: true, behind: false },
      { art: "panda-sad", stone: "qibu3-u2-2", dx: -177, dy: -4.4, w: 29.7, flip: false, behind: false },
      { art: "fol-blossom", stone: "qibu3-u2-5", dx: 195.7, dy: 58.7, w: 61, flip: true, behind: true }
    ]
  };
  /* Local editing only: the path editor (tools/path-editor) previews an
     unsaved layout by handing it over through localStorage. Never runs on the
     live site, which is not served from localhost. */
  const DEV_LAYOUT_KEY = "bubu.dev.pathLayout";
  function devLayout() {
    if (location.hostname !== "localhost") return;
    try {
      const o = JSON.parse(localStorage.getItem(DEV_LAYOUT_KEY) || "null");
      if (o && Array.isArray(o.pieces)) { PATH_LAYOUT.headers = o.headers || {}; PATH_LAYOUT.pieces = o.pieces; }
    } catch (e) {}
  }
  devLayout();
  // Where the mascot stands relative to the lesson you are on.
  const PANDA = { x: 79.2, y: 50.8, w: 22, flip: true, ar: 831 / 614 };
  /* Where each piece is actually painted: ten strips top to bottom, each the
     opaque extent as a fraction of the width. Measured from the artwork.
     Collisions are judged on these, so foliage can lean towards the path the
     way it was composed without its empty corners counting against it. */
  const SLABS = {
    "cluster-left-bamboo": [[0.0, 0.306], [0.0, 0.346], [0.0, 0.352], [0.0, 0.427], [0.0, 0.499], [0.0, 0.596], [0.0, 0.598], [0.0, 0.605], [0.0, 0.932], [0.0, 1.0]],
    "cluster-left-waterfall": [[0.0, 0.307], [0.0, 0.378], [0.0, 0.505], [0.0, 0.465], [0.0, 0.39], [0.0, 0.5], [0.0, 0.594], [0.0, 0.704], [0.0, 0.967], [0.0, 0.999]],
    "cluster-left-bridge": [[0.0, 0.285], [0.0, 0.511], [0.0, 0.511], [0.0, 0.52], [0.0, 0.478], [0.0, 0.532], [0.0, 0.69], [0.0, 0.913], [0.0, 0.95], [0.0, 1.0]],
    "cluster-left-steps": [[0.0, 0.309], [0.0, 0.481], [0.0, 0.512], [0.0, 0.373], [0.0, 0.462], [0.0, 0.524], [0.0, 0.595], [0.0, 0.772], [0.0, 0.962], [0.0, 1.0]],
    "land-bridge-red": [[0.129, 0.74], [0.09, 0.763], [0.041, 0.856], [0.041, 0.888], [0.088, 0.958], [0.057, 0.991], [0.007, 0.998], [0.0, 0.998], [0.006, 1.0], [0.073, 0.949]],
    "land-pavilion-pond": [[0.447, 0.659], [0.38, 0.698], [0.239, 0.864], [0.139, 0.862], [0.098, 0.879], [0.091, 0.94], [0.061, 0.977], [0.017, 0.998], [0.0, 1.0], [0.122, 0.924]],
    "land-hall": [[0.585, 0.75], [0.177, 0.776], [0.101, 0.874], [0.063, 0.899], [0.028, 0.916], [0.031, 0.965], [0.043, 0.989], [0.006, 0.998], [0.0, 0.999], [0.01, 0.966]],
    "cluster-right-temple": [[0.735, 1.0], [0.641, 1.0], [0.423, 1.0], [0.332, 1.0], [0.278, 1.0], [0.185, 1.0], [0.06, 1.0], [0.0, 1.0], [0.149, 1.0], [0.48, 1.0]],
    "cluster-right-bamboo": [[0.718, 0.989], [0.668, 1.0], [0.618, 1.0], [0.638, 1.0], [0.707, 1.0], [0.627, 1.0], [0.618, 1.0], [0.449, 1.0], [0.38, 1.0], [0.0, 1.0]],
    "panda-walking": [[0.143, 0.893], [0.117, 0.926], [0.131, 0.986], [0.119, 0.995], [0.048, 0.969], [0.0, 0.995], [0.0, 1.0], [0.067, 0.8], [0.045, 0.94], [0.048, 0.94]],
    "fol-bamboo": [[0.081, 0.433], [0.0, 0.473], [0.0, 0.544], [0.0, 0.528], [0.0, 0.576], [0.0, 0.57], [0.0, 0.5], [0.0, 0.746], [0.0, 0.878], [0.0, 1.0]],
    "fol-pine": [[0.011, 0.375], [0.0, 0.569], [0.0, 0.618], [0.0, 0.759], [0.0, 0.768], [0.0, 0.506], [0.0, 0.536], [0.0, 0.718], [0.0, 0.943], [0.0, 1.0]],
    "fol-blossom": [[0.005, 0.335], [0.0, 0.463], [0.0, 0.728], [0.0, 0.817], [0.0, 0.667], [0.0, 0.618], [0.0, 0.434], [0.0, 0.669], [0.0, 0.712], [0.0, 1.0]],
    "fol-banana": [[0.235, 0.434], [0.014, 0.418], [0.014, 0.676], [0.0, 0.646], [0.0, 0.716], [0.0, 0.717], [0.0, 0.58], [0.0, 0.747], [0.0, 0.899], [0.0, 1.0]],
    "land-torii": [[0.587, 0.791], [0.161, 0.919], [0.175, 0.948], [0.209, 1.0], [0.213, 0.999], [0.097, 0.937], [0.046, 0.93], [0.016, 0.924], [0.012, 0.94], [0.0, 0.94]],
    "land-pagoda": [[0.551, 0.581], [0.49, 0.639], [0.38, 0.885], [0.359, 0.944], [0.215, 0.981], [0.159, 0.989], [0.115, 1.0], [0.06, 0.988], [0.021, 0.993], [0.0, 0.994]],
    "land-pavilion": [[0.545, 0.795], [0.478, 0.918], [0.415, 0.926], [0.129, 0.964], [0.051, 0.958], [0.018, 0.958], [0.022, 0.976], [0.009, 1.0], [0.0, 0.98], [0.056, 0.873]],
    "land-house": [[0.577, 0.798], [0.172, 0.833], [0.149, 0.864], [0.078, 0.924], [0.046, 0.969], [0.033, 1.0], [0.044, 0.998], [0.04, 0.977], [0.0, 0.995], [0.002, 0.995]],
    "fol-oak": [[0.052, 0.425], [0.0, 0.625], [0.016, 0.675], [0.0, 0.782], [0.0, 0.796], [0.0, 0.501], [0.0, 0.552], [0.0, 0.696], [0.0, 0.937], [0.0, 1.0]],
    "land-bridge": [[0.478, 0.821], [0.419, 0.931], [0.365, 0.959], [0.311, 0.976], [0.165, 0.968], [0.105, 0.986], [0.041, 0.988], [0.001, 0.999], [0.0, 0.997], [0.009, 0.893]],
    "land-waterfall": [[0.452, 0.964], [0.341, 1.0], [0.294, 1.0], [0.296, 1.0], [0.261, 1.0], [0.167, 1.0], [0.11, 1.0], [0.046, 1.0], [0.0, 1.0], [0.269, 1.0]],
    "grass-1": [[0.167, 0.309], [0.189, 0.394], [0.215, 0.454], [0.0, 0.994], [0.022, 0.984], [0.102, 0.904], [0.169, 0.843], [0.032, 1.0], [0.084, 0.976], [0.163, 0.845]],
    "grass-2": [[0.194, 0.305], [0.224, 0.364], [0.25, 0.732], [0.271, 0.702], [0.29, 0.663], [0.0, 0.632], [0.054, 1.0], [0.091, 0.897], [0.076, 0.792], [0.151, 0.729]],
    "grass-3": [[0.168, 0.344], [0.213, 0.434], [0.255, 0.934], [0.29, 0.922], [0.317, 0.863], [0.078, 0.818], [0.0, 0.785], [0.137, 1.0], [0.164, 0.92], [0.228, 0.858]],
    "land-cliff": [[0.0, 0.287], [0.0, 0.367], [0.0, 0.372], [0.0, 0.405], [0.0, 0.537], [0.0, 0.588], [0.0, 0.683], [0.0, 0.758], [0.0, 0.915], [0.0, 1.0]],
    "panda-celebrate": [[0.17, 0.952], [0.059, 0.947], [0.061, 1.0], [0.065, 0.984], [0.0, 0.972], [0.089, 0.986], [0.212, 0.851], [0.218, 0.838], [0.242, 0.79], [0.291, 0.505]],
    "panda-idle": [[0.077, 0.914], [0.077, 0.912], [0.107, 0.893], [0.107, 0.893], [0.118, 0.954], [0.035, 0.998], [0.0, 1.0], [0.002, 0.979], [0.167, 0.824], [0.139, 0.856]],
    "panda-peek": [[0.139, 0.728], [0.06, 0.734], [0.052, 0.728], [0.056, 0.954], [0.11, 0.998], [0.1, 1.0], [0.1, 0.996], [0.102, 0.975], [0.023, 0.942], [0.0, 0.888]],
    "panda-sad": [[0.188, 0.816], [0.107, 0.897], [0.109, 0.897], [0.135, 0.84], [0.137, 0.893], [0.176, 0.911], [0.145, 0.927], [0.014, 0.99], [0.0, 1.0], [0.012, 0.986]],
    "panda-teacher": [[0.036, 0.62], [0.008, 0.994], [0.026, 1.0], [0.073, 0.923], [0.032, 0.899], [0.006, 0.824], [0.0, 0.691], [0.032, 0.691], [0.119, 0.683], [0.081, 0.733]],
    "panda-waving": [[0.087, 0.741], [0.077, 0.939], [0.123, 1.0], [0.123, 0.998], [0.032, 0.956], [0.004, 0.838], [0.0, 0.78], [0.046, 0.78], [0.182, 0.78], [0.152, 0.808]],
    "panda-reading": [[0.054, 0.892], [0.052, 0.89], [0.11, 0.871], [0.104, 0.876], [0.116, 0.959], [0.035, 0.985], [0.0, 1.0], [0.002, 0.985], [0.015, 0.988], [0.033, 0.969]],
    "panda-baozi": [[0.088, 0.865], [0.066, 0.865], [0.088, 0.864], [0.125, 0.869], [0.131, 0.891], [0.133, 0.943], [0.103, 0.969], [0.045, 0.969], [0.0, 1.0], [0.002, 0.994]],
    "panda-writing": [[0.277, 0.805], [0.277, 0.818], [0.248, 0.8], [0.248, 0.777], [0.209, 0.838], [0.186, 0.891], [0.098, 0.918], [0.002, 0.998], [0.0, 1.0], [0.035, 0.968]],
    "panda-listening": [[0.05, 0.721], [0.029, 0.891], [0.09, 1.0], [0.003, 0.967], [0.0, 0.888], [0.01, 0.913], [0.093, 0.922], [0.01, 0.933], [0.002, 0.927], [0.026, 0.843]],
    "panda-puzzled": [[0.331, 1.0], [0.036, 0.96], [0.036, 0.882], [0.002, 0.806], [0.0, 0.832], [0.034, 0.876], [0.192, 0.896], [0.184, 0.89], [0.188, 0.776], [0.152, 0.824]],
    "panda-sleeping": [[0.288, 0.583], [0.091, 0.655], [0.0, 0.9], [0.086, 0.886], [0.083, 0.809], [0.134, 0.878], [0.122, 0.905], [0.063, 0.935], [0.043, 0.992], [0.097, 1.0]]
  };
  // Each stone shows the first character of its lesson that no earlier stone
  // already shows, so two stones never carry the same character.
  const HEROES = (() => {
    const used = new Set(), out = {};
    LESSONS.forEach(l => {
      const firsts = l.words.map(w => cjkOnly(w.hanzi)[0]).filter(Boolean);
      const ch = firsts.find(c => !used.has(c)) || l.words.flatMap(w => cjkOnly(w.hanzi)).find(c => !used.has(c)) || firsts[0] || "字";
      used.add(ch); out[l.id] = ch;
    });
    return out;
  })();
  const lessonHero = lesson => HEROES[lesson.id] || "字";
  /* ---- Lesson completion -------------------------------------------------
     Separate from mastery. A word is "mastered" only once its SRS interval
     reaches a week, so gating the path on that meant finishing a lesson today
     never advanced it. Completing a study round marks the lesson done; mastery
     still drives the progress bar in the lesson sheet.                      */
  const LS_DONE = "zhBeginnerA.done.v1";
  const LS_MIGRATED = "zhBeginnerA.migrated.v1";
  let doneLessons = (() => {
    try { return migrateOldDone(new Set(JSON.parse(localStorage.getItem(LS_DONE)) || [])); }
    catch { return new Set(); }
  })();
  // Lesson ids from the JIC edition don't exist any more: a new lesson counts as
  // done when every one of its words already has review history.
  function migrateOldDone(set) {
    const stale = [...set].filter(id => !LESSONS.some(l => l.id === id));
    if (!stale.length) return set;
    stale.forEach(id => set.delete(id));
    let carried = 0;
    LESSONS.forEach(l => {
      const cs = CARDS.filter(c => c.lessonId === l.id);
      if (!set.has(l.id) && cs.length && cs.every(c => srs[c.id] && srs[c.id].reps > 0)) { set.add(l.id); carried++; }
    });
    // tell them once, so stones that start out done don't look like a glitch
    if (!localStorage.getItem(LS_MIGRATED)) localStorage.setItem(LS_MIGRATED, JSON.stringify({ stones: carried, shown: false }));
    localStorage.setItem(LS_DONE, JSON.stringify([...set]));
    if (prefs.lessons && prefs.lessons.some(id => !LESSONS.some(l => l.id === id))) { delete prefs.lessons; savePrefs(prefs); }
    return set;
  }
  const saveDone = () => { localStorage.setItem(LS_DONE, JSON.stringify([...doneLessons])); queueSync(); };
  const lessonDone = id => doneLessons.has(id);
  function nextLessonId(after) {
    const i = LESSONS.findIndex(l => l.id === after);
    for (let k = i + 1; k < LESSONS.length; k++) if (!doneLessons.has(LESSONS[k].id)) return LESSONS[k].id;
    return LESSONS.find(l => !doneLessons.has(l.id))?.id || null;
  }

  const lessonPct = id => { const t = lessonCardCount(id); return t ? Math.round(lessonMastered(id) / t * 100) : 0; };
  const lessonStudied = id => CARDS.some(c => c.lessonId === id && srs[c.id]);
  // Beyond this many due cards a lesson study is split into even batches.
  const SESSION_CAP = 20;
  const SESSION_LEN = 12;     // words per session
  const NEW_PER_SESSION = 6;  // brand-new words in one session, at most
  const REVIEW_PER_SESSION = 4; // known words mixed into a session that teaches new ones
  const MEET_GROUP = 3;       // new words introduced together, before they are practised
  // A lesson is complete once every one of its words has been answered correctly
  // at least once (reps ≥ 1) — this is what lets big lessons finish across batches
  // instead of on a single cleared round.
  const lessonCleared = id => CARDS.filter(c => c.lessonId === id).every(c => srs[c.id] && srs[c.id].reps >= 1);

  /* ---- Review ------------------------------------------------------------
     The SRS was running but never surfaced: once a lesson was finished its
     words went stale with no way back to them. Review pulls everything that
     has fallen due across lessons you've already worked through.           */
  let reviewMode = false;
  function dueReviewCards() {
    const now = NOW();
    return CARDS.filter(c => {
      const s = srs[c.id];
      if (!s) return false;                       // never studied - not a review
      if (!doneLessons.has(c.lessonId) && c.lessonId !== firstUnfinishedId()) return false;
      return s.due <= now;
    });
  }
  function firstUnfinishedId() {
    for (const l of LESSONS) if (!doneLessons.has(l.id)) return l.id;
    return null;
  }
  function startReview() {
    const cards = dueReviewCards();
    if (!cards.length) { toast("Nothing due yet - come back later."); return; }
    reviewMode = true;
    scopeLessons = new Set(cards.map(c => c.lessonId));   // distractors from these lessons
    scopeFocuses = new Set(selectedFocuses);
    beginStudySession(shuffle(cards).slice(0, 20));
    $("#studyTitle").textContent = "Review";
  }

  // The words you personally keep missing. Ease only ever drops when you tap
  // "again", so ease < the 2.4 start means it's tripped you up; lapses (how many
  // times) refines the order. Only words you've actually reached count.
  function troubleCards() {
    return CARDS.filter(c => {
      const s = srs[c.id];
      if (!s || !s.reps && !s.lapses) return false;
      if (!doneLessons.has(c.lessonId) && c.lessonId !== firstUnfinishedId()) return false;
      return (s.lapses || 0) > 0 || s.ease < 2.4;
    }).sort((a, b) => {
      const sa = srs[a.id], sb = srs[b.id];
      return (sb.lapses || 0) - (sa.lapses || 0) || sa.ease - sb.ease;   // most-missed first
    });
  }
  /* ---- Your mistakes ------------------------------------------------------
     A wrong answer is kept on the word (srs[id].miss: the exercise type and
     when). It counts as fixed once the word is answered right in a LATER
     session, or in a mistakes session, so a retry at the end of the same
     session doesn't wipe it. The mistakes session asks each word the way
     you missed it. */
  let mistakesMode = false, sessionMistakes = 0, sessionFixed = 0;
  function mistakeCards() {
    return CARDS.filter(c => srs[c.id] && srs[c.id].miss).sort((a, b) => srs[b.id].miss.at - srs[a.id].miss.at);
  }
  function startMistakes() {
    const cards = mistakeCards().slice(0, SESSION_LEN);
    if (!cards.length) { toast("No mistakes to fix. Nice!"); return; }
    reviewMode = true;
    scopeLessons = new Set(cards.map(c => c.lessonId));   // plausible distractors
    scopeFocuses = new Set(FOCUSES.map(f => f.key));        // so each can be asked the way it was missed
    beginStudySession(cards, { mistakes: true });
    $("#studyTitle").textContent = "Your mistakes";
  }
  function startTrouble() {
    const cards = troubleCards();
    if (!cards.length) { toast("No trouble words yet — nothing you're stuck on. Nice!"); return; }
    reviewMode = true;
    scopeLessons = new Set(cards.map(c => c.lessonId));   // plausible distractors
    scopeFocuses = new Set(selectedFocuses);
    beginStudySession(cards.slice(0, 20));                // already hardest-first
    $("#studyTitle").textContent = "Trouble words";
  }

  // A listening-first session: audio plays and you answer from what you hear,
  // before reading anything. Reuses the existing "listen" card direction.
  function startListening() {
    reviewMode = false;
    scopeLessons = null;
    const cards = activeCards();                          // the words from your selected lessons
    const studied = cards.filter(c => srs[c.id]);        // you can only recognise words you've met
    const pool = studied.length ? studied : cards;
    if (!pool.length) { toast("Pick at least one lesson — open “What to study”."); $("#studyPanel").open = true; return; }
    scopeFocuses = new Set(["listen"]);
    beginStudySession(shuffle(pool).slice(0, 20));
    $("#studyTitle").textContent = "Listening";
  }

  function currentLessonId() {
    for (const l of LESSONS) if (!doneLessons.has(l.id)) return l.id;
    return LESSONS[LESSONS.length - 1].id;   // everything finished → last
  }

  /* ---- The river ------------------------------------------------------
     The path is a sine wave. The same function draws the water AND places the
     lotuses, so they can never drift apart. `t` runs along the scroll axis;
     the return value is the cross-axis position. Settings were dialled in on
     pathmock2.html — each orientation needs its own, because the cross-axis is
     ~800px tall on desktop but only ~400px wide on a phone.                */
  const PATH_CFG = {
    desktop: { size: 84, gap: 132, wave: 118, per: 8, phase: 6, pad: 180, sprite: 140, sgap: 80, svert: 0 },
    phone:   { size: 74, gap: 143, wave: 106, per: 8, phase: 6, pad: 170, sprite: 124, sgap: 70, svert: 0 }
  };
  const pathIsPhone = () => window.matchMedia("(max-width: 699px)").matches;
  let pathTries = 0;

  function renderPath() {
    $("#pathStreak").textContent = computeStreak();
    // Daily-goal ring in the HUD: fills through the day, flips to a gold ✓ when met.
    const goal = dailyGoal(), done = todayXP(), met = done >= goal;
    const frac = Math.max(0, Math.min(1, goal ? done / goal : 0));
    const arc = $("#pathGoalArc"), circ = 2 * Math.PI * 9;
    arc.setAttribute("stroke-dasharray", circ.toFixed(1));
    arc.setAttribute("stroke-dashoffset", (circ * (1 - frac)).toFixed(1));
    $("#pathGoal").classList.toggle("done", met);
    $("#pathGoalTxt").textContent = met ? "✓" : `${done}/${goal}`;
    renderBackupNudge();
    // Review call-to-action: only shown when something has actually fallen due.
    const due = dueReviewCards().length, fab = $("#reviewFab");
    const allDone = LESSONS.every(l => doneLessons.has(l.id));
    fab.innerHTML = "";
    if (due) {
      fab.appendChild(icon("repeat", 18));
      fab.appendChild(document.createTextNode(` Review ${due} word${due === 1 ? "" : "s"}`));
      fab.classList.remove("hidden", "caughtup");
    } else if (allDone) {
      fab.appendChild(document.createTextNode("Course complete — all caught up"));
      fab.classList.remove("hidden");
      fab.classList.add("caughtup");
    } else fab.classList.add("hidden");

    const wrap = $("#pathList");
    const phone = pathIsPhone(), c = phone ? PATH_CFG.phone : PATH_CFG.desktop;
    const curId = currentLessonId();

    // flatten chapters into an ordered list, remembering where each one starts.
    // The banner shows the unit + a chapter number counted WITHIN that unit.
    const items = [];
    const unitCh = {};
    CHAPTERS.forEach((ch, ci) => {
      unitCh[ch.unit] = (unitCh[ch.unit] || 0) + 1;
      const chNo = unitCh[ch.unit];
      ch.lessons.forEach((id, li) => {
        const lesson = LESSONS.find(l => l.id === id);
        if (lesson) items.push({
          lesson,
          chapter: li === 0 ? {
            unit: ch.unit, chNo, title: ch.title,
            total: ch.lessons.length,
            done: ch.lessons.filter(x => doneLessons.has(x)).length, ci
          } : null
        });
      });
    });

    // everything this function draws, so a redraw never stacks a second copy
    [...wrap.querySelectorAll(".pnode,.pchapter,.psprite,.pcluster,.pground,.ppebble")].forEach(n => n.remove());

    // Vertical positions. A chapter opens a banner-sized void before its first
    // button; size that void to one even edge-gap above AND below the banner
    // (plus the START bubble's headroom, but only when that first button is the
    // current lesson) so the path's rhythm doesn't stutter around a header.
    const BUBBLE = 40;                    // headroom reserved for a START bubble (placement measures the real overhang)
    // Measure the HUD rather than hardcode it: on a notched phone its safe-area
    // top padding makes it taller, and the first banner must clear THAT, not 62.
    const hudEl = document.querySelector(".path-top");
    const HUD_H = (hudEl && hudEl.offsetHeight) || 62;
    const EDGE = Math.max(22, c.gap - c.size);   // normal coin-to-coin edge gap
    const BANNER_H = 72;                  // the header block; placement re-centres on the real height
    const HGAP = 36;                      // extra room a header gets, over the normal stone gap
    // A chapter banner gets a roomier gap than the coins do, the SAME above and
    // below — and, crucially, banner→coin stays this size even when that coin is
    // the current lesson, because bubbleFor() reserves the START bubble's height
    // ON TOP. So a bubble arriving under a banner (as progression reaches a new
    // chapter) never eats into the gap or clips the banner.
    const BGAP = EDGE + 24;
    const bubbleFor = i => (items[i].lesson.id === curId ? BUBBLE : 0);
    const ys = [];
    // Chapter 1's banner sits nearer the HUD than later banners do — there's no
    // preceding coin to breathe from, so the full 2×BGAP void just read as dead
    // space at the very top. One BGAP splits evenly above/below it instead.
    let y = HUD_H + 16 + BANNER_H + bubbleFor(0) + c.size / 2;
    items.forEach((it, i) => {
      if (it.chapter && i > 0) y += HGAP + BANNER_H + bubbleFor(i);
      ys.push(y); y += c.gap;
    });
    wrap.style.height = (ys[ys.length - 1] + c.pad) + "px";

    // A hidden #path has width 0 and can't be laid out. Only retry while the path
    // is actually the visible view — otherwise a render kicked off while we're on
    // another tab would storm retries and burn through pathTries, leaving the path
    // blank on its first open (the "have to tap Learn twice" bug). Callers show
    // the path FIRST, then render, so this measures a real width straight away.
    const W = wrap.clientWidth;
    if (!W) {
      if (document.body.dataset.view === "path" && pathTries++ < 40) setTimeout(renderPath, 50);
      return;
    }
    pathTries = 0;

    // The sine advances one step per BUTTON, so `per` is how many buttons make
    // up a full sweep. Normalising by the largest value the buttons actually
    // reach makes `wave` the true offset of the outermost one — without it,
    // changing `per` would silently change the path's width too.
    let k = 0;
    for (let i = 0; i < items.length; i++) k = Math.max(k, Math.abs(Math.sin(i * 2 * Math.PI / c.per)));
    if (k < 1e-6) k = 1;                  // every button on a zero crossing: straight column
    const half = c.size / 2 + 8;
    const nodeX = i => Math.max(half, Math.min(W - half,
      W / 2 + c.wave * Math.sin((i + (c.phase || 0)) * 2 * Math.PI / c.per) / k));

    const place = (node, x, yy) => {
      node.style.left = x + "px"; node.style.top = yy + "px"; wrap.appendChild(node);
    };

    /* ---- Scenery. Settled in the path composer and expressed here against the
       same 74px stone the editor used, so the numbers carry straight over. */
    const SC = { patchW: 1.20, patchSquash: .66,
                 pebEvery: 9.2, pebSize: 11, pebVar: .63, pebWander: 31, pebClear: 4,
                 clusterEvery: 6 };
    const unit = c.size / 74;                       // editor units to real pixels
    const noise = n => {
      const v = Math.sin(n * 12.9898) * 43758.5453;
      return (v - Math.floor(v)) * 2 - 1;
    };

    // A smooth walk down the whole path, used to thread the pebbles.
    const curve = t => {
      const f = t * (ys.length - 1);
      const i = Math.max(0, Math.min(ys.length - 2, Math.floor(f)));
      let u = f - i;
      u = u * u * (3 - 2 * u);
      return { x: nodeX(i) + (nodeX(i + 1) - nodeX(i)) * u,
               y: ys[i] + (ys[i + 1] - ys[i]) * u };
    };

    // A header takes the side of the path the stones around it leave free.
    // The first one sits on the left, under the HUD, as the design has it.
    const headerRight = i => {
      const chosen = PATH_LAYOUT.headers[items[i].lesson.id];
      if (chosen) return chosen === "right";
      return i > 0 && (nodeX(i - 1) + nodeX(i)) / 2 < W / 2;
    };

    // Everything scenery has to keep out of: the stones, and the chapter
    // headers, each on its own side of the page.
    const obstacles = [];
    for (let i = 0; i < ys.length; i++) {
      obstacles.push({
        x0: nodeX(i) - c.size * STONE_RATIO / 2, x1: nodeX(i) + c.size * STONE_RATIO / 2,
        y0: ys[i] - c.size / 2, y1: ys[i] + c.size / 2
      });
      if (!items[i].chapter) continue;
      const top = ys[i] - c.size / 2 - bubbleFor(i);
      const prev = i === 0 ? HUD_H : ys[i - 1] + c.size / 2;
      const mid = (prev + top) / 2;
      const right = headerRight(i);
      obstacles.push({ header: true, x0: right ? W * .38 : 0, x1: right ? W : W * .62,
                       y0: mid - BANNER_H / 2, y1: mid + BANNER_H / 2 });
    }
    // Ground under each stone, so it reads as resting on cleared earth.
    items.forEach((it, i) => {
      const w = c.size * STONE_RATIO * SC.patchW;
      const g = el("div", { className: "pground g" + (i % 4) });
      g.style.width = w + "px";
      g.style.height = (w * SC.patchSquash) + "px";
      place(g, nodeX(i), ys[i] + c.size * .14);
    });

    // The pebble trail. Density is fixed, so a long chapter gets more of them
    // rather than the same number stretched further apart.
    const span = ys[ys.length - 1] - ys[0];
    const pebbles = Math.max(0, Math.round(span / (SC.pebEvery * unit)));
    const halfW = c.size * STONE_RATIO / 2 + SC.pebClear * unit;
    const halfH = c.size / 2 + SC.pebClear * unit;
    for (let n = 1; n <= pebbles; n++) {
      const t = n / (pebbles + 1);
      const p = curve(t), q = curve(Math.min(1, t + 0.002));
      const dx = q.x - p.x, dy = q.y - p.y;
      const len = Math.hypot(dx, dy) || 1;
      const off = SC.pebWander * unit * noise(n * 1.7);
      const w = SC.pebSize * unit * (1 + SC.pebVar * noise(n * 4.3));
      const bx = p.x - dy / len * off, by = p.y + dx / len * off;
      // Anything landing inside a stone, or under a header, is dropped, not drawn.
      let hidden = false;
      for (let i = 0; i < ys.length && !hidden; i++) {
        const ex = (bx - nodeX(i)) / (halfW + w / 2), ey = (by - ys[i]) / (halfH + w / 2);
        if (ex * ex + ey * ey < 1) hidden = true;
      }
      for (const b of obstacles) {
        if (b.header && bx > b.x0 - w && bx < b.x1 + w && by > b.y0 - w && by < b.y1 + w) {
          hidden = true; break;
        }
      }
      if (hidden) continue;
      const pb = el("div", { className: "ppebble" });
      pb.style.width = Math.max(3, w) + "px";
      pb.style.height = Math.max(2, w * .62) + "px";
      place(pb, bx, by);
    }

    /* ---- Scenery placement. Every band starts from the composed template.
       Collisions are judged on where a piece is painted (SLABS), not on its
       bounding box. A piece that would run into a stone, a header or another
       piece slides up or down the path to the nearest clear stretch; failing
       that it tries the mirrored side; failing that it is left out. Nothing
       goes under the HUD, and nothing goes below the last stone. */
    const bandScale = c.gap / 143;                  // the spacing it was composed at
    const pathTop = HUD_H + 8;
    const pathEnd = ys[ys.length - 1] + c.size * .9;
    const taken = [];                               // strips scenery already paints
    const overlap = (a, b, pad) =>
      a.x0 < b.x1 + pad && a.x1 > b.x0 - pad && a.y0 < b.y1 + pad && a.y1 > b.y0 - pad;
    const strips = (art, x0, y0, w, h, mirrored) => {
      const out = [], sl = SLABS[art];
      sl.forEach((sb, r) => {
        if (!sb) return;
        const l = mirrored ? 1 - sb[1] : sb[0], rr = mirrored ? 1 - sb[0] : sb[1];
        out.push({ x0: x0 + l * w, x1: x0 + rr * w,
                   y0: y0 + h * r / sl.length, y1: y0 + h * (r + 1) / sl.length });
      });
      return out;
    };
    /* The template was composed with foliage touching the stones, so stones
       get no margin (the alpha cut when the strips were measured is margin
       enough); header text and other scenery get a little. */
    const PAD = { stone: 0, header: 4, scenery: 4 };
    // `asComposed` is for the first band, laid out exactly as the template
    // was approved: its pieces were composed against each other, so only the
    // stones and headers can turn one away.
    const fits = (art, x0, y0, w, h, mirrored, asComposed) => {
      if (y0 < pathTop || y0 + h > pathEnd) return false;
      const st = strips(art, x0, y0, w, h, mirrored);
      for (const sp of st) {
        for (const o of obstacles) if (overlap(sp, o, o.header ? PAD.header : PAD.stone)) return false;
        if (!asComposed) for (const t of taken) if (overlap(sp, t, PAD.scenery)) return false;
      }
      return true;
    };
    // The composed spot first, then step away from it down and up the path.
    const settle = (art, cx, base, w, h, mirrored, reach, asComposed) => {
      for (let d = 0; d <= reach; d += 12) {
        for (const sgn of (d ? [1, -1] : [1])) {
          const y0 = base - h + sgn * d;
          if (fits(art, cx - w / 2, y0, w, h, mirrored, asComposed)) return y0 + h;
        }
      }
      return null;
    };
    const claim = (art, cx, base, w, h, mirrored) =>
      taken.push(...strips(art, cx - w / 2, base - h, w, h, mirrored));

    // The mascot stands on a little patch of the same ground as the stones,
    // and faces the path.
    const addPanda = (cx, base) => {
      const pw = W * PANDA.w / 100, ph = pw * PANDA.ar;
      const gw = pw * .82, gh = gw * .38;
      const g = el("div", { className: "pground g2" });
      g.style.width = gw + "px";
      g.style.height = gh + "px";
      place(g, cx, base - gh * .62 + gh / 2);
      const sp = el("div", { className: "psprite" + (cx > W / 2 ? " flip" : "") });
      sp.style.backgroundImage = "var(--panda-walk)";
      sp.style.width = pw + "px";
      sp.style.height = ph + "px";
      place(sp, cx, base - ph / 2);
      claim("panda-walking", cx, base, pw, ph, cx > W / 2);
    };

    /* ---- The hand-composed layout, drawn exactly as placed. It was composed
       at 390 wide: sideways offsets scale with the screen, vertical ones do
       not, because the stone spacing is fixed in pixels. */
    const kx = W / 390;
    let composedUntil = -1;
    PATH_LAYOUT.pieces.forEach(p => {
      const i = items.findIndex(it => it.lesson.id === p.stone);
      const a = ART[p.art];
      if (i < 0 || !a) return;
      composedUntil = Math.max(composedUntil, i);
      const cx = nodeX(i) + p.dx * kx, base = ys[i] + p.dy;
      const w = W * p.w / 100, h = w * a.ar;
      if (/^panda/.test(p.art)) {
        const gw = w * .82, gh = gw * .38;
        const g = el("div", { className: "pground g2" });
        g.style.width = gw + "px";
        g.style.height = gh + "px";
        place(g, cx, base - gh * .62 + gh / 2);
        const sp = el("div", { className: "psprite" + (p.flip ? " flip" : "") });
        sp.style.backgroundImage = `var(--${p.art === "panda-walking" ? "panda-walk" : p.art})`;
        sp.style.width = w + "px";
        sp.style.height = h + "px";
        place(sp, cx, base - h / 2);
      } else {
        const cl = el("div", { className: "pcluster" + (p.flip ? " flip" : "") + (p.behind ? "" : " front") +
          (PATH_LIGHTS[p.art] ? "" : " nolight") });
        cl.style.width = w + "px";
        cl.style.height = h + "px";
        cl.style.backgroundImage = `var(--${p.art})`;
        const lit = PATH_LIGHTS[p.art];
        if (lit) {
          const lx = p.flip ? 100 - lit.x : lit.x;
          cl.style.setProperty("--lx", ((35 + lx) / 170 * 100).toFixed(1) + "%");
          cl.style.setProperty("--ly", ((45 + lit.y) / 190 * 100).toFixed(1) + "%");
          cl.style.setProperty("--glow-r", Math.round(parseFloat(cl.style.width) * 0.38) + "px");   // the pool of light scales with the piece
        }
        place(cl, cx, base);
      }
      claim(p.art, cx, base, w, h, p.flip);
    });

    // Only the scenery composed in the path editor is drawn. The automatic bands
    // below fill a path only when nothing has been composed at all.
    const autoScenery = !PATH_LAYOUT.pieces.length;
    for (let b = 0; autoScenery && b * BAND_LESSONS < items.length; b++) {
      const first = b * BAND_LESSONS;
      if (first <= composedUntil) continue;             // composed by hand: leave it be
      const anchor = ys[first] - BAND_TOP * bandScale;
      const bandH = BAND_H * bandScale;

      // The mascot goes first: it matters more than the planting. As composed
      // if that is clear, otherwise beside one of the band's stones, on the
      // open side, about a stone's width away from it.
      const pw = W * PANDA.w / 100, ph = pw * PANDA.ar;
      const tx = W * PANDA.x / 100, tb = anchor + BAND_H * PANDA.y / 100 * bandScale;
      const ty = settle("panda-walking", tx, tb, pw, ph, tx > W / 2, b === 0 ? 0 : c.gap * .5, b === 0)
              ?? settle("panda-walking", tx, tb, pw, ph, tx > W / 2, c.gap * .5);
      if (ty !== null) addPanda(tx, ty);
      else for (const k of [1, 3, 0, 2, 4]) {
        const i = first + k;
        if (i >= items.length) continue;
        const side = nodeX(i) < W / 2 ? 1 : -1;
        const edge = nodeX(i) + side * c.size * STONE_RATIO / 2;
        let cx = edge + side * (c.size * .9 + pw / 2);
        cx = Math.max(pw / 2 + 4, Math.min(W - pw / 2 - 4, cx));
        if (Math.abs(cx - edge) - pw / 2 < c.size * .4) continue;      // too tight a fit
        const yb = settle("panda-walking", cx, ys[i] + c.size * 1.16, pw, ph, cx > W / 2, c.gap * .35);
        if (yb !== null) { addPanda(cx, yb); break; }
      }

      PATH_TEMPLATE.forEach((spec, k) => {
        const base = anchor + BAND_H * spec.y / 100 * bandScale;
        // The first band is the template as composed; after that each slot
        // rotates through its family, the two foliage slots out of step so a
        // band never shows the same piece twice.
        const fam = FAMILIES[spec.family];
        const art = b === 0 ? spec.art : fam[(b * 5 + k * 7) % fam.length];
        const a = ART[art];
        const slotRight = spec.x > 50;
        // Full size on the composed side, then mirrored, then a little smaller,
        // anywhere in the band. Off the edge as composed: the pieces were
        // drawn to bleed, and moving them inward is what causes the clutter.
        let cw, ch, cx, mirrored, flipped, y = null;
        if (b === 0) {                              // exactly as composed, if the stones allow
          cw = W * a.w / 100; ch = cw * a.ar; cx = W * spec.x / 100;
          mirrored = false; flipped = false;
          y = settle(art, cx, base, cw, ch, false, 0, true);
        }
        if (y === null) for (const scale of [1, .85, .72]) {
          cw = W * a.w / 100 * scale; ch = cw * a.ar;
          for (mirrored of [false, true]) {
            // The slot's outer edge stays where it was composed, so any piece
            // in it keeps the same overhang off the side of the screen.
            const full = W * spec.w / 100, x0 = W * spec.x / 100;
            const outer = slotRight ? x0 + full / 2 - cw / 2 : x0 - full / 2 + cw / 2;
            cx = mirrored ? W - outer : outer;
            const onRight = slotRight !== mirrored;
            flipped = a.side === "any" ? mirrored : (onRight !== (a.side === "right"));
            y = settle(art, cx, base, cw, ch, flipped, bandH * .6);
            if (y !== null) break;
          }
          if (y !== null) break;
        }
        if (y === null) return;                     // no room for it in this band
        const cl = el("div", { className: "pcluster" + (flipped ? " flip" : "") +
          (PATH_LIGHTS[art] ? "" : " nolight") });
        cl.style.width = cw + "px";
        cl.style.height = ch + "px";
        cl.style.backgroundImage = `var(--${art})`;
        const lit = PATH_LIGHTS[art];
        if (lit) {
          // The glow's box is 170% wide and 190% tall of the piece (see the CSS
          // inset), so the light's position has to be mapped into that box.
          const lx = flipped ? 100 - lit.x : lit.x;
          cl.style.setProperty("--lx", ((35 + lx) / 170 * 100).toFixed(1) + "%");
          cl.style.setProperty("--ly", ((45 + lit.y) / 190 * 100).toFixed(1) + "%");
          cl.style.setProperty("--glow-r", Math.round(parseFloat(cl.style.width) * 0.38) + "px");   // the pool of light scales with the piece
        }
        place(cl, cx, y);
        claim(art, cx, y, cw, ch, flipped);
      });
    }

    items.forEach((it, i) => {
      const yy = ys[i], x = nodeX(i), id = it.lesson.id;
      const state = lessonDone(id) ? "done" : (id === curId ? "now" : "todo");
      // Lessons unlock in order: you can replay finished ones and play the
      // current one, but everything ahead is locked.
      const btn = el("button", { className: "pnode" + (state === "todo" ? " locked" : "") });
      btn.appendChild(coinMarkup(it.lesson, state, c.size));
      // Every node opens its sheet. A locked node's sheet offers the skip test,
      // so tapping ahead is a way to test out rather than a dead end.
      btn.addEventListener("click", () => openLessonSheet(id));
      place(btn, x, yy);

      if (it.chapter) {                    // banner sits in the lead-in gap above
        const pct = it.chapter.total ? Math.round(it.chapter.done / it.chapter.total * 100) : 0;
        const hd = el("div", { className: "pchapter" }, [
          el("div", { className: "u" }, [`${it.chapter.unit} · CHAPTER ${it.chapter.chNo}`, guideLink(it.chapter.ci)]),
          el("div", { className: "t" }, it.chapter.title),
          el("div", { className: "bar" }, el("i", { style: `width:${pct}%` })),
          el("div", { className: "n" }, `${it.chapter.done} / ${it.chapter.total} lessons`)
        ]);
        // A finished chapter ends in a short story written from its words.
        const story = readingFor(it.chapter.ci);
        if (story && it.chapter.done === it.chapter.total) {
          const rb = el("button", { className: "pread" + (readDone(story.id) ? " read" : ""), type: "button" });
          rb.appendChild(licon("i-book", "licon-sm"));
          rb.appendChild(el("span", {}, readDone(story.id) ? "Read again" : "Read the story"));
          rb.addEventListener("click", e => { e.stopPropagation(); openReading(story.id, "path"); });
          hd.querySelector(".n").appendChild(rb);
        }
        // Centre it in the gap it opened. `btn` (the button this banner labels)
        // is already in the DOM, so measure the START bubble's REAL overhang
        // rather than guessing it — a fixed constant was 11px too big and
        // re-skewed the gaps the moment progression put a bubble here. Measuring
        // also keeps the edge gaps equal for any banner or bubble height.
        const startEl = btn.querySelector(".start");
        let overhang = 0;
        if (startEl) {
          const bt = btn.getBoundingClientRect(), st = startEl.getBoundingClientRect();
          overhang = Math.max(0, bt.top - st.top);
        }
        const topOfNext = yy - c.size / 2 - overhang;
        const bottomOfPrev = i === 0 ? HUD_H : ys[i - 1] + c.size / 2;
        if (headerRight(i)) { hd.classList.add("right"); hd.style.right = "0"; }
        else hd.style.left = "0";
        hd.style.top = ((bottomOfPrev + topOfNext) / 2) + "px";
        wrap.appendChild(hd);
      }
    });

    // Land the path on your CURRENT lesson every render, so it opens where you
    // are — and, crucially, at a deterministic scroll position. Leaving the inner
    // scroll wherever it happened to be is what showed up as the whole path
    // "pushed up" after finishing a session.
    const scroller = $("#pathScroll");
    const curIdx = items.findIndex(it => it.lesson.id === curId);
    if (scroller && curIdx >= 0) {
      const curY = ys[curIdx];
      requestAnimationFrame(() => {
        const max = Math.max(0, wrap.offsetHeight - scroller.clientHeight);
        scroller.scrollTop = Math.min(max, Math.max(0, curY - scroller.clientHeight * 0.5));
      });
    }
  }
  // Home scenery parallax. Each layer carries its own drift, the share of the
  // scroll it climbs by: clouds barely move, the hills a little, the near
  // bush the most, so the view has depth. Nothing moves under reduced motion.
  (() => {
    const layers = [...document.querySelectorAll(".home-bg[data-drift]")];
    if (!layers.length) return;
    // Browsers with scroll-driven animations do this in CSS, on the compositor.
    if (window.CSS && CSS.supports && CSS.supports("animation-timeline: scroll()")) return;
    const calm = window.matchMedia("(prefers-reduced-motion: reduce)");
    let queued = false;
    const settle = () => {
      queued = false;
      const home = document.body.dataset.view === "home" && !calm.matches;
      layers.forEach(l => {
        l.style.transform = home ? `translate3d(0, ${(-window.scrollY * parseFloat(l.dataset.drift)).toFixed(1)}px, 0)` : "";
      });
    };
    window.addEventListener("scroll", () => { if (!queued) { queued = true; requestAnimationFrame(settle); } }, { passive: true });
    settle();
  })();

  // Re-lay when the window changes shape (positions are measured, not static).
  let pathResizeTimer = null;
  window.addEventListener("resize", () => {
    if (document.body.dataset.view !== "path") return;
    clearTimeout(pathResizeTimer);
    pathResizeTimer = setTimeout(renderPath, 120);
  });

  // Character size and nudge, settled in the stone editor against a 74px stone.
  const HERO = { size: 35, dy: -7.5 };
  const STONE_RATIO = 1.62;          // the stone artwork is wider than it is tall

  // Which of the five stone outlines a lesson gets. Hashing the id keeps it
  // stable, so a lesson always sits on the same stone.
  const stoneShape = id => {
    let h = 0;
    for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
    return h % 5;
  };

  // Lesson stones: the character is carved into the stone, and the stone's own
  // colour says whether the lesson is finished, current or still locked.
  function coinMarkup(lesson, state, size) {
    const node = el("div", { className: "coin " + state });
    const art = state === "todo" ? "locked" : state;
    node.style.width = Math.round(size * STONE_RATIO) + "px";
    node.style.height = size + "px";
    node.style.setProperty("--stone", `var(--st-${art}-${stoneShape(lesson.id)})`);
    node.style.setProperty("--hero-dy", (size * HERO.dy / 74).toFixed(2) + "px");
    node.style.setProperty("--hero-d", (size * HERO.size / 74 * 0.05).toFixed(2) + "px");

    const hero = el("div", { className: "hero" }, lessonHero(lesson));
    hero.style.fontSize = (size * HERO.size / 74).toFixed(1) + "px";
    node.appendChild(hero);
    if (state === "now") node.appendChild(el("div", { className: "start" }, "START"));
    return node;
  }


  function openLessonSheet(id) {
    returnView = "path";
    const lesson = LESSONS.find(l => l.id === id);
    const pct = lessonPct(id), total = lessonCardCount(id), mastered = lessonMastered(id);
    // A completed lesson counts as studied even if its SRS was cleared/imported,
    // so a done coin never opens a "new lesson" sheet.
    const due = dueCountForLesson(id), studied = lessonStudied(id) || lessonDone(id);
    const sheet = $("#lessonSheet");
    const chip = (icoId, label, focus, wide) => {
      const c = el("div", { className: "lchip" + (wide ? " wide" : "") }, [
        el("span", { className: "em" }, licon(icoId, "licon-sm")), document.createTextNode(" " + label)
      ]);
      if (studied) c.addEventListener("click", () => { closeLessonSheet(); launchLesson(id, focus); });
      else c.appendChild(el("span", { className: "lk" }, icon("lock", 15)));
      return c;
    };
    const box = el("div", { className: "lsheet" });
    box.addEventListener("click", e => e.stopPropagation());
    const pose = pct >= 100 ? "panda-celebrate" : studied ? "panda-idle" : "panda-waving";
    box.appendChild(el("img", { className: "lsheet-mascot", src: `images/${pose}.png${ASSET_V}`, alt: "" }));
    box.appendChild(el("div", { className: "handle" }));
    box.appendChild(el("div", { className: "lhead" }, [
      el("div", { className: "lcoin" }, lessonHero(lesson)),
      el("div", { className: "lmeta" }, [
        el("div", { className: "k" }, lesson.title.split(" · ")[0].toUpperCase()),
        el("div", { className: "t" }, lesson.title.replace(/^.*?· /, "")),
        el("div", { className: "bar" }, el("i", { style: `width:${pct}%` })),
        el("div", { className: "m" }, studied ? `${mastered} / ${total} mastered${due ? ` · ${due} due` : ""}` : `new lesson · ${total} words`)
      ])
    ]));
    const locked = !lessonDone(id) && id !== currentLessonId();
    const study = el("button", { className: "lstudy" });
    if (locked) {
      // A locked lesson can't be studied directly — offer to test out to reach it.
      study.innerHTML = `<svg class="licon licon-sm"><use href="#i-target"/></svg> Take the skip test<small>pass to unlock this — and everything before it</small>`;
      study.addEventListener("click", () => { closeLessonSheet(); startPlacement(id); });
    } else {
      study.innerHTML = (studied ? "Study" : "Start studying") + "<small>mixed skills · spaced repetition</small>";
      study.addEventListener("click", () => { closeLessonSheet(); launchLesson(id, null); });
    }
    box.appendChild(study);
    notesFor(id).forEach(n => box.appendChild(el("div", { className: "lnote" }, [
      el("div", { className: "lnote-t" }, [licon("i-bulb", "licon-sm"), document.createTextNode(" " + n.title)]),
      el("div", { className: "lnote-b" }, n.body)
    ])));
    // Before a lesson is studied the focused-practice chips are all locked, so
    // showing six greyed-out rows is just dead height — keep the sheet short and
    // only reveal them once they actually work.
    if (studied) {
      box.appendChild(el("div", { className: "lsub" }, [document.createTextNode("OR PRACTISE ONE SKILL")]));
      box.appendChild(el("div", { className: "lchips" }, [
        chip("i-pencil", "Write", "write"),
        chip("i-languages", "Pinyin", "pinyin"),
        chip("i-headphones", "Listen", "listen"),
        chip("i-blocks", "Sentences", "sentence"),
        chip("i-check", "Quiz", "quiz"),
        chip("i-book", "Browse the words", "browse", true)
      ]));
    } else {
      box.appendChild(el("div", { className: "lsub" },
        [icon("lock", 15), document.createTextNode(locked
          ? "Reach this in order, or pass the skip test above"
          : "Finish a Study round to unlock focused practice")]));
    }
    // Scroll the sheet's CONTENT (not the mascot) so a tall sheet — a lesson with
    // a note plus six skill chips — never clips on a phone with a home indicator.
    const inner = el("div", { className: "lsheet-inner" });
    [...box.children].forEach(ch => { if (!ch.classList.contains("lsheet-mascot")) inner.appendChild(ch); });
    box.appendChild(inner);
    sheet.innerHTML = "";
    sheet.appendChild(box);
    sheet.classList.remove("hidden");
  }
  function closeLessonSheet() { $("#lessonSheet").classList.add("hidden"); }
  $("#lessonSheet").addEventListener("click", closeLessonSheet);

  // Launch a lesson in the chosen way (null focus = mixed study).
  function launchLesson(id, focus) {
    returnView = "path";
    if (!lessonDone(id) && id !== currentLessonId()) return;   // locked — play in order
    reviewMode = false;
    scopeLessons = new Set([id]);
    if (focus === "quiz") { scopeFocuses = null; startQuiz(); }
    else if (focus === "browse") { scopeFocuses = null; startBrowse(); }
    else if (focus) { scopeFocuses = new Set([focus]); startStudy(); }
    else { scopeFocuses = new Set(selectedFocuses); startStudy(); }   // mixed = user's chosen skills
  }

  // Bottom nav
  document.querySelectorAll(".bottomnav button").forEach(b =>
    b.addEventListener("click", () => {
      const nav = b.dataset.nav;
      if (nav === "settings") { syncSettings(); renderAccount(); openModal("settingsModal"); return; }
      // (highlight is synced by show() itself)
      if (nav === "home") { renderHome(); show("home"); }
      else if (nav === "path") { show("path"); renderPath(); }
      else if (nav === "progress") { renderDashboard(); show("progress"); }
    }));
  $("#reviewFab").addEventListener("click", () => { if (!$("#reviewFab").classList.contains("caughtup")) { returnView = "path"; startReview(); } });
  $("#pathSettings").addEventListener("click", () => { syncSettings(); renderAccount(); openModal("settingsModal"); });
  // Tapping the daily-goal ring jumps to Progress, where the full ring + streak live.
  $("#pathGoal").addEventListener("click", () => { renderDashboard(); show("progress"); });

  let queue = [];        // array of card objects
  let studyStats = { reviewed: 0, again: 0 };

  /* ---- Sentence pool (for the word-tile builder) ---------------------- */
  // The dialogue pinyin is grouped by word ("nǐ jiào shénme míngzi"), so counting
  // the syllables in each pinyin token tells us how many hanzi it covers — that
  // gives a proper word segmentation to build tiles from.
  const PY_VOWELS = "aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ";
  function syllableCount(token) {
    let n = 0, inVowel = false;
    for (const ch of token.toLowerCase()) {
      const isV = PY_VOWELS.includes(ch);
      if (isV && !inVowel) n++;
      inVowel = isV;
    }
    return Math.max(1, n);
  }
  const CJK_ONE = /[一-鿿]/;
  function segmentSentence(hanzi, pinyin) {
    const chars = [...hanzi].filter(c => CJK_ONE.test(c));
    const tokens = pinyin.split(/\s+/).map(t => t.replace(/[,.!?;:，。！？]/g, "")).filter(Boolean);
    const words = [];
    let i = 0;
    for (const tok of tokens) {
      // an erhua syllable (nǎr, yīdiǎnr) also takes the 儿 that follows it
      const n = syllableCount(tok) + (/[^e]r$/i.test(tok) && chars[i + syllableCount(tok)] === "儿" ? 1 : 0);
      const w = chars.slice(i, i + n).join("");
      if (!w) break;
      words.push({ hanzi: w, pinyin: tok });
      i += n;
    }
    // Only trust the split if it consumed every character and gives ≥2 tiles.
    return (i === chars.length && words.length >= 2) ? words : null;
  }
  const SENTENCES = [];
  (window.DIALOGUES || []).forEach(d => (d.turns || []).forEach(t => {
    const words = segmentSentence(t.hanzi, t.pinyin);
    if (words) SENTENCES.push({ hanzi: t.hanzi, pinyin: t.pinyin, en: t.en, words, alt: t.alt || [] });
  }));

  /* ---- Other word orders that are also right ---------------------------
     Chinese lets a time word sit before or after the subject (明天我要… and
     我明天要… are both fine), so a sentence built the other way round must not
     be marked wrong. Each sentence yields every order it accepts: the stored
     one, the subject/time swap when it opens that way, and any alternatives
     written into the dialogue data as `alt` (which must use the same words). */
  const SUBJECTS = new Set(["我", "你", "他", "她", "它", "我们", "你们", "他们", "她们", "咱们", "您"]);
  const isTimeWord = w => /^(今|明|昨|后|前)(天|年)$/.test(w) || /^(早|晚|上|中|下)(上|午)$/.test(w)
    || /^(星期|周)/.test(w) || ["现在", "周末", "每天", "每年", "平时", "以后", "以前", "刚才"].includes(w);
  function acceptedOrders(sent) {
    const base = sent.words.map(w => w.hanzi);
    const orders = [base];
    const add = seq => { if (!orders.some(o => o.join("") === seq.join(""))) orders.push(seq); };
    const [a, b] = base;
    if (base.length > 2 && ((SUBJECTS.has(a) && isTimeWord(b)) || (isTimeWord(a) && SUBJECTS.has(b))))
      add([b, a, ...base.slice(2)]);
    // Alternatives from the data: split each on the sentence's own words.
    const vocab = [...new Set(base)].sort((x, y) => y.length - x.length);
    (sent.alt || []).forEach(h => {
      const chars = [...h].filter(c => CJK_ONE.test(c)).join("");
      const seq = [];
      let i = 0;
      while (i < chars.length) {
        const w = vocab.find(v => chars.startsWith(v, i));
        if (!w) return;
        seq.push(w); i += w.length;
      }
      if (seq.length === base.length && [...seq].sort().join() === [...base].sort().join()) add(seq);
    });
    return orders;
  }
  // The stored pinyin, re-ordered to follow a different word order.
  function pinyinFor(sent, order) {
    const py = {};
    sent.words.forEach(w => { py[w.hanzi] = w.pinyin; });
    return order.map(w => py[w] || "").join(" ");
  }
  const tailPunct = h => (/[。？！]$/.test(h) ? h.slice(-1) : "");
  const enWords = s => s.replace(/[.!?,;:]+/g, "").split(/\s+/).filter(Boolean);
  const sentencesFor = card => SENTENCES.filter(s => s.hanzi.includes(card.hanzi));

  function pickDirection(card) {
    const miss = mistakesMode && card && srs[card.id] && srs[card.id].miss;
    if (miss && !dirByCard[card.id] && missedDirPossible(card, miss.d)) { dirByCard[card.id] = miss.d; return (lastDir = miss.d); }
    const focusSet = scopeFocuses || selectedFocuses;
    let enabled = FOCUSES.filter(f => focusSet.has(f.key)).map(f => f.key);
    // "write" only makes sense when we have stroke data for the whole word.
    if (card && !(HW_OK && wordWritable(card.hanzi))) enabled = enabled.filter(k => k !== "write");
    // "sentence" only when this word actually appears in a dialogue sentence.
    if (card && !sentencesFor(card).length) enabled = enabled.filter(k => k !== "sentence");
    // The ladder, easy to hard, in a MIXED session. A word you have never got
    // right is recognised (meaning from the characters, or from the sound).
    // Once right, you produce it with support (pick the characters, the pinyin,
    // or build a sentence). Only a word that has held up in a later session
    // is written or spoken. A single-skill practice is always honoured.
    if (card && (scopeFocuses || selectedFocuses).size > 1) {
      const s = srs[card.id], reps = s ? (s.reps || 0) : 0;
      // a word learnt before this ladder existed (it has a long interval but
      // few counted reviews) is treated as known
      const level = reps >= 2 || (s && (s.interval || 0) >= 7) ? 2 : reps >= 1 ? 1 : 0;
      const rung = level === 0 ? ["recognize", "listen"] : level === 1 ? ["recall", "pinyin", "sentence", "listen"] : null;
      if (rung) {
        let on = enabled.filter(k => rung.includes(k));
        // the second meeting in a session asks it a different way from the first
        const before = dirByCard[card.id];
        if (before && on.length > 1) on = on.filter(k => k !== before);
        if (on.length) enabled = on;
        else { const eased = enabled.filter(k => k !== "write" && k !== "speak"); if (eased.length) enabled = eased; }
      }
    }
    if (enabled.length === 0) enabled = ["recognize"];
    // vary the exercise type: never the same one twice running when there is a choice
    if (enabled.length > 1 && lastDir) { const alt = enabled.filter(k => k !== lastDir); if (alt.length) enabled = alt; }
    lastDir = enabled[Math.floor(Math.random() * enabled.length)];
    if (card) dirByCard[card.id] = lastDir;
    return lastDir;
  }
  let lastDir = null, sessionStart = 0, dirByCard = {};
  function missedDirPossible(card, d) {
    if (d === "write") return HW_OK && wordWritable(card.hanzi);
    if (d === "sentence") return sentencesFor(card).length > 0;
    return FOCUSES.some(f => f.key === d);
  }

  function buildStudyQueue() {
    const focusSet = scopeFocuses || selectedFocuses;
    let cards = activeCards();
    // A sentence-only session only makes sense for words that appear in one.
    if (focusSet.size === 1 && focusSet.has("sentence")) {
      const withSent = cards.filter(c => sentencesFor(c).length);
      if (withSent.length) cards = withSent;
    }
    const due = cards.filter(c => { const s = srs[c.id]; return !s || s.due <= NOW(); });
    // New words come a few at a time: at most NEW_PER_SESSION, in even
    // batches (15 new words is 5, 5, 5), in the book's order, with a few
    // words you already know mixed in to review, Duolingo-style.
    const fresh = due.filter(c => !srs[c.id]);
    if (fresh.length && !(focusSet.size === 1 && (focusSet.has("write") || focusSet.has("speak")))) {
      const order = new Map(CARDS.map((c, i) => [c.id, i]));
      fresh.sort((a, b) => order.get(a.id) - order.get(b.id));
      const n = fresh.length > NEW_PER_SESSION ? Math.ceil(fresh.length / Math.ceil(fresh.length / NEW_PER_SESSION)) : fresh.length;
      const picked = fresh.slice(0, n), ids = new Set(picked.map(c => c.id));
      const scope = new Set(cards.map(c => c.id));
      // review: this lesson's words that are due, then any due word from lessons
      // you have reached, then this lesson's words met in an earlier batch
      const reviews = [];
      const addFrom = list => shuffle(list).forEach(c => { if (reviews.length < REVIEW_PER_SESSION && !ids.has(c.id) && !reviews.includes(c)) reviews.push(c); });
      addFrom(due.filter(c => srs[c.id]));
      if (!reviewMode) addFrom(dueReviewCards().filter(c => !scope.has(c.id)));
      addFrom(cards.filter(c => srs[c.id] && (srs[c.id].reps || 0) >= 1));
      return picked.concat(reviews);
    }
    // If nothing is due, review everything (a manual refresher session).
    const pool = due.length ? due : cards;
    const q = shuffle(pool);
    // A session is short and fixed: about a dozen words, three minutes. A
    // bigger pool comes in even batches (15 words is 8 then 7, never 12 then
    // 3); the rest is picked up next time.
    const n = pool.length > SESSION_LEN ? Math.ceil(pool.length / Math.ceil(pool.length / SESSION_LEN)) : pool.length;
    return q.slice(0, n);
  }

  let sessionTotal = 0;
  let studySource = [];       // the unique cards this session was built from (for "Practice again")
  let clearedIds = new Set(); // cards answered correctly (a card is "cleared" once right)
  let stepsDone = 0;          // exercises answered right this session (a new word has two)
  let studyAnswered = false;  // has the current card been answered yet?

  // Start (or restart) a study session over a given set of cards.
  function beginStudySession(cards, opts = {}) {
    mistakesMode = !!opts.mistakes; sessionMistakes = 0; sessionFixed = 0;
    studySource = cards.slice();
    queue = sessionOrder(cards);
    clearedIds = new Set(); stepsDone = 0;
    studyStats = { answered: 0, again: 0, learned: 0 };
    sessionXP = 0; combo = 0; lastDir = null; dirByCard = {}; sessionStart = Date.now();
    sessionTotal = queue.filter(x => !x.meet).length;
    $("#studyTitle").textContent = "Study";
    show("study");
    renderCombo(); renderBoost();
    updateStudyProgress();
    nextStudyCard();
  }
  /* The order of a session that teaches new words: meet two or three, practise
     them straight away (the easy rung), a word you know, then the group before
     comes back a rung harder, so each new word is seen twice with a gap
     between. Sessions with no new words are simply shuffled. */
  function sessionOrder(cards) {
    const orderIx = new Map(CARDS.map((c, i) => [c.id, i]));
    const fresh = cards.filter(c => !srs[c.id]).sort((a, b) => orderIx.get(a.id) - orderIx.get(b.id));
    const known = shuffle(cards.filter(c => srs[c.id]));
    if (!fresh.length) return shuffle(cards.slice());
    const groups = [], k = Math.ceil(fresh.length / MEET_GROUP), size = Math.ceil(fresh.length / k);
    for (let i = 0; i < fresh.length; i += size) groups.push(fresh.slice(i, i + size));
    const out = [];
    const review = () => { if (known.length) out.push(known.shift()); };
    groups.forEach((g, gi) => {
      out.push({ meet: g, first: gi === 0, left: fresh.length - groups.slice(0, gi).flat().length });
      shuffle(g).forEach(c => out.push(c));
      review();
      if (gi > 0) { shuffle(groups[gi - 1]).forEach(c => out.push(c)); review(); }
    });
    shuffle(groups[groups.length - 1]).forEach(c => out.push(c));
    while (known.length) review();
    return out;
  }
  function startStudy() { beginStudySession(buildStudyQueue()); }

  // "Meet the new words" preview — shown once per session, before the first quiz
  // card, whenever the session brings in words never studied before. Beginners
  // get to SEE and HEAR a word before being asked to recall it.
  function meetNewWords(cards, done, info = {}) {
    curCard = null; studyAnswered = true;
    $("#promptLabel").textContent = "New words";
    $("#studyChoices").classList.add("hidden");
    $("#studyContinueWrap").classList.add("hidden");
    $("#studyReveal").classList.add("hidden");
    $("#studyNext").classList.add("hidden");
    // Cap the preview so a large mixed session never dumps a wall of words to
    // "meet" — you'll still meet the rest as they first come up in practice.
    const MAX_MEET = 15;
    const shown = cards.slice(0, MAX_MEET);
    const more = cards.length - shown.length;
    const face = $("#studyFace");
    face.innerHTML = "";
    face.style.justifyContent = "flex-start";
    const later = info.left != null ? info.left - shown.length : more;
    face.appendChild(newBadge());
    face.appendChild(el("div", { className: "meet-intro" },
      (shown.length === 1 ? "A new word. Tap the speaker to hear it, then practise it."
        : `${shown.length === 2 ? "Two" : shown.length === 3 ? "Three" : shown.length} new words. Tap each speaker to hear it, then practise them.`) +
      (later > 0 ? ` ${later} more come${later === 1 ? "s" : ""} later in this session.` : "")));
    // If every new word is from one lesson and it has a pattern note, teach it
    // with the first group.
    const lid = info.first !== false && cards.length && cards.every(c => c.lessonId === cards[0].lessonId) ? cards[0].lessonId : null;
    const note = lid && notesFor(lid)[0];
    if (note) face.appendChild(el("div", { className: "lnote" }, [
      el("div", { className: "lnote-t" }, [licon("i-bulb", "licon-sm"), document.createTextNode(" " + note.title)]),
      el("div", { className: "lnote-b" }, note.body)
    ]));
    const list = el("div", { className: "meet-list" });
    shown.forEach(c => {
      const row = el("div", { className: "meet-row" });
      const info = el("div", { className: "meet-info" }, [
        el("div", { className: "meet-py" }, pySpans(c.pinyin)),
        el("div", { className: "meet-en" }, c.en)
      ]);
      // how each character is built: 好 = 女 woman + 子 child
      [...c.hanzi].filter(ch => isHan(ch) && CHD.chars[ch] && (CHD.chars[ch].c || []).length > 1).slice(0, 3).forEach(ch => {
        const line = el("div", { className: "meet-parts" }, [el("b", { className: "chz", }, ch), " = "]);
        line.firstChild.dataset.ch = ch;
        CHD.chars[ch].c.forEach(([comp, role], i) => {
          if (i) line.appendChild(document.createTextNode(" + "));
          const p = CHD.parts[comp] || (CHD.chars[comp] ? [charEn(comp), charPy(comp)] : null);
          line.appendChild(el("span", { className: "mp-c" + (role === "s" ? " snd" : "") }, comp));
          if (p && p[0]) line.appendChild(document.createTextNode(" " + (role === "s" ? p[1] : p[0])));
        });
        info.appendChild(line);
      });
      row.append(el("div", { className: "meet-hz" }, hzSpans(c.hanzi, c.pinyin, true)), info, speakerBtn(c.hanzi));
      list.appendChild(row);
    });
    face.appendChild(list);
    const start = el("button", { className: "study-start", type: "button" }, shown.length === 1 ? "Practise it →" : "Practise them →");
    start.addEventListener("click", done);
    face.appendChild(start);
  }

  let curCard = null, curDir = null;

  function nextStudyCard() {
    if (queue.length === 0) return finishStudy();
    const item = queue.shift();
    if (item && item.meet) { meetNewWords(item.meet, () => nextStudyCard(), item); return; }
    curCard = item;
    curDir = pickDirection(curCard);
    studyAnswered = false;
    renderStudyCard();
  }

  let lastCleared = 0;
  function updateStudyProgress() {
    const done = Math.min(stepsDone, sessionTotal);
    $("#studyBar").style.width = `${(done / Math.max(sessionTotal, 1)) * 100}%`;
    $("#studyCounter").textContent = `${done} / ${sessionTotal}`;
    if (done > lastCleared) pulseBar($("#studyBar"));
    lastCleared = done;
  }
  // A light sweeps along the bar each time it grows.
  function pulseBar(bar) {
    const p = bar && bar.parentElement; if (!p) return;
    p.classList.remove("pulse"); void p.offsetWidth; p.classList.add("pulse");
  }
  // Short taps on the phone: one for right, a double for wrong. Silently
  // ignored where the browser has no vibration (iOS Safari).
  function buzz(correct) { try { if (navigator.vibrate) navigator.vibrate(correct ? 25 : [45, 40, 45]); } catch (e) {} }
  // The combo chip in the study and quiz bars: appears from three in a row,
  // and turns gold once each answer is worth more.
  function renderCombo() {
    document.querySelectorAll(".combo-chip").forEach(ch => {
      ch.classList.toggle("hidden", combo < 3);
      ch.classList.toggle("hot", combo >= COMBO_AT);
      ch.innerHTML = `${svgUse("i-flame-solid")}<b>${combo}</b>`;
      ch.classList.remove("bump"); void ch.offsetWidth; ch.classList.add("bump");
    });
  }
  // Double-XP: a pill on the home screen and in the study bars while it runs.
  let boostTimer = null;
  function renderBoost() {
    const left = boostLeft(), on = left > 0;
    const mm = Math.floor(left / 60000), ss = Math.floor((left % 60000) / 1000);
    document.querySelectorAll(".boost-pill").forEach(p => {
      p.classList.toggle("hidden", !on);
      p.innerHTML = on ? `<b>2×</b> XP · ${mm}:${String(ss).padStart(2, "0")}` : "";
    });
    clearTimeout(boostTimer);
    if (on) boostTimer = setTimeout(renderBoost, 1000);
  }
  function renderDoneNotes(perfect, lesson) {
    const box = $("#doneNotes"); if (!box) return;
    box.innerHTML = "";
    if (perfect) box.appendChild(el("div", { className: "done-note gold" }, `Perfect! No mistakes, +${XP.perfect} XP`));
    if (lesson) box.appendChild(el("div", { className: "done-note boost" }, `Lesson done: double XP for the next 15 minutes`));
    if (sessionFixed) box.appendChild(el("div", { className: "done-note fixed" }, `${sessionFixed} mistake${sessionFixed === 1 ? "" : "s"} fixed`));
    else if (sessionMistakes && !mistakesMode) box.appendChild(el("div", { className: "done-note miss" },
      `${sessionMistakes} mistake${sessionMistakes === 1 ? "" : "s"} saved to practise in Fix your mistakes`));
    else if (boostOn()) box.appendChild(el("div", { className: "done-note boost" }, `Double XP is on`));
  }

  // Record the outcome of the current card: correct = cleared & advances the SRS;
  // wrong = shown the answer, SRS reset, and requeued to come back later this session.
  function answerStudy(correct) {
    if (studyAnswered) return;
    studyAnswered = true;
    sfx(correct ? "correct" : "wrong"); buzz(correct);
    const wasNew = !srs[curCard.id];
    schedule(curCard.id, correct ? "good" : "again");
    // "Mastered" requires you to have PRODUCED the word, not just recognised it:
    // mark a production pass when you get a recall / write / speak card right.
    if (correct && srs[curCard.id] && !srs[curCard.id].known) { srs[curCard.id].known = true; saveSRS(srs); }
    const sEntry = srs[curCard.id];
    if (sEntry && !correct) { sEntry.miss = { d: curDir, at: NOW(), s: sessionStart }; sessionMistakes++; saveSRS(srs); }
    else if (sEntry && correct && sEntry.miss && (mistakesMode || sEntry.miss.s !== sessionStart)) { delete sEntry.miss; sessionFixed++; saveSRS(srs); }
    if (correct && srs[curCard.id] && PRODUCTION_DIRS.has(curDir)) {
      srs[curCard.id].prod = true;
      saveSRS(srs);
    }
    recordReview(1);
    answerXP(correct);
    questEvent(curDir, correct);
    studyStats.answered += 1;
    if (correct) {
      stepsDone += 1;
      if (!clearedIds.has(curCard.id)) { clearedIds.add(curCard.id); if (wasNew) studyStats.learned += 1; }
    } else {
      studyStats.again += 1;
      queue.push(curCard);   // comes back later this session
    }
    updateStudyProgress();
  }

  const DIR_LABEL = {
    recognize: "Character → meaning",
    recall: "English → characters",
    pinyin: "Read the pinyin",
    listen: "Listen",
    write: "Trace, then write it",
    speak: "Say it out loud"
  };
  // Locks/unlocks the advance buttons (write mode until it's written, sentence
  // mode until at least one tile is placed).
  function setWriteGate(enabled) {
    $("#studyNext").disabled = !enabled;
    $("#studyContinue").disabled = !enabled;
  }
  function setContinueLabel(txt) { $("#studyContinue").firstChild.textContent = txt + " "; }
  // When set, the pinned button checks the answer first instead of advancing.
  let studyCheckFn = null;

  let writeWriters = [];   // active Hanzi Writer instances in study "write" mode
  let writeInk = null;     // freehand tracing canvas for the write copybook
  let writeCharIdx = 0;    // phone: which character of the word we're on
  let writeNextFn = null;  // phone: advances to the next character (pinned button)
  const isPhone = () => window.matchMedia("(max-width: 560px)").matches;

  // Build a mascot + prompt bubble into `face`; returns the bubble to fill.
  // Chat-style: one squared corner toward the dragon (no fragile pointy tail).
  /* ---- Tap-a-word hints and new-word highlights (Duolingo-style) --------
     Any word marked .hintable shows its English and pinyin in a small bubble
     when tapped, and says it. A word you have never got right is "new": it
     wears a NEW WORD tag and a highlight until you do. */
  const WORD_EN = {};
  CARDS.forEach(c => { if (!WORD_EN[c.hanzi]) WORD_EN[c.hanzi] = c.en; });
  function wordMeaning(h) {
    if (WORD_EN[h]) return WORD_EN[h];
    const han = [...h].filter(isHan);
    if (han.length > 1) {
      // a compound the lessons don't list as a word: build it from its parts
      for (let k = han.length - 1; k > 0; k--) {
        const a = han.slice(0, k).join(""), b = han.slice(k).join("");
        if (WORD_EN[a] && (WORD_EN[b] || charEn(b))) return `${WORD_EN[a]} + ${WORD_EN[b] || charEn(b)}`;
      }
    }
    return han.map(ch => charEn(ch)).filter(Boolean).join(" + ");
  }
  const isNewCard = c => {
    const s = c && srs[c.id];
    return !s || (!(s.reps >= 1) && !s.known && !((s.lapses || 0) >= 2) && !((s.interval || 0) > 0));
  };
  const NEW_CARD_BY_HANZI = h => CARDS.find(c => c.hanzi === h);
  function newBadge() { return el("div", { className: "new-badge-row" }, el("span", { className: "new-badge" }, "New word")); }
  let hintEl = null, hintFor = null;
  function closeHint() {
    if (hintEl) hintEl.remove();
    if (hintFor) hintFor.classList.remove("open");
    hintEl = hintFor = null;
  }
  function showHint(anchor, h, p, rev) {
    closeHint();
    if (!h) {                             // no Chinese word for this one
      hintEl = el("div", { className: "word-hint note", role: "tooltip" }, [el("div", { className: "wh-e" }, "No separate word in Chinese")]);
      document.body.appendChild(hintEl);
      const r = anchor.getBoundingClientRect(), b = hintEl.getBoundingClientRect();
      const left = Math.max(8, Math.min(innerWidth - b.width - 8, r.left + r.width / 2 - b.width / 2));
      let top = r.top - b.height - 10; if (top < 8) { top = r.bottom + 10; hintEl.classList.add("below"); }
      hintEl.style.left = left + "px"; hintEl.style.top = top + "px"; hintEl.style.setProperty("--ax", (r.left + r.width / 2 - left) + "px");
      anchor.classList.add("open"); hintFor = anchor;
      return;
    }
    const e = wordMeaning(h);
    hintEl = el("div", { className: "word-hint" + (rev ? " rev" : ""), role: "tooltip" }, rev ? [
      el("div", { className: "wh-h" }, hzSpans(h, p || PINYIN_BY_HANZI[h] || "", false)),
      el("div", { className: "wh-p" }, pySpans(p || PINYIN_BY_HANZI[h] || ""))
    ] : [
      el("div", { className: "wh-e" }, e || "No meaning listed yet"),
      el("div", { className: "wh-p" }, pySpans(p || PINYIN_BY_HANZI[h] || ""))
    ]);
    document.body.appendChild(hintEl);
    const r = anchor.getBoundingClientRect(), b = hintEl.getBoundingClientRect();
    const left = Math.max(8, Math.min(innerWidth - b.width - 8, r.left + r.width / 2 - b.width / 2));
    let top = r.top - b.height - 10;
    if (top < 8) { top = r.bottom + 10; hintEl.classList.add("below"); }
    hintEl.style.left = left + "px"; hintEl.style.top = top + "px";
    hintEl.style.setProperty("--ax", (r.left + r.width / 2 - left) + "px");
    anchor.classList.add("open"); hintFor = anchor;
    speak(h);
    try { localStorage.setItem("zhBeginnerA.hintUsed.v1", "1"); } catch (err) {}
  }
  function hintable(node, h, p, rev) {
    node.classList.add("hintable");
    node.setAttribute("role", "button");
    node.addEventListener("click", ev => {
      ev.stopPropagation();
      if (hintFor === node) closeHint(); else showHint(node, h, p, rev);
    });
    return node;
  }
  /* English -> Chinese hints. Each English word of a sentence is matched to the
     Chinese word in the same sentence whose meaning contains it (plurals, -ing,
     -ed and "n't" folded). Filler words match nothing, and only matched words
     are tappable, so a hint is never a guess. */
  const EN_FILLER = new Set(["the", "a", "an", "to", "of", "is", "are", "am", "be", "it", "its", "that", "this", "and", "or", "for", "in", "on", "at", "with", "some", "do", "does", "did"]);
  const enStem = w => {
    w = w.toLowerCase().replace(/[’']/g, "'").replace(/[^a-z']/g, "");
    if (w.endsWith("n't")) return "not";
    w = w.replace(/'(s|m|re|ll|d|ve)$/, "");
    if (w.length > 4 && w.endsWith("ies")) return w.slice(0, -3) + "y";
    if (w.length > 5 && w.endsWith("ing")) return w.slice(0, -3);
    if (w.length > 4 && w.endsWith("ed")) return w.slice(0, -2);
    if (w.length > 3 && w.endsWith("s") && !w.endsWith("ss")) return w.slice(0, -1);
    return w;
  };
  function englishHints(en, words) {
    const pools = words.map(w => {
      const m = WORD_EN[w.hanzi] || wordMeaning(w.hanzi) || "";
      return { w, stems: new Set(m.replace(/\([^)]*\)/g, " ").split(/[^A-Za-z']+/).map(enStem).filter(s => s && !EN_FILLER.has(s))) };
    });
    // I / me / my all point at 我, you / your at 你, yes at 对 or 是
    const alias = { me: ["i"], my: ["i"], mine: ["i"], your: ["you"], yours: ["you"], yes: ["yes", "right", "correct"],
      ok: ["good", "okay"], okay: ["good", "okay"], hi: ["hello"], bye: ["goodbye", "bye"], thank: ["thank"], thanks: ["thank"] };
    const keysFor = st => {
      const ks = alias[st] ? alias[st].slice() : [st];
      if (st.length > 4 && st.endsWith("er")) {              // cheaper, colder, faster, bigger
        const base = st.slice(0, -2); ks.push(base, base + "e");
        if (/(.)\1$/.test(base)) ks.push(base.slice(0, -1));
        if (base.endsWith("i")) ks.push(base.slice(0, -1) + "y");
      }
      return ks;
    };
    const find = ks => {
      for (const k of ks) { const hit = pools.find(p => p.stems.has(k)); if (hit) return hit; }
      // "plane" inside "aeroplane", "phone" inside "telephone"
      for (const k of ks) if (k.length >= 4) { const hit = pools.find(p => [...p.stems].some(s => s.length > k.length && s.endsWith(k))); if (hit) return hit; }
      return null;
    };
    return en.split(/(\s+)/).map(tok => {
      if (!tok.trim()) return { text: tok };
      const st = enStem(tok);
      if (!st) return { text: tok };
      const hit = EN_FILLER.has(st) && !alias[st] ? null : find(keysFor(st));
      return hit ? { text: tok, word: hit.w } : { text: tok, none: true };
    });
  }
  document.addEventListener("pointerdown", ev => { if (hintEl && !ev.target.closest(".word-hint, .hintable")) closeHint(); }, true);
  window.addEventListener("scroll", closeHint, true);
  window.addEventListener("resize", closeHint);
  // a one-line nudge until the learner has used a hint once
  const hintTip = () => { try { return !localStorage.getItem("zhBeginnerA.hintUsed.v1"); } catch (e) { return false; } };

  function mascotSpeech(face, src) {
    const speech = el("div", { className: "mascot-prompt" });
    speech.appendChild(el("img", { className: "quiz-dragon", src: src || "images/path/panda-teacher.webp?v=218", alt: "" }));
    const bubble = el("div", { className: "q-bubble" });
    speech.appendChild(bubble);
    face.appendChild(speech);
    return bubble;
  }

  // Duolingo-style sentence builder: tap word tiles to assemble the translation.
  // Two directions, picked at random:
  //   cn2en - bubble shows the 汉字 (+audio), tiles are English words
  //   en2cn - bubble shows the English, tiles are 汉字 with pinyin underneath
  // Sets studyCheckFn so the pinned button acts as "Check" then "Continue".
  let devSentence = null, devEn2cn = null;     // localhost testing only: force a sentence and a direction
  function buildSentenceExercise(face, host, sent, labelEl, onResult) {
    // Translating to English needs ≥2 English words, or it's a 1-tile giveaway
    // (e.g. 再见！→ "Goodbye!"); fall back to building the Chinese instead.
    const en2cn = devEn2cn !== null ? devEn2cn : (enWords(sent.en).length < 2 || Math.random() < 0.5);
    face.innerHTML = "";
    face.classList.add("sent");
    host.innerHTML = "";
    host.classList.add("sentence-mode"); host.classList.remove("long");
    $("#studyContinueWrap").classList.add("wide");
    const bubble = mascotSpeech(face);
    // A long sentence gets the whole width: the mascot steps up out of the way
    // and the bubble runs edge to edge, so the words wrap into two lines, not four.
    const longSentence = sent.words.length > 6 || enWords(sent.en).length > 7;
    if (longSentence) { bubble.parentElement.classList.add("long"); bubble.parentElement.classList.toggle("en2cn", en2cn); host.classList.add("long"); }
    // fewer distractors on a long one, so the bank stays in view
    const nDistract = longSentence ? 2 : 3;

    let target, tiles, answerDisplay;
    bubble.classList.add("sent");
    if (en2cn) {
      labelEl.textContent = "Build the Chinese";
      const enLine = el("div", { className: "en en-hints" });
      englishHints(sent.en, sent.words).forEach(t => {
        if (!t.word && !t.none) { enLine.appendChild(document.createTextNode(t.text)); return; }
        // the underline covers the word, not the punctuation after it
        const [, lead, core, tail] = /^([“"‘(—]*)(.*?)([.,!?;:—”"’)]*)$/.exec(t.text);
        if (lead) enLine.appendChild(document.createTextNode(lead));
        enLine.appendChild(t.word ? hintable(el("span", { className: "ew" }, core), t.word.hanzi, t.word.pinyin, true)
          : hintable(el("span", { className: "ew none" }, core), null, null, true));
        if (tail) enLine.appendChild(document.createTextNode(tail));
      });
      bubble.appendChild(enLine);
      if (hintTip()) face.appendChild(el("div", { className: "hint-tip" }, "Tap a word for the Chinese, or hold a tile"));
      target = sent.words.map(w => w.hanzi);
      tiles = sent.words.map(w => ({ val: w.hanzi, hanzi: w.hanzi, pinyin: w.pinyin }));
      answerDisplay = sent.hanzi;
      const pool = SENTENCES.filter(s => s !== sent).flatMap(s => s.words)
        .filter(w => !target.includes(w.hanzi));
      sample(pool, nDistract).forEach(w => tiles.push({ val: w.hanzi, hanzi: w.hanzi, pinyin: w.pinyin }));
    } else {
      labelEl.textContent = "Translate this sentence";
      // The sentence reads across the bubble, each word with its pinyin above.
      // With pinyin turned off the readings stay hidden until the bubble is tapped.
      bubble.appendChild(speakerBtn(sent.hanzi));
      let anyNew = false;
      sent.words.forEach(w => {
        const card = NEW_CARD_BY_HANZI(w.hanzi), fresh = !!card && isNewCard(card);
        if (fresh) anyNew = true;
        bubble.appendChild(hintable(el("span", { className: "sw" + (fresh ? " new" : "") }, [
          el("span", { className: "py" }, pySpans(w.pinyin)),
          el("span", { className: "hz" }, hzSpans(w.hanzi, w.pinyin, false))
        ]), w.hanzi, w.pinyin));
      });
      if (anyNew) bubble.insertBefore(newBadge(), bubble.firstChild);
      if (hintTip()) face.appendChild(el("div", { className: "hint-tip" }, "Tap any word for its meaning, or hold a tile"));
      const tail = sent.hanzi.slice(-1);
      if (/[。？！，、]/.test(tail)) {
        // the mark stays glued to the last word rather than wrapping onto a line of its own
        const last = bubble.lastElementChild, group = el("span", { className: "swg" });
        bubble.insertBefore(group, last); group.appendChild(last);
        group.appendChild(el("span", { className: "sw punct" }, [el("span", { className: "py" }, ""), el("span", { className: "hz" }, tail)]));
      }
      if (!showPinyin()) {
        bubble.classList.add("nopy");
        bubble.addEventListener("click", () => bubble.classList.remove("nopy"), { once: true });
      }
      target = enWords(sent.en);
      tiles = target.map(w => ({ val: w, text: w }));
      answerDisplay = sent.en;
      const pool = SENTENCES.filter(s => s !== sent).flatMap(s => enWords(s.en))
        .filter(w => !target.includes(w));
      sample([...new Set(pool)], nDistract).forEach(w => tiles.push({ val: w, text: w }));
    }

    const answer = el("div", { className: "sent-answer " + (en2cn ? "han" : "txt") });
    // ruled lines for about as many rows as the answer will need (five or six tiles a line)
    answer.style.setProperty("--rows", String(Math.max(2, Math.ceil(target.length / (en2cn ? 6 : 5)))));
    const bank = el("div", { className: "sent-bank" });
    host.append(answer, bank);

    // A tile slides from where it was to where it lands; its bank slot stays
    // behind as a ghost so nothing else shuffles about.
    const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const settleFrom = (tile, a) => {
      if (calm) return;
      const b = tile.getBoundingClientRect();
      const dx = a.left - b.left, dy = a.top - b.top;
      if (!dx && !dy) return;
      // Start it where it was, force that to lay out, then let it travel. A
      // forced reflow rather than a frame callback, so a hidden tab (which
      // never gets frames) still ends with the tile where it belongs.
      tile.style.transition = "none";
      tile.style.transform = `translate(${dx}px, ${dy}px)`;
      void tile.offsetWidth;
      tile.style.transition = "transform .22s cubic-bezier(.2,.8,.3,1)";
      tile.style.transform = "";
      tile.addEventListener("transitionend", () => { tile.style.transition = ""; }, { once: true });
    };
    const glide = (tile, to) => { const a = tile.getBoundingClientRect(); to.appendChild(tile); settleFrom(tile, a); };
    const placed = () => [...answer.querySelectorAll(".tile")];
    const refreshGate = () => setWriteGate(placed().length > 0);
    shuffle(tiles).forEach(item => {
      const t = el("button", { className: "tile" });
      t.dataset.val = item.val;
      if (item.pinyin) {
        t.appendChild(el("span", { className: "t-han" }, hzSpans(item.hanzi, item.pinyin, false)));
        t.appendChild(el("span", { className: "t-py" }, pySpans(item.pinyin)));
      } else t.textContent = item.text;
      const slot = el("div", { className: "slot" });
      slot.appendChild(t);
      bank.appendChild(slot);
      // The ghost takes the tile's painted size, read from the slot itself
      // (which is exactly the tile) so no pressed or stretched state leaks in.
      const ghost = () => {
        const r = slot.getBoundingClientRect();
        slot.style.width = r.width.toFixed(1) + "px"; slot.style.height = r.height.toFixed(1) + "px";
        slot.classList.add("empty");
      };
      const toBank = (animate) => {
        const cell = t.parentElement;
        slot.classList.remove("empty");
        if (animate) glide(t, slot); else slot.appendChild(t);
        if (cell !== slot) cell.remove();
      };
      // A tap moves the tile between the bank and the end of the answer.
      const toggle = () => {
        if (t.parentElement === slot) {
          ghost();
          const cell = el("div", { className: "cell" });
          answer.appendChild(cell);
          glide(t, cell);
        } else toBank(true);
        refreshGate();
      };
      // A drag carries the tile, and its place among the answer's tiles follows
      // the finger, so the order can be fixed without taking tiles out again.
      let press = null;
      // Holding a tile shows what it means without moving it; a tap still places it.
      const tileHint = () => {
        if (item.hanzi) return showHint(t, item.hanzi, item.pinyin, false);
        const m = englishHints(item.text, sent.words)[0];
        showHint(t, m && m.word ? m.word.hanzi : null, m && m.word ? m.word.pinyin : null, true);
      };
      t.addEventListener("pointerdown", ev => {
        if (studyAnswered || t.disabled) return;
        const r = t.getBoundingClientRect();
        press = { x: ev.clientX, y: ev.clientY, offX: ev.clientX - r.left, offY: ev.clientY - r.top, moved: false, hinted: false };
        press.timer = setTimeout(() => { if (press && !press.moved) { press.hinted = true; tileHint(); } }, 450);
        try { t.setPointerCapture(ev.pointerId); } catch (e) {}
      });
      t.addEventListener("contextmenu", ev => ev.preventDefault());
      t.addEventListener("pointermove", ev => {
        if (!press) return;
        if (!press.moved) {
          if (Math.hypot(ev.clientX - press.x, ev.clientY - press.y) < 6) return;
          clearTimeout(press.timer); closeHint();
          press.moved = true;
          t.classList.add("lift");
          if (t.parentElement === slot) {                 // lifted out of the bank
            ghost();
            const cell = el("div", { className: "cell" });
            answer.appendChild(cell); cell.appendChild(t);
          }
        }
        const cell = t.parentElement;
        let before = null;
        for (const c of answer.querySelectorAll(".cell")) {
          if (c === cell) continue;
          const r = c.getBoundingClientRect();
          if (ev.clientY < r.top || (ev.clientY <= r.bottom && ev.clientX < r.left + r.width / 2)) { before = c; break; }
        }
        if (before ? cell.nextElementSibling !== before : answer.lastElementChild !== cell) answer.insertBefore(cell, before);
        const r = cell.getBoundingClientRect();
        t.style.transition = "none";
        t.style.transform = `translate(${(ev.clientX - press.offX - r.left).toFixed(1)}px, ${(ev.clientY - press.offY - r.top).toFixed(1)}px)`;
      });
      const release = ev => {
        if (!press) return;
        const p = press; press = null;
        clearTimeout(p.timer);
        t.classList.remove("lift");
        if (p.hinted) { setTimeout(closeHint, 1400); return; }   // it was a hold: leave the tile where it is
        if (!p.moved) { toggle(); return; }
        // Where it was let go: below the answer's lines means back to the bank.
        const was = t.getBoundingClientRect();
        t.style.transform = ""; t.style.transition = "";
        const a = answer.getBoundingClientRect();
        if (ev.type === "pointercancel" || ev.clientY > a.bottom + 24) toBank(false);
        settleFrom(t, was);
        refreshGate();
      };
      t.addEventListener("pointerup", release);
      t.addEventListener("pointercancel", release);
    });
    refreshGate();
    setContinueLabel("Check");

    studyCheckFn = () => {
      const got = placed().map(t => t.dataset.val);
      const same = (x, y) => x.length === y.length && x.every((v, i) => v === y[i]);
      // Building the Chinese: any accepted word order counts, not only the stored one.
      const orders = en2cn ? acceptedOrders(sent) : [target];
      const hit = orders.find(o => same(got, o));
      const correct = !!hit;
      answer.classList.add(correct ? "ok" : "bad");
      host.querySelectorAll(".tile").forEach(t => t.disabled = true);
      // Feedback sits under the bank, never on the mascot.
      const fb = el("div", { className: "sent-fb " + (correct ? "ok" : "bad") });
      fb.innerHTML = `<svg class="licon"><use href="#${correct ? "i-tick" : "i-x"}"/></svg>`;
      const body = el("div");
      body.appendChild(el("div", { className: "fb-t" }, correct ? "Nicely done!" : "Correct solution:"));
      if (!correct) {
        body.appendChild(el("div", { className: "fb-a" }, answerDisplay));
        if (en2cn) body.appendChild(el("div", { className: "fb-py" }, prettyPinyin(sent.pinyin)));
      }
      // Show the other orders that would also have been right, so a swap
      // learnt one way is seen the other way too.
      const shown = !en2cn ? [] : correct ? orders.filter(o => o !== hit) : orders.slice(1);
      if (shown.length) {
        body.appendChild(el("div", { className: "fb-also" }, correct ? "Also correct:" : "Also accepted:"));
        shown.forEach(o => {
          body.appendChild(el("div", { className: "fb-a" }, o.join("") + tailPunct(sent.hanzi)));
          body.appendChild(el("div", { className: "fb-py" }, prettyPinyin(pinyinFor(sent, o))));
        });
      }
      fb.appendChild(body);
      // The result rides with the Continue button, pinned at the bottom, so it
      // is always in view however long the word bank is.
      const wrapEl = $("#studyContinueWrap");
      wrapEl.insertBefore(fb, wrapEl.firstChild);
      wrapEl.classList.add(correct ? "ok" : "bad");
      const drg = face.querySelector(".quiz-dragon");
      if (drg) { drg.src = correct ? "images/path/panda-celebrate.webp?v=218" : "images/path/panda-sad.webp?v=218"; drg.classList.add("react"); }
      onResult(correct);
      setContinueLabel("Continue");
      setWriteGate(true);
    };
  }

  // Objective multiple-choice exercise (Duolingo-style). Builds the mascot prompt
  // into `face` and answer buttons into `choicesBox`; the dragon reacts and the
  // correct answer is revealed on a wrong pick. Calls onResult(correct) once.
  // Shared by Study and Quiz.
  // ---- Tone-aware distractors -----------------------------------------
  // Same base letters, different tone marks — so the "pinyin" drill actually
  // tests tone instead of letting you pick the answer by its consonants/vowels.
  const TONE_VOWELS = {
    a: ["ā", "á", "ǎ", "à"], e: ["ē", "é", "ě", "è"], i: ["ī", "í", "ǐ", "ì"],
    o: ["ō", "ó", "ǒ", "ò"], u: ["ū", "ú", "ǔ", "ù"], "ü": ["ǖ", "ǘ", "ǚ", "ǜ"]
  };
  const TONE_DECODE = {};   // toned char -> [baseVowel, toneIndex 0..3]
  Object.entries(TONE_VOWELS).forEach(([base, arr]) =>
    arr.forEach((ch, i) => { TONE_DECODE[ch] = [base, i]; }));
  const tonelessPinyin = py => [...(py || "")].map(ch => TONE_DECODE[ch] ? TONE_DECODE[ch][0] : ch).join("");

  // ---- Readable pinyin ---------------------------------------------------
  // The data joins syllables within a word ("láizì") — standard orthography, and
  // it drives the word-level sentence tiles. But joined compounds are hard for a
  // beginner to read, so for DISPLAY we split them back into syllables ("lái zì").
  // Display-only: the data (and the tile grouping) is never touched. Validated to
  // round-trip exactly on every pinyin string in the app; anything it can't
  // segment is left exactly as-is.
  const PY_SYL = (() => {
    const initials = ["","b","p","m","f","d","t","n","l","g","k","h","j","q","x","zh","ch","sh","r","z","c","s","y","w"];
    const finals = ["a","o","e","ê","ai","ei","ao","ou","an","en","ang","eng","ong","er",
      "i","ia","ie","iao","iu","ian","in","iang","ing","iong",
      "u","ua","uo","uai","ui","uan","un","uang","ueng",
      "ü","üe","üan","ün","v","ve","van","vn"];
    const set = new Set();
    for (const ini of initials) for (const fin of finals) set.add(ini + fin);
    ["a","o","e","ê","ai","ei","ao","ou","an","en","ang","eng","er","yi","wu","yu","ye","yue","yuan","yun","yin","ying",
     "n","ng","m","hm","hng","lo","yo","ju","qu","xu","jue","xue","que","juan","xuan","quan","jun","xun","qun",
     "nü","nüe","lü","lüe","nv","nve","lv","lve"].forEach(s => set.add(s));
    return set;
  })();
  const PY_TONE_BASE = { "ā":"a","á":"a","ǎ":"a","à":"a","ē":"e","é":"e","ě":"e","è":"e",
    "ī":"i","í":"i","ǐ":"i","ì":"i","ō":"o","ó":"o","ǒ":"o","ò":"o","ū":"u","ú":"u","ǔ":"u","ù":"u",
    "ǖ":"ü","ǘ":"ü","ǚ":"ü","ǜ":"ü","ń":"n","ň":"n","ǹ":"n" };
  function splitPySyllables(run) {
    const base = [...run].map(ch => PY_TONE_BASE[ch] || ch).join("").toLowerCase();
    const n = base.length, cuts = [0];
    let i = 0;
    while (i < n) {
      let matched = 0;
      for (let len = Math.min(6, n - i); len >= 1; len--) {
        if (PY_SYL.has(base.slice(i, i + len))) { matched = len; break; }
      }
      if (!matched) return null;              // can't segment — caller keeps original
      i += matched; cuts.push(i);
    }
    const chars = [...run], parts = [];
    for (let k = 0; k < cuts.length - 1; k++) parts.push(chars.slice(cuts[k], cuts[k + 1]).join(""));
    return parts;
  }
  /* ---- Characters: tones, pages and the Characters screen ----------------
     CHARS_DATA (chars-data.js, built from Make Me a Hanzi) gives each
     character its parts and a memory hook. Tone colours come from the word's
     own pinyin, aligned syllable by syllable to its characters. */
  const CHD = (window.CHARS_DATA || { chars: {}, parts: {} });
  const TONE_OF = {};
  "āēīōūǖ".split("").forEach(v => TONE_OF[v] = 1); "áéíóúǘ".split("").forEach(v => TONE_OF[v] = 2);
  "ǎěǐǒǔǚ".split("").forEach(v => TONE_OF[v] = 3); "àèìòùǜ".split("").forEach(v => TONE_OF[v] = 4);
  const toneOf = syl => { for (const ch of syl) if (TONE_OF[ch]) return TONE_OF[ch]; return 5; };
  const tonesOn = () => prefs.toneColours !== false;
  const isHan = ch => /[\u3400-\u9fff]/.test(ch);
  const sylls = py => (prettyPinyin(py || "").match(/[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹ]+/g) || []);
  // Each character of a word, tone-classed when its pinyin lines up; tappable
  // characters (tap) open their page.
  function hzSpans(hanzi, pinyin, tap) {
    const f = document.createDocumentFragment(), cs = [...(hanzi || "")];
    const han = cs.filter(isHan), ss = sylls(pinyin), aligned = ss.length === han.length;
    let k = 0;
    cs.forEach(ch => {
      if (!isHan(ch)) { f.appendChild(document.createTextNode(ch)); return; }
      const s = el("span", { className: "tn" + (aligned ? " t" + toneOf(ss[k]) : "") + (tap && CHD.chars[ch] ? " chz" : "") }, ch);
      if (tap && CHD.chars[ch]) s.dataset.ch = ch;
      f.appendChild(s); k++;
    });
    return f;
  }
  // Pinyin with each syllable tone-classed, spacing kept.
  function pySpans(pinyin) {
    const f = document.createDocumentFragment(), s = prettyPinyin(pinyin || "");
    let last = 0;
    s.replace(/[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹ]+/g, (m, i) => {
      if (i > last) f.appendChild(document.createTextNode(s.slice(last, i)));
      f.appendChild(el("span", { className: "tn t" + toneOf(m) }, m)); last = i + m.length; return m;
    });
    if (last < s.length) f.appendChild(document.createTextNode(s.slice(last)));
    return f;
  }
  // A character's reading and meaning as this app teaches them.
  const CHAR_PY = {}, CHAR_EN = {};
  function charIndex() {
    if (Object.keys(CHAR_PY).length) return;
    CARDS.forEach(c => {
      const han = [...c.hanzi].filter(isHan), ss = sylls(c.pinyin);
      if (han.length === 1 && !CHAR_EN[han[0]]) CHAR_EN[han[0]] = c.en;
      if (ss.length === han.length) han.forEach((ch, i) => { if (!CHAR_PY[ch] && toneOf(ss[i]) !== 5) CHAR_PY[ch] = ss[i]; });
      if (ss.length === han.length) han.forEach((ch, i) => { if (!CHAR_PY[ch]) CHAR_PY[ch] = ss[i]; });
    });
  }
  const charPy = ch => { charIndex(); return CHAR_PY[ch] || (CHD.chars[ch] || {}).p || ""; };
  const charEn = ch => { charIndex(); return CHAR_EN[ch] || (CHD.chars[ch] || {}).d || ""; };
  const cardsWith = ch => CARDS.filter(c => c.hanzi.includes(ch));
  // 0 not met, 1 learning, 2 getting there, 3 strong — the best of the words it appears in
  function charLevel(ch) {
    let lv = 0;
    cardsWith(ch).forEach(c => {
      const s = srs[c.id]; if (!s || s.reps < 1) return;
      lv = Math.max(lv, s.interval >= MASTER_INTERVAL ? 3 : s.interval >= 3 ? 2 : 1);
    });
    return lv;
  }
  const charDue = ch => cardsWith(ch).some(c => srs[c.id] && srs[c.id].due <= NOW());
  function allChars() {
    const seen = new Set(), out = [];
    CARDS.forEach(c => [...c.hanzi].forEach(ch => { if (isHan(ch) && !seen.has(ch)) { seen.add(ch); out.push({ ch, lesson: c.lessonTitle }); } }));
    return out;
  }
  const charsKnown = () => allChars().filter(x => charLevel(x.ch) >= 1).length;

  /* ---- Look-alikes ------------------------------------------------------
     Wrong answers that make you look: words whose characters share parts,
     plus classic confusions a beginner mixes up. A note says what tells a
     hand-picked pair apart; other pairs are explained from their parts. */
  const LOOKALIKE_NOTES = {
    "买卖": "卖 sell has an extra 十 on top of 买 buy: you add something on top when you sell it on.",
    "人入": "人 person steps forward on its left leg; 入 enter leads with the right, stepping in.",
    "大太": "太 too is 大 big with an extra dot underneath: bigger than big.",
    "大天": "天 sky has a line over 大 big: the sky above a person.",
    "大夫": "夫 has a second line through the top of 大.",
    "己已": "已 already closes a little higher than 己 self; 巳 closes all the way.",
    "日目": "目 eye has two lines inside; 日 sun has one.",
    "日白": "白 white has a small tick on top of 日 sun.",
    "土士": "士 has the longer line on top; 土 earth has the longer line at the bottom.",
    "未末": "末 end has the longer line on top; 未 not yet has the shorter line on top.",
    "千干": "千 thousand starts with a slanted stroke; 干 starts with a flat one.",
    "午牛": "牛 cow's middle stroke pokes through the top; 午 noon's doesn't.",
    "儿几": "几 has a lid across the top; 儿 is open.",
    "问间": "问 ask has a mouth 口 in the door 门; 间 between has the sun 日.",
    "今令": "令 has a hook at the bottom where 今 has a flat stroke.",
    "见贝": "见 see ends in a long hooked leg; 贝 shell has two short legs.",
    "为办": "办 do has a dot on each side of 力; 为 has two dots together.",
    "力刀": "力 strength pokes up through the top; 刀 knife doesn't.",
    "东车": "车 car has a flat line at the bottom; 东 east has two dots.",
    "找我": "我 I has an extra dot on the right that 找 look for doesn't.",
    "住往": "住 live has person 亻 on the left; 往 towards has the double person 彳.",
    "休体": "体 body has an extra line at the bottom of 木.",
    "午年": "年 year has extra strokes on the left of 午 noon.",
    "左右": "左 left has 工 underneath; 右 right has 口."
  };
  const pairKey = (a, b) => LOOKALIKE_NOTES[a + b] ? a + b : LOOKALIKE_NOTES[b + a] ? b + a : null;
  // tiny strokes and the everywhere-parts don't make two characters look alike
  const TRIVIAL_PARTS = new Set("口一丨丿丶乛亅乚八十冖亠".split(""));
  const partsOf = ch => new Set(((CHD.chars[ch] || {}).c || []).map(p => p[0]).filter(p => !TRIVIAL_PARTS.has(p)));
  function charSim(a, b) {
    if (a === b) return 2;
    if (pairKey(a, b)) return 4;
    let n = 0; const pa = partsOf(a);
    partsOf(b).forEach(p => { if (pa.has(p)) n += 1.5; });
    return n;
  }
  // how easily two words could be mistaken for each other at a glance
  function wordSim(a, b) {
    const x = [...a].filter(isHan), y = [...b].filter(isHan);
    if (!x.length || x.length !== y.length || a === b) return 0;
    let s = 0, differ = 0;
    x.forEach((ch, i) => { if (ch !== y[i]) differ++; s += charSim(ch, y[i]); });
    return differ ? s / x.length + (differ === 1 && x.length > 1 ? 1 : 0) : 0;
  }
  // up to n look-alike cards for card c, strongest first with a little shuffle
  function lookalikes(c, n) {
    return shuffle(CARDS.filter(x => x.en !== c.en && x.hanzi !== c.hanzi).map(x => ({ x, s: wordSim(c.hanzi, x.hanzi) })).filter(o => o.s >= 1.5))
      .sort((p, q) => q.s - p.s).slice(0, n).map(o => o.x);
  }
  // the "spot the difference" block for a wrong pick that was a look-alike
  function diffBlock(right, wrong) {
    const x = [...right.hanzi].filter(isHan), y = [...wrong.hanzi].filter(isHan);
    const i = x.findIndex((ch, k) => ch !== y[k]); if (i < 0) return null;
    const a = x[i], b = y[i];
    let note = pairKey(a, b) && LOOKALIKE_NOTES[pairKey(a, b)];
    if (!note) {
      const pa = partsOf(a), pb = partsOf(b);
      const onlyA = [...pa].filter(p => !pb.has(p)), onlyB = [...pb].filter(p => !pa.has(p));
      const name = p => { const d = CHD.parts[p]; return d && d[0] ? `${p} ${d[0]}` : p; };
      if (onlyA.length || onlyB.length) note = `${a} ${charEn(a)} has ${onlyA.map(name).join(" and ") || "no extra part"}; ${b} ${charEn(b)} has ${onlyB.map(name).join(" and ") || "no extra part"}.`;
      else note = `Look closely at ${a} and ${b}: same parts, different arrangement.`;
    }
    const cell = (card, ch) => el("div", { className: "dcell" }, [
      el("div", { className: "dh" }, [...card.hanzi].map(k => el("span", { className: (k === ch ? "dmark " : "") + "chz" }, k))),
      el("div", { className: "dm" }, card.en)]);
    const box = el("div", { className: "diff" }, [el("div", { className: "dlabel" }, "Spot the difference"),
      el("div", { className: "dcells" }, [cell(right, a), cell(wrong, b)]), el("div", { className: "dn" }, note)]);
    box.querySelectorAll(".chz").forEach(s => { if (CHD.chars[s.textContent]) s.dataset.ch = s.textContent; else s.classList.remove("chz"); });
    return box;
  }

  // ---- the character page, as a sheet over whatever is on screen ----
  function partBox(comp, role) {
    const p = CHD.parts[comp] || (CHD.chars[comp] ? [charEn(comp), charPy(comp)] : null);
    const b = el("button", { className: "cpart" + (CHD.chars[comp] ? " chz" : ""), type: "button" }, [el("span", { className: "g" }, comp)]);
    if (CHD.chars[comp]) b.dataset.ch = comp;
    if (p && p[0]) b.appendChild(el("span", { className: "m" }, role === "s" ? `${p[1]} · ${p[0]}` : p[0]));
    if (role) b.appendChild(el("span", { className: "role " + (role === "s" ? "sound" : "meaning") }, role === "s" ? "sound" : "meaning"));
    return b;
  }
  /* Tapping a character inside the sheet opens that one in the same sheet, so
     the sheet keeps a trail: Back and the trail of characters lead back, the
     sheet keeps one height, and each page starts at its top. */
  let charTrail = [];
  function openCharSheet(ch) {
    if (!CHD.chars[ch]) return;
    const open = !$("#hzSheet").classList.contains("hidden");
    if (!open) charTrail = [ch];
    else if (charTrail[charTrail.length - 1] !== ch) { charTrail.push(ch); if (charTrail.length > 12) charTrail.shift(); }
    renderCharSheet(ch, !open);
  }
  function renderCharSheet(ch, first) {
    const d = CHD.chars[ch]; if (!d) return;
    const back = $("#hzSheet");
    const box = el("div", { className: "lsheet csheet" + (first ? "" : " still") });
    box.addEventListener("click", e => e.stopPropagation());
    const inner = el("div", { className: "lsheet-inner" });
    const py = charPy(ch), strokes = (window.HANZI_DATA && HANZI_DATA[ch] && HANZI_DATA[ch].strokes || []).length;
    const words = cardsWith(ch);
    inner.appendChild(el("div", { className: "handle" }));
    // the trail: Back, the characters you came through, and Close
    const nav = el("div", { className: "cnav" });
    if (charTrail.length > 1) {
      const bk = el("button", { className: "cnav-back", type: "button" }, "‹ Back");
      bk.addEventListener("click", () => { charTrail.pop(); renderCharSheet(charTrail[charTrail.length - 1], false); });
      nav.appendChild(bk);
      const crumbs = el("div", { className: "cnav-trail" });
      charTrail.forEach((c, i) => {
        if (i) crumbs.appendChild(el("span", { className: "cnav-sep" }, "›"));
        const b = el("button", { className: "cnav-c" + (i === charTrail.length - 1 ? " on" : ""), type: "button" }, c);
        if (i < charTrail.length - 1) b.addEventListener("click", () => { charTrail = charTrail.slice(0, i + 1); renderCharSheet(c, false); });
        crumbs.appendChild(b);
      });
      nav.appendChild(crumbs);
    } else nav.appendChild(el("span", { className: "cnav-hint" }, "Tap any character to explore it"));
    const x = el("button", { className: "cnav-x", type: "button", title: "Close" }, "✕");
    x.addEventListener("click", closeCharSheet);
    nav.appendChild(x);
    inner.appendChild(nav);
    const big = el("div", { className: "cbig tn t" + toneOf(py) }, ch);
    const acts = el("div", { className: "cacts" }, [speakerBtn(ch)]);
    if (HW_OK && strokes) acts.appendChild(strokeBtn(ch, py));
    inner.appendChild(el("div", { className: "chero" }, [big,
      el("div", { className: "cmeta" }, [el("div", { className: "cpy" }, pySpans(py)), el("div", { className: "cen" }, charEn(ch)),
        el("div", { className: "cinfo" }, [strokes ? `${strokes} strokes` : "", words.length ? `in ${words.length} of your word${words.length === 1 ? "" : "s"}` : ""].filter(Boolean).join(" · "))]),
      acts]));
    if (d.c && d.c.length > 1) {
      const row = el("div", { className: "cparts" });
      d.c.forEach(([comp, role], i) => { if (i) row.appendChild(el("span", { className: "plus" }, "+")); row.appendChild(partBox(comp, role)); });
      inner.appendChild(row);
    } else if (d.t === "g") inner.appendChild(el("div", { className: "cnote" }, "A picture character: it started as a drawing of the thing itself."));
    // memory hook: the generated one, or your own
    const hooks = prefs.hooks || {};
    const hookBox = el("div", { className: "chook" });
    const drawHook = () => {
      hookBox.innerHTML = "";
      hookBox.append(licon("i-bulb", "licon-sm"), el("div", { className: "ht" }, [el("span", {}, hooks[ch] || d.h || "Write a story to remember this one."),
        el("button", { className: "link hedit", type: "button" }, hooks[ch] ? "Edit your hook" : "Write your own")]));
      hookBox.querySelector(".hedit").addEventListener("click", () => {
        hookBox.innerHTML = "";
        const ta = el("textarea", { className: "hta", rows: 3, value: hooks[ch] || d.h || "" });
        const save = el("button", { className: "primary", type: "button" }, "Save hook");
        const reset = el("button", { className: "ghost", type: "button" }, hooks[ch] ? "Use the suggested one" : "Cancel");
        save.addEventListener("click", () => { const v = ta.value.trim(); prefs.hooks = Object.assign({}, prefs.hooks); if (v && v !== d.h) prefs.hooks[ch] = v; else delete prefs.hooks[ch]; savePrefs(prefs); Object.assign(hooks, prefs.hooks); if (!prefs.hooks[ch]) delete hooks[ch]; drawHook(); toast("Hook saved"); });
        reset.addEventListener("click", () => { if (hooks[ch]) { prefs.hooks = Object.assign({}, prefs.hooks); delete prefs.hooks[ch]; delete hooks[ch]; savePrefs(prefs); } drawHook(); });
        hookBox.append(ta, el("div", { className: "hbtns" }, [reset, save]));
        ta.focus();
      });
    };
    drawHook(); inner.appendChild(hookBox);
    if (words.length) {
      inner.appendChild(el("div", { className: "csub" }, `Words with ${ch}`));
      const list = el("div", { className: "cwords" });
      words.slice(0, 12).forEach(c => {
        const known = srs[c.id] && srs[c.id].reps >= 1;
        list.appendChild(el("div", { className: "cw" }, [el("span", { className: "h" }, hzSpans(c.hanzi, c.pinyin, true)),
          el("span", { className: "d" }, [pySpans(c.pinyin), el("br"), c.en]), el("span", { className: "k" + (known ? "" : " new") }, known ? "KNOWN" : "NEW")]));
      });
      inner.appendChild(list);
    }
    // relatives: characters from your lessons sharing a meaning part or a sound part
    const mine = new Set(allChars().map(x => x.ch));
    (d.c || []).forEach(([comp, role]) => {
      if (!role) return;
      const rel = [...mine].filter(o => o !== ch && CHD.chars[o] && (CHD.chars[o].c || []).some(([cc, rr]) => cc === comp && (role === "s" ? rr === "s" : true)));
      if (!rel.length) return;
      inner.appendChild(el("div", { className: "csub" }, role === "s" ? `Same sound part ${comp}` : `Also has ${comp}`));
      const chips = el("div", { className: "cchips" });
      rel.slice(0, 8).forEach(o => { const b = el("button", { className: "cchip chz", type: "button" }, [el("span", { className: "tn t" + toneOf(charPy(o)) }, o), el("small", {}, role === "s" ? charPy(o) : charEn(o))]); b.dataset.ch = o; chips.appendChild(b); });
      inner.appendChild(chips);
    });
    box.appendChild(inner);
    back.innerHTML = ""; back.appendChild(box); back.classList.remove("hidden");
    inner.scrollTop = 0;
    const cur = nav.querySelector(".cnav-c.on"); if (cur) cur.scrollIntoView({ block: "nearest", inline: "end" });
  }
  function closeCharSheet() { $("#hzSheet").classList.add("hidden"); charTrail = []; }
  // any tappable character anywhere opens its page
  document.addEventListener("click", e => {
    const t = e.target.closest(".chz[data-ch]"); if (!t) return;
    e.preventDefault(); e.stopPropagation(); openCharSheet(t.dataset.ch);
  }, true);

  // ---- the Characters screen ----
  let charsFilter = "all";
  let charsFrom = "home";
  function openChars() { charsFrom = document.body.dataset.view === "progress" ? "progress" : "home"; renderChars(); show("chars"); $("#charsBack").textContent = charsFrom === "progress" ? "← Profile" : "← Home"; }
  function renderChars() {
    const q = ($("#charsSearch").value || "").trim().toLowerCase();
    const strip = s => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/ü/g, "v").toLowerCase();
    const body = $("#charsBody"); body.innerHTML = "";
    const all = allChars();
    $("#charsCount").textContent = `${charsKnown()} / ${all.length}`;
    let group = null, grid = null, shown = 0;
    all.forEach(({ ch, lesson }) => {
      const lv = charLevel(ch), due = charDue(ch) && lv > 0;
      if (charsFilter === "due" && !due) return;
      if (charsFilter === "weak" && lv !== 1) return;
      if (charsFilter === "new" && lv !== 0) return;
      if (q && !(ch.includes(q) || strip(charPy(ch)).includes(strip(q)) || charEn(ch).toLowerCase().includes(q))) return;
      if (lesson !== group) { group = lesson; body.appendChild(el("div", { className: "unit-h" }, lesson)); grid = el("div", { className: "cgrid" }); body.appendChild(grid); }
      const b = el("button", { className: `cg s${lv}${due ? " due" : ""} chz`, type: "button", title: `${charPy(ch)} · ${charEn(ch)}` }, ch);
      b.dataset.ch = ch; grid.appendChild(b); shown++;
    });
    if (!shown) body.appendChild(el("p", { className: "muted", style: "text-align:center;margin:30px 0" }, q ? "No characters match that search." : "Nothing here right now."));
    $("#charsFilter").querySelectorAll("button").forEach(b => b.classList.toggle("on", b.dataset.f === charsFilter));
  }
  $("#charsFilter").querySelectorAll("button").forEach(b => b.addEventListener("click", () => { charsFilter = b.dataset.f; renderChars(); }));
  $("#charsSearch").addEventListener("input", renderChars);
  $("#charsBack").addEventListener("click", () => { if (charsFrom === "progress") { renderDashboard(); show("progress"); } else { renderHome(); show("home"); } });
  $("#hzSheet").addEventListener("click", closeCharSheet);

  /* ---- Reading: a short story at the end of each chapter -----------------
     READINGS (readings.js) holds one passage per chapter, written only from
     words taught by then (check-readings.js proves it). Tap a word for its
     pinyin and meaning; a question at the end checks you followed it. */
  const READS = window.READINGS || [];
  const READ_XP = 15;
  const readingFor = ci => READS.find(r => r.chapter === ci);
  const readDone = id => !!(activity.readsDone || {})[id];
  const chapterDone = ci => CHAPTERS[ci] && CHAPTERS[ci].lessons.every(id => doneLessons.has(id));
  const readOpen = r => chapterDone(r.chapter) || (location.hostname === "localhost" && new URLSearchParams(location.search).has("unlock"));
  const chLabel = ci => { const u = CHAPTERS[ci].unit; return `${u} · Chapter ${CHAPTERS.slice(0, ci + 1).filter(c => c.unit === u).length}`; };
  const tok = t => { const p = t.split("|"); return p.length === 3 ? { h: p[0], p: p[1], e: p[2] } : { h: t }; };
  let readFrom = "home";
  function openReadings(from) {
    readFrom = from || (document.body.dataset.view === "path" ? "path" : "home");
    renderReadList(); show("read");
  }
  function readBackLabel() { $("#readBack").textContent = readFrom === "path" ? "← Path" : "← Home"; }
  function readLeave() { if (readFrom === "path") { show("path"); renderPath(); } else { renderHome(); show("home"); } }
  function renderReadList() {
    readBackLabel(); $("#readTitle").textContent = "Reading";
    const body = $("#readBody"); body.innerHTML = "";
    $("#readCount").textContent = `${READS.filter(r => readDone(r.id)).length} / ${READS.length} read`;
    body.appendChild(el("p", { className: "read-intro" }, "Finish a chapter and its story opens here. Every word in it is one you've learnt."));
    READS.forEach(r => {
      const open = readOpen(r), done = readDone(r.id), ch = CHAPTERS[r.chapter];
      const card = el("button", { className: "rcard" + (open ? "" : " locked") + (done ? " done" : ""), type: "button" }, [
        el("div", { className: "rc-h" }, hzSpans(r.title, r.py)),
        el("div", { className: "rc-t" }, [
          el("div", { className: "rc-u" }, chLabel(r.chapter)),
          el("b", {}, r.en),
          el("span", {}, open ? (done ? "Read ✓" : `New · +${READ_XP} XP`) : `Finish “${ch.title}” to open`)
        ])
      ]);
      card.addEventListener("click", () => open ? openReading(r.id) : toast(`Finish every lesson in “${ch.title}” first.`));
      body.appendChild(card);
    });
  }
  function openReading(id, from) {
    const r = READS.find(x => x.id === id); if (!r) return;
    if (from) readFrom = from;
    readBackLabel(); $("#readTitle").textContent = r.title;
    $("#readCount").textContent = "";
    const body = $("#readBody"); body.innerHTML = "";
    const all = r.sentences.map(s => s.map(t => tok(t).h).join("")).join("");
    const head = el("div", { className: "rhead" }, [
      el("div", { className: "rc-u" }, `${chLabel(r.chapter)} · Story`),
      el("div", { className: "rh-t" }, [el("span", { className: "rh-h" }, hzSpans(r.title, r.py)), el("span", { className: "rh-e" }, r.en)])
    ]);
    const tools = el("div", { className: "rtools" });
    const play = el("button", { className: "rtool", type: "button" }); play.appendChild(licon("i-volume", "licon-sm")); play.appendChild(el("span", {}, "Listen"));
    play.addEventListener("click", () => speak(all));
    const slow = el("button", { className: "rtool", type: "button" }, "½×"); slow.addEventListener("click", () => speak(all, { rate: 0.55 }));
    const pyT = el("button", { className: "rtool", type: "button" }, "Pinyin");
    const enT = el("button", { className: "rtool", type: "button" }, "English");
    tools.append(play, slow, pyT, enT);
    const text = el("div", { className: "rtext" });
    const panel = el("div", { className: "rword empty" }, "Tap any word for its pinyin and meaning.");
    let openW = null;
    const showWord = (t, w) => {
      if (openW) openW.classList.remove("open");
      openW = w; w.classList.add("open");
      panel.className = "rword"; panel.innerHTML = "";
      const hz = el("div", { className: "rw-h" }, hzSpans(t.h, t.p, true));
      const sp = el("button", { className: "speaker", type: "button", title: "Play" }); sp.appendChild(licon("i-volume", "licon-sm"));
      sp.addEventListener("click", () => speak(t.h));
      panel.append(hz, el("div", { className: "rw-m" }, [el("div", { className: "rw-p" }, pySpans(t.p)), el("div", { className: "rw-e" }, t.e)]), sp);
      if ([...t.h].some(c => CHD.chars[c])) panel.appendChild(el("div", { className: "rw-tip" }, "Tap a character to see how it's built"));
      speak(t.h);
    };
    r.sentences.forEach(s => {
      const sen = el("span", { className: "rs" });
      s.forEach(raw => {
        const t = tok(raw);
        if (!t.p) { sen.appendChild(el("span", { className: "rpunct" }, t.h)); return; }
        const w = el("span", { className: "rw", role: "button", tabIndex: 0 }, [el("span", { className: "rp" }, pySpans(t.p)), el("span", { className: "rh" }, hzSpans(t.h, t.p))]);
        w.addEventListener("click", () => showWord(t, w));
        sen.appendChild(w);
      });
      text.appendChild(sen);
    });
    const tr = el("p", { className: "rtrans hidden" }, r.translation);
    pyT.addEventListener("click", () => { text.classList.toggle("pyon"); pyT.classList.toggle("on"); });
    enT.addEventListener("click", () => { tr.classList.toggle("hidden"); enT.classList.toggle("on"); });
    // the question
    const q = el("div", { className: "rq" }, [el("div", { className: "rq-l" }, "Did you follow it?"), el("div", { className: "rq-t" }, r.q.text)]);
    const opts = el("div", { className: "rq-o" });
    const finish = el("button", { className: "primary rfinish hidden", type: "button" }, "Finish");
    shuffle(r.q.options.map((o, i) => ({ o, i }))).forEach(({ o, i }) => {
      const b = el("button", { className: "rq-b", type: "button" }, o);
      b.addEventListener("click", () => {
        if (q.classList.contains("solved") || b.disabled) return;
        if (i === r.q.answer) { b.classList.add("right"); q.classList.add("solved"); sfx("correct"); buzz(true); finish.classList.remove("hidden"); }
        else { b.classList.add("wrong"); b.disabled = true; sfx("wrong"); buzz(false); }
      });
      opts.appendChild(b);
    });
    q.appendChild(opts);
    finish.addEventListener("click", () => {
      const first = !readDone(r.id);
      activity.readsDone = activity.readsDone || {}; activity.readsDone[r.id] = todayStr();
      localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity)); queueSync();
      if (first) { earnXP(READ_XP); sfx("complete"); confetti(70); toast(`Story read! +${READ_XP} XP`); }
      if (readFrom === "path") readLeave(); else renderReadList();
    });
    body.append(head, tools, text, tr, panel, q, finish);
    if (document.body.dataset.view !== "read") show("read");
  }
  $("#readBack").addEventListener("click", () => {
    if ($("#readBody .rtext") && readFrom !== "path") renderReadList(); else readLeave();
  });

  /* ---- Guidebook: one page per chapter --------------------------------------
     What the chapter teaches, before or after you do it: its grammar tips, key
     phrases from the dialogues that use only words taught by then, and its
     words with how well you know each. */
  let guideFrom = "path";
  function guideLink(ci) {
    const b = el("button", { className: "pguide", type: "button", title: "Guidebook" });
    b.appendChild(licon("i-bulb", "licon-sm")); b.appendChild(document.createTextNode("Guide"));
    b.addEventListener("click", e => { e.stopPropagation(); openGuide(ci, "path"); });
    return b;
  }
  function chapterChars(ci) {
    const ids = new Set(CHAPTERS.slice(0, ci + 1).flatMap(c => c.lessons));
    return new Set(CARDS.filter(c => ids.has(c.lessonId)).flatMap(c => [...c.hanzi].filter(isHan)));
  }
  function keyPhrases(ci) {
    const ch = CHAPTERS[ci], known = chapterChars(ci);
    const words = CARDS.filter(c => ch.lessons.includes(c.lessonId) && [...c.hanzi].some(isHan));
    const seen = new Set(), out = [];
    (window.DIALOGUES || []).forEach(d => (d.turns || []).forEach(t => {
      const han = [...t.hanzi].filter(isHan);
      if (han.length < 2 || seen.has(t.hanzi) || t.free) return;
      if (!han.every(c => known.has(c))) return;                    // only words taught by now
      const hits = words.filter(w => t.hanzi.includes(w.hanzi.replace(/[^\u3400-\u9fff]/g, "")) && w.hanzi.replace(/[^\u3400-\u9fff]/g, "")).length;
      if (!hits) return;                                            // must use this chapter's words
      seen.add(t.hanzi); out.push({ t, hits, len: han.length });
    }));
    return out.sort((a, b) => b.hits - a.hits || a.len - b.len).slice(0, 6).map(o => o.t)
      .sort((a, b) => [...a.hanzi].length - [...b.hanzi].length);
  }
  function openGuide(ci, from) {
    guideFrom = from || (document.body.dataset.view === "home" ? "home" : "path");
    const ch = CHAPTERS[ci]; if (!ch) return;
    $("#guideBack").textContent = guideFrom === "home" ? "← Home" : "← Path";
    const body = $("#guideBody"); body.innerHTML = "";
    const cards = CARDS.filter(c => ch.lessons.includes(c.lessonId));
    const learnt = cards.filter(c => srs[c.id] && (srs[c.id].reps || 0) >= 1).length;
    $("#guideCount").textContent = `${learnt} / ${cards.length} words`;
    body.appendChild(el("div", { className: "g-head" }, [
      el("div", { className: "rc-u" }, chLabel(ci)),
      el("h2", {}, ch.title),
      el("p", {}, `${ch.lessons.length} lesson${ch.lessons.length === 1 ? "" : "s"} · ${cards.length} words` + (chapterDone(ci) ? " · finished" : ""))
    ]));
    // grammar tips
    const notes = ch.lessons.flatMap(notesFor);
    if (notes.length) {
      body.appendChild(el("h3", { className: "g-h" }, "Grammar tips"));
      notes.forEach(n => body.appendChild(el("div", { className: "g-tip" }, [
        el("div", { className: "g-tip-t" }, [licon("i-bulb", "licon-sm"), document.createTextNode(" " + n.title)]),
        el("div", { className: "g-tip-b" }, n.body)])));
    }
    // key phrases
    const phrases = keyPhrases(ci);
    if (phrases.length) {
      body.appendChild(el("h3", { className: "g-h" }, "Key phrases"));
      const box = el("div", { className: "g-phrases" });
      phrases.forEach(t => {
        const words = segmentSentence(t.hanzi, t.pinyin);
        const line = el("div", { className: "g-ph-h" });
        if (words) {
          // walk the sentence, so its punctuation stays where it was
          const H = [...t.hanzi]; let pos = 0;
          const punct = () => { while (pos < H.length && !isHan(H[pos])) line.appendChild(document.createTextNode(H[pos++])); };
          words.forEach(w => { punct(); line.appendChild(hintable(el("span", { className: "g-w" }, hzSpans(w.hanzi, w.pinyin, false)), w.hanzi, w.pinyin)); pos += [...w.hanzi].length; });
          punct();
        } else line.appendChild(hzSpans(t.hanzi, t.pinyin, false));
        box.appendChild(el("div", { className: "g-ph" }, [
          el("div", { className: "g-ph-m" }, [line, el("div", { className: "g-ph-p" }, pySpans(t.pinyin)), el("div", { className: "g-ph-e" }, t.en)]),
          speakerBtn(t.hanzi)]));
      });
      body.appendChild(box);
      body.appendChild(el("div", { className: "hint-tip" }, "Tap a word for its meaning"));
    }
    // words, lesson by lesson
    body.appendChild(el("h3", { className: "g-h" }, "Words"));
    ch.lessons.forEach(id => {
      const l = LESSONS.find(x => x.id === id); if (!l) return;
      body.appendChild(el("div", { className: "g-lesson" }, l.title.replace(/^.*?· /, "")));
      const list = el("div", { className: "g-words" });
      cards.filter(c => c.lessonId === id).forEach(c => {
        const s = srs[c.id], lv = !s ? 0 : (s.reps || 0) >= 2 || (s.interval || 0) >= 7 ? 2 : (s.reps || 0) >= 1 ? 1 : 0;
        list.appendChild(el("div", { className: "g-word k" + lv }, [
          el("span", { className: "g-wh" }, hzSpans(c.hanzi, c.pinyin, true)),
          el("span", { className: "g-wm" }, [el("span", { className: "g-wp" }, pySpans(c.pinyin)), el("span", { className: "g-we" }, c.en)]),
          el("i", { className: "g-dot", title: ["Not met yet", "Learning", "Known"][lv] }),
          speakerBtn(c.hanzi)]));
      });
      body.appendChild(list);
    });
    const story = readingFor(ci);
    if (story) {
      const b = el("button", { className: "g-story", type: "button" }, [licon("i-book", "licon-sm"),
        document.createTextNode(chapterDone(ci) ? ` Read the story: ${story.title}` : ` Finish the chapter to unlock its story`)]);
      b.disabled = !chapterDone(ci);
      b.addEventListener("click", () => openReading(story.id, guideFrom));
      body.appendChild(b);
    }
    show("guide");
    window.scrollTo(0, 0);
  }
  $("#guideBack").addEventListener("click", () => { if (guideFrom === "home") { renderHome(); show("home"); } else { show("path"); renderPath(); } });

  /* ---- Tone pairs ------------------------------------------------------
     Hear a two-syllable word you've met and pick its two tones. Mandarin's
     tones are easiest to hear in pairs, the way they come in real words.
     Words whose spoken tones differ from their written ones (3+3, 不, 一)
     are left out, so the answer always matches what you hear. */
  const TONE_ROUNDS = 10;
  const TONE_NAME = { 1: "high", 2: "rising", 3: "dipping", 4: "falling", 5: "light" };
  function tonePair(c) {
    const han = [...c.hanzi].filter(isHan), ss = sylls(c.pinyin);
    if (han.length !== 2 || ss.length !== 2 || /[不一]/.test(c.hanzi)) return null;
    const a = toneOf(ss[0]), b = toneOf(ss[1]);
    if (a === 5 || (a === 3 && b === 3)) return null;
    return [a, b];
  }
  // a little picture of the pitch: the classic 1-5 pitch scale, drawn left to right
  function toneShape(t, x0) {
    const y = v => 30 - v * 5;
    const d = { 1: `M${x0} ${y(5)}L${x0 + 26} ${y(5)}`, 2: `M${x0} ${y(3)}L${x0 + 26} ${y(5)}`,
      3: `M${x0} ${y(2)}Q${x0 + 10} ${y(0.2)} ${x0 + 14} ${y(1)}T${x0 + 26} ${y(4)}`, 4: `M${x0} ${y(5)}L${x0 + 26} ${y(1)}` }[t];
    return d ? `<path d="${d}" stroke="var(--t${t})"/>` : `<circle cx="${x0 + 8}" cy="${y(2)}" r="3.2" fill="var(--t5)"/>`;
  }
  const pairSvg = ([a, b]) => `<svg viewBox="-3 -3 70 36" class="tpic" fill="none" stroke-width="4.2" stroke-linecap="round">${toneShape(a, 0)}${toneShape(b, 36)}</svg>`;
  let toneQ = [], toneI = 0, toneRight = 0, toneMiss = {};
  function startTones() {
    returnView = "home";
    const all = CARDS.filter(tonePair);
    const met = all.filter(c => srs[c.id] || doneLessons.has(c.lessonId));
    const pool = met.length >= 6 ? met : all.filter(c => CHAPTERS[0].lessons.includes(c.lessonId)).concat(met);
    const pick = shuffle([...new Map(pool.map(c => [c.hanzi, c])).values()]);
    toneQ = []; for (let i = 0; pick.length && i < TONE_ROUNDS; i++) toneQ.push(pick[i % pick.length]); toneI = 0; toneRight = 0; toneMiss = {};
    show("tones"); renderTone();
  }
  function toneChoices(ans) {
    const key = p => p.join("");
    const pairs = []; for (let a = 1; a <= 4; a++) for (let b = 1; b <= 5; b++) if (!(a === 3 && b === 3)) pairs.push([a, b]);
    const others = pairs.filter(p => key(p) !== key(ans));
    const near = shuffle(others.filter(p => p[0] === ans[0] || p[1] === ans[1])).slice(0, 2);
    const far = shuffle(others.filter(p => !near.includes(p))).slice(0, 3 - near.length);
    return shuffle([ans, ...near, ...far]);
  }
  function renderTone() {
    const c = toneQ[toneI], ans = tonePair(c), body = $("#tonesBody");
    $("#tonesCount").textContent = `${toneI + 1} / ${toneQ.length}`;
    $("#tonesBar").style.width = (toneI / toneQ.length * 100) + "%";
    body.innerHTML = "";
    const play = el("button", { className: "tplay", type: "button", title: "Play again" }); play.appendChild(licon("i-volume"));
    play.addEventListener("click", () => speak(c.hanzi));
    const slow = el("button", { className: "tslow", type: "button" }, "½×"); slow.addEventListener("click", () => speak(c.hanzi, { rate: 0.5 }));
    body.append(el("div", { className: "tprompt" }, "Which two tones do you hear?"), el("div", { className: "tplays" }, [play, slow]));
    const reveal = el("div", { className: "treveal" });
    const grid = el("div", { className: "tgrid" });
    const next = el("button", { className: "primary tnext hidden", type: "button" }, toneI + 1 < toneQ.length ? "Continue" : "See results");
    toneChoices(ans).forEach(p => {
      const b = el("button", { className: "tch", type: "button" });
      b.innerHTML = pairSvg(p) + `<span class="tl"><span class="tn t${p[0]}">${p[0] === 5 ? "light" : p[0]}</span> + <span class="tn t${p[1]}">${p[1] === 5 ? "light" : p[1]}</span></span>`;
      b.addEventListener("click", () => {
        if (grid.classList.contains("answered")) return;
        grid.classList.add("answered");
        const ok = p.join("") === ans.join("");
        grid.querySelectorAll(".tch").forEach(x => { if (x === b) x.classList.add(ok ? "right" : "wrong"); });
        if (!ok) { [...grid.children].find(x => x.dataset.p === ans.join("")).classList.add("right"); toneMiss[ans.join("+")] = (toneMiss[ans.join("+")] || 0) + 1; }
        else toneRight++;
        sfx(ok ? "correct" : "wrong"); buzz(ok);
        reveal.innerHTML = "";
        reveal.append(el("div", { className: "tr-h" }, hzSpans(c.hanzi, c.pinyin, true)),
          el("div", { className: "tr-m" }, [el("div", { className: "tr-p" }, pySpans(c.pinyin)), el("div", { className: "tr-e" }, c.en)]),
          el("div", { className: "tr-n" }, `${TONE_NAME[ans[0]]} then ${TONE_NAME[ans[1]]}`));
        reveal.classList.add("show", ok ? "ok" : "no");
        next.classList.remove("hidden");
        speak(c.hanzi);
      });
      b.dataset.p = p.join("");
      grid.appendChild(b);
    });
    next.addEventListener("click", () => { toneI++; if (toneI < toneQ.length) renderTone(); else toneResults(); });
    body.append(grid, reveal, next);
    setTimeout(() => speak(c.hanzi), 250);
  }
  function toneResults() {
    $("#tonesBar").style.width = "100%"; $("#tonesCount").textContent = "";
    const xp = toneRight * XP.correct + XP.session;
    earnXP(xp); sfx("complete"); if (toneRight >= toneQ.length * 0.8) confetti(70);
    const worst = Object.entries(toneMiss).sort((a, b) => b[1] - a[1])[0];
    const body = $("#tonesBody"); body.innerHTML = "";
    body.append(el("div", { className: "tres" }, [
      el("div", { className: "tres-n" }, `${toneRight} / ${toneQ.length}`),
      el("div", { className: "tres-l" }, toneRight === toneQ.length ? "Perfect ear!" : toneRight >= toneQ.length * 0.7 ? "Nicely heard" : "Tones take time. Keep listening."),
      el("div", { className: "tres-x" }, `+${xp} XP`)
    ]));
    if (worst) {
      const [a, b] = worst[0].split("+").map(Number);
      const tip = el("div", { className: "ttip" }); tip.innerHTML = pairSvg([a, b]);
      tip.appendChild(el("div", {}, [el("b", {}, `Trickiest: ${TONE_NAME[a]} + ${TONE_NAME[b]}`), el("span", {}, "Say a few words with this pattern out loud, drawing the shape with your hand.")]));
      body.appendChild(tip);
    }
    const again = el("button", { className: "primary", type: "button" }, "Go again"); again.addEventListener("click", startTones);
    const home = el("button", { className: "ghost", type: "button" }, "Done"); home.addEventListener("click", () => { renderHome(); show("home"); });
    body.appendChild(el("div", { className: "tres-b" }, [again, home]));
  }
  $("#tonesBack").addEventListener("click", () => { renderHome(); show("home"); });

  function prettyPinyin(s) {
    if (!s) return s;
    return String(s).replace(/[A-Za-zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹ]+/g, run => {
      if (/^[A-Z]/.test(run)) return run;      // proper nouns (Dàwèi) — leave alone
      const parts = splitPySyllables(run);
      return parts ? parts.join(" ") : run;
    });
  }
  function toneVariants(py, n) {
    const chars = [...py];
    const marks = [];
    chars.forEach((ch, i) => { if (TONE_DECODE[ch]) marks.push(i); });
    if (!marks.length) return [];               // all-neutral word (ma, de…): can't retone
    const out = new Set();
    let guard = 0;
    while (out.size < n && guard++ < 60) {
      const arr = chars.slice();
      const k = 1 + Math.floor(Math.random() * Math.min(2, marks.length));
      shuffle(marks.slice()).slice(0, k).forEach(idx => {
        const [base, tone] = TONE_DECODE[chars[idx]];
        let t2 = tone; while (t2 === tone) t2 = Math.floor(Math.random() * 4);
        arr[idx] = TONE_VOWELS[base][t2];
      });
      const v = arr.join("");
      if (v !== py) out.add(v);
    }
    return [...out].slice(0, n);
  }

  function buildChoiceExercise(face, choicesBox, c, dir, labelEl, onResult) {
    face.innerHTML = "";
    choicesBox.classList.remove("sentence-mode");
    const bubble = mascotSpeech(face);
    let promptNode, answerText, distractField;
    if (dir === "recall") {
      labelEl.textContent = "Which characters mean this?";
      promptNode = el("div", { className: "en" }, c.en);
      answerText = c.hanzi; distractField = "hanzi";
    } else if (dir === "pinyin") {
      labelEl.textContent = "Which pinyin is correct?";
      promptNode = el("div", { className: "hanzi" + (c.hanzi.length > 3 ? " small" : "") }, c.hanzi);
      answerText = c.pinyin; distractField = "pinyin";
      // First time you meet the tone drill, introduce the tones themselves.
      try {
        if (!localStorage.getItem("zhBeginnerA.tonesSeen.v1")) {
          localStorage.setItem("zhBeginnerA.tonesSeen.v1", "1");
          setTimeout(openTones, 350);
        }
      } catch (e) {}
    } else if (dir === "listen") {
      labelEl.textContent = "What did you hear?";
      // Tappable, so a missed auto-play (voice still loading, synth stuck) is always
      // recoverable — tap the headphones to hear it again.
      promptNode = el("button", { className: "listen-replay", type: "button", title: "Play again" });
      promptNode.innerHTML = '<svg class="licon"><use href="#i-headphones"/></svg>';
      promptNode.addEventListener("click", () => speak(c.hanzi));
      answerText = c.en; distractField = "en";
      setTimeout(() => speak(c.hanzi), 60);   // let the card mount, then play
    } else {
      labelEl.textContent = "What does this mean?";
      promptNode = el("div", { className: "hanzi" + (c.hanzi.length > 3 ? " small" : "") }, c.hanzi);
      answerText = c.en; distractField = "en";
    }
    // A word you have never got right is introduced, not tested: it wears a
    // NEW WORD tag, and its characters can be tapped for the meaning.
    const fresh = isNewCard(c);
    if (fresh) {
      bubble.appendChild(newBadge());
      promptNode.classList.add("is-new");
      if (dir === "recognize") hintable(promptNode, c.hanzi, c.pinyin);
      if (dir === "recall") { promptNode.classList.add("en-new"); hintable(promptNode, c.hanzi, c.pinyin, true); }
    }
    bubble.appendChild(promptNode);
    // The pinyin drill tests the pinyin, so it can't show the answer — but a bare
    // character is a blind guess, so give the English meaning as context.
    if (dir === "pinyin") bubble.appendChild(el("div", { className: "en", style: "font-size:1rem;margin-top:2px" }, c.en));
    if (dir !== "pinyin") bubble.appendChild(speakerBtn(c.hanzi));
    // Recall shows pinyin on the option tiles instead (below), so its prompt
    // pinyin hint would just give the answer away.
    if (dir !== "pinyin" && dir !== "listen" && !(dir === "recall" && showPinyin())) {
      face.appendChild(el("div", { className: "aids-row" }, pinyinHint(c.pinyin)));
    }
    if (dir === "pinyin") {
      const tl = el("button", { className: "tones-link", type: "button" });
      tl.innerHTML = `<svg class="licon licon-sm"><use href="#i-music"/></svg> What are tones?`;
      tl.addEventListener("click", openTones);
      face.appendChild(tl);
    }

    const cards = activeCards();
    let distractors;
    if (dir === "pinyin") {
      // Same syllables, different tones — a genuine tone-discrimination drill.
      distractors = toneVariants(answerText, 3);
      if (distractors.length < 3)
        distractors = distractors.concat(sample(
          [...new Set(cards.map(x => x.pinyin))].filter(v => v !== answerText && !distractors.includes(v)),
          3 - distractors.length));
    } else if (dir === "listen") {
      // Prefer true tone minimal-pairs (same letters, different tones) when the
      // vocab has any; otherwise fall back to random meanings.
      const target = tonelessPinyin(c.pinyin);
      const near = [...new Set(cards.filter(x => x.en !== answerText && tonelessPinyin(x.pinyin) === target).map(x => x.en))];
      distractors = sample(near, 3);
      if (distractors.length < 3)
        distractors = distractors.concat(sample(
          [...new Set(cards.map(x => x.en))].filter(v => v !== answerText && !distractors.includes(v)),
          3 - distractors.length));
    } else {
      // two of the three wrong answers are look-alikes when there are any
      const near = (dir === "recall" || dir === "recognize") ? [...new Set(lookalikes(c, 2).map(x => x[distractField]))].filter(v => v !== answerText) : [];
      distractors = near.concat(sample([...new Set(cards.map(x => x[distractField]))].filter(v => v !== answerText && !near.includes(v)), 3 - near.length));
    }
    const options = shuffle([answerText, ...distractors]);
    choicesBox.innerHTML = "";
    choicesBox.dataset.answered = "";
    // Recall options are bare characters a beginner can't read — show pinyin
    // under each (when the aid is on) so the choice is legible, not a guess.
    const withTilePinyin = dir === "recall" && showPinyin();
    options.forEach(opt => {
      const btn = el("button", { className: "choice" + (withTilePinyin ? " choice-py" : "") });
      btn.dataset.val = opt;
      if (withTilePinyin) {
        btn.appendChild(el("span", { className: "c-han" }, opt));
        if (PINYIN_BY_HANZI[opt]) btn.appendChild(el("span", { className: "c-py" }, pySpans(PINYIN_BY_HANZI[opt])));
      } else {
        // display prettified for the pinyin drill; the match still uses dataset.val
        btn.textContent = dir === "pinyin" ? prettyPinyin(opt) : opt;
      }
      btn.addEventListener("click", () => {
        if (choicesBox.dataset.answered) return;
        choicesBox.dataset.answered = "1";
        const correct = opt === answerText;
        const drg = face.querySelector(".quiz-dragon");
        if (correct) { btn.classList.add("correct"); if (drg) { drg.src = "images/path/panda-celebrate.webp?v=218"; drg.classList.add("react"); } }
        else {
          btn.classList.add("wrong");
          [...choicesBox.children].forEach(ch => { if (ch.dataset.val === answerText) ch.classList.add("correct"); });
          if (drg) { drg.src = "images/path/panda-sad.webp?v=218"; drg.classList.add("react"); }
        }
        onResult(correct, opt);
      });
      choicesBox.appendChild(btn);
    });
  }

  function renderStudyCard() {
    closeHint();
    { const st = $("#study .stage"); if (st) st.scrollTop = 0; }
    $("#promptLabel").textContent = DIR_LABEL[curDir];
    const face = $("#studyFace");
    face.innerHTML = "";              // every mode starts from a clean face — the
    face.style.justifyContent = "";   // speak branch used to inherit the last card's
                                       // write grid, stacking two exercises on one page.
    // Reset all pinned controls; each mode re-shows what it needs.
    $("#studyContinueWrap").classList.add("hidden");
    $("#studyContinueWrap").classList.remove("wide", "reserve", "short");
    clearFeedback($("#studyContinueWrap"));
    face.classList.remove("sent");
    $("#studyReveal").classList.add("hidden");
    $("#studyNext").classList.add("hidden");
    setWriteGate(true);   // only write/sentence modes lock these
    studyCheckFn = null;
    setContinueLabel("Continue");
    const choices = $("#studyChoices");
    choices.classList.remove("sentence-mode");
    const c = curCard;

    if (curDir === "write") {
      // Writing practice keeps its full-width grid; finishing it = correct.
      choices.classList.add("hidden"); choices.innerHTML = "";
      face.innerHTML = "";
      const chars = cjkOnly(c.hanzi);
      const checkOn = prefs.checkStrokes !== false;
      if (isPhone()) { writeCharIdx = 0; renderWritePhone(face, c, chars, checkOn); }
      else {
        // desktop keeps the fuller prompt above the grid
        face.appendChild(el("div", { className: "en" }, c.en));
        face.appendChild(el("div", { className: "pinyin" }, prettyPinyin(c.pinyin)));
        face.appendChild(aidsRow(c, { speaker: true }));
        renderWriteDesktop(face, chars, checkOn);
      }
    } else if (curDir === "speak") {
      choices.classList.add("hidden"); choices.innerHTML = "";
      /* Speech recognition is very poor on a single Chinese syllable — with no
         surrounding context the recogniser is guessing between dozens of
         homophones, which is why a correct 也 came back as 野. Give it a short
         PHRASE containing the word instead: more acoustic context makes
         recognition far more reliable, and practising the word in context is
         better learning anyway. Falls back to the bare word when we have no
         sentence for it. */
      const phrase = sentencesFor(c)
        .filter(s => { const n = cjkOnly(s.hanzi).length; return n >= 3 && n <= 12; })
        .sort((a, b) => cjkOnly(a.hanzi).length - cjkOnly(b.hanzi).length)[0] || null;
      const sayHanzi  = phrase ? phrase.hanzi  : c.hanzi;
      const sayPinyin = phrase ? phrase.pinyin : c.pinyin;
      const sayEn     = phrase ? phrase.en     : c.en;

      const bubble = mascotSpeech(face);
      bubble.appendChild(el("div", { className: "hanzi" + (sayHanzi.length > 3 ? " small" : "") }, sayHanzi));
      bubble.appendChild(speakerBtn(sayHanzi));
      face.appendChild(el("div", { className: "pinyin" }, prettyPinyin(sayPinyin)));
      face.appendChild(el("div", { className: "muted" }, sayEn));
      if (phrase) face.appendChild(el("div", { className: "muted", style: "font-size:.78rem" },
        `practising ${c.hanzi} — ${c.pinyin}`));
      const fb = el("div", { className: "speak-fb" });
      const settle = (correct, html) => {
        fb.innerHTML = html;
        const drg = face.querySelector(".quiz-dragon");
        if (drg) { drg.src = `images/${correct ? "panda-celebrate" : "panda-sad"}.png${ASSET_V}`; drg.classList.add("react"); }
        answerStudy(correct);
        $("#studyContinueWrap").classList.add(correct ? "ok" : "bad");
        setWriteGate(true);
      };
      if (canRecognize()) {
        const micLbl2 = `<svg class="licon licon-sm"><use href="#i-mic"/></svg> Tap and say it`;
        const mic = el("button", { className: "speak-btn", type: "button" });
        mic.innerHTML = micLbl2;
        let tries = 0;
        const MAX_TRIES = 2;   // recognition is stochastic — a second pass often lands
        mic.addEventListener("click", () => {
          if (studyAnswered) return;
          let gotResult = false;
          mic.disabled = true; mic.textContent = "● Listening…"; mic.classList.add("listening");
          fb.textContent = "";
          recognizeOnce({
            // live partial text so it visibly responds while you're still talking
            onInterim: alts => { if (!studyAnswered && alts[0])
              fb.innerHTML = `<span class="muted">…${alts[0]}</span>`; },
            // accept once a partial contains the whole phrase — don't wait for the
            // silence timeout, but don't cut off a prefix mid-phrase either.
            acceptEarly: alts => saidWhole(sayHanzi, alts),
            onResult: alts => {
              gotResult = true; tries++;
              const r = scoreSpeech(sayHanzi, alts, c.hanzi);
              if (r.level === "exact") settle(true, `<span class="ok">✓ Perfect</span>`);
              else if (r.level === "close") settle(true, `<span class="ok">✓ Got it</span> — heard “${r.heard}”`);
              else if (tries < MAX_TRIES)
                fb.innerHTML = `<span class="muted">Heard “${r.heard || "…"}” — give it one more go.</span>`;
              else settle(false, `<span class="bad">Not quite</span> — heard “${r.heard || "…"}”. It's <b>${sayHanzi}</b> (${sayPinyin}).`);
            },
            // a mic failure isn't a wrong answer — let them try again
            onError: err => { fb.innerHTML = err === "not-allowed"
              ? `<span class="bad">Allow microphone access to use this.</span>`
              : `<span class="muted">Didn't catch that — tap and try again.</span>`; },
            // the recogniser can end without ever returning a result (short words,
            // background noise); always leave a visible prompt, never a dead button.
            onEnd: () => { if (!studyAnswered) {
              mic.disabled = false; mic.innerHTML = micLbl2; mic.classList.remove("listening");
              if (!gotResult && !fb.textContent.trim())
                fb.innerHTML = `<span class="muted">Didn't catch that — tap and try again.</span>`;
            } }
          });
        });
        // Not being able to use the mic isn't a wrong answer — reveal it and
        // requeue it for later this session with no SRS penalty (parity with the
        // self-assessed iOS path, which also never marks you wrong here).
        const skip = el("button", { className: "hint-btn", type: "button" }, "Can't speak now");
        skip.addEventListener("click", () => {
          if (studyAnswered) return;
          studyAnswered = true;
          fb.innerHTML = `<span class="muted">No problem — it's <b>${c.hanzi}</b> (${c.pinyin}). We'll come back to it.</span>`;
          queue.push(curCard);   // returns later this session, not counted wrong
          updateStudyProgress();
          setWriteGate(true);
        });
        face.append(mic, fb, skip);
      } else {
        // iOS Safari has no speech recognition: keep the practice, self-assessed.
        face.appendChild(el("div", { className: "muted", style: "font-size:.8rem" },
          "This browser can't check speech — say it aloud, then mark yourself."));
        const said = el("button", { className: "speak-btn", type: "button" });
        said.innerHTML = `<svg class="licon licon-sm"><use href="#i-volume"/></svg> I said it`;
        said.addEventListener("click", () => { if (!studyAnswered) settle(true, `<span class="ok">✓ Nice</span>`); });
        face.append(said, fb);
      }
      setWriteGate(false);                       // locked until they attempt
      $("#studyContinueWrap").classList.remove("hidden");
    } else if (curDir === "sentence") {
      // Tap word tiles to assemble the sentence; the button checks, then advances.
      choices.classList.remove("hidden");
      const pool = devSentence ? [devSentence] : sentencesFor(c);
      buildSentenceExercise(face, choices, pool[Math.floor(Math.random() * pool.length)],
        $("#promptLabel"), correct => answerStudy(correct));
      $("#studyContinueWrap").classList.remove("hidden");
      $("#studyContinueWrap").classList.add("reserve", "short");
    } else {
      // Objective multiple choice: mascot asks, you pick, it marks you.
      choices.classList.remove("hidden");
      buildChoiceExercise(face, choices, c, curDir, $("#promptLabel"), (correct, chosen) => {
        answerStudy(correct);
        feedbackBanner($("#studyContinueWrap"), correct, c, curDir, chosen);
        $("#studyContinueWrap").classList.remove("hidden");
        setWriteGate(true);
      });
      // The answer's feedback appears in a slot kept for it from the start,
      // so answering never moves the question or the choices.
      $("#studyContinueWrap").classList.remove("hidden");
      $("#studyContinueWrap").classList.add("reserve");
      setWriteGate(false);
    }
    updateStudyProgress();
  }

  // Animated red stroke-order reference box for one character (loops, tap-replay).
  // Past the first stage the answer isn't on screen; Peek shows it briefly.
  function peekBox(ch, size) {
    const box = el("button", { className: "tzg-cell peek-box", type: "button", title: "Peek at the character" });
    box.style.width = box.style.height = size + "px";
    box.innerHTML = `<svg class="licon"><use href="#i-eye"/></svg><span>Peek</span>`;
    box.addEventListener("click", () => {
      if (box.dataset.open) return;
      box.dataset.open = "1"; box.innerHTML = "";
      const ref = refAnimBox(ch, size); ref.style.border = "0"; box.appendChild(ref);
      setTimeout(() => { delete box.dataset.open; box.innerHTML = `<svg class="licon"><use href="#i-eye"/></svg><span>Peek</span>`; }, 3200);
    });
    return box;
  }
  function refAnimBox(ch, size) {
    const accent = getComputedStyle(document.body).getPropertyValue("--accent").trim() || "#2b776d";
    const box = el("div", { className: "tzg-cell", style: "cursor:pointer" });
    box.style.width = box.style.height = size + "px";
    const w = makeWriter(box, ch, { width: size, height: size, showCharacter: true, strokeColor: accent });
    box.addEventListener("click", () => w.animateCharacter());
    let n = 0;
    const play = () => w.animateCharacter({ onComplete: () => { if (++n < 2) setTimeout(play, 500); } });
    w.hideCharacter(); play();
    return box;
  }

  // Desktop/tablet: all characters in a grid on one page.
  function renderWriteDesktop(face, chars, checkOn) {
    const avail = (face.clientWidth || 340) - 4;
    const refSize = Math.max(56, Math.min(96, Math.floor((avail - (chars.length - 1) * 12) / chars.length)));
    const stage = checkOn ? writeStage(curCard) : 0;
    const refRow = el("div", { className: "writing-inline", style: "gap:12px" });
    face.appendChild(refRow);
    chars.forEach(ch => refRow.appendChild(!hasStrokes(ch) ? el("div", { className: "hanzi" }, ch) : stage === 0 ? refAnimBox(ch, refSize) : peekBox(ch, refSize)));
    face.appendChild(el("div", { className: "muted", style: "font-size:.78rem" }, stage === 0 ? "stroke order — tap a character to replay" : `${STAGE_INFO[stage].chip}: ${STAGE_INFO[stage].note}`));

    const cols = chars.length === 1 ? (checkOn ? 3 : 4) : chars.length;
    const cell = checkOn
      ? Math.max(62, Math.min(112, Math.floor(avail / cols)))
      : Math.max(50, Math.min(88, Math.floor(avail / cols)));
    setWriteGate(!checkOn);   // stroke-check mode stays locked until it's written
    if (checkOn) {
      face.appendChild(el("div", { className: "muted", style: "margin-top:8px" },
        "write each character once to continue — wrong strokes won’t register; a hint appears after 2 misses"));
      buildCheckGrid(face, chars, { rows: 2, cols, cell, stage, onAllDone: () => setWriteGate(true) });
    } else {
      face.appendChild(el("div", { className: "muted", style: "margin-top:8px" },
        "trace each row — the guide fades; the last row is from memory"));
      writeInk = buildCopybook(face, chars, { rows: 4, cols, cell });
      face.appendChild(el("div", { className: "writing-inline", style: "gap:8px;margin-top:10px" }, [
        (() => { const b = el("button", { className: "ghost" }, "Undo ↶"); b.addEventListener("click", () => writeInk && writeInk.undo()); return b; })(),
        (() => { const b = el("button", { className: "ghost" }, "Clear ✕"); b.addEventListener("click", () => writeInk && writeInk.clear()); return b; })()
      ]));
    }
    $("#studyReveal").classList.add("hidden");
    $("#studyNext").classList.add("hidden");
    $("#studyContinueWrap").classList.remove("hidden");
  }

  // Phone: ONE big writing box that dominates the screen (Duolingo-style),
  // paged with a pinned "Next character →". Minimal chrome around the box.
  function renderWritePhone(face, c, chars, checkOn) {
    face.style.justifyContent = "flex-start";
    const pageWrap = el("div", { style: "width:100%;display:flex;flex-direction:column;align-items:center;gap:10px" });
    face.appendChild(pageWrap);
    const renderPage = () => {
      pageWrap.innerHTML = "";
      const ch = chars[writeCharIdx];
      const N = chars.length, last = writeCharIdx === N - 1;

      // Compact one-line header: small animated stroke-order + prompt + audio.
      const stage = checkOn ? writeStage(c) : 0;
      const header = el("div", { className: "write-head" });
      if (hasStrokes(ch)) header.appendChild(stage === 0 ? refAnimBox(ch, 50) : peekBox(ch, 50));
      header.appendChild(el("div", { className: "wh-txt" }, [
        el("div", { className: "pinyin", style: "font-size:1.15rem;line-height:1.15" }, pySpans(c.pinyin)),
        el("div", { className: "muted", style: "font-size:.9rem" }, c.en + (N > 1 ? `  ·  ${writeCharIdx + 1}/${N}` : ""))
      ]));
      // the title says what this stage asks for, with the stage as a chip beside it
      if (checkOn) {
        const lbl = $("#promptLabel"); lbl.textContent = ["Trace, then write it", "Write it", "Write it from memory"][stage] + " ";
        lbl.appendChild(el("span", { className: "wstage s" + stage }, STAGE_INFO[stage].chip));
      }
      header.appendChild(speakerBtn(c.hanzi));
      pageWrap.appendChild(header);

      // Each page must be written before its advance button unlocks.
      setWriteGate(!(checkOn && hasStrokes(ch)));
      if (hasStrokes(ch)) {
        // The box fills the on-screen space between the header and the controls.
        const gap = face.getBoundingClientRect().bottom - header.getBoundingClientRect().bottom - 84;
        const box = Math.max(180, Math.min((face.clientWidth || 340) - 8, gap, 460));
        if (checkOn) {
          buildCheckGrid(pageWrap, [ch], { rows: 1, cols: 1, cell: box, tight: true, stage, onAllDone: () => setWriteGate(true) });
          pageWrap.appendChild(el("div", { className: "wstage-note" }, STAGE_INFO[stage].note));
          const redo = el("button", { className: "ghost", style: "margin-top:2px" }, "↺ Clear");
          redo.addEventListener("click", renderPage);
          pageWrap.appendChild(redo);
        } else {
          writeInk = buildCopybook(pageWrap, [ch], { rows: 1, cols: 1, cell: box, tight: true });
          pageWrap.appendChild(el("div", { className: "writing-inline", style: "gap:8px;margin-top:6px" }, [
            (() => { const b = el("button", { className: "ghost" }, "Undo ↶"); b.addEventListener("click", () => writeInk && writeInk.undo()); return b; })(),
            (() => { const b = el("button", { className: "ghost" }, "Clear ✕"); b.addEventListener("click", () => writeInk && writeInk.clear()); return b; })()
          ]));
        }
      } else {
        pageWrap.appendChild(el("div", { className: "hanzi" }, ch));
      }

      // Pinned action at the card bottom (always visible, never scrolls away).
      if (last) {
        writeNextFn = null;
        $("#studyReveal").classList.add("hidden");
        $("#studyContinueWrap").classList.remove("hidden");
      } else {
        writeNextFn = () => { writeCharIdx++; renderPage(); };
        $("#studyContinueWrap").classList.add("hidden");
        $("#studyNext").textContent = `Next character (${writeCharIdx + 1}/${N}) →`;
        $("#studyNext").classList.remove("hidden");
        $("#studyReveal").classList.remove("hidden");
      }
    };
    renderPage();
  }

  /* ---- Feedback banner -----------------------------------------------
     The same treatment on every exercise: a banner slides up beside the
     Continue button, green with a word of praise or red with the right
     answer, and the button takes the colour. */
  const PRAISE = ["Nice!", "Great job!", "Excellent!", "Spot on!", "太棒了!", "对了!"];
  function feedbackBanner(wrapEl, correct, c, dir, chosen) {
    if (!wrapEl) return;
    clearFeedback(wrapEl);
    const fb = el("div", { className: "sent-fb " + (correct ? "ok" : "bad") });
    fb.innerHTML = `<svg class="licon"><use href="#${correct ? "i-tick" : "i-x"}"/></svg>`;
    const body = el("div");
    body.appendChild(el("div", { className: "fb-t" }, correct ? PRAISE[Math.floor(Math.random() * PRAISE.length)] : "Correct answer:"));
    // what to show: the whole word, with the part they were asked for first
    const first = dir === "recognize" ? "en" : dir === "pinyin" ? "py" : "hz";
    const piece = k => k === "en" ? document.createTextNode(c.en) : k === "py" ? pySpans(c.pinyin) : hzSpans(c.hanzi, c.pinyin, true);
    body.appendChild(el("div", { className: "fb-a" }, piece(first)));
    const rest = el("div", { className: "fb-py" });
    ["hz", "py", "en"].filter(k => k !== first).forEach((k, i) => { if (i) rest.appendChild(document.createTextNode(" · ")); rest.appendChild(piece(k)); });
    body.appendChild(rest);
    const picked = !correct && chosen && (dir === "recall" ? CARDS.find(x => x.hanzi === chosen) : dir === "recognize" ? CARDS.find(x => x.en === chosen) : null);
    const diff = picked && wordSim(c.hanzi, picked.hanzi) >= 1.5 && diffBlock(c, picked);
    if (diff) { body.querySelector(".fb-t").textContent = "Nearly! Those two look alike"; body.appendChild(diff); }
    else if ([...c.hanzi].some(ch => CHD.chars[ch])) body.appendChild(el("div", { className: "fb-tip" }, "Tap a character to see how it's built"));
    fb.appendChild(body);
    wrapEl.insertBefore(fb, wrapEl.firstChild);
    wrapEl.classList.add(correct ? "ok" : "bad", "wide");
    // the bar sticks to the bottom of the card; bring the last option out from under it
    // (with a reserved slot nothing needs bringing into view, and moving would be the drift)
    const stage = wrapEl.closest(".stage");
    if (stage && !wrapEl.classList.contains("reserve")) { const down = () => { stage.scrollTop = stage.scrollHeight; }; requestAnimationFrame(down); setTimeout(down, 320); }
  }
  function clearFeedback(wrapEl) {
    if (!wrapEl) return;
    wrapEl.querySelectorAll(".sent-fb").forEach(n => n.remove());
    wrapEl.classList.remove("ok", "bad");
  }

  /* ---- Session complete, in stages -------------------------------------
     Three tiles that count up, then the streak with this week's days, then
     today's quests. One Continue button walks through them. */
  const fmtTime = s => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
  let doneStage = 0, doneStageCount = 1;
  function tick(node, to, render) {
    const t0 = performance.now(), dur = 700;
    const step = now => {
      const k = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - k, 3);
      node.textContent = render(Math.round(to * e));
      if (k < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }
  let doneFire = null;
  function startDoneSequence(tiles, fire = null) {
    doneFire = fire;
    $("#doneStats").classList.add("hidden");
    const box = $("#doneTiles"); box.classList.remove("hidden"); box.innerHTML = "";
    tiles.forEach((t, i) => {
      const d = el("div", { className: "dt " + t.cls });
      const b = el("b", {}, "0"), s = el("span", {}, t.label);
      d.append(s, b); box.appendChild(d);
      setTimeout(() => { d.classList.add("in"); tick(b, t.value, v => `${t.prefix || ""}${t.fmt ? t.fmt(v) : v}${t.suffix || ""}`); }, 200 + i * 220);
    });
    // stage two: the streak
    const s = computeStreak(), lit = litOn(todayStr());
    $("#doneStreak").textContent = s;
    $("#doneStreakMsg").textContent = fire ? (s === 1 ? "Fire lit. Come back tomorrow to make it two." : (MILESTONE_WORDS[s] || "Fire lit. Keep it going tomorrow."))
      : lit ? "Already lit today. Keep it going tomorrow." : "Finish a session to light today's fire.";
    $(".done-stage.s2").classList.toggle("lit", lit);
    const ne = embers();
    $("#doneEmbers").innerHTML = `${svgUse("i-ember")} ${fire && fire.ember ? "You earned an ember · " : ""}${ne} ember${ne === 1 ? "" : "s"} protecting it`;
    renderWeekStrip($("#doneWeek"));
    // stage three: the quests
    const q = todayQuests(), done = questRowsInto($("#doneQuests"), q);
    $("#doneQuestSub").textContent = done === 3 ? "All three done. Chest opened!" : `${done} of 3 done today`;
    doneStageCount = 3;
    showDoneStage(0);
  }
  function doneSimple() {
    $("#doneStats").classList.remove("hidden");
    $("#doneTiles").classList.add("hidden");
    $("#doneNotes").innerHTML = "";
    doneStageCount = 1;
    showDoneStage(0);
  }
  function showDoneStage(i) {
    doneStage = i;
    document.querySelectorAll(".done-stage").forEach((st, k) => st.classList.toggle("hidden", k !== i));
    const last = i >= doneStageCount - 1;
    $("#doneContinue").classList.toggle("hidden", last);
    $(".done-final").classList.toggle("hidden", !last);
    if (i === 1) {
      if (doneFire && doneFire.milestone) { sfx("milestone"); setTimeout(() => celebrateMilestone(doneFire.streak, doneFire.ember), 900); }
      else if (doneFire) { sfx("goal"); buzz(true); }
    }
  }

  function finishStudy() {
    doneAction = null;
    // A lesson completes once ALL its words are cleared — which can take a few
    // batches for a big lesson, not just one round.
    let justFinished = null;
    const scopedId = (!reviewMode && scopeLessons && scopeLessons.size === 1) ? [...scopeLessons][0] : null;
    if (scopedId && !doneLessons.has(scopedId) && lessonCleared(scopedId)) {
      doneLessons.add(scopedId); saveDone(); justFinished = scopedId;
      // finishing a chapter opens its story
      const ci = CHAPTERS.findIndex(ch => ch.lessons.includes(scopedId)), story = readingFor(ci);
      if (story && chapterDone(ci) && !readDone(story.id)) setTimeout(() => toast(`New story unlocked: ${story.title}. Find it in Reading.`), 2200);
    }
    const upNext = justFinished ? nextLessonId(justFinished) : null;
    questEvent("session", true, { lesson: !!justFinished, perfect: studyStats.again === 0 && studyStats.answered >= 5 });
    // Words still to clear in this lesson (a long lesson comes in batches).
    const remaining = (scopedId && !justFinished)
      ? CARDS.filter(c => c.lessonId === scopedId && !(srs[c.id] && srs[c.id].reps >= 1)).length
      : 0;

    $("#doneTitle").textContent = mistakesMode ? "Mistakes practised" : reviewMode ? "Review complete"
      : justFinished ? "Lesson complete"
      : remaining ? "Batch done" : "Session complete";
    sfx("complete");
    earnXP(justFinished ? XP.lesson : XP.session);
    const perfect = studyStats.again === 0 && studyStats.answered >= 5;
    if (perfect) earnXP(XP.perfect);
    if (justFinished) startBoost();
    const acc = studyStats.answered ? Math.round((studyStats.answered - studyStats.again) / studyStats.answered * 100) : 100;
    const fire = lightFire();
    startDoneSequence([
      { value: sessionXP, label: "XP", prefix: "+", cls: "xp" },
      { value: Math.round((Date.now() - sessionStart) / 1000), label: "Time", fmt: fmtTime, cls: "time" },
      { value: acc, label: "Accuracy", suffix: "%", cls: "acc" }
    ], fire);
    renderDoneNotes(perfect, justFinished);
    const nextBtn = $("#doneNext");
    if (upNext) {
      const l = LESSONS.find(x => x.id === upNext);
      nextBtn.textContent = `Next: ${l.title.replace(/^.*?· /, "")} →`;
      nextBtn.dataset.next = upNext;
      nextBtn.classList.remove("hidden");
    } else if (remaining) {
      nextBtn.textContent = `Keep going — ${remaining} word${remaining === 1 ? "" : "s"} left →`;
      nextBtn.dataset.next = scopedId;
      nextBtn.classList.remove("hidden");
    } else nextBtn.classList.add("hidden");
    $("#doneAgain").classList.remove("hidden");
    saveSRS(srs);
    show("done");
  }

  $("#doneContinue").addEventListener("click", () => showDoneStage(doneStage + 1));
  $("#studyNext").addEventListener("click", () => { if (writeNextFn) writeNextFn(); });
  $("#studyContinue").addEventListener("click", () => {
    // Sentence mode: first press checks the answer, second advances.
    if (!studyAnswered && studyCheckFn) { studyCheckFn(); return; }
    if (!studyAnswered) answerStudy(true);   // write mode: finishing the character = correct
    nextStudyCard();
  });
  $("#studyBack").addEventListener("click", () => { goBack(); });
  $("#studyShuffle").addEventListener("click", () => {
    // new words keep their order: each group is met before it is practised
    if (queue.some(x => x.meet)) { toast("Shuffle is available once all the new words have been introduced."); return; }
    if (curCard && !studyAnswered) queue.push(curCard);
    queue = shuffle(queue); nextStudyCard();
  });

  /* ==================================================================== */
  /*  QUIZ (multiple choice)                                              */
  /* ==================================================================== */

  let quizItems = [], quizIdx = 0, quizScore = 0;
  // Placement / "skip test": pass a quick test to unlock lessons you already know.
  let quizMode = "quiz";
  let placeRange = [], placeTarget = null, placeScores = {}, placeCorrectCards = new Set();

  // Build a skip test covering every not-yet-done lesson up to (and including)
  // the target. Passing unlocks the longest run of lessons you're solid on.
  function startPlacement(targetId, label = "Skip test") {
    const order = LESSONS.map(l => l.id);
    const ti = order.indexOf(targetId);
    const range = [];
    for (let i = 0; i <= ti; i++) if (!doneLessons.has(order[i])) range.push(order[i]);
    if (!range.length) { toast("That's already unlocked."); return; }
    const perLesson = Math.max(2, Math.min(5, Math.floor(20 / range.length)));
    placeScores = {}; placeCorrectCards = new Set();
    const items = [];
    range.forEach(lid => {
      placeScores[lid] = { ok: 0, total: 0 };
      const cards = CARDS.filter(c => c.lessonId === lid);
      shuffle(cards).slice(0, Math.min(perLesson, cards.length)).forEach(c => items.push(c));
    });
    quizItems = shuffle(items);
    quizIdx = 0; quizScore = 0; quizMode = "placement";
    placeRange = range; placeTarget = targetId;
    scopeLessons = new Set(range);                     // distractors drawn from the tested range
    scopeFocuses = new Set(["recognize", "recall"]);   // clean "do you know this word" tests
    $("#quizTitle").textContent = `${label} · ${quizItems.length} question${quizItems.length === 1 ? "" : "s"}`;
    show("quiz");
    renderQuiz();
  }

  function finishPlacement() {
    doneAction = null;
    quizMode = "quiz";
    const PASS = 0.7;
    const unlocked = [];
    for (const lid of placeRange) {          // linear: stop at the first lesson you don't clear
      const s = placeScores[lid] || { ok: 0, total: 0 };
      if (s.total && s.ok / s.total >= PASS) unlocked.push(lid); else break;
    }
    unlocked.forEach(lid => doneLessons.add(lid));
    if (unlocked.length) saveDone();
    placeCorrectCards.forEach(id => {          // seed known words so they don't read as brand-new
      const card = CARD_BY_ID[id];
      if (card && unlocked.includes(card.lessonId) && !srs[id])
        srs[id] = { ease: 2.4, interval: 3, due: NOW() + 3 * DAY, reps: 2, prod: true };
    });
    if (unlocked.length) saveSRS(srs);
    scopeLessons = null; scopeFocuses = null;
    const reachedTarget = unlocked.includes(placeTarget);
    doneSimple();
    $("#doneTitle").textContent = !unlocked.length ? "Not yet"
      : reachedTarget ? "You tested out!" : "Skipped ahead";
    sfx(unlocked.length ? "complete" : "wrong");
    $("#doneStats").innerHTML = "";
    $("#doneStats").append(
      statEl(`${quizScore}/${quizItems.length}`, "correct"),
      statEl(unlocked.length, unlocked.length === 1 ? "lesson unlocked" : "lessons unlocked")
    );
    $("#doneNext").classList.add("hidden");
    $("#doneAgain").classList.add("hidden");
    show("done");
    toast(!unlocked.length
      ? "Keep studying from where you are — you'll get there."
      : reachedTarget ? "Unlocked all the way to your target — nice!"
      : "Unlocked what you're solid on — the rest needs a little more study.");
  }

  function startQuiz() {
    const cards = activeCards();
    if (cards.length < 3) { toast("Pick more lessons — a quiz needs at least 3 words."); $("#studyPanel").open = true; return; }
    quizItems = shuffle(cards).slice(0, Math.min(20, cards.length));
    quizIdx = 0; quizScore = 0; quizMode = "quiz"; combo = 0; sessionXP = 0; sessionStart = Date.now();
    $("#quizTitle").textContent = `Quiz · ${quizItems.length} questions`;
    show("quiz");
    renderQuiz();
  }

  function renderQuiz() {
    if (quizIdx >= quizItems.length) return quizMode === "placement" ? finishPlacement() : finishQuiz();
    const c = quizItems[quizIdx];
    clearFeedback($("#quizNextWrap"));
    { const st = $("#quiz .stage"); if (st) st.scrollTop = 0; }
    pulseBar($("#quizBar"));
    // Direction: only multiple-choice types (write/sentence/speak aren't MC).
    let dirs = [...(scopeFocuses || selectedFocuses)].filter(k => k !== "write" && k !== "sentence" && k !== "speak");
    if (dirs.length === 0) dirs = ["recognize"];
    const dir = dirs[Math.floor(Math.random() * dirs.length)];

    $("#quizBar").style.width = `${(quizIdx / quizItems.length) * 100}%`;
    buildChoiceExercise($("#quizFace"), $("#quizChoices"), c, dir, $("#quizPromptLabel"), (correct, chosen) => {
      sfx(correct ? "correct" : "wrong"); buzz(correct);
      feedbackBanner($("#quizNextWrap"), correct, c, dir, chosen);
      if (correct) quizScore++;
      answerXP(correct);
      questEvent(dir, correct);
      if (quizMode === "placement") {
        const s = placeScores[c.lessonId] || (placeScores[c.lessonId] = { ok: 0, total: 0 });
        s.total++; if (correct) { s.ok++; placeCorrectCards.add(c.id); }
      } else {
        schedule(c.id, correct ? "good" : "again");
        recordReview(1);
      }
      $("#quizNext").disabled = false;
    });
    // feedback slot kept from the start, so answering doesn't move anything
    $("#quizNextWrap").classList.remove("hidden");
    $("#quizNextWrap").classList.add("reserve");
    $("#quizNext").disabled = true;
  }

  $("#quizNext").addEventListener("click", () => { quizIdx++; renderQuiz(); });
  $("#quizBack").addEventListener("click", () => { goBack(); });

  function finishQuiz() {
    doneAction = null;
    const perfect = quizItems.length >= 5 && quizScore === quizItems.length;
    questEvent("session", true, { perfect });
    $("#doneTitle").textContent = "Quiz complete";
    sfx("complete");
    earnXP(XP.session);
    if (perfect) earnXP(XP.perfect);
    const pct = Math.round((quizScore / quizItems.length) * 100);
    const fire = lightFire();
    startDoneSequence([
      { value: sessionXP, label: "XP", prefix: "+", cls: "xp" },
      { value: Math.round((Date.now() - sessionStart) / 1000), label: "Time", fmt: fmtTime, cls: "time" },
      { value: pct, label: "Accuracy", suffix: "%", cls: "acc" }
    ], fire);
    renderDoneNotes(perfect, false);
    $("#doneAgain").classList.add("hidden");   // redo is a Study feature
    show("done");
  }

  /* ==================================================================== */
  /*  BROWSE                                                              */
  /* ==================================================================== */

  function startBrowse() {
    const body = $("#browseBody");
    body.innerHTML = "";
    let curLesson = null;
    activeCards().forEach(c => {
      if (c.lessonId !== curLesson) {
        curLesson = c.lessonId;
        const th = el("td", { colSpan: 4, style: "background:var(--accent-soft);font-weight:700;" }, c.lessonTitle);
        body.appendChild(el("tr", {}, th));
      }
      const actions = el("td", {}, [speakerBtn(c.hanzi)]);
      if (HW_OK && cjkOnly(c.hanzi).length) actions.appendChild(strokeBtn(c.hanzi, c.pinyin));
      const tr = el("tr", {}, [
        el("td", { className: "h" }, c.hanzi),
        el("td", { className: "p" }, prettyPinyin(c.pinyin)),
        el("td", {}, c.pos ? `${c.en}  ·  ${c.pos}` : c.en),
        actions
      ]);
      body.appendChild(tr);
    });
    $("#browseTitle").textContent = `Browse · ${activeCards().length} words`;
    show("browse");
  }
  $("#browseBack").addEventListener("click", () => { goBack(); });

  /* ==================================================================== */
  /*  PICK & PRACTISE — choose any words, then flashcards / match / quiz  */
  /* ==================================================================== */

  const pickSel = new Set();            // chosen card ids (kept across visits)
  let pickFilter = "";

  function openPicker() { renderPicker(); show("pick"); }

  function pickedCards() { return CARDS.filter(c => pickSel.has(c.id)); }

  function updatePickCount() {
    const n = pickSel.size;
    $("#pickCount").textContent = `${n} chosen`;
    document.querySelectorAll(".pick-actions button").forEach(b => b.disabled = n < 1);
  }

  function renderPicker() {
    // Preset chips
    const presets = $("#pickPresets"); presets.innerHTML = "";
    const chip = (label, fn) => { const b = el("button", { className: "pick-chip", type: "button" }, label); b.addEventListener("click", fn); presets.appendChild(b); };
    chip("＋ Current lesson", () => { CARDS.filter(c => c.lessonId === currentLessonId()).forEach(c => pickSel.add(c.id)); renderPicker(); });
    chip("＋ Still learning", () => { CARDS.forEach(c => { const s = srs[c.id]; if (s && !isMastered(s)) pickSel.add(c.id); }); renderPicker(); });
    chip("＋ Due for review", () => { dueReviewCards().forEach(c => pickSel.add(c.id)); renderPicker(); });
    chip("✕ Clear", () => { pickSel.clear(); renderPicker(); });

    const q = pickFilter.trim().toLowerCase();
    // Match pinyin WITHOUT tone marks and with spaces optional, so a beginner can
    // type "ni hao" or "nihao" (not just "nǐ hǎo") and still find the word.
    const qp = tonelessPinyin(q), qpNoSpace = qp.replace(/\s+/g, "");
    const match = c => {
      if (!q) return true;
      if (c.hanzi.includes(q) || c.en.toLowerCase().includes(q)) return true;
      const py = tonelessPinyin(c.pinyin).toLowerCase();
      return py.includes(qp) || py.replace(/\s+/g, "").includes(qpNoSpace);
    };

    const list = $("#pickList"); list.innerHTML = "";
    let curLesson = null, group = null;
    CARDS.filter(match).forEach(c => {
      if (c.lessonId !== curLesson) {
        curLesson = c.lessonId;
        // Each lesson is its own block so its sticky header stays pinned only
        // WHILE that block is on screen — flat siblings all pin at top:0 at once
        // and pile up (a tall 2-line header peeking under the next single one,
        // and stacked headers hiding the top rows' 汉字).
        group = el("div", { className: "pick-group" });
        const head = el("div", { className: "pick-lhead" });
        const title = el("span", {}, c.lessonTitle.replace(/^.*?· /, ""));
        const all = el("button", { className: "link", type: "button" }, "all");
        all.addEventListener("click", () => {
          const cards = CARDS.filter(x => x.lessonId === c.lessonId && match(x));
          const every = cards.every(x => pickSel.has(x.id));
          cards.forEach(x => every ? pickSel.delete(x.id) : pickSel.add(x.id));
          renderPicker();
        });
        head.append(title, all);
        group.appendChild(head);
        list.appendChild(group);
      }
      const row = el("label", { className: "pick-row" });
      const cb = el("input", { type: "checkbox" });
      cb.checked = pickSel.has(c.id);
      cb.addEventListener("change", () => { cb.checked ? pickSel.add(c.id) : pickSel.delete(c.id); updatePickCount(); });
      row.append(cb,
        el("span", { className: "pk-han" }, c.hanzi),
        el("span", { className: "pk-py" }, prettyPinyin(c.pinyin)),
        el("span", { className: "pk-en" }, c.en));
      group.appendChild(row);
    });
    if (!list.children.length) list.appendChild(el("p", { className: "muted", style: "padding:10px" }, "No words match that search."));
    updatePickCount();
  }

  $("#pickSearch").addEventListener("input", e => { pickFilter = e.target.value; renderPicker(); });
  $("#pickBack").addEventListener("click", () => show("home"));
  document.querySelectorAll(".pick-actions button").forEach(btn => btn.addEventListener("click", () => {
    const cards = pickedCards();
    if (!cards.length) { toast("Tick some words first."); return; }
    const m = btn.dataset.pmode;
    if (m === "flash") startFlash(cards);
    else if (m === "match") startMatch(cards);
    else if (m === "quiz") startQuizOn(cards);
  }));

  /* ---- Flashcards ---------------------------------------------------- */
  let flashCards = [], flashIdx = 0;

  function startFlash(cards) {
    flashCards = shuffle(cards.slice()); flashIdx = 0;
    show("flash"); renderFlash();
  }
  function renderFlash() {
    const c = flashCards[flashIdx];
    $("#flashCount").textContent = `${flashIdx + 1} / ${flashCards.length}`;
    $("#flashBar").style.width = `${((flashIdx + 1) / flashCards.length) * 100}%`;
    const card = $("#flashCard");
    card.className = "flashcard";
    card.innerHTML = "";
    const front = el("div", { className: "fc-face fc-front" }, [
      el("div", { className: "fc-han" + (cjkOnly(c.hanzi).length > 3 ? " small" : "") }, c.hanzi),
      el("div", { className: "fc-tip muted" }, "tap to flip")
    ]);
    const back = el("div", { className: "fc-face fc-back" }, [
      el("div", { className: "fc-py" }, prettyPinyin(c.pinyin)),
      el("div", { className: "fc-en" }, c.pos ? `${c.en} · ${c.pos}` : c.en)
    ]);
    const aids = el("div", { className: "fc-aids" }, [speakerBtn(c.hanzi), slowSpeakerBtn(c.hanzi)]);
    if (HW_OK && cjkOnly(c.hanzi).length) aids.appendChild(strokeBtn(c.hanzi, c.pinyin));
    back.appendChild(aids);
    card.append(front, back);
    card.onclick = e => { if (e.target.closest("button")) return; card.classList.toggle("flipped"); };
  }
  const flashStep = d => { flashIdx = (flashIdx + d + flashCards.length) % flashCards.length; renderFlash(); };
  $("#flashPrev").addEventListener("click", () => flashStep(-1));
  $("#flashNext").addEventListener("click", () => flashStep(1));
  $("#flashFlip").addEventListener("click", () => $("#flashCard").classList.toggle("flipped"));
  $("#flashShuffle").addEventListener("click", () => { flashCards = shuffle(flashCards); flashIdx = 0; renderFlash(); });
  $("#flashBack").addEventListener("click", () => show("pick"));

  /* ---- Matching game ------------------------------------------------- */
  let matchQueue = [], matchFirst = null, matchLeft = 0, matchTotal = 0, matchDone = 0;

  function startMatch(cards) {
    // Two words that mean the same thing (中文 / 汉语 = "Chinese (language)") would
    // make two indistinguishable meaning tiles and score a correct pairing as wrong.
    // Keep one card per meaning so every tile is uniquely matchable.
    const seenEn = new Set(), uniq = [];
    shuffle(cards.slice()).forEach(c => { if (!seenEn.has(c.en)) { seenEn.add(c.en); uniq.push(c); } });
    if (uniq.length < 3) { toast("Pick at least 3 words with different meanings to match."); return; }
    matchQueue = uniq;
    matchTotal = matchQueue.length; matchDone = 0;
    show("match"); nextMatchRound();
  }
  function nextMatchRound() {
    const round = matchQueue.splice(0, Math.min(6, matchQueue.length));
    matchLeft = round.length; matchFirst = null;
    const tiles = [];
    round.forEach(c => { tiles.push({ id: c.id, kind: "han", text: c.hanzi }); tiles.push({ id: c.id, kind: "en", text: c.en }); });
    const grid = $("#matchGrid"); grid.innerHTML = "";
    shuffle(tiles).forEach(t => {
      const b = el("button", { className: "match-tile " + (t.kind === "han" ? "mt-han" : "mt-en") }, t.text);
      b.dataset.id = t.id; b.dataset.kind = t.kind;
      b.addEventListener("click", () => onMatchTap(b));
      grid.appendChild(b);
    });
    $("#matchCount").textContent = `${matchDone} / ${matchTotal}`;
    $("#matchMsg").textContent = "Tap a character, then its meaning.";
  }
  function onMatchTap(b) {
    if (b.classList.contains("matched") || b.classList.contains("miss")) return;
    if (!matchFirst) { matchFirst = b; b.classList.add("sel"); return; }
    if (b === matchFirst) { b.classList.remove("sel"); matchFirst = null; return; }
    const a = matchFirst; matchFirst = null; a.classList.remove("sel");
    if (a.dataset.id === b.dataset.id && a.dataset.kind !== b.dataset.kind) {
      a.classList.add("matched"); b.classList.add("matched");
      sfx("correct");
      const card = CARD_BY_ID[a.dataset.id]; if (card) speak(card.hanzi);
      matchLeft--; matchDone++;
      $("#matchCount").textContent = `${matchDone} / ${matchTotal}`;
      if (matchLeft === 0) {
        if (matchQueue.length) { $("#matchMsg").textContent = "Nice — next set…"; setTimeout(nextMatchRound, 650); }
        else finishMatch();
      }
    } else {
      sfx("wrong");
      a.classList.add("miss"); b.classList.add("miss");
      setTimeout(() => { a.classList.remove("miss"); b.classList.remove("miss"); }, 450);
    }
  }
  function finishMatch() {
    doneSimple();
    $("#doneTitle").textContent = "Matching done";
    sfx("complete");
    $("#doneStats").innerHTML = "";
    $("#doneStats").append(statEl(matchTotal, matchTotal === 1 ? "pair matched" : "pairs matched"));
    doneAction = () => startMatch(pickedCards());
    $("#doneNext").innerHTML = `<svg class="licon licon-sm"><use href="#i-shuffle"/></svg> Again`;
    delete $("#doneNext").dataset.next;
    $("#doneNext").classList.remove("hidden");
    $("#doneAgain").classList.add("hidden");
    show("done");
  }
  $("#matchBack").addEventListener("click", () => show("pick"));

  /* ---- Quiz over the picked words ------------------------------------ */
  function startQuizOn(cards) {
    if (cards.length < 3) { toast("Pick at least 3 words to quiz."); return; }
    scopeLessons = new Set(cards.map(c => c.lessonId));        // plausible distractors
    scopeFocuses = new Set(["recognize", "recall", "pinyin", "listen"]);
    quizItems = shuffle(cards.slice()).slice(0, Math.min(20, cards.length));
    quizIdx = 0; quizScore = 0; quizMode = "quiz"; combo = 0; sessionXP = 0; sessionStart = Date.now();
    $("#quizTitle").textContent = `Quiz · ${quizItems.length} questions`;
    show("quiz"); renderQuiz();
  }

  /* ==================================================================== */
  /*  DONE / shared                                                       */
  /* ==================================================================== */

  function statEl(value, label) {
    const b = el("b");
    if (typeof value === "string" && value.startsWith("<")) b.innerHTML = value; else b.textContent = String(value);
    return el("span", { className: "stat" }, [b, el("div", { className: "muted" }, label)]);
  }
  // A one-shot action for the done screen's primary button (used by Matching's
  // "Again"); lesson flows leave it null and fall through to the dataset.next path.
  let doneAction = null;
  $("#doneHome").addEventListener("click", () => { doneAction = null; goBack(); });
  $("#doneNext").addEventListener("click", () => {
    if (doneAction) { const fn = doneAction; doneAction = null; $("#doneNext").classList.add("hidden"); fn(); return; }
    const id = $("#doneNext").dataset.next;
    if (id) { $("#doneNext").classList.add("hidden"); launchLesson(id, null); }
  });
  $("#doneAgain").addEventListener("click", () => {
    $("#doneAgain").classList.add("hidden");
    beginStudySession(studySource);   // re-run the exact same set
  });

  /* ==================================================================== */
  /*  SETTINGS & HELP                                                     */
  /* ==================================================================== */

  function openModal(id) { $("#" + id).classList.remove("hidden"); }
  function closeModal(id) { $("#" + id).classList.add("hidden"); }

  function syncSettings() {
    const theme = prefs.theme || "system";
    $("#themeSeg").querySelectorAll("button").forEach(b => b.classList.toggle("on", b.dataset.theme === theme));
    $("#rateRange").value = audioRate();
    if ($("#appVersion")) $("#appVersion").textContent = APP_VERSION;
    if (typeof syncVoicePicker === "function") syncVoicePicker();
    const g = dailyGoal();
    $("#goalSeg").querySelectorAll("button").forEach(b => b.classList.toggle("on", +b.dataset.goal === g));
    $("#checkSwitch").classList.toggle("on", prefs.checkStrokes !== false);
    $("#soundSwitch").classList.toggle("on", prefs.sound !== false);
    $("#relightSwitch").classList.toggle("on", prefs.autoRelight !== false);
    $("#pinyinSwitch").classList.toggle("on", prefs.showPinyin !== false);
    $("#toneSwitch").classList.toggle("on", tonesOn());
    if ($("#nameInput") && document.activeElement !== $("#nameInput")) $("#nameInput").value = prefs.name || "";
    const bk = $("#backupAge");
    if (bk) {
      bk.textContent = backupAgeText();
      bk.classList.toggle("stale", !lastBackupAt() || (NOW() - lastBackupAt()) / DAY >= STALE_DAYS);
    }
  }
  function toggleCheck() {
    prefs.checkStrokes = prefs.checkStrokes === false ? true : false;
    savePrefs(prefs); syncSettings();
  }
  function toggleSound() {
    prefs.sound = prefs.sound === false ? true : false;
    savePrefs(prefs); syncSettings();
    if (prefs.sound) sfx("correct");   // little confirmation you can hear it
  }
  function togglePinyin() {
    prefs.showPinyin = prefs.showPinyin === false ? true : false;
    savePrefs(prefs); syncSettings();
  }
  const toggleTones = () => { prefs.toneColours = !tonesOn(); savePrefs(prefs); document.body.classList.toggle("tones", tonesOn()); syncSettings(); };
  $("#toneSwitch").addEventListener("click", toggleTones);
  $("#toneSwitch").addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggleTones(); } });
  $("#pinyinSwitch").addEventListener("click", togglePinyin);
  $("#pinyinSwitch").addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); togglePinyin(); } });
  if ($("#nameInput")) $("#nameInput").addEventListener("input", e => {
    prefs.name = e.target.value.slice(0, 24); savePrefs(prefs); renderHomeTop();
  });
  $("#checkSwitch").addEventListener("click", toggleCheck);
  $("#checkSwitch").addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggleCheck(); } });
  const toggleRelight = () => { prefs.autoRelight = prefs.autoRelight === false ? true : false; savePrefs(prefs); syncSettings(); };
  $("#relightSwitch").addEventListener("click", toggleRelight);
  $("#relightSwitch").addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggleRelight(); } });
  $("#soundSwitch").addEventListener("click", toggleSound);
  $("#soundSwitch").addEventListener("keydown", e => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggleSound(); } });
  $("#settingsBtn").addEventListener("click", () => { syncSettings(); renderAccount(); openModal("settingsModal"); });
  $("#settingsClose").addEventListener("click", () => closeModal("settingsModal"));
  $("#settingsModal").addEventListener("click", e => { if (e.target.id === "settingsModal") closeModal("settingsModal"); });
  $("#helpBtn").addEventListener("click", () => openModal("helpModal"));
  $("#helpClose").addEventListener("click", () => closeModal("helpModal"));
  $("#helpModal").addEventListener("click", e => { if (e.target.id === "helpModal") closeModal("helpModal"); });

  // ---- Tones primer ----
  const TONE_DEMO = [
    { n: "1st tone", desc: "high and flat", py: "mā", hz: "妈", en: "mother" },
    { n: "2nd tone", desc: "rising, like asking a question", py: "má", hz: "麻", en: "hemp" },
    { n: "3rd tone", desc: "dips down low, then rises", py: "mǎ", hz: "马", en: "horse" },
    { n: "4th tone", desc: "sharp and falling, like a command", py: "mà", hz: "骂", en: "to scold" }
  ];
  let tonesBuilt = false;
  function buildTonesRows() {
    const box = $("#tonesRows"); box.innerHTML = "";
    TONE_DEMO.forEach(t => {
      box.appendChild(el("div", { className: "tone-row" }, [
        el("div", { className: "tone-badge" }, t.py),
        el("div", { className: "tone-info" }, [
          el("div", {}, [el("b", {}, t.n), document.createTextNode(` — ${t.hz} ${t.en}`)]),
          el("div", { className: "muted", style: "font-size:.82rem" }, t.desc)
        ]),
        speakerBtn(t.hz)
      ]));
    });
    tonesBuilt = true;
  }
  function openTones() { if (!tonesBuilt) buildTonesRows(); openModal("tonesModal"); }
  $("#tonesClose").addEventListener("click", () => closeModal("tonesModal"));
  $("#tonesModal").addEventListener("click", e => { if (e.target.id === "tonesModal") closeModal("tonesModal"); });
  const helpTonesLink = $("#tonesFromHelp");
  if (helpTonesLink) helpTonesLink.addEventListener("click", () => { closeModal("helpModal"); openTones(); });

  $("#themeSeg").querySelectorAll("button").forEach(b =>
    b.addEventListener("click", () => { prefs.theme = b.dataset.theme; savePrefs(prefs); applyTheme(); syncSettings(); }));
  $("#rateRange").addEventListener("input", e => { prefs.rate = parseFloat(e.target.value); savePrefs(prefs); });
  $("#rateRange").addEventListener("change", e => speak("你好", { rate: parseFloat(e.target.value) }));

  // ---- Chinese-voice picker ----
  // Lists the Chinese voices actually installed on THIS device so you can see
  // what you've got and choose one. If there's only the default (robotic) voice,
  // the note explains how to get a better one — no app can install voices.
  function voiceLabel(v) {
    let n = (v.name || v.voiceURI || "Voice").replace(/\s*\((enhanced|premium)\)/i, "");
    const q = voiceQuality(v);
    if (/siri/i.test(v.name + v.voiceURI)) n += " · Siri";
    else if (q >= 8) n += " · enhanced";
    return n;
  }
  function syncVoicePicker() {
    const sel = $("#voiceSel"); if (!sel) return;
    const list = zhVoices().slice().sort((a, b) => voiceQuality(b) - voiceQuality(a));
    sel.innerHTML = "";
    sel.appendChild(el("option", { value: "" }, "Auto — best available"));
    list.forEach(v => sel.appendChild(el("option", { value: v.voiceURI }, voiceLabel(v))));
    sel.value = prefs.voiceURI && list.some(v => v.voiceURI === prefs.voiceURI) ? prefs.voiceURI : "";
    const note = $("#voiceNote");
    if (note) {
      if (!list.length) note.textContent = "No Chinese voice found on this device.";
      else if (list.length === 1) note.innerHTML = /iPad|iPhone|iPod/.test(navigator.userAgent)
        ? "Only one voice installed (it sounds robotic). For a natural voice: iOS <b>Settings → Accessibility → Spoken Content → Voices → Chinese</b>, then download an <b>Enhanced</b> voice and pick it here."
        : "Only one Chinese voice is installed. Add a higher-quality one in your system's speech settings.";
      else note.textContent = "";
    }
  }
  $("#voiceSel").addEventListener("change", e => {
    prefs.voiceURI = e.target.value || null;
    savePrefs(prefs); pickVoice();
    speak("你好，我叫步步");   // hear the chosen voice immediately
  });
  $("#voiceTest").addEventListener("click", () => speak("你好，很高兴认识你"));
  // Voices often arrive after boot (esp. iOS) — refresh the list when they land.
  if ("speechSynthesis" in window)
    speechSynthesis.onvoiceschanged = () => { pickVoice(); syncVoicePicker(); };
  $("#goalSeg").querySelectorAll("button").forEach(b =>
    b.addEventListener("click", () => {
      prefs.dailyGoal = +b.dataset.goal;
      savePrefs(prefs); renderDashboard(); renderHomeTop(); syncSettings();
    }));
  /* ---- Backup / restore --------------------------------------------------
     Everything lives in localStorage, so clearing site data, switching browser
     or reinstalling the PWA would wipe months of study with no warning.     */
  const BACKUP_KEYS = [LS_KEY, LS_PREFS, LS_DONE, LS_ACTIVITY];
  // Progress lives only in localStorage, which iOS can evict if the app sits
  // unused or gets offloaded. Track the last backup so we can nudge before that
  // silently costs someone their streak and review history.
  const LS_BACKUP = "zhBeginnerA.lastBackup.v1";
  const LS_BK_SNOOZE = "zhBeginnerA.backupSnooze.v1";
  const STALE_DAYS = 14, SNOOZE_DAYS = 7;
  const lastBackupAt = () => +localStorage.getItem(LS_BACKUP) || 0;
  const markBackedUp = () => { localStorage.setItem(LS_BACKUP, String(NOW())); localStorage.removeItem(LS_BK_SNOOZE); };
  function backupAgeText() {
    const t = lastBackupAt();
    if (!t) return "never backed up";
    const d = Math.floor((NOW() - t) / DAY);
    return d <= 0 ? "backed up today" : `backed up ${d} day${d === 1 ? "" : "s"} ago`;
  }
  // Only nag when there is actually something worth losing, and not while snoozed.
  function backupOverdue() {
    const worthLosing = doneLessons.size > 0 || Object.keys(srs).length >= 8 || computeStreak() > 0;
    if (!worthLosing) return false;
    // A signed-in account that synced recently IS the backup — nagging would be noise.
    if (cloudOn() && signedIn() && (NOW() - lastSyncAt()) / DAY < STALE_DAYS) return false;
    if (NOW() < (+localStorage.getItem(LS_BK_SNOOZE) || 0)) return false;
    const t = lastBackupAt();
    return !t || (NOW() - t) / DAY >= STALE_DAYS;
  }
  function renderBackupNudge() {
    const n = $("#backupNudge");
    if (!n) return;
    if (!backupOverdue()) { n.classList.add("hidden"); return; }
    const hud = document.querySelector(".path-top");
    n.style.top = ((hud && hud.offsetHeight ? hud.offsetHeight : 62) + 6) + "px";
    $("#bkNudgeSub").textContent = lastBackupAt()
      ? `Last ${backupAgeText()}. Progress lives only on this device.`
      : "Your streak and history live only on this device.";
    n.classList.remove("hidden");
  }
  function exportProgress() {
    const payload = { app: "zhBeginnerA", version: 1, exported: new Date().toISOString(), data: {} };
    BACKUP_KEYS.forEach(k => { const v = localStorage.getItem(k); if (v !== null) payload.data[k] = v; });
    const url = URL.createObjectURL(new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" }));
    const a = document.createElement("a");
    a.href = url;
    a.download = `chinese-progress-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    markBackedUp();
    renderBackupNudge();
    syncSettings();
    toast("Progress exported — keep the file somewhere safe.");
  }
  function importProgress(file) {
    const r = new FileReader();
    r.onload = () => {
      let p;
      try { p = JSON.parse(r.result); } catch { return toast("That file isn't valid JSON."); }
      if (!p || p.app !== "zhBeginnerA" || !p.data) return toast("That isn't a progress backup.");
      let words = 0, lessons = 0;
      try { words = Object.keys(JSON.parse(p.data[LS_KEY] || "{}")).length; } catch {}
      try { lessons = (JSON.parse(p.data[LS_DONE] || "[]")).length; } catch {}
      const when = (p.exported || "").slice(0, 10) || "unknown date";
      if (!confirm(`Restore backup from ${when}?

${lessons} lesson(s) complete, ${words} word(s) with progress.

This REPLACES the progress on this device.`)) return;
      BACKUP_KEYS.forEach(k => localStorage.removeItem(k));
      Object.entries(p.data).forEach(([k, v]) => { if (BACKUP_KEYS.includes(k)) localStorage.setItem(k, v); });
      markBackedUp();          // they demonstrably hold a copy of this state
      location.reload();
    };
    r.onerror = () => toast("Couldn't read that file.");
    r.readAsText(file);
  }
  $("#exportBtn").addEventListener("click", exportProgress);
  $("#bkNudgeExport").addEventListener("click", exportProgress);
  $("#bkNudgeClose").addEventListener("click", () => {
    localStorage.setItem(LS_BK_SNOOZE, String(NOW() + SNOOZE_DAYS * DAY));
    $("#backupNudge").classList.add("hidden");
  });
  $("#importBtn").addEventListener("click", () => $("#importFile").click());
  $("#importFile").addEventListener("change", e => {
    const f = e.target.files && e.target.files[0];
    if (f) importProgress(f);
    e.target.value = "";        // allow re-picking the same file
  });


  /* ==================================================================== */
  /*  ACCOUNT + CLOUD SYNC  (optional — inert until configured)           */
  /* ==================================================================== */
  /* Talks to Supabase over its plain REST API with fetch(), deliberately NOT
     the JS SDK: the app is 100% self-hosted with no CDN calls, which is what
     lets it work offline, and a 40KB library would break that for no gain.

     LOCAL-FIRST: localStorage stays the source of truth, so everything keeps
     working with no signal. Signing in only adds a backup + multi-device copy.

     SUPABASE_ANON_KEY is the PUBLIC key — it is designed to be embedded in a
     client and is safe here. The service_role key must NEVER appear in this
     file; it bypasses row-level security entirely. */
  const SUPABASE_URL = "https://cthoynfsgpqgthxpmngm.supabase.co";
  // Public "anon" key — designed to be embedded in a client; row-level security
  // in Postgres is what actually protects the data. NEVER the service_role key.
  const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0aG95bmZzZ3BxZ3RoeHBtbmdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2MDM3NDksImV4cCI6MjEwMDE3OTc0OX0.nj0EP_CL5wA61D9ebjTKIDwMLj3ou_2LtEVSN1Rsn1E";
  const cloudOn = () => !!(SUPABASE_URL && SUPABASE_ANON_KEY);

  const LS_SESSION = "zhBeginnerA.session.v1";
  const LS_SYNCED  = "zhBeginnerA.lastSync.v1";
  const LS_SKIPAUTH = "zhBeginnerA.skipAuth.v1";   // chose to use the app without an account
  let session = (() => { try { return JSON.parse(localStorage.getItem(LS_SESSION)) || null; } catch { return null; } })();
  const signedIn = () => !!(session && session.access_token);
  const userEmail = () => (session && session.user && session.user.email) || "";
  function setSession(s) {
    session = s;
    if (s) localStorage.setItem(LS_SESSION, JSON.stringify(s));
    else localStorage.removeItem(LS_SESSION);
    renderAccount();
  }

  async function sb(path, opts = {}, useAuth = true) {
    const headers = Object.assign(
      { apikey: SUPABASE_ANON_KEY, "Content-Type": "application/json" }, opts.headers || {});
    if (useAuth && signedIn()) headers.Authorization = `Bearer ${session.access_token}`;
    return fetch(SUPABASE_URL + path, Object.assign({}, opts, { headers }));
  }
  // Access tokens expire (~1h). Refresh once and replay rather than logging out.
  // DEFENSIVE: with the sign-in gate on, dropping the session locks the user out
  // of an app whose data is on their own device. So only a DEFINITIVE rejection
  // from the server ends a session — never a network error, never a 5xx.
  const NET_FAIL = { ok: false, status: 0, networkError: true,
                     json: async () => ({}), text: async () => "" };
  async function sbAuthed(path, opts = {}) {
    let r;
    try { r = await sb(path, opts); } catch { return NET_FAIL; }
    if (r.status !== 401 || !session || !session.refresh_token) return r;
    let rr;
    try {
      rr = await sb(`/auth/v1/token?grant_type=refresh_token`,
        { method: "POST", body: JSON.stringify({ refresh_token: session.refresh_token }) }, false);
    } catch { return r; }                    // offline — keep the session, stay usable
    if (!rr.ok) {
      // 400/401 = the refresh token really is dead. Anything else is transient.
      if (rr.status === 400 || rr.status === 401) { setSession(null); openAuthGate(); }
      return r;
    }
    setSession(await rr.json());
    try { return await sb(path, opts); } catch { return NET_FAIL; }
  }

  async function signUp(email, password) {
    const r = await sb("/auth/v1/signup", { method: "POST", body: JSON.stringify({ email, password }) }, false);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.msg || j.error_description || j.message || "Sign-up failed");
    // With email confirmation ON, Supabase returns a user but no session.
    if (j.access_token) { setSession(j); return { confirmed: true }; }
    return { confirmed: false };
  }
  async function signIn(email, password) {
    const r = await sb("/auth/v1/token?grant_type=password",
      { method: "POST", body: JSON.stringify({ email, password }) }, false);
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.error_description || j.msg || j.message || "Sign-in failed");
    setSession(j);
    return j;
  }
  function signOut() {
    // Local data is deliberately left alone — signing out must never wipe progress.
    setSession(null);
    localStorage.removeItem(LS_SYNCED);
    toast("Signed out — your progress stays on this device.");
    closeModal("settingsModal");
    openAuthGate();
  }

  /* ---- merge -------------------------------------------------------------
     Naive last-write-wins silently destroys progress when two devices are used.
     Merge per data type instead, always in the direction that KEEPS work:
       lessons  -> union            (finished on either device counts)
       activity -> max per day      (never double-counts, never loses a day)
       srs      -> more-reviewed entry wins
       prefs    -> this device wins, remote fills any gaps                     */
  function mergeProgress(local, remote) {
    const P = (v, f) => { try { return typeof v === "string" ? JSON.parse(v) : (v || f); } catch { return f; } };
    const out = {};

    const sa = P(local[LS_KEY], {}), sbb = P(remote[LS_KEY], {});
    const srsM = Object.assign({}, sbb);
    for (const [id, e] of Object.entries(sa)) {
      const o = srsM[id];
      const better = !o || ((e.last || o.last) ? (e.last || 0) > (o.last || 0)
        : (e.reps || 0) > (o.reps || 0) || ((e.reps || 0) === (o.reps || 0) && (e.due || 0) > (o.due || 0)));
      if (better) srsM[id] = e;
    }
    out[LS_KEY] = JSON.stringify(srsM);

    const da = P(local[LS_DONE], []), db = P(remote[LS_DONE], []);
    out[LS_DONE] = JSON.stringify([...new Set([].concat(
      Array.isArray(da) ? da : [], Array.isArray(db) ? db : []))]);

    const aa = P(local[LS_ACTIVITY], { days: {} }), ab = P(remote[LS_ACTIVITY], { days: {} });
    const days = Object.assign({}, ab.days || {});
    for (const [d, n] of Object.entries(aa.days || {})) days[d] = Math.max(n || 0, days[d] || 0);
    const xpDays = Object.assign({}, ab.xpDays || {});
    for (const [d, n] of Object.entries(aa.xpDays || {})) xpDays[d] = Math.max(n || 0, xpDays[d] || 0);
    const relit = Object.assign({}, ab.relit || {}, aa.relit || {});
    const emb = Math.max(typeof aa.embers === "number" ? aa.embers : 1, typeof ab.embers === "number" ? ab.embers : 1);
    const emberFor = Object.assign({}, ab.emberFor || {}, aa.emberFor || {});
    const best = Math.max(aa.best || 0, ab.best || 0);
    const questMonths = Object.assign({}, ab.questMonths || {});
    for (const [m, n] of Object.entries(aa.questMonths || {})) questMonths[m] = Math.max(n || 0, questMonths[m] || 0);
    const chests = Math.max(aa.chests || 0, ab.chests || 0);
    const boostUntil = Math.max(aa.boostUntil || 0, ab.boostUntil || 0);
    const levelSeen = Math.max(aa.levelSeen || 0, ab.levelSeen || 0);
    const lit = Object.assign({}, ab.lit || {}, aa.lit || {});
    // today's quests: keep whichever side has claimed more of them
    const qa = aa.quests, qb = ab.quests, nd = q => (q && q.done ? Object.keys(q.done).length : -1);
    const quests = (qa && qb && qa.date === qb.date) ? (nd(qa) >= nd(qb) ? qa : qb) : ((qa && qa.date) >= (qb && qb.date || "") ? qa : qb);
    out[LS_ACTIVITY] = JSON.stringify(Object.assign({}, ab, aa, { days, xpDays, relit, embers: emb, emberFor, best, questMonths, chests, quests, boostUntil, levelSeen, lit }));

    out[LS_PREFS] = JSON.stringify(Object.assign({}, P(remote[LS_PREFS], {}), P(local[LS_PREFS], {})));
    return out;
  }

  const localPayload = () => {
    const d = {};
    BACKUP_KEYS.forEach(k => { const v = localStorage.getItem(k); if (v !== null) d[k] = v; });
    return d;
  };
  // Re-read everything into memory after a merge, so we never need a page reload.
  function reloadStateFromStorage() {
    srs = loadSRS(); prefs = loadPrefs(); activity = loadActivity();
    try { doneLessons = migrateOldDone(new Set(JSON.parse(localStorage.getItem(LS_DONE)) || [])); }
    catch { doneLessons = new Set(); }
    applyTheme();
    renderPath();
    if (document.body.dataset.view === "home") renderHome();
  }

  let syncing = false;
  async function cloudSync(reason) {
    if (!cloudOn() || !signedIn() || syncing || !navigator.onLine) return false;
    syncing = true; renderAccount();
    try {
      const uid = session.user && session.user.id;
      const get = await sbAuthed(`/rest/v1/progress?user_id=eq.${uid}&select=data`);
      if (!get.ok) throw new Error("pull failed");
      const rows = await get.json();
      const remote = (rows[0] && rows[0].data) || {};
      const merged = mergeProgress(localPayload(), remote);

      Object.entries(merged).forEach(([k, v]) => localStorage.setItem(k, v));
      reloadStateFromStorage();

      const put = await sbAuthed("/rest/v1/progress", {
        method: "POST",
        headers: { Prefer: "resolution=merge-duplicates" },
        body: JSON.stringify([{ user_id: uid, data: merged, updated_at: new Date().toISOString() }])
      });
      if (!put.ok) throw new Error("push failed");

      localStorage.setItem(LS_SYNCED, String(NOW()));
      renderBackupNudge();
      return true;
    } catch (e) {
      if (reason === "manual") toast("Couldn't sync — will retry later.");
      return false;
    } finally { syncing = false; renderAccount(); }
  }
  // Debounced background sync after progress changes.
  let syncTimer = null;
  function queueSync() {
    if (!cloudOn() || !signedIn()) return;
    clearTimeout(syncTimer);
    syncTimer = setTimeout(() => cloudSync("auto"), 4000);
  }
  window.addEventListener("online", () => cloudSync("online"));

  const lastSyncAt = () => +localStorage.getItem(LS_SYNCED) || 0;

  /* ---- sign-in gate ---------------------------------------------------
     Blocks the app until there's a session. Deliberately NOT a network check:
     a cached session opens the app instantly, online or off. Only shown when
     cloud sync is configured, so the app still runs standalone without it.   */
  let gateMode = "signup";
  function openAuthGate() {
    const g = $("#authGate");
    if (!g || !cloudOn()) return;
    g.classList.remove("hidden"); g.setAttribute("aria-hidden", "false");
    paintGate();
  }
  function closeAuthGate() {
    const g = $("#authGate");
    if (!g) return;
    g.classList.add("hidden"); g.setAttribute("aria-hidden", "true");
  }
  function paintGate() {
    const signup = gateMode === "signup";
    $("#gateIntro").textContent = signup
      ? "Your progress is saved to the cloud and follows you to any device."
      : "Sign in to pick up where you left off.";
    $("#gateIntroTitle").textContent = signup ? "Create your account" : "Welcome back";
    $("#gatePrimary").textContent = signup ? "Create account" : "Sign in";
    $("#gateToggle").textContent = signup ? "I already have an account" : "Create an account instead";
    $("#gatePass").setAttribute("autocomplete", signup ? "new-password" : "current-password");
    gateMsg("");
  }
  function gateMsg(text, kind) {
    const m = $("#gateMsg");
    if (m) { m.textContent = text || ""; m.className = "acct-msg" + (kind ? " " + kind : ""); }
  }
  async function afterSignedIn() {
    closeAuthGate();
    renderAccount();
    await cloudSync("manual");                       // pull anything already in the cloud
    if (!localStorage.getItem(LS_ONBOARDED)) runOnboarding();
  }
  if ($("#gatePrimary")) {
    // Splash → "Sign in" slides the account form up over the scene.
    $("#gateShowForm").addEventListener("click", () => {
      gateMode = "signin"; paintGate();
      $("#authGate").classList.add("form-open");
      setTimeout(() => $("#gateEmail").focus(), 50);
    });
    $("#gateSheetClose").addEventListener("click", () => $("#authGate").classList.remove("form-open"));
    $("#gateToggle").addEventListener("click", () => {
      gateMode = gateMode === "signup" ? "signin" : "signup"; paintGate();
    });
    $("#gatePrimary").addEventListener("click", async () => {
      const email = ($("#gateEmail").value || "").trim();
      const password = $("#gatePass").value || "";
      if (!email || !password) return gateMsg("Enter an email and password.", "err");
      if (password.length < 6) return gateMsg("Password needs at least 6 characters.", "err");
      if (!navigator.onLine) return gateMsg("You're offline — connect to the internet to sign in.", "err");
      const btn = $("#gatePrimary");
      btn.disabled = true;
      gateMsg(gateMode === "signup" ? "Creating account…" : "Signing in…");
      try {
        if (gateMode === "signup") {
          const r = await signUp(email, password);
          if (!r.confirmed) {
            gateMsg("Check your email to confirm, then sign in.", "ok");
            gateMode = "signin";
            btn.disabled = false;
            return paintGate();
          }
        } else {
          await signIn(email, password);
        }
        $("#gatePass").value = "";
        await afterSignedIn();
      } catch (e) {
        gateMsg(e.message || "That didn't work — try again.", "err");
      } finally { btn.disabled = false; }
    });
    ["gateEmail", "gatePass"].forEach(id =>
      $("#" + id).addEventListener("keydown", e => { if (e.key === "Enter") $("#gatePrimary").click(); }));
    if ($("#gateSkip")) $("#gateSkip").addEventListener("click", () => {
      // Run the app locally with no account. The app is local-first, so this
      // loses nothing — and it means a missing/paused backend can never lock you out.
      try { localStorage.setItem(LS_SKIPAUTH, "1"); } catch (e) {}
      closeAuthGate();
      if (!localStorage.getItem(LS_ONBOARDED)) runOnboarding();
    });
  }

  function renderAccount() {
    const box = $("#acctBox");
    if (!box) return;
    // Nothing about accounts appears at all until the app is pointed at a project.
    box.classList.toggle("hidden", !cloudOn());
    if (!cloudOn()) return;
    const inOK = signedIn();
    $("#acctSignedOut").classList.toggle("hidden", inOK);
    $("#acctSignedIn").classList.toggle("hidden", !inOK);
    $("#acctState").textContent = inOK ? userEmail() : "Not signed in";
    if (inOK) {
      const t = lastSyncAt();
      $("#acctSyncLine").textContent = syncing ? "Syncing…"
        : !t ? "Not synced yet."
        : `Last synced ${Math.max(0, Math.floor((NOW() - t) / 60000))} min ago.`;
      $("#acctSyncNow").disabled = syncing;
    }
  }
  function acctMsg(text, kind) {
    const m = $("#acctMsg");
    if (!m) return;
    m.textContent = text || "";
    m.className = "acct-msg" + (kind ? " " + kind : "");
  }
  if ($("#acctSignIn")) {
    const creds = () => ({
      email: ($("#acctEmail").value || "").trim(),
      password: $("#acctPass").value || ""
    });
    const guard = c => {
      if (!c.email || !c.password) { acctMsg("Enter an email and password.", "err"); return false; }
      if (c.password.length < 6) { acctMsg("Password needs at least 6 characters.", "err"); return false; }
      return true;
    };
    $("#acctSignIn").addEventListener("click", async () => {
      const c = creds(); if (!guard(c)) return;
      acctMsg("Signing in…");
      try {
        await signIn(c.email, c.password);
        $("#acctPass").value = "";
        acctMsg("");
        await cloudSync("manual");
        toast("Signed in — progress synced.");
      } catch (e) { acctMsg(e.message, "err"); }
    });
    $("#acctSignUp").addEventListener("click", async () => {
      const c = creds(); if (!guard(c)) return;
      acctMsg("Creating account…");
      try {
        const r = await signUp(c.email, c.password);
        $("#acctPass").value = "";
        if (r.confirmed) { acctMsg(""); await cloudSync("manual"); toast("Account created — progress synced."); }
        else acctMsg("Check your email to confirm, then sign in.", "ok");
      } catch (e) { acctMsg(e.message, "err"); }
    });
    $("#acctSignOut").addEventListener("click", signOut);
    $("#acctSyncNow").addEventListener("click", async () => {
      const ok = await cloudSync("manual");
      if (ok) toast("Synced.");
    });
  }


  $("#resetBtn").addEventListener("click", () => { closeModal("settingsModal"); resetProgress(); });

  // Force the newest version: wipe the service-worker caches and unregister it,
  // then reload — so the next load fetches everything fresh from the network,
  // no matter how stale the cached copy was. (Progress lives in localStorage,
  // which this does NOT touch.)
  async function forceUpdate() {
    const btn = $("#updateBtn");
    if (btn) { btn.disabled = true; btn.textContent = "Updating…"; }
    try {
      if (window.caches) {
        const keys = await caches.keys();
        await Promise.all(keys.map(k => caches.delete(k)));
      }
      if (navigator.serviceWorker) {
        const regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.map(r => r.unregister()));
      }
    } catch (e) {}
    // cache-busting reload so even the HTML itself is re-fetched
    const u = new URL(location.href);
    u.searchParams.set("fresh", Date.now().toString());
    location.replace(u.toString());
  }
  if ($("#updateBtn")) $("#updateBtn").addEventListener("click", forceUpdate);

  // ---- Keyboard shortcuts ----
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") {
      if (!$("#lessonSheet").classList.contains("hidden")) { closeLessonSheet(); return; }
      if (!$("#settingsModal").classList.contains("hidden")) { closeModal("settingsModal"); return; }
      if (!$("#helpModal").classList.contains("hidden")) { closeModal("helpModal"); return; }
      if (!$("#tonesModal").classList.contains("hidden")) { closeModal("tonesModal"); return; }
    }
    if (!$("#charModal").classList.contains("hidden")) {
      if (e.key === "Escape") closeCharModal();
      return;
    }
    if (!$("#study").classList.contains("hidden")) {
      const choices = $("#studyChoices");
      if (e.code === "Space" || e.key === "Enter") {
        e.preventDefault();
        if (!$("#studyContinueWrap").classList.contains("hidden")) {
          if (!$("#studyContinue").disabled) $("#studyContinue").click();
        } else if (writeNextFn && !$("#studyNext").classList.contains("hidden") && !$("#studyNext").disabled) {
          writeNextFn();
        }
      } else if (!choices.classList.contains("hidden") && !choices.dataset.answered) {
        const n = parseInt(e.key, 10);   // 1-4 picks an answer
        if (n >= 1 && n <= choices.children.length) choices.children[n - 1].click();
      }
    }
  });

  // ---- First-run onboarding ----
  const LS_ONBOARDED = "zhBeginnerA.onboarded.v1";
  function runOnboarding() {
    const ob = $("#onboard");
    const slides = [...ob.querySelectorAll(".ob-slide")];
    const dots = $("#obDots");
    dots.innerHTML = ""; slides.forEach(() => dots.appendChild(el("i")));
    let i = 0, level = "new";
    const paint = () => {
      slides.forEach((s, k) => s.classList.toggle("on", k === i));
      [...dots.children].forEach((d, k) => d.classList.toggle("on", k === i));
      // display:none, NOT visibility:hidden — a hidden-but-present Back button
      // still occupies its width and shoves "Next" off-centre on the first slide.
      $("#obBack").style.display = i === 0 ? "none" : "";
      $("#obNext").textContent = i < slides.length - 1 ? "Next" : level === "new" ? "Start my first lesson" : "Take the test";
    };
    // goal presets inside onboarding write straight to prefs
    ob.querySelectorAll("#obGoalSeg button").forEach(b =>
      b.addEventListener("click", () => {
        ob.querySelectorAll("#obGoalSeg button").forEach(x => x.classList.toggle("on", x === b));
        prefs.dailyGoal = +b.dataset.goal; savePrefs(prefs);
      }));
    // how much you know decides where you start
    ob.querySelectorAll("#obLevel button").forEach(b =>
      b.addEventListener("click", () => {
        ob.querySelectorAll("#obLevel button").forEach(x => x.classList.toggle("on", x === b));
        level = b.dataset.level; paint();
      }));
    // The last lesson of a unit, for a placement test up to it.
    const unitEnd = u => { const chs = CHAPTERS.filter(c => c.unit === u); const last = chs[chs.length - 1]; return last && last.lessons[last.lessons.length - 1]; };
    const finish = () => {
      localStorage.setItem(LS_ONBOARDED, "1");
      ob.classList.add("hidden"); ob.setAttribute("aria-hidden", "true");
      renderHome();                       // reflect the chosen goal on Home
      // Straight into learning, the way Duolingo does it: the first lesson, or
      // a placement test for someone who already knows some.
      returnView = "path";
      show("path"); renderPath();
      const books = [...new Set(CHAPTERS.map(c => c.unit))];
      const target = level === "a" ? unitEnd(books[0]) : level === "b" ? unitEnd(books[1]) : null;
      setTimeout(() => { if (target) startPlacement(target, "Placement test"); else launchLesson(currentLessonId(), null); }, 350);
    };
    $("#obBack").addEventListener("click", () => { if (i > 0) { i--; paint(); } });
    $("#obNext").addEventListener("click", () => {
      if (i < slides.length - 1) { i++; paint(); } else finish();
    });
    hydrateIcons(ob);
    ob.classList.remove("hidden"); ob.setAttribute("aria-hidden", "false");
    paint();
  }

  // ---- Boot ----
  applyTheme();
  hydrateIcons();
  renderHome();
  show("home");                          // land on the Home dashboard (path renders on first Learn tap)
  setTimeout(protectStreak, 600);            // an ember relights yesterday's miss, or the fire is declared out
  // once, after moving from the JIC edition: say what carried over
  try {
    const m = JSON.parse(localStorage.getItem(LS_MIGRATED) || "null");
    if (m && !m.shown) {
      setTimeout(() => toast(m.stones > 0
        ? `Welcome to the new course! ${m.stones} stone${m.stones === 1 ? " is" : "s are"} already done from your old progress, and your words keep their reviews.`
        : "Welcome to the new course! Your words keep their reviews.", 7000), 1200);
      m.shown = true; localStorage.setItem(LS_MIGRATED, JSON.stringify(m));
    }
  } catch {}
  if (activity.levelSeen == null) { activity.levelSeen = levelInfo().level; localStorage.setItem(LS_ACTIVITY, JSON.stringify(activity)); }
  // local development only: open straight onto a view (?view=progress) for screenshots
  if (location.hostname === "localhost") {
    // the path editor's live preview: redraw in place when it hands over a new
    // layout or a different current lesson, keeping the scroll where it was
    window.addEventListener("storage", e => {
      if (e.key !== DEV_LAYOUT_KEY && e.key !== LS_DONE) return;
      devLayout();
      if (e.key === LS_DONE) { try { doneLessons = new Set(JSON.parse(e.newValue || "[]")); } catch (err) {} }
      if (document.body.dataset.view !== "path") return;
      const sc = $("#pathScroll"), top = sc ? sc.scrollTop : 0;
      renderPath();
      if (sc && e.key === DEV_LAYOUT_KEY) requestAnimationFrame(() => requestAnimationFrame(() => { sc.scrollTop = top; }));
    });
    const v = new URLSearchParams(location.search).get("view");
    if (v === "progress") { renderDashboard(); show("progress"); if (new URLSearchParams(location.search).get("act") === "chars") setTimeout(() => { $("#actSeg [data-act=chars]").click(); $("#actChars").scrollIntoView({ block: "center" }); }, 200); }
    else if (v === "path") { show("path"); renderPath(); }
    else if (v === "chars") openChars();
    else if (v === "reads") openReadings("home");
    else if (v === "read") openReading(new URLSearchParams(location.search).get("r") || "r1", "home");
    else if (v === "tones") startTones();
    else if (v === "guide") openGuide(+(new URLSearchParams(location.search).get("c") || 0), "path");
    else if (v === "onboard") runOnboarding();
    else if (v === "char") setTimeout(() => openCharSheet(new URLSearchParams(location.search).get("ch") || "好"), 300);
    // screenshot helpers: the longest sentence card, or an answered choice card
    else if (v === "sentence") setTimeout(() => window.__dev.sentence(window.__dev.longest()[0].slice(0, 4), false), 300);
    else if (v === "write") setTimeout(() => {
      const st = +(new URLSearchParams(location.search).get("stage") || 0);
      curCard = CARDS.find(c => c.hanzi.length === 2 && HW_OK && wordWritable(c.hanzi)) || CARDS[0]; curDir = "write"; studyAnswered = false;
      if (st) srs[curCard.id] = { ease: 2.4, reps: 3, interval: st === 2 ? 20 : 3, due: NOW() + DAY }; else delete srs[curCard.id];
      queue = [curCard]; sessionTotal = 1; clearedIds = new Set(); stepsDone = 0; show("study"); renderStudyCard();
    }, 600);
    else if (v === "choice") setTimeout(() => {
      curCard = CARDS.find(c => c.hanzi.length === 2) || CARDS[0]; curDir = "recognize"; studyAnswered = false;
      beginStudySession([curCard]); if ($(".meet-intro")) $("#studyContinue").click();
      setTimeout(() => { const ch = $("#studyChoices").querySelectorAll(".choice"); if (ch[0]) ch[0].click(); }, 400);
    }, 300);
    else if (v === "avatar") { show("avatar"); renderAvatarBuilder(); }
  }
  // local development only: poke the streak moments from the console
  if (location.hostname === "localhost") window.__dev = { enHints: () => SENTENCES.map(x => englishHints(x.en, x.words).map(t => t.word ? `[${t.text}=${t.word.hanzi}]` : t.text).join("")), lesson: id => { returnView = "path"; reviewMode = false; scopeLessons = new Set([id]); scopeFocuses = new Set(selectedFocuses); startStudy(); return queue.map(x => x.meet ? "[meet " + x.meet.map(c => c.hanzi).join(" ") + "]" : x.hanzi + (srs[x.id] ? "(r)" : "")); }, state: () => ({ curDir, card: curCard && curCard.hanzi, left: queue.length, stepsDone, sessionTotal }), card: (h, dir) => { curCard = CARDS.find(x => x.hanzi === h); curDir = dir; studyAnswered = false; queue = []; sessionTotal = 1; clearedIds = new Set(); stepsDone = 0; show("study"); renderStudyCard(); }, lookalikes: (h, n = 6) => { const c = CARDS.find(x => x.hanzi === h); return c ? lookalikes(c, n).map(x => x.hanzi + " " + wordSim(h, x.hanzi).toFixed(1)) : null; }, earnXP, lightFire, celebrateMilestone, celebrateGoal, askRelight, computeStreak, protectStreak, celebrateRelight, showFireOut, celebrateLevel, confetti, sfx, questEvent, todayQuests, celebrateChest, startBoost, answerXP, finishStudy, nextStudyCard,
    // __dev.sentence("咖啡", true) opens the study card on that sentence, building the Chinese (true) or the English (false)
    sentence: (sub, en2cn = null) => { devSentence = SENTENCES.find(s => s.hanzi.includes(sub)) || null; devEn2cn = en2cn; curCard = CARDS.find(c => devSentence && devSentence.hanzi.includes(c.hanzi)) || CARDS[0]; curDir = "sentence"; studyAnswered = false; show("study"); renderStudyCard(); },
    longest: () => SENTENCES.slice().sort((a, b) => b.words.length - a.words.length).slice(0, 5).map(s => s.hanzi) };
  renderAccount();
  if (cloudOn() && !signedIn() && !localStorage.getItem(LS_SKIPAUTH)) {
    openAuthGate();                       // no session yet — offer sign-in (skippable)
  } else {
    // Cached session (or no cloud configured): open the app immediately and sync
    // in the background. A failed sync must never block usage.
    if (cloudOn() && signedIn()) cloudSync("boot");
    if (!localStorage.getItem(LS_ONBOARDED)) runOnboarding();
  }
})();
