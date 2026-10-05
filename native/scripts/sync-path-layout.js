// Copies the hand-placed path layout (and the art sizes) from the web app's app.js into the
// native course.json, without re-exporting everything else. The path editor runs this when you
// press "Send to the app"; it can also be run by hand:  node native/scripts/sync-path-layout.js
const fs = require("fs"), path = require("path"), vm = require("vm");

const WEB = path.resolve(__dirname, "../../../chineseLearning/app");
const COURSE = path.resolve(__dirname, "../Bubu/Resources/Data/course.json");

const app = fs.readFileSync(path.join(WEB, "app.js"), "utf8");
function literal(name, open, close) {
  const i = app.indexOf(`const ${name} = ${open}`);
  if (i < 0) throw new Error("not found in app.js: " + name);
  const j = app.indexOf(`\n  ${close};`, i);
  return vm.runInNewContext("(" + app.slice(i + `const ${name} = `.length, j + 3 + close.length) + ")");
}
const layout = literal("PATH_LAYOUT", "{", "}");
const art = literal("ART", "{", "}");

const course = JSON.parse(fs.readFileSync(COURSE, "utf8"));
const stones = new Set(course.lessons.map(l => l.id));
const lost = layout.pieces.filter(p => !stones.has(p.stone));
if (lost.length) throw new Error("pieces on stones the app doesn't have: " + lost.map(p => `${p.art}@${p.stone}`).join(", "));
const unknown = layout.pieces.filter(p => !art[p.art]);
if (unknown.length) throw new Error("pieces with no size in ART: " + unknown.map(p => p.art).join(", "));

const before = JSON.stringify(course.pathLayout);
course.pathLayout = layout;
course.art = art;
fs.writeFileSync(COURSE, JSON.stringify(course));
console.log(`course.json: ${layout.pieces.length} pieces (${before === JSON.stringify(layout) ? "unchanged" : "updated"}), ${Object.keys(art).length} art sizes`);
