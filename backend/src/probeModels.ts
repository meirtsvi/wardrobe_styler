// `npm run probe-models`: lists the models the key can use and checks the configured ids exist (PLAN §13.3 item 1–6, ADR 0002).
import { GoogleGenAI } from "@google/genai";
import { loadConfig } from "./config.js";

const cfg = loadConfig();
if (!cfg.geminiApiKey) { console.error("GEMINI_API_KEY not set in backend/.env"); process.exit(1); }
const ai = new GoogleGenAI({ apiKey: cfg.geminiApiKey });

const names = new Set<string>();
for await (const m of await ai.models.list()) {
  const n = (m.name ?? "").replace(/^models\//, "");
  names.add(n);
  console.log(`${n.padEnd(44)} ${(m.supportedActions ?? []).join(",")}`);
}
console.log("\nConfigured:");
for (const [k, v] of Object.entries(cfg.models)) console.log(`  ${k.padEnd(20)} ${v.padEnd(36)} ${names.has(v) ? "ok" : "NOT FOUND — set GEMINI_*_MODEL in .env"}`);
