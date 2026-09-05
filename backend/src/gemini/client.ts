// Gemini access (PLAN §7.2 "Retries", §5.3 tier policy). One place builds requests so the response_format/image_config deprecation
// switch (PLAN §13.3 item 9) is a one-file change. The SDK is behind `GenerateFn` so tests and the load test use a fake.
import { GoogleGenAI, type GenerateContentParameters, type GenerateContentResponse } from "@google/genai";

export type GenerateFn = (params: GenerateContentParameters) => Promise<GenerateContentResponse>;

export type RetryOptions = { maxAttempts?: number; baseMs?: number; maxMs?: number; sleep?: (ms: number) => Promise<void> };

const RETRYABLE = new Set([408, 429, 500, 502, 503, 504]);

export function statusOf(err: unknown): number | undefined {
  const e = err as { status?: number; code?: number; error?: { code?: number } };
  return e?.status ?? e?.code ?? e?.error?.code;
}

export function isSafetyBlock(res: GenerateContentResponse): boolean {
  const reason = res.candidates?.[0]?.finishReason ?? res.promptFeedback?.blockReason;
  return reason === "SAFETY" || reason === "PROHIBITED_CONTENT" || reason === "BLOCKLIST" || reason === "IMAGE_SAFETY";
}

/** Exponential backoff with full jitter (0.5 → 8 s, max 4 attempts), honouring Retry-After; never retries safety blocks. */
export async function withRetries<T>(fn: () => Promise<T>, opts: RetryOptions = {}): Promise<T> {
  const maxAttempts = opts.maxAttempts ?? 4;
  const base = opts.baseMs ?? 500;
  const cap = opts.maxMs ?? 8000;
  const sleep = opts.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  let attempt = 0;
  for (;;) {
    try {
      return await fn();
    } catch (err) {
      attempt++;
      const status = statusOf(err);
      if (attempt >= maxAttempts || status === undefined || !RETRYABLE.has(status)) throw err;
      const retryAfter = Number((err as { headers?: Record<string, string> })?.headers?.["retry-after"]);
      const delay = Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter * 1000 : Math.random() * Math.min(cap, base * 2 ** (attempt - 1));
      await sleep(delay);
    }
  }
}

export type GeminiCallOptions = {
  model: string;
  systemInstruction?: string;
  contents: GenerateContentParameters["contents"];
  responseSchema?: Record<string, unknown>;
  thinkingLevel?: "MINIMAL" | "LOW" | "MEDIUM" | "HIGH";
  temperature?: number;
  maxOutputTokens?: number;
  mediaResolution?: "MEDIA_RESOLUTION_LOW" | "MEDIA_RESOLUTION_MEDIUM" | "MEDIA_RESOLUTION_HIGH";
  /** Flex tier is cheaper and slower; on 503 we fall back to standard once (PLAN §5.3). */
  serviceTier?: "flex" | "standard";
};

/** Builds the request in one place (PLAN §13.3 item 9: response_mime_type/response_json_schema are deprecated in favour of response_format). */
export function buildParams(o: GeminiCallOptions): GenerateContentParameters {
  const config: Record<string, unknown> = {};
  if (o.systemInstruction) config.systemInstruction = o.systemInstruction;
  if (o.responseSchema) {
    config.responseMimeType = "application/json";
    config.responseJsonSchema = o.responseSchema;
  }
  if (o.thinkingLevel) config.thinkingConfig = { thinkingLevel: o.thinkingLevel };
  if (o.temperature !== undefined) config.temperature = o.temperature;
  if (o.maxOutputTokens) config.maxOutputTokens = o.maxOutputTokens;
  if (o.mediaResolution) config.mediaResolution = o.mediaResolution;
  if (o.serviceTier === "flex") config.httpOptions = { ...(config.httpOptions as object), extraBody: { service_tier: "flex" } };
  return { model: o.model, contents: o.contents, config } as GenerateContentParameters;
}

export type Usage = { in: number; out: number; thought: number; cached: number };

export function usageOf(res: GenerateContentResponse): Usage {
  const u = res.usageMetadata;
  return { in: u?.promptTokenCount ?? 0, out: u?.candidatesTokenCount ?? 0, thought: u?.thoughtsTokenCount ?? 0, cached: u?.cachedContentTokenCount ?? 0 };
}

export class GeminiClient {
  constructor(private readonly generate: GenerateFn, private readonly retry: RetryOptions = {}) {}

  static fromApiKey(apiKey: string, retry: RetryOptions = {}): GeminiClient {
    const ai = new GoogleGenAI({ apiKey });
    return new GeminiClient((p) => ai.models.generateContent(p), retry);
  }

  /** JSON-mode call. Returns parsed JSON or throws {code:"safety_block"|"empty"|"bad_json"}. Flex 503 falls back to standard. */
  async generateJson<T>(o: GeminiCallOptions): Promise<{ data: T; usage: Usage; model: string; finishReason: string | undefined; tier: string }> {
    const run = (tier: "flex" | "standard") => withRetries(() => this.generate(buildParams({ ...o, serviceTier: tier })), this.retry);
    let res: GenerateContentResponse;
    let tier = o.serviceTier ?? "standard";
    try {
      res = await run(tier);
    } catch (err) {
      if (tier === "flex" && statusOf(err) === 503) {
        tier = "standard";
        res = await run(tier);
      } else throw err;
    }
    if (isSafetyBlock(res)) throw Object.assign(new Error("safety block"), { code: "safety_block" });
    const text = res.text;
    if (!text) throw Object.assign(new Error(`empty response (${res.candidates?.[0]?.finishReason})`), { code: "empty" });
    let data: T;
    try {
      data = JSON.parse(text) as T;
    } catch {
      throw Object.assign(new Error("model returned invalid JSON"), { code: "bad_json" });
    }
    return { data, usage: usageOf(res), model: o.model, finishReason: res.candidates?.[0]?.finishReason, tier };
  }
}
