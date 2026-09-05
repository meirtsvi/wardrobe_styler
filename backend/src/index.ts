// Entry point for the personal gateway on the Mac mini (ADR 0002). `npm start` after filling backend/.env.
import { randomBytes } from "node:crypto";
import { loadConfig } from "./config.js";
import { GeminiClient } from "./gemini/client.js";
import { ImageGenerator } from "./gemini/images.js";
import { buildServer } from "./server.js";
import { UsageLog } from "./usage.js";
import { GoogleGenAI } from "@google/genai";

const cfg = loadConfig();
if (!cfg.gatewayToken) {
  console.error(`GATEWAY_TOKEN is not set. Add this to backend/.env:\nGATEWAY_TOKEN=${randomBytes(32).toString("hex")}`);
  process.exit(1);
}
if (!cfg.geminiApiKey) console.warn("GEMINI_API_KEY not set: planning falls back to rules; attributes, looks and cleanup return 503.");

const ai = cfg.geminiApiKey ? new GoogleGenAI({ apiKey: cfg.geminiApiKey }) : undefined;
const generate = ai ? (p: Parameters<typeof ai.models.generateContent>[0]) => ai.models.generateContent(p) : undefined;

const app = buildServer({
  token: cfg.gatewayToken,
  dailyBudgetUsd: cfg.dailyBudgetUsd,
  usage: new UsageLog(cfg.dataDir),
  models: cfg.models,
  ...(generate ? { gemini: new GeminiClient(generate), images: new ImageGenerator(generate) } : {}),
});

app.listen({ port: cfg.port, host: "127.0.0.1" }).then(() => {
  console.log(`gateway listening on http://127.0.0.1:${cfg.port}  (gemini: ${!!ai}, budget: $${cfg.dailyBudgetUsd}/day)`);
});
