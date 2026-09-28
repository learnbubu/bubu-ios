// Exports everything the native app needs from the web app (../../../chineseLearning/app):
//   Bubu/Resources/Data/course.json   lessons, chapters, notes, dialogues, stories, path layout, art sizes
//   Bubu/Resources/Data/chars.json    character meanings and parts (Make Me a Hanzi)
//   Bubu/Resources/Data/strokes.json  stroke outlines and medians for writing practice
//   Bubu/Assets.xcassets/...          stones, path scenery, pandas, welcome art (light + dark variants), app icon
// Run on Windows or a Mac:  node native/scripts/export-data.js
const fs = require("fs"), path = require("path"), vm = require("vm");
const sharp = require(path.resolve(__dirname, "../../node_modules/sharp"));

const WEB = path.resolve(__dirname, "../../../chineseLearning/app");
const OUT = path.resolve(__dirname, "../Bubu");
const DATA = path.join(OUT, "Resources", "Data");
const ASSETS = path.join(OUT, "Assets.xcassets");
fs.mkdirSync(DATA, { recursive: true });

// ---- the web app's data files (window.X = …)
const ctx = { window: {} }; vm.createContext(ctx);
for (const f of ["data.js", "readings.js", "chars-data.js", "hanzi-data.js"]) vm.runInContext(fs.readFileSync(path.join(WEB, f), "utf8"), ctx);
const W = ctx.window;

// ---- literals that live in app.js
const app = fs.readFileSync(path.join(WEB, "app.js"), "utf8");
function literal(name, open, close) {
  const i = app.indexOf(`const ${name} = ${open}`);
  if (i < 0) throw new Error("not found in app.js: " + name);
  const j = app.indexOf(`\n  ${close};`, i);
  return vm.runInNewContext("(" + app.slice(i + `const ${name} = `.length, j + 3 + close.length) + ")");
}
const CHAPTERS = literal("CHAPTERS", "[", "]");
const NOTES = literal("LESSON_NOTES", "{", "}");
const PATH_LAYOUT = literal("PATH_LAYOUT", "{", "}");
const ART = literal("ART", "{", "}");

const course = {
  meta: W.VOCAB.meta, names: W.VOCAB.names || [],
  lessons: W.VOCAB.lessons, chapters: CHAPTERS,
  notes: Object.fromEntries(Object.entries(NOTES).map(([k, v]) => [k, Array.isArray(v) ? v : [v]])),
  dialogues: W.DIALOGUES, readings: W.READINGS,
  pathLayout: PATH_LAYOUT, art: ART,
};
fs.writeFileSync(path.join(DATA, "course.json"), JSON.stringify(course));
fs.writeFileSync(path.join(DATA, "chars.json"), JSON.stringify(W.CHARS_DATA));
// the JIC edition's card ids and their words, so a backup from it restores by word
{
  const src = fs.readFileSync(path.join(WEB, "migrate-old.js"), "utf8");
  const win = {}; new Function("window", src)(win);
  fs.writeFileSync(path.join(DATA, "oldcards.json"), JSON.stringify(win.OLD_CARDS || {}));
  // lessons before they were cut into stones of five, and the stones holding each one's words
  fs.writeFileSync(path.join(DATA, "oldlessons.json"), JSON.stringify(win.OLD_LESSONS || {}));
}
const strokes = Object.fromEntries(Object.entries(W.HANZI_DATA).map(([c, d]) => [c, d.radStrokes ? { strokes: d.strokes, medians: d.medians, rad: d.radStrokes } : { strokes: d.strokes, medians: d.medians }]));
fs.writeFileSync(path.join(DATA, "strokes.json"), JSON.stringify(strokes));

// ---- artwork → asset catalog image sets, with a dark variant where the art has one
const contents = (o) => JSON.stringify(Object.assign({ info: { author: "xcode", version: 1 } }, o), null, 2);
fs.mkdirSync(ASSETS, { recursive: true });
fs.writeFileSync(path.join(ASSETS, "Contents.json"), contents({}));

async function imageSet(name, lightSrc, darkSrc) {
  const dir = path.join(ASSETS, name + ".imageset");
  fs.rmSync(dir, { recursive: true, force: true }); fs.mkdirSync(dir, { recursive: true });
  const images = [];
  await sharp(lightSrc).png().toFile(path.join(dir, name + ".png"));
  images.push({ idiom: "universal", filename: name + ".png", scale: "2x" });
  if (darkSrc) {
    await sharp(darkSrc).png().toFile(path.join(dir, name + "-dark.png"));
    images.push({ idiom: "universal", filename: name + "-dark.png", scale: "2x", appearances: [{ appearance: "luminosity", value: "dark" }] });
  }
  fs.writeFileSync(path.join(dir, "Contents.json"), contents({ images }));
}

