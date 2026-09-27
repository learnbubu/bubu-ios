// Copies the web app (../chineseLearning/app) into www/ for the native build.
// Leaves out the editor, build tools, dev pages and sources; switches the service
// worker off (the native app ships every file already, and WKWebView doesn't run it).
const fs = require("fs"), path = require("path");
const SRC = path.resolve(__dirname, "../../chineseLearning/app");
const OUT = path.resolve(__dirname, "../www");
const INCLUDE = ["index.html", "app.js", "data.js", "chars-data.js", "hanzi-data.js", "readings.js", "migrate-old.js",
  "avatar-modular.js", "avatar-modular-data.js", "manifest.webmanifest", "icons", "images", "sounds", "vendor"];

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });
for (const name of INCLUDE) {
  const from = path.join(SRC, name);
  if (!fs.existsSync(from)) { console.warn("missing:", name); continue; }
  fs.cpSync(from, path.join(OUT, name), { recursive: true });
}
const idx = path.join(OUT, "index.html");
let html = fs.readFileSync(idx, "utf8");
const before = html;
html = html.replace('if ("serviceWorker" in navigator) {', 'if (!window.Capacitor && "serviceWorker" in navigator) {');
if (html === before) throw new Error("service worker registration not found in index.html");
fs.writeFileSync(idx, html);
let n = 0, bytes = 0;
(function walk(d) { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); if (f.isDirectory()) walk(p); else { n++; bytes += fs.statSync(p).size; } } })(OUT);
console.log(`www: ${n} files, ${(bytes / 1048576).toFixed(1)} MB (from ${SRC})`);
