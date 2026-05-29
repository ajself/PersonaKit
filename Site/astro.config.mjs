import { defineConfig } from "astro/config";

const site = process.env.PERSONAKIT_SITE_URL ?? "https://ajself.github.io";
const base = process.env.PERSONAKIT_SITE_BASE ?? "/";

export default defineConfig({
  site,
  base,
  output: "static",
});
