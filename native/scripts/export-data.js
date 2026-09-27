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
const strokes = Object.fromEntries(Object.entries(W.HANZI_DATA).map(([c, d]) => [c, { strokes: d.strokes, medians: d.medians }]));
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
  // app icon (1024, one size: Xcode derives the rest)
  const icon = path.join(ASSETS, "AppIcon.appiconset");
  fs.rmSync(icon, { recursive: true, force: true }); fs.mkdirSync(icon, { recursive: true });
  await sharp(path.resolve(WEB, "../images/icon-panda.png")).resize(1024, 1024).flatten({ background: "#faf7f1" }).png().toFile(path.join(icon, "icon.png"));
  fs.writeFileSync(path.join(icon, "Contents.json"), contents({ images: [{ idiom: "universal", platform: "ios", size: "1024x1024", filename: "icon.png" }] }));
  const kb = f => Math.round(fs.statSync(path.join(DATA, f)).size / 1024);
  console.log(`lessons ${course.lessons.length}, chapters ${course.chapters.length}, dialogues ${course.dialogues.length}, stories ${course.readings.length}`);
  console.log(`course.json ${kb("course.json")} KB, chars.json ${kb("chars.json")} KB, strokes.json ${kb("strokes.json")} KB, ${n} image sets`);
})();