(async () => {
  const P = path.join(WEB, "images", "path");
  const files = new Set(fs.readdirSync(P));
  let n = 0;
  // stones: stone-<state>-<n> with light and dark art
  for (const st of ["done", "now", "locked"]) for (let k = 0; k < 5; k++) {
    await imageSet(`stone-${st}-${k}`, path.join(P, `stone-light-${st}-${k}.webp`), path.join(P, `stone-dark-${st}-${k}.webp`)); n++;
  }
  // scenery and pandas: <art>-light/-dark, or one file for both
  for (const a of Object.keys(ART)) {
    const l = files.has(`${a}-light.webp`) ? `${a}-light.webp` : files.has(`${a}.webp`) ? `${a}.webp` : null;
    if (!l) continue;
    await imageSet(a, path.join(P, l), files.has(`${a}-dark.webp`) ? path.join(P, `${a}-dark.webp`) : null); n++;
  }
  await imageSet("welcome", path.join(WEB, "images", "welcome-light.webp"), path.join(WEB, "images", "welcome-dark.webp")); n++;
  // Home: the scenery behind it and the Continue card's art
  const H = path.join(WEB, "images", "home");
  for (const h of ["temple", "cloud-a", "bottom"]) {
    await imageSet(`home-${h}`, path.join(H, `${h}-light.webp`), path.join(H, `${h}-dark.webp`)); n++;
  }
  await imageSet("home-peek", path.join(WEB, "images", "panda-peek.png"), null); n++;
  await imageSet("sheet-waving", path.join(WEB, "images", "panda-waving.png"), null); n++;
  await imageSet("done-panda", path.join(WEB, "images", "panda-celebrate.png"), null); n++;
  // rewards: the coin, buns, the red and jade pockets, and Bùbù with a bun for the buns sheet
  for (const r of ["bun", "bun-bitten", "pocket-red", "pocket-jade", "coin"]) {
    await imageSet(r, path.join(WEB, "images", "rewards", `${r}.webp`), null); n++;
  }
  await imageSet("sprite-baozi", path.join(WEB, "images", "sprite-baozi.png"), null); n++;
  // the web's two-tone flame, from its icon sprite, drawn at 3x
  {
    const html = fs.readFileSync(path.join(WEB, "index.html"), "utf8");
    const sym = html.match(/<symbol id="i-flame-solid" viewBox="([^"]+)">([\s\S]*?)<\/symbol>/);
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${sym[1]}" width="144" height="144">${sym[2]}</svg>`;
    const dir = path.join(ASSETS, "flame.imageset");
    fs.mkdirSync(dir, { recursive: true });
    await sharp(Buffer.from(svg)).png().toFile(path.join(dir, "flame.png"));
    fs.writeFileSync(path.join(dir, "Contents.json"), contents({ images: [{ idiom: "universal", filename: "flame.png", scale: "3x" }] }));
    n++;
  }
  await imageSet("home-card", path.join(WEB, "images", "card-light.webp"), path.join(WEB, "images", "card-dark.webp")); n++;
  // sound effects, as the web plays them
  const SND = path.resolve(__dirname, "../Bubu/Resources/Sounds");
  fs.mkdirSync(SND, { recursive: true });
  for (const f of fs.readdirSync(path.join(WEB, "sounds"))) fs.copyFileSync(path.join(WEB, "sounds", f), path.join(SND, f));
  // the avatar wardrobe: every layer and its thumbnail, and the data with asset names for paths
  {
    const src = fs.readFileSync(path.join(WEB, "avatar-modular-data.js"), "utf8").replace("const MODULAR_AVATAR_DATA", "globalThis.__AV");
    eval(src);
    const D = globalThis.__AV;
    const name = p => p ? "av-" + path.basename(p, ".webp") : null;
    const conv = o => typeof o === "string" ? name(o) : o && typeof o === "object" && !Array.isArray(o)
      ? Object.fromEntries(Object.entries(o).map(([k, v]) => [k, conv(v)])) : o;
    const out = {};
    for (const [k, v] of Object.entries(D)) {
      if (k === "thumbnails") out.thumbnails = Object.fromEntries(Object.entries(v).map(([a, b]) => [name(a), name(b)]));
      else if (k === "toneColours" || k === "defaults") out[k] = v;
      else out[k] = conv(v);
    }
    // JSON object order is lost on the other side: keep each list's order explicitly
    out.order = Object.fromEntries(["skin", "top", "bottom", "shoes", "eyes", "brows", "mouth", "accessory", "hair"].map(k => [k, Object.keys(D[k])]));
    out.order.hairColours = Object.fromEntries(Object.entries(D.hair).map(([h, v]) => [h, Object.keys(v)]));
    fs.writeFileSync(path.join(DATA, "avatar.json"), JSON.stringify(out));
    const AV = path.join(WEB, "images", "avatar-modular-v006");
    for (const f of fs.readdirSync(AV)) {
      if (!f.endsWith(".webp")) continue;
      const nm = "av-" + path.basename(f, ".webp");
      const dir = path.join(ASSETS, nm + ".imageset");
      fs.mkdirSync(dir, { recursive: true });
      const thumb = f.includes("-thumb");
      await sharp(path.join(AV, f)).resize(thumb ? 160 : 768).png({ compressionLevel: 9, palette: false }).toFile(path.join(dir, nm + ".png"));
      fs.writeFileSync(path.join(dir, "Contents.json"), contents({ images: [{ idiom: "universal", filename: nm + ".png" }] }));
      n++;
    }
  }
  // the profile's artwork
  {
    const PR = path.join(WEB, "images", "profile");
    for (const [nm, f] of [["profile-hero", "avatarBackground"], ["profile-path", "learningPathBackground"], ["profile-foliage", "quoteFoliage"]]) {
      await imageSet(nm, path.join(PR, `light_${f}.webp`), path.join(PR, `dark_${f}.webp`)); n++;
    }
  }
  // the web's synthesised effects (synthSfx), rendered to WAV with the same tone recipes
  {
    const RATE = 44100;
    const tone = (buf, freq, start, dur, type = "sine", gain = 0.16) => {
      const s0 = Math.floor(start * RATE), n = Math.floor((dur + 0.03) * RATE);
      for (let i = 0; i < n && s0 + i < buf.length; i++) {
        const t = i / RATE;
        const env = t < 0.012 ? 0.0001 + (gain - 0.0001) * t / 0.012
          : t < dur ? gain * Math.pow(0.0001 / gain, (t - 0.012) / (dur - 0.012)) : 0;
        const ph = (freq * t) % 1;
        const w = type === "sawtooth" ? 2 * ph - 1 : type === "triangle" ? 1 - 4 * Math.abs(ph - 0.5) : Math.sin(2 * Math.PI * freq * t);
        buf[s0 + i] += w * env;
      }
    };
    const recipes = {
      combo: b => { tone(b, 880, 0, 0.08, "sine", 0.12); tone(b, 1175, 0.06, 0.1, "sine", 0.12); tone(b, 1568, 0.12, 0.14, "sine", 0.1); },
      chest: b => { tone(b, 784, 0, 0.18, "sine", 0.16); tone(b, 1568, 0.12, 0.35, "sine", 0.14); tone(b, 2093, 0.2, 0.4, "sine", 0.08); tone(b, 2637, 0.28, 0.45, "sine", 0.05); },
      milestone: b => { [659, 784, 988, 1319, 1568].forEach((f, i) => tone(b, f, i * 0.11, 0.38, "sine", 0.19)); tone(b, 330, 0, 0.9, "triangle", 0.08); },
      levelup: b => { [523, 659, 784, 1047].forEach((f, i) => tone(b, f, i * 0.07, 0.2, "sine", 0.16)); [1319, 1568, 2093].forEach((f, i) => tone(b, f, 0.32 + i * 0.09, 0.5, "sine", 0.14)); },
      relight: b => { [220, 330, 440, 660].forEach((f, i) => tone(b, f, i * 0.05, 0.25, "triangle", 0.09)); tone(b, 1319, 0.24, 0.5, "sine", 0.16); tone(b, 1760, 0.34, 0.6, "sine", 0.1); },
      tap: b => { tone(b, 430, 0, 0.05, "sine", 0.07); },
    };
    for (const [name, make] of Object.entries(recipes)) {
      const buf = new Float32Array(Math.ceil(1.1 * RATE));
      make(buf);
      let last = buf.length; while (last > 0 && Math.abs(buf[last - 1]) < 1e-5) last--;
      const pcm = Buffer.alloc(44 + last * 2);
      pcm.write("RIFF", 0); pcm.writeUInt32LE(36 + last * 2, 4); pcm.write("WAVE", 8); pcm.write("fmt ", 12);
      pcm.writeUInt32LE(16, 16); pcm.writeUInt16LE(1, 20); pcm.writeUInt16LE(1, 22); pcm.writeUInt32LE(RATE, 24);
      pcm.writeUInt32LE(RATE * 2, 28); pcm.writeUInt16LE(2, 32); pcm.writeUInt16LE(16, 34); pcm.write("data", 36); pcm.writeUInt32LE(last * 2, 40);
      for (let i = 0; i < last; i++) pcm.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(buf[i] * 2.2 * 32767))), 44 + i * 2);
      fs.writeFileSync(path.join(SND, name + ".wav"), pcm);
    }
  }
  // app icon (1024, one size: Xcode derives the rest)
  const icon = path.join(ASSETS, "AppIcon.appiconset");
  fs.rmSync(icon, { recursive: true, force: true }); fs.mkdirSync(icon, { recursive: true });
  await sharp(path.resolve(WEB, "../images/icon-panda.png")).resize(1024, 1024).flatten({ background: "#faf7f1" }).png().toFile(path.join(icon, "icon.png"));
  fs.writeFileSync(path.join(icon, "Contents.json"), contents({ images: [{ idiom: "universal", platform: "ios", size: "1024x1024", filename: "icon.png" }] }));
  const kb = f => Math.round(fs.statSync(path.join(DATA, f)).size / 1024);
  console.log(`lessons ${course.lessons.length}, chapters ${course.chapters.length}, dialogues ${course.dialogues.length}, stories ${course.readings.length}`);
  console.log(`course.json ${kb("course.json")} KB, chars.json ${kb("chars.json")} KB, strokes.json ${kb("strokes.json")} KB, ${n} image sets`);
})();
