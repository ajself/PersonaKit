// Regenerates the Open Graph / Twitter share image at
// public/brand/personakit-og.png. Run after the hero copy changes:
//
//   npm run generate:og
//
// Chrome (or Chromium) renders the card so the image uses the same system
// fonts and brand palette as the site. Set CHROME to override the binary path.
// This is a manual asset step, intentionally kept out of `astro build`.

import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const publicDir = join(here, "..", "public");
const markPath = join(publicDir, "brand", "personakit-mark.svg");
const outPath = join(publicDir, "brand", "personakit-og.png");

// Single source for the card copy. Keep the title in sync with the site hero.
const card = {
  wordmark: "PersonaKit",
  title: "You told the agent to stay read-only. It edited anyway.",
  lede: "PersonaKit writes the boundary down as a contract you can read before the agent starts.",
  principle: "Availability is not authorization.",
  url: "ajself.github.io/PersonaKit",
};

// Brand palette, mirrored from SiteLayout :root.
const ink = "#202428";
const muted = "#606a73";
const accent = "#2e6f95";

const mark = readFileSync(markPath).toString("base64");
const html = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0}
*{box-sizing:border-box;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif}
</style></head><body>
<div style="width:1200px;height:630px;background:#fff;display:flex;flex-direction:column;justify-content:space-between;padding:74px 80px;position:relative">
  <div style="position:absolute;left:0;top:0;bottom:0;width:14px;background:${accent}"></div>
  <div style="display:flex;align-items:center;gap:18px">
    <div style="width:64px;height:64px;border-radius:16px;background:${accent};display:grid;place-items:center">
      <img src="data:image/svg+xml;base64,${mark}" style="width:37px;height:48px;display:block">
    </div>
    <span style="font-size:40px;font-weight:800;color:${ink};letter-spacing:-0.01em">${card.wordmark}</span>
  </div>
  <div>
    <div style="font-size:70px;line-height:1.08;font-weight:800;color:${ink};letter-spacing:-0.02em;max-width:1000px">${card.title}</div>
    <div style="font-size:31px;color:${muted};margin-top:26px;max-width:920px;line-height:1.4">${card.lede}</div>
  </div>
  <div style="display:flex;align-items:center;justify-content:space-between">
    <span style="font-size:25px;font-weight:800;color:${accent}">${card.principle}</span>
    <span style="font-size:22px;color:${muted}">${card.url}</span>
  </div>
</div>
</body></html>`;

const htmlPath = join(mkdtempSync(join(tmpdir(), "pk-og-")), "og.html");
writeFileSync(htmlPath, html);

const candidates = [
  process.env.CHROME,
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "google-chrome",
  "chromium",
].filter(Boolean);
const chrome = candidates.find((c) => c.includes("/") ? existsSync(c) : true);

execFileSync(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  "--force-device-scale-factor=1",
  "--window-size=1200,630",
  `--screenshot=${outPath}`,
  `file://${htmlPath}`,
], { stdio: "inherit" });

console.log(`Wrote ${outPath}`);
