// Renders the deck style previews and the gallery.
//
//   node scripts/render-previews.mjs                 every style -> deck/previews/<id>.png (cover) and <id>-2.png (chart slide),
//                                                    plus deck/previews/gallery.png and deck/gallery.html
//   node scripts/render-previews.mjs --only ember    just one style (comma list allowed)
//   node scripts/render-previews.mjs --all ember --out /some/dir   every slide of a style, for checking layouts
//
// Only needed if you change the styles and want new pictures. It needs Google Chrome plus two helper packages,
// puppeteer-core and sharp. Either:
//   - run `npm install` in this repo once (they are listed as devDependencies in package.json), or
//   - set PUPPETEER_PATH to a folder where both are already installed (for example another project's node_modules).
// Set CHROME=/path/to/chrome if Chrome is not in a usual place.
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { checkStyle } from "./check-contrast.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// Find puppeteer-core and sharp: PUPPETEER_PATH first, then this repo's own node_modules.
function findHelpers() {
  const places = [process.env.PUPPETEER_PATH, process.env.PUPPETEER_FROM].filter(Boolean).map((d) => path.join(path.resolve(d), "noop.js"));
  places.push(path.join(ROOT, "package.json"));
  for (const from of places) {
    const req = createRequire(from);
    try {
      req.resolve("puppeteer-core");
      req.resolve("sharp");
      return req;
    } catch {
      /* try the next place */
    }
  }
  console.error(
    "Could not find puppeteer-core and sharp.\n" +
      "Fix it one of two ways:\n" +
      "  1. Run `npm install` in this repo, then run this script again.\n" +
      "  2. Or set PUPPETEER_PATH to a folder that already has both, for example:\n" +
      "     PUPPETEER_PATH=/path/to/other-project/node_modules node scripts/render-previews.mjs",
  );
  process.exit(1);
}
const require = findHelpers();
const puppeteer = require("puppeteer-core");
const sharp = require("sharp");

const DECK = path.join(ROOT, "plugins/fundraise/skills/fundraise/deck");
const STYLES = path.join(DECK, "styles");
const PREVIEWS = path.join(DECK, "previews");
const TEMPLATE = pathToFileURL(path.join(DECK, "deck-template.html")).href;

const CHROME_CANDIDATES = [
  process.env.CHROME,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
  "/usr/bin/chromium",
  "/usr/bin/chromium-browser",
].filter(Boolean);
const CHROME = CHROME_CANDIDATES.find((p) => fs.existsSync(p));
if (!CHROME) throw new Error("Chrome not found. Set CHROME=/path/to/chrome");

const arg = (name) => {
  const i = process.argv.indexOf(name);
  return i > -1 ? process.argv[i + 1] : null;
};
const ONLY = (arg("--only") || arg("--all") || "").split(",").filter(Boolean);
const ALL = process.argv.includes("--all");
const OUT = arg("--out") || PREVIEWS;

const index = JSON.parse(fs.readFileSync(path.join(STYLES, "index.json"), "utf8"));
const styles = index.styles.map((s) => JSON.parse(fs.readFileSync(path.join(STYLES, `${s.id}.json`), "utf8")));
const chosen = ONLY.length ? styles.filter((s) => ONLY.includes(s.id)) : styles;

// camelCase token -> CSS variable (same mapping as the notes at the top of deck-template.html)
const cssVar = (k) => "--" + k.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());

/** The bar chart, exactly as the template notes describe (viewBox 0 0 600 440). */
function chartSvg({ labels, values }) {
  const n = values.length;
  const slot = 600 / n;
  const w = +(slot * 0.56).toFixed(1);
  const max = Math.max(...values);
  const fmt = (v) => (v >= 1000 ? v.toLocaleString("en-US") : String(v));
  let s = [70, 150, 230, 310].map((y) => `<line class="gl" x1="0" x2="600" y1="${y}" y2="${y}"/>`).join("");
  s += `<line class="base" x1="0" x2="600" y1="390" y2="390"/>`;
  values.forEach((v, i) => {
    const h = +((v / max) * 320).toFixed(1);
    const x = +(i * slot + (slot - w) / 2).toFixed(1);
    const y = +(390 - h).toFixed(1);
    const cx = +(x + w / 2).toFixed(1);
    s += `<rect class="bar${i === n - 1 ? " hi" : ""}" x="${x}" y="${y}" width="${w}" height="${h}" rx="6"/>`;
    s += `<text class="v" x="${cx}" y="${+(y - 12).toFixed(1)}">${fmt(v)}</text><text x="${cx}" y="420">${labels[i]}</text>`;
  });
  return s;
}

