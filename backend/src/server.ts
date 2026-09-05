// Personal gateway (ADR 0002): one bearer token, Gemini behind a daily budget, no database. Runs on the Mac mini behind a Cloudflare quick tunnel.
import Fastify, { type FastifyInstance, type FastifyRequest } from "fastify";
import { timingSafeEqual } from "node:crypto";
import { isOccasion, type AccessoryCount } from "./domain/taxonomy.js";
import type { Candidate, PlanContext } from "./domain/types.js";
import { analyseAttributes } from "./gateway/attributes.js";
import type { GeminiClient } from "./gemini/client.js";
import { ImageGenError, type ImageGenerator, type InlineImage } from "./gemini/images.js";
import { GeminiPlanner } from "./planner/geminiPlanner.js";
import { CombinerPlanner, planFromCandidates, type Planner } from "./planner/planOutfits.js";
import { estimateCost, type UsageLog } from "./usage.js";

export type ServerDeps = {
  token: string;
  dailyBudgetUsd: number;
  usage: UsageLog;
  models: { plan: string; attributesBulk: string; attributesAccurate: string; image: string; imageLite: string };
  gemini?: GeminiClient; // text/JSON
  images?: ImageGenerator; // image output
  now?: () => Date;
};

class HttpError extends Error {
  constructor(public readonly status: number, public readonly code: string, message: string, public readonly extra: Record<string, unknown> = {}) { super(message); }
}

type PlanBody = {
  occasion: string;
  weather: { wear_window: { min_feels_like_c: number; max_feels_like_c: number; precip_prob_max: number; wind_max?: number | null }; city?: string | null };
  anchor_id?: string | null;
  accessory_count: AccessoryCount;
  learned_rules?: string[];
  recent_outfit_item_ids?: string[][];
  yesterday_item_ids?: string[];
  candidates: {
    id: string; category: string; subcategory: string; layer_role?: string | null; color_name: string; color_hex: string; pattern?: string; material?: string;
    warmth: string; formality: string; last_suggested_days?: number | null; wear_count?: number; quantity?: number; in_palette?: boolean;
  }[];
};

const inlineImageSchema = { type: "object", required: ["mime_type", "data"], properties: { mime_type: { type: "string", enum: ["image/jpeg", "image/png", "image/webp"] }, data: { type: "string", maxLength: 12_000_000 } } };

