// Checks that every deck style's text is readable (WCAG AA: 4.5 to 1 for body text).
// Usage: node scripts/check-contrast.mjs        (exits with 1 if any pair fails)
//
// Pairs checked per style:
//   ink on bg, ink on surface, muted on bg, muted on surface,
//   coverInk on every colour stop of cover, accentInk on accent.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const STYLES = path.join(ROOT, "plugins/fundraise/skills/fundraise/deck/styles");
const MIN = 4.5;

const parse = (s) => {
  let h = s.trim().replace("#", "");
  if (h.length === 3) h = [...h].map((x) => x + x).join("");
  if (!/^[0-9a-f]{6}$/i.test(h)) return null;
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
};
const lum = (rgb) => {
  const [r, g, b] = rgb.map((v) => {
    const x = v / 255;
    return x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
export const ratio = (a, b) => {
  const [x, y] = [lum(parse(a)), lum(parse(b))].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};
/** Every hex colour in a CSS background value (a plain colour or a gradient). */
const stops = (bg) => bg.match(/#[0-9a-f]{3,6}\b/gi) ?? [];

export function checkStyle(t) {
  const pairs = [
    ["ink / bg", t.ink, [t.bg]],
    ["ink / surface", t.ink, [t.surface]],
    ["muted / bg", t.muted, [t.bg]],
    ["muted / surface", t.muted, [t.surface]],
    ["coverInk / cover", t.coverInk, stops(t.cover)],
    ["accentInk / accent", t.accentInk, [t.accent]],
  ];
  return pairs.map(([name, fg, grounds]) => {
    const worst = Math.min(...grounds.map((g) => ratio(fg, g)));
    return { name, ratio: worst, ok: worst >= MIN };
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  let bad = 0;
  const files = fs.readdirSync(STYLES).filter((f) => f.endsWith(".json") && f !== "index.json").sort();
  for (const f of files) {
    const s = JSON.parse(fs.readFileSync(path.join(STYLES, f), "utf8"));
    const res = checkStyle(s.tokens);
    const fails = res.filter((r) => !r.ok);
    bad += fails.length;
    const line = res.map((r) => `${r.name} ${r.ratio.toFixed(1)}${r.ok ? "" : " FAIL"}`).join(" | ");
    console.log(`${fails.length ? "FAIL" : "ok  "} ${s.id.padEnd(8)} ${line}`);
  }
  console.log(bad ? `\n${bad} pair(s) below ${MIN}:1` : `\nAll ${files.length} styles pass ${MIN}:1`);
  process.exit(bad ? 1 : 0);
}