/** Applies a style and its sample to the open template (runs in the page). */
function applyStyle(vars, deco, fontsHref, fill, chart) {
  const root = document.documentElement;
  for (const [k, v] of Object.entries(vars)) root.style.setProperty(k, String(v));
  root.dataset.deco = deco;
  // A fresh <link> so onload always fires, even when the href is the same as the template's.
  const old = document.getElementById("google-fonts");
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.id = "google-fonts";
  const loaded = new Promise((res) => {
    link.onload = res;
    link.onerror = res;
    setTimeout(res, 15000);
  });
  link.href = fontsHref;
  old.replaceWith(link);
  for (const el of document.querySelectorAll("[data-k]")) {
    const key = el.dataset.k;
    if (key === "growth.chart") el.innerHTML = chart;
    else if (key in fill) el.textContent = fill[key];
  }
  document.title = `${fill.company} · Sample deck`;
  const ready = Promise.race([document.fonts.ready, new Promise((res) => setTimeout(res, 10000))]);
  return loaded.then(() => ready).then(() => {
    const faces = [...document.fonts].filter((f) => f.status === "loaded").map((f) => f.family.replace(/["']/g, ""));
    return [...new Set(faces)];
  });
}

/** Flattens the sample into the data-k keys the template uses. */
function fillFor(s) {
  const out = {};
  const walk = (o, pre) => {
    for (const [k, v] of Object.entries(o)) {
      const key = pre ? `${pre}.${k}` : k;
      if (v && typeof v === "object" && !Array.isArray(v)) walk(v, key);
      else if (Array.isArray(v) && v.every((x) => x && typeof x === "object")) v.forEach((x, i) => walk(x, `${key}.${i}`));
      else out[key] = v;
    }
  };
  walk(s.sample, "");
  out.initial = s.sample.company.trim()[0].toUpperCase();
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- contrast first
let contrastFails = 0;
for (const s of chosen) {
  const bad = checkStyle(s.tokens).filter((r) => !r.ok);
  contrastFails += bad.length;
  if (bad.length) console.log(`contrast FAIL ${s.id}: ${bad.map((b) => `${b.name} ${b.ratio.toFixed(2)}`).join(", ")}`);
}

// ---------------------------------------------------------------- render
fs.mkdirSync(OUT, { recursive: true });
const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ["--no-first-run", "--allow-file-access-from-files"] });
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });
const fontProblems = [];

async function save(file) {
  const buf = await page.screenshot({ type: "png" });
  await sharp(buf).png({ compressionLevel: 9, effort: 10 }).toFile(file);
}

for (const s of chosen) {
  const vars = Object.fromEntries(Object.entries(s.tokens).filter(([k]) => k !== "decoration").map(([k, v]) => [cssVar(k), v]));
  const href = `https://fonts.googleapis.com/css2?${s.googleFonts}`;
  let faces = [];
  let missing = [];
  // Google Fonts is sometimes slow; try up to 3 times before giving up on a style's fonts.
  for (let attempt = 1; attempt <= 3; attempt++) {
    if (process.env.DEBUG) console.log(`${s.id}: open (try ${attempt})`);
    await page.goto(`${TEMPLATE}?clean#1`, { waitUntil: "domcontentloaded", timeout: 60000 });
    faces = await page.evaluate(applyStyle, vars, s.tokens.decoration, href, fillFor(s), chartSvg(s.sample.growth));
    missing = [s.fonts.head, s.fonts.body].filter((want) => !faces.includes(want));
    if (!missing.length) break;
  }
  for (const want of missing) fontProblems.push(`${s.id}: "${want}" did not load (got ${faces.join(", ") || "none"})`);
  if (process.env.DEBUG) console.log(`${s.id}: styled`);
  await sleep(150);
  const count = await page.evaluate(() => document.querySelectorAll(".slide").length);
  if (ALL) {
    for (let n = 1; n <= count; n++) {
      await page.evaluate((n) => (location.hash = `#${n}`), n);
      await sleep(80);
      await save(path.join(OUT, `${s.id}-all-${String(n).padStart(2, "0")}.png`));
    }
    console.log(`${s.id}: ${count} slides -> ${OUT}`);
    continue;
  }
  await save(path.join(OUT, `${s.id}.png`));
  const growth = await page.evaluate(() => [...document.querySelectorAll(".slide")].findIndex((el) => el.dataset.section === "growth") + 1);
  await page.evaluate((n) => (location.hash = `#${n}`), growth);
  await sleep(80);
  await save(path.join(OUT, `${s.id}-2.png`));
  console.log(`${s.id.padEnd(8)} ${s.name.padEnd(8)} ${s.tokens.decoration.padEnd(6)} fonts: ${faces.join(" + ")}`);
}

