// `npm run smoke [outdir]`: exercises every Gemini path against the real API with generated assets and reports cost. Dev only.
import { GoogleGenAI, type GenerateContentParameters } from "@google/genai";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { loadConfig } from "./config.js";
import { context, fixtureCloset } from "./domain/fixtures.js";
import { stageA } from "./domain/stageA.js";
import { analyseAttributes } from "./gateway/attributes.js";
import { GeminiClient, usageOf } from "./gemini/client.js";
import { ImageGenerator, type InlineImage } from "./gemini/images.js";
import { GeminiPlanner } from "./planner/geminiPlanner.js";
import { planFromCandidates } from "./planner/planOutfits.js";
import { estimateCost } from "./usage.js";

const cfg = loadConfig();
if (!cfg.geminiApiKey) { console.error("GEMINI_API_KEY not set"); process.exit(1); }
const out = process.argv[2] ?? "data/smoke";
mkdirSync(out, { recursive: true });
const ai = new GoogleGenAI({ apiKey: cfg.geminiApiKey });
const generate = (p: GenerateContentParameters) => ai.models.generateContent(p);
const client = new GeminiClient(generate);
const images = new ImageGenerator(generate);
let total = 0;
const step = (name: string, cost: number, ms: number, extra = "") => { total += cost; console.log(`${name.padEnd(22)} ${(ms / 1000).toFixed(1)}s  $${cost.toFixed(4)}  ${extra}`); };

async function textToImage(prompt: string, model: string, file: string): Promise<InlineImage> {
  const t = Date.now();
  const res = await generate({ model, contents: prompt, config: { responseModalities: ["IMAGE"], imageConfig: { imageSize: "1K" } } } as unknown as GenerateContentParameters);
  const part = res.candidates?.[0]?.content?.parts?.find((p) => p.inlineData);
  if (!part?.inlineData?.data) throw new Error(`no image for "${prompt.slice(0, 40)}" (${res.candidates?.[0]?.finishReason})`);
  const img = { mimeType: part.inlineData.mimeType as InlineImage["mimeType"], data: part.inlineData.data };
  writeFileSync(join(out, file), Buffer.from(img.data, "base64"));
  step(`gen ${file}`, estimateCost(model, usageOf(res), 1, "1K").cost, Date.now() - t, `${img.mimeType} ${Math.round(img.data.length * 0.75 / 1024)} KB`);
  return img;
}

// 1. Stage B planning (JSON schema + thinking config).
{
  const ctx = context({ wearWindow: { min_feels_like_c: 9, max_feels_like_c: 21, precip_prob_max: 10 } });
  const cands = stageA(fixtureCloset(), ctx);
  const t = Date.now();
  let cost = 0;
  const planner = new GeminiPlanner(client, { model: cfg.models.plan, onUsage: (u) => { cost += estimateCost(u.model, u.usage).cost; } });
  const r = await planFromCandidates(planner, cands, ctx, 3);
  step("plan", cost, Date.now() - t, `${r.outfits.length} outfits, calls=${r.calls}, first-pass=${r.outfits.filter((o) => !o.validator.repaired && !o.validator.fallback).length}`);
  for (const o of r.outfits) console.log(`   ${o.validator.fallback ? "[combiner]" : o.validator.repaired ? "[repaired]" : "[ok]"} ${o.outfit.rationale}\n     ${o.outfit.slots.map((s) => `${s.slot}=${s.item_id}`).join(" ")}`);
  writeFileSync(join(out, "plan.json"), JSON.stringify(r, null, 2));
}

// 2. A garment product image, then attribute naming on it.
const garment = await textToImage("Flat product photo of a navy blue wool blazer, centred, on a pure white background, no people, no text, no logos.", cfg.models.imageLite, "garment.png");
{
  const t = Date.now();
  const r = await analyseAttributes(client, { bulk: cfg.models.attributesBulk, accurate: cfg.models.attributesAccurate }, {
    imageBase64: garment.data, mimeType: garment.mimeType === "image/jpeg" ? "image/jpeg" : "image/png",
    pixelPalette: { primary_hex: "#1F2A44", primary_name: "navy", secondary_hex: [] }, detectionLabel: "clothing",
  });
  step("attributes", estimateCost(r.model, r.usage).cost, Date.now() - t, `${r.attributes.category}/${r.attributes.subcategory} ${r.attributes.material} ${r.attributes.formality} conf=${r.attributes.field_confidences.category}`);
  writeFileSync(join(out, "attributes.json"), JSON.stringify(r.attributes, null, 2));
}

// 3. A person photo (generated, so no real person is sent), then try-on with the garment.
const person = await textToImage("Full-body photo of an adult standing facing the camera in a plain grey t-shirt and jeans, neutral pose, plain light background, natural light, photorealistic.", cfg.models.image, "person.png");
{
  const t = Date.now();
  const r = await images.tryOn(cfg.models.image, { person, garments: [{ image: garment, label: "navy wool blazer" }], imageSize: "1K" });
  writeFileSync(join(out, "look.png"), Buffer.from(r.image.data, "base64"));
  step("try-on", estimateCost(r.model, r.usage, 1, "1K").cost, Date.now() - t, `${r.image.mimeType} finish=${r.finishReason}${r.text ? " text=" + r.text.slice(0, 60) : ""}`);
}

console.log(`\nTotal estimated: $${total.toFixed(4)}  (outputs in ${out})`);
