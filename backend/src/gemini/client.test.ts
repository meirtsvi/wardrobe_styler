import { describe, expect, it } from "vitest";
import type { GenerateContentResponse } from "@google/genai";
import { GeminiClient, buildParams, withRetries } from "./client.js";

function response(text: string | undefined, finishReason = "STOP"): GenerateContentResponse {
  return { text, candidates: [{ finishReason }], usageMetadata: { promptTokenCount: 10, candidatesTokenCount: 5 } } as unknown as GenerateContentResponse;
}
const noSleep = async () => {};

describe("withRetries", () => {
  it("retries 429/503 with backoff and gives up after 4 attempts", async () => {
    let n = 0;
    await expect(withRetries(async () => { n++; throw { status: 503 }; }, { sleep: noSleep })).rejects.toEqual({ status: 503 });
    expect(n).toBe(4);
  });
  it("does not retry 400 or non-HTTP errors", async () => {
    let n = 0;
    await expect(withRetries(async () => { n++; throw { status: 400 }; }, { sleep: noSleep })).rejects.toEqual({ status: 400 });
    expect(n).toBe(1);
  });
  it("honours Retry-After", async () => {
    const delays: number[] = [];
    let n = 0;
    await withRetries(async () => { if (n++ === 0) throw { status: 429, headers: { "retry-after": "2" } }; return "ok"; }, { sleep: async (ms) => { delays.push(ms); } });
    expect(delays).toEqual([2000]);
  });
});

describe("buildParams", () => {
  it("sets JSON schema, thinking level and flex tier in one place", () => {
    const p = buildParams({ model: "gemini-3.8-flash", contents: "hi", responseSchema: { type: "object" }, thinkingLevel: "LOW", serviceTier: "flex", maxOutputTokens: 4096 });
    const config = p.config as Record<string, unknown>;
    expect(config.responseMimeType).toBe("application/json");
    expect(config.responseJsonSchema).toEqual({ type: "object" });
    expect(config.thinkingConfig).toEqual({ thinkingLevel: "LOW" });
    expect(config.maxOutputTokens).toBe(4096);
    expect((config.httpOptions as { extraBody: unknown }).extraBody).toEqual({ service_tier: "flex" });
  });
});

describe("GeminiClient.generateJson", () => {
  it("parses JSON and reports usage", async () => {
    const c = new GeminiClient(async () => response('{"a":1}'), { sleep: noSleep });
    const r = await c.generateJson<{ a: number }>({ model: "m", contents: "x" });
    expect(r.data).toEqual({ a: 1 });
    expect(r.usage.in).toBe(10);
    expect(r.tier).toBe("standard");
  });
  it("falls back from flex to standard on 503", async () => {
    const tiers: string[] = [];
    const c = new GeminiClient(async (p) => {
      const flex = !!(p.config as { httpOptions?: { extraBody?: { service_tier?: string } } })?.httpOptions?.extraBody?.service_tier;
      tiers.push(flex ? "flex" : "standard");
      if (flex) throw { status: 503 };
      return response("{}");
    }, { sleep: noSleep, maxAttempts: 2 });
    const r = await c.generateJson({ model: "m", contents: "x", serviceTier: "flex" });
    expect(r.tier).toBe("standard");
    expect(tiers).toEqual(["flex", "flex", "standard"]);
  });
  it("never retries a safety block and surfaces empty/bad JSON with codes", async () => {
    let n = 0;
    const safety = new GeminiClient(async () => { n++; return response(undefined, "SAFETY"); }, { sleep: noSleep });
    await expect(safety.generateJson({ model: "m", contents: "x" })).rejects.toMatchObject({ code: "safety_block" });
    expect(n).toBe(1);
    const empty = new GeminiClient(async () => response(undefined, "MAX_TOKENS"), { sleep: noSleep });
    await expect(empty.generateJson({ model: "m", contents: "x" })).rejects.toMatchObject({ code: "empty" });
    const bad = new GeminiClient(async () => response("not json"), { sleep: noSleep });
    await expect(bad.generateJson({ model: "m", contents: "x" })).rejects.toMatchObject({ code: "bad_json" });
  });
});
