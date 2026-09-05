import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import type { GenerateContentParameters, GenerateContentResponse } from "@google/genai";
import { context, fixtureCloset } from "./domain/fixtures.js";
import { stageA } from "./domain/stageA.js";
import { GeminiClient } from "./gemini/client.js";
import { ImageGenerator } from "./gemini/images.js";
import { buildServer } from "./server.js";
import { UsageLog } from "./usage.js";

const models = { plan: "gemini-3.8-flash", attributesBulk: "gemini-3.5-flash-lite", attributesAccurate: "gemini-3.8-flash", image: "gemini-3.1-flash-image", imageLite: "gemini-3.1-flash-lite-image" };
const auth = { authorization: "Bearer secret-token" };
const png = { mime_type: "image/png", data: "iVBORw0KGgo=" };

const goodPlan = { outfits: [{ slots: [{ slot: "top", item_id: "shirt-blue", reason: "blue shirt" }, { slot: "bottom", item_id: "chinos-tan", reason: "tan chinos" }, { slot: "shoes", item_id: "sneakers-white", reason: "white sneakers" }], rationale: "Blue and tan, complementary.", weather_fit: "good", formality: "smart_casual", palette: [], layering_note: null, confidence: 0.9 }], anchor_honored: true, anchor_reason: null };

function fakeGen(): (p: GenerateContentParameters) => Promise<GenerateContentResponse> {
  return async (p) => {
    const cfg = p.config as { responseModalities?: string[] } | undefined;
    if (cfg?.responseModalities?.includes("IMAGE")) {
      return { candidates: [{ finishReason: "STOP", content: { parts: [{ inlineData: { mimeType: "image/png", data: "RENDER" } }] } }], usageMetadata: { promptTokenCount: 2000, candidatesTokenCount: 1290 } } as unknown as GenerateContentResponse;
    }
    return { text: JSON.stringify(goodPlan), candidates: [{ finishReason: "STOP" }], usageMetadata: { promptTokenCount: 3000, candidatesTokenCount: 600 } } as unknown as GenerateContentResponse;
  };
}

let app: FastifyInstance;
let offline: FastifyInstance;
let usage: UsageLog;

beforeAll(async () => {
  usage = new UsageLog(mkdtempSync(join(tmpdir(), "usage-")));
  const gen = fakeGen();
  app = buildServer({ token: "secret-token", dailyBudgetUsd: 1, usage, models, gemini: new GeminiClient(gen, { sleep: async () => {} }), images: new ImageGenerator(gen, { sleep: async () => {} }) });
  offline = buildServer({ token: "secret-token", dailyBudgetUsd: 1, usage: new UsageLog(mkdtempSync(join(tmpdir(), "usage-"))), models });
  await app.ready(); await offline.ready();
});
afterAll(async () => { await app.close(); await offline.close(); });

describe("auth", () => {
  it("rejects a missing or wrong token, accepts the right one", async () => {
    expect((await app.inject({ method: "GET", url: "/v1/usage" })).statusCode).toBe(401);
    expect((await app.inject({ method: "GET", url: "/v1/usage", headers: { authorization: "Bearer nope" } })).statusCode).toBe(401);
    expect((await app.inject({ method: "GET", url: "/v1/usage", headers: auth })).statusCode).toBe(200);
    expect((await app.inject({ method: "GET", url: "/healthz" })).json()).toEqual({ ok: true, gemini: true, images: true });
  });
});

describe("/v1/outfits/plan", () => {
  it("plans with Gemini from client candidates and logs usage", async () => {
    const ctx = context();
    const r = await app.inject({ method: "POST", url: "/v1/outfits/plan", headers: auth, payload: { occasion: "casual", weather: { wear_window: ctx.wearWindow }, accessory_count: "some", candidates: stageA(fixtureCloset(), ctx) } });
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json().planner).toBe("gemini");
    expect(r.json().outfits[0].validator.passed).toBe(true);
    expect(usage.spentToday().calls).toBeGreaterThanOrEqual(1);
  });
  it("works offline with the combiner", async () => {
    const ctx = context();
    const r = await offline.inject({ method: "POST", url: "/v1/outfits/plan", headers: auth, payload: { occasion: "casual", weather: { wear_window: ctx.wearWindow }, accessory_count: "some", candidates: stageA(fixtureCloset(), ctx) } });
    expect(r.statusCode).toBe(200);
    expect(r.json().planner).toBe("combiner");
  });
});

describe("/v1/looks", () => {
  it("returns a render and estimates cost per image", async () => {
    const r = await app.inject({ method: "POST", url: "/v1/looks", headers: auth, payload: { person: png, garments: [{ image: png, label: "navy blazer" }], image_size: "1K" } });
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json().image.data).toBe("RENDER");
    expect(r.json().cost_usd_est).toBeGreaterThan(0.05);
  });
  it("503 without a key; 400 on 5 garments", async () => {
    expect((await offline.inject({ method: "POST", url: "/v1/looks", headers: auth, payload: { person: png, garments: [{ image: png, label: "x" }] } })).statusCode).toBe(503);
    const five = Array.from({ length: 5 }, () => ({ image: png, label: "x" }));
    expect((await app.inject({ method: "POST", url: "/v1/looks", headers: auth, payload: { person: png, garments: five } })).statusCode).toBe(400);
  });
});

describe("budget", () => {
  it("refuses Gemini calls once the daily budget is spent", async () => {
    const tight = buildServer({ token: "t", dailyBudgetUsd: 0.0001, usage, models, gemini: new GeminiClient(fakeGen()), images: new ImageGenerator(fakeGen()) });
    await tight.ready();
    const r = await tight.inject({ method: "POST", url: "/v1/looks", headers: { authorization: "Bearer t" }, payload: { person: png, garments: [{ image: png, label: "x" }] } });
    expect(r.statusCode).toBe(429);
    expect(r.json().error).toBe("budget_exhausted");
    await tight.close();
  });
});
