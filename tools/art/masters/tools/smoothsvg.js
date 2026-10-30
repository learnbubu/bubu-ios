// a traced SVG's outlines smoothed: each outline resampled evenly and averaged along its length (a Gaussian of sigma
// units), so the tracer's little pixel steps become curves; a thin edge in each shape's own colour covers any hairline
// gaps opened between neighbours; a pale pink sliver (the keyed-off magenta) is dropped.
//   node masters/tools/smoothsvg.js traced.svg masters/vec-roof-eave.svg 4   (the owner: "rough edge clean up")
const fs = require("fs");
const [, , src, out, sig] = process.argv, SIG = +sig;
const svg = fs.readFileSync(src, "utf8");
function polys(d) {
  const t = d.match(/[MCLZ]|-?[\d.]+/g), res = []; let cur = null, i = 0, x = 0, y = 0;
  const num = () => +t[i++];
  while (i < t.length) {
    const c = t[i++];
    if (c === "M") { x = num(); y = num(); cur = [[x, y]]; res.push(cur); }
    else if (c === "L") { x = num(); y = num(); cur.push([x, y]); }
    else if (c === "C") { const p = [x, y, num(), num(), num(), num(), num(), num()];
      for (let k = 1; k <= 8; k++) { const s = k / 8, u = 1 - s;
        cur.push([u*u*u*p[0] + 3*u*u*s*p[2] + 3*u*s*s*p[4] + s*s*s*p[6], u*u*u*p[1] + 3*u*u*s*p[3] + 3*u*s*s*p[5] + s*s*s*p[7]]); }
      x = p[6]; y = p[7]; }
    else if (c === "Z") {}
  }
  return res;
}
function resample(pl, step) {
  const o = []; const n = pl.length;
  for (let k = 0; k < n; k++) { const a = pl[k], b = pl[(k + 1) % n]; const L = Math.hypot(b[0] - a[0], b[1] - a[1]); const m = Math.max(1, Math.ceil(L / step));
    for (let j = 0; j < m; j++) o.push([a[0] + (b[0] - a[0]) * j / m, a[1] + (b[1] - a[1]) * j / m]); }
  return o;
}
function smooth(pl) {
  const p = resample(pl, 1), n = p.length, r = Math.ceil(SIG * 2.5);
  if (n < 2 * r + 3) return p;
  const w = []; for (let j = -r; j <= r; j++) w.push(Math.exp(-j * j / (2 * SIG * SIG)));
  const ws = w.reduce((a, b) => a + b);
  const o = p.map((_, k) => { let sx = 0, sy = 0; for (let j = -r; j <= r; j++) { const q = p[(k + j + n) % n]; sx += q[0] * w[j + r]; sy += q[1] * w[j + r]; } return [sx / ws, sy / ws]; });
  return o.filter((_, k) => k % 2 === 0);
}
const res = svg.replace(/<path ([^>]*?)d="([^"]*)"([^>]*?)\/>/g, (m, pre, d, post) => {
  const fill = (/fill="([^"]*)"/.exec(pre + post) || [])[1] || "#000";
  // (the magenta it was keyed off, left as a pale pink sliver round the edge: dropped)
  const [r, g, b] = [1, 3, 5].map(k => parseInt(fill.slice(k, k + 2), 16));
  if (r > 200 && b > 150 && b > g + 8) return "";
  const nd = polys(d).map(pl => "M" + smooth(pl).map(q => q[0].toFixed(1) + " " + q[1].toFixed(1)).join("L") + "Z").join("");
  return `<path ${pre}d="${nd}"${post.replace(/\s*$/, "")} stroke="${fill}" stroke-width="1.2" stroke-linejoin="round"/>`;
});
fs.writeFileSync(out, res);
console.log(out.split(/[\/]/).pop(), (res.length / 1024).toFixed(0) + "k");