// ---------------------------------------------------------------- gallery.png (4 x 5 grid of covers) + gallery.html
if (!ALL && !ONLY.length) {
  const thumbs = [];
  for (const s of styles) {
    const b = await sharp(path.join(PREVIEWS, `${s.id}.png`)).resize(400, 225).png().toBuffer();
    thumbs.push({ s, src: `data:image/png;base64,${b.toString("base64")}` });
  }
  const cards = thumbs
    .map(({ s, src }, i) => `<figure><img src="${src}"><figcaption><b>${i + 1}. ${s.name}</b><span>${s.bestFor}</span></figcaption></figure>`)
    .join("");
  const html = `<!doctype html><meta charset="utf-8"><style>
    *{box-sizing:border-box;margin:0}
    body{background:#f4f3ef;font:15px/1.35 -apple-system,'Helvetica Neue',Arial,sans-serif;color:#1f1f1f;padding:36px 36px 28px;width:1764px}
    h1{font-size:30px;font-weight:650;letter-spacing:-.02em}
    p.sub{color:#5c5c5c;margin:6px 0 26px;font-size:16px}
    main{display:grid;grid-template-columns:repeat(4,400px);gap:28px 28px}
    figure img{display:block;width:400px;height:225px;border-radius:10px;box-shadow:0 1px 2px rgba(0,0,0,.08),0 6px 18px rgba(0,0,0,.08)}
    figcaption{padding:10px 2px 0;display:grid;gap:2px}
    figcaption b{font-size:16px}
    figcaption span{color:#5c5c5c;font-size:13.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  </style><h1>20 pitch deck styles</h1><p class="sub">Pick one by name. Every deck is one HTML file you can present or save as PDF. Sample companies are made up.</p><main>${cards}</main>`;
  await page.setViewport({ width: 1764, height: 800, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: "load" });
  const buf = await page.screenshot({ type: "png", fullPage: true });
  const galleryFile = path.join(PREVIEWS, "gallery.png");
  await sharp(buf).png({ compressionLevel: 9, effort: 10, palette: true, quality: 92, dither: 0.6 }).toFile(galleryFile);
  console.log(`gallery.png ${(fs.statSync(galleryFile).size / 1024 / 1024).toFixed(2)} MB`);

  const esc = (t) => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;");
  const items = styles
    .map(
      (s, i) => `    <article>
      <img src="previews/${s.id}.png" alt="${esc(s.name)} cover" loading="lazy">
      <img src="previews/${s.id}-2.png" alt="${esc(s.name)} chart slide" loading="lazy">
      <h2>${i + 1}. ${esc(s.name)} <code>${s.id}</code></h2>
      <p class="best">${esc(s.bestFor)}</p>
      <p class="mood">${esc(s.mood)} Fonts: ${esc(s.fonts.head)} + ${esc(s.fonts.body)}.</p>
    </article>`,
    )
    .join("\n");
  const gallery = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Deck styles</title>
<!-- Made by scripts/render-previews.mjs. Edit the script, not this file. -->
<style>
  :root { --bg: #f6f5f1; --ink: #1f1f1f; --muted: #5c5c5c; --card: #ffffff; --line: #e4e1d9; }
  @media (prefers-color-scheme: dark) { :root { --bg: #151517; --ink: #ededed; --muted: #a6a6ad; --card: #1f1f22; --line: #2e2e33; } }
  * { box-sizing: border-box; margin: 0; }
  body { background: var(--bg); color: var(--ink); font: 16px/1.45 -apple-system, "Segoe UI", Roboto, Arial, sans-serif; padding: 40px 16px 64px; }
  header, main { max-width: 1240px; margin: 0 auto; }
  h1 { font-size: 32px; letter-spacing: -.02em; }
  header p { color: var(--muted); margin: 8px 0 32px; max-width: 720px; }
  main { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap: 28px; }
  article { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 14px; display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  article img { width: 100%; aspect-ratio: 16 / 9; border-radius: 8px; display: block; }
  article h2, article p { grid-column: 1 / -1; }
  h2 { font-size: 19px; margin-top: 6px; }
  code { font-size: 13px; color: var(--muted); font-weight: 400; }
  .best { font-weight: 600; }
  .mood { color: var(--muted); font-size: 14px; }
</style>
</head>
<body>
  <header>
    <h1>Pick a style for your pitch deck</h1>
    <p>Tell Claude the name you like, for example "use Harbor". Each style changes colours, fonts and the cover art. Your words stay the same. Every sample company here is made up.</p>
  </header>
  <main>
${items}
  </main>
</body>
</html>
`;
  fs.writeFileSync(path.join(DECK, "gallery.html"), gallery);
  console.log("gallery.html written");
}

await browser.close();
if (fontProblems.length) console.log("\nFONT PROBLEMS:\n" + fontProblems.join("\n"));
if (contrastFails) console.log(`\n${contrastFails} contrast failure(s)`);
const total = fs.readdirSync(OUT).filter((f) => f.endsWith(".png")).reduce((a, f) => a + fs.statSync(path.join(OUT, f)).size, 0);
console.log(`\n${OUT}: ${(total / 1024 / 1024).toFixed(1)} MB of PNGs`);
process.exit(contrastFails || fontProblems.length ? 1 : 0);