export function buildServer(deps: ServerDeps): FastifyInstance {
  const app = Fastify({ logger: false, bodyLimit: 40 * 1024 * 1024 });
  const now = deps.now ?? (() => new Date());

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof HttpError) return reply.status(err.status).send({ error: err.code, message: err.message, ...err.extra });
    if (err instanceof ImageGenError) return reply.status(err.code === "safety_block" ? 422 : 502).send({ error: err.code, message: err.message });
    const status = (err as { statusCode?: number }).statusCode;
    if (typeof status === "number" && status < 500) return reply.status(status).send({ error: "bad_request", message: (err as Error).message });
    const code = (err as { code?: string }).code;
    if (code === "safety_block") return reply.status(422).send({ error: code, message: "Gemini declined this content." });
    if (code === "bad_request") return reply.status(502).send({ error: "gemini_bad_request", message: (err as Error).message });
    console.error(err);
    return reply.status(500).send({ error: "internal", message: "internal error" });
  });

  function authenticate(req: FastifyRequest) {
    const header = req.headers.authorization ?? "";
    const given = header.startsWith("Bearer ") ? header.slice(7) : "";
    const a = Buffer.from(given), b = Buffer.from(deps.token);
    if (a.length === 0 || a.length !== b.length || !timingSafeEqual(a, b)) throw new HttpError(401, "unauthorized", "bad token");
  }

  function budgetCheck() {
    const spent = deps.usage.spentToday(now());
    if (spent.usd >= deps.dailyBudgetUsd) {
      throw new HttpError(429, "budget_exhausted", `Today's Gemini budget ($${deps.dailyBudgetUsd.toFixed(2)}) is used up; resets at midnight.`, { spent_usd: spent.usd });
    }
  }

  function requireGemini(): GeminiClient {
    if (!deps.gemini) throw new HttpError(503, "gemini_unavailable", "GEMINI_API_KEY is not set on the server.");
    return deps.gemini;
  }

  const planner: Planner = deps.gemini ? new GeminiPlanner(deps.gemini, { model: deps.models.plan, onUsage: (u) => {
    deps.usage.record({ feature: "plan", model: u.model, tokens: u.usage, images_out: 0, image_size: null, cost_usd_est: estimateCost(u.model, u.usage).cost, latency_ms: 0 });
  } }) : new CombinerPlanner();

  app.get("/healthz", async () => ({ ok: true, gemini: !!deps.gemini, images: !!deps.images }));

  app.get("/v1/usage", async (req) => {
    authenticate(req);
    const spent = deps.usage.spentToday(now());
    return { spent_today_usd: Number(spent.usd.toFixed(4)), calls_today: spent.calls, daily_budget_usd: deps.dailyBudgetUsd, models: deps.models };
  });

  app.post<{ Body: PlanBody; Headers: { "x-plan-n"?: string } }>("/v1/outfits/plan", {
    schema: { body: { type: "object", required: ["occasion", "weather", "candidates", "accessory_count"], properties: {
      occasion: { type: "string" },
      weather: { type: "object", required: ["wear_window"], properties: { wear_window: { type: "object", required: ["min_feels_like_c", "max_feels_like_c", "precip_prob_max"] }, city: { type: ["string", "null"] } } },
      anchor_id: { type: ["string", "null"] },
      accessory_count: { type: "string", enum: ["none", "some", "many"] },
      candidates: { type: "array", minItems: 1, maxItems: 45, items: { type: "object", required: ["id", "category", "subcategory", "color_hex", "color_name", "warmth", "formality"] } },
    } } },
  }, async (req) => {
    authenticate(req);
    if (deps.gemini) budgetCheck();
    if (!isOccasion(req.body.occasion)) throw new HttpError(400, "bad_request", "unknown occasion");
    const n = Math.max(1, Math.min(3, Number(req.headers["x-plan-n"] ?? 3) || 3));
    const w = req.body.weather.wear_window;
    const t = now();
    const ctx: PlanContext = {
      occasion: req.body.occasion,
      wearWindow: { min_feels_like_c: w.min_feels_like_c, max_feels_like_c: w.max_feels_like_c, precip_prob_max: w.precip_prob_max, ...(w.wind_max != null ? { wind_max: w.wind_max } : {}) },
      ...(req.body.anchor_id ? { anchorId: req.body.anchor_id } : {}),
      accessoryCount: req.body.accessory_count,
      bodyAvoid: [],
      calendarSeason: calendarSeason(t),
      today: t.toISOString().slice(0, 10),
      feedback: {},
      recentSubcategorySuggestions: {},
      recentOutfits: req.body.recent_outfit_item_ids ?? [],
      yesterdayItemIds: req.body.yesterday_item_ids ?? [],
    };
    const candidates: Candidate[] = req.body.candidates.map((c) => ({
      id: c.id, category: c.category as Candidate["category"], subcategory: c.subcategory, layer_role: (c.layer_role ?? null) as Candidate["layer_role"],
      color_name: c.color_name, color_hex: c.color_hex, pattern: c.pattern ?? "solid", material: c.material ?? "unknown",
      warmth: c.warmth as Candidate["warmth"], formality: c.formality as Candidate["formality"], last_suggested_days: c.last_suggested_days ?? null,
      wear_count: c.wear_count ?? 0, quantity: c.quantity ?? 1, in_palette: c.in_palette ?? false, score: 0.5,
    }));
    const outcome = await planFromCandidates(planner, candidates, ctx, n);
    return {
      outfits: outcome.outfits.map((o) => ({ ...o.outfit, validator: o.validator })),
      anchor_honored: outcome.anchor_honored, anchor_reason: outcome.anchor_reason,
      candidate_count: candidates.length, planner: deps.gemini ? "gemini" : "combiner", calls: outcome.calls,
    };
  });

  app.post<{ Body: { image: { mime_type: InlineImage["mimeType"]; data: string }; pixel_palette: { primary_hex: string; primary_name: string; secondary_hex?: string[] }; detection_label?: string; accurate?: boolean } }>(
    "/v1/items/attributes",
    { schema: { body: { type: "object", required: ["image", "pixel_palette"], properties: { image: inlineImageSchema, pixel_palette: { type: "object", required: ["primary_hex", "primary_name"] }, detection_label: { type: "string" }, accurate: { type: "boolean" } } } } },
    async (req) => {
      authenticate(req);
      const client = requireGemini();
      budgetCheck();
      const started = Date.now();
      const r = await analyseAttributes(client, { bulk: deps.models.attributesBulk, accurate: deps.models.attributesAccurate }, {
        imageBase64: req.body.image.data, mimeType: req.body.image.mime_type === "image/webp" ? "image/png" : req.body.image.mime_type,
        pixelPalette: { ...req.body.pixel_palette, secondary_hex: req.body.pixel_palette.secondary_hex ?? [] },
        ...(req.body.detection_label ? { detectionLabel: req.body.detection_label } : {}),
        ...(req.body.accurate ? { accurate: true } : {}),
      });
      deps.usage.record({ feature: "attributes", model: r.model, tokens: r.usage, images_out: 0, image_size: null, cost_usd_est: estimateCost(r.model, r.usage).cost, latency_ms: Date.now() - started });
      return { attributes: r.attributes, model: r.model };
    },
  );

  app.post<{ Body: { person: { mime_type: InlineImage["mimeType"]; data: string }; garments: { image: { mime_type: InlineImage["mimeType"]; data: string }; label: string }[]; image_size?: "512px" | "1K" | "2K"; notes?: string } }>(
    "/v1/looks",
    { schema: { body: { type: "object", required: ["person", "garments"], properties: {
      person: inlineImageSchema,
      garments: { type: "array", minItems: 1, maxItems: 4, items: { type: "object", required: ["image", "label"], properties: { image: inlineImageSchema, label: { type: "string", maxLength: 80 } } } },
      image_size: { type: "string", enum: ["512px", "1K", "2K"] },
      notes: { type: "string", maxLength: 300 },
    } } } },
    async (req) => {
      authenticate(req);
      if (!deps.images) throw new HttpError(503, "gemini_unavailable", "GEMINI_API_KEY is not set on the server.");
      budgetCheck();
      const started = Date.now();
      const size = req.body.image_size ?? "1K";
      const r = await deps.images.tryOn(deps.models.image, {
        person: { mimeType: req.body.person.mime_type, data: req.body.person.data },
        garments: req.body.garments.map((g) => ({ image: { mimeType: g.image.mime_type, data: g.image.data }, label: g.label })),
        imageSize: size,
        ...(req.body.notes ? { notes: req.body.notes } : {}),
      });
      const cost = estimateCost(r.model, r.usage, 1, size);
      deps.usage.record({ feature: "look", model: r.model, tokens: r.usage, images_out: 1, image_size: size, cost_usd_est: cost.cost, latency_ms: Date.now() - started });
      return { image: { mime_type: r.image.mimeType, data: r.image.data }, model: r.model, latency_ms: Date.now() - started, cost_usd_est: cost.cost, note: r.text };
    },
  );

  app.post<{ Body: { image: { mime_type: InlineImage["mimeType"]; data: string } } }>("/v1/images/cleanup",
    { schema: { body: { type: "object", required: ["image"], properties: { image: inlineImageSchema } } } },
    async (req) => {
      authenticate(req);
      if (!deps.images) throw new HttpError(503, "gemini_unavailable", "GEMINI_API_KEY is not set on the server.");
      budgetCheck();
      const started = Date.now();
      const r = await deps.images.cleanup(deps.models.imageLite, { mimeType: req.body.image.mime_type, data: req.body.image.data });
      const cost = estimateCost(r.model, r.usage, 1, "1K");
      deps.usage.record({ feature: "cleanup", model: r.model, tokens: r.usage, images_out: 1, image_size: "1K", cost_usd_est: cost.cost, latency_ms: Date.now() - started });
      return { image: { mime_type: r.image.mimeType, data: r.image.data }, model: r.model };
    });

  return app;
}

function calendarSeason(d: Date): PlanContext["calendarSeason"] {
  const m = d.getMonth();
  return m <= 1 || m === 11 ? "winter" : m <= 4 ? "spring" : m <= 7 ? "summer" : "autumn";
}
