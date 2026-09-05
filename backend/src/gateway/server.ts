// ai-gateway (PLAN §7.1, §7.6). Phase 0 skeleton: health, /v1/me, job create/get/cancel, synchronous outfit plan.
// Queue dispatch (Cloud Tasks), rate limits, weather, chat, webhooks and the Gemini planner are added in later phases.
import Fastify, { type FastifyInstance } from "fastify";
import type { Firestore } from "firebase-admin/firestore";
import { createHash } from "node:crypto";
import { isOccasion, type AccessoryCount } from "../domain/taxonomy.js";
import type { Candidate, PlanContext } from "../domain/types.js";
import type { GeminiClient } from "../gemini/client.js";
import { analyseAttributes } from "./attributes.js";
import { effectiveGrant, looksFromCredits } from "../ledger/credits.js";
import { JOB_TYPES, JobError, type JobType, createJob, refundJob } from "../jobs/createJob.js";
import { type Planner, planFromCandidates } from "../planner/planOutfits.js";
import { AuthError, type Verifier } from "./auth.js";

const METERED: ReadonlySet<JobType> = new Set(["look", "twin", "glowup"]);
const BODY_PHOTO_TYPES: ReadonlySet<JobType> = new Set(["look", "twin", "check", "glowup", "battle", "color_season"]);
const QUEUE_FOR: Record<JobType, string> = {
  catalog: "q-catalog", segment: "q-catalog", reembed: "q-batch", import: "q-batch", export: "q-batch",
  plan: "q-plan", week_plan: "q-plan", daily: "q-plan",
  look: "q-tryon-free", twin: "q-tryon-free", glowup: "q-render", cleanup: "q-render",
  finder: "q-render", check: "q-render", battle: "q-render", purchase_check: "q-plan", color_season: "q-render",
};

export type ServerDeps = {
  db: Firestore;
  verifier: Verifier;
  planner: Planner;
  gemini?: { client: GeminiClient; models: { bulk: string; accurate: string } };
  creditPrices?: Record<string, number>;
  now?: () => number;
};

type PlanBody = {
  occasion: string;
  weather: { wear_window: { min_feels_like_c: number; max_feels_like_c: number; precip_prob_max: number; wind_max?: number | null }; city?: string | null };
  anchor_id?: string | null;
  accessory_count: AccessoryCount;
  learned_rules?: string[];
  recent_outfit_item_ids?: string[][];
  yesterday_item_ids?: string[];
  violations?: unknown;
  previous_outfits?: unknown;
  candidates: {
    id: string; category: string; subcategory: string; layer_role?: string | null; color_name: string; color_hex: string; pattern?: string; material?: string;
    warmth: string; formality: string; last_suggested_days?: number | null; wear_count?: number; quantity?: number; in_palette?: boolean;
  }[];
};

function hash(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").slice(0, 16);
}

const headerNames = { appCheck: "x-firebase-appcheck" } as const;

export function buildServer(deps: ServerDeps): FastifyInstance {
  const app = Fastify({ logger: false });
  const now = deps.now ?? (() => Date.now());

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof AuthError) return reply.status(err.status).send({ error: "unauthorized", message: err.message });
    if (err instanceof JobError) {
      if (err.code === "user_missing") return reply.status(409).send({ error: "user_missing", message: err.message });
      const cause = err.cause;
      if (cause?.code === "daily_cap_reached") {
        return reply.status(429).send({ error: "daily_cap_reached", message: err.message, retry_after: cause.details, ...cause.details });
      }
      return reply.status(402).send({ error: cause?.code ?? "credits", message: err.message, ...(cause?.details ?? {}) });
    }
    const status = (err as { statusCode?: number }).statusCode;
    if (typeof status === "number") return reply.status(status).send({ error: "bad_request", message: (err as Error).message });
    return reply.status(500).send({ error: "internal", message: "internal error" });
  });

  async function authenticate(req: { headers: Record<string, unknown> }, consume: boolean) {
    const headers: { authorization?: string; appCheck?: string } = {};
    if (typeof req.headers.authorization === "string") headers.authorization = req.headers.authorization;
    if (typeof req.headers[headerNames.appCheck] === "string") headers.appCheck = req.headers[headerNames.appCheck] as string;
    return deps.verifier.verify(headers, { consume });
  }

  app.get("/healthz", async () => ({ ok: true }));

  app.get("/v1/me", async (req) => {
    const p = await authenticate(req, false);
    const snap = await deps.db.collection("users").doc(p.uid).get();
    if (!snap.exists) return { uid: p.uid, plan: "free", looks: { plan: 0, purchased: 0, renews_at: null }, flags: {}, exists: false };
    const u = snap.data()!;
    const t = now();
    const grant = effectiveGrant({ grant: u.grant_balance?.amount ?? 0, grant_expires_at: u.grant_balance?.expires_at ?? null, purchased: 0 }, t);
    return {
      uid: p.uid,
      plan: u.plan ?? "free",
      looks: { plan: looksFromCredits(grant), purchased: looksFromCredits(u.purchased_balance ?? 0), renews_at: u.grant_balance?.expires_at ?? null },
      daily_credits_used: u.daily_credits_used ?? 0,
      flags: u.flags ?? {},
      consent: u.consent ?? {},
      exists: true,
    };
  });

  app.post<{ Body: { type: string; input?: Record<string, unknown> }; Headers: { "idempotency-key"?: string } }>(
    "/v1/jobs",
    {
      schema: {
        body: { type: "object", required: ["type"], properties: { type: { type: "string", enum: [...JOB_TYPES] }, input: { type: "object" } } },
      },
    },
    async (req, reply) => {
      const type = req.body.type as JobType;
      const key = req.headers["idempotency-key"];
      if (!key || !/^[0-9a-f-]{36}$/i.test(key)) return reply.status(400).send({ error: "bad_request", message: "Idempotency-Key header (UUID) is required" });
      const input = req.body.input ?? {};
      if (BODY_PHOTO_TYPES.has(type) && input.self_ack !== true) {
        return reply.status(400).send({ error: "self_ack_required", message: "Body-photo jobs require input.self_ack=true" });
      }
      const metered = METERED.has(type);
      const p = await authenticate(req, metered);
      const price = metered ? (deps.creditPrices?.[type] ?? undefined) : 0;
      const { job, created } = await createJob(deps.db, { uid: p.uid, type, idempotencyKey: key, queue: QUEUE_FOR[type], input, ...(price !== undefined ? { creditPrice: price } : {}) }, now());
      // TODO(phase 0): enqueue on Cloud Tasks with task name = key.
      return reply.status(created ? 201 : 200).send({ id: key, ...job });
    },
  );

  app.get<{ Params: { id: string } }>("/v1/jobs/:id", async (req, reply) => {
    const p = await authenticate(req, false);
    const snap = await deps.db.collection("jobs").doc(req.params.id).get();
    if (!snap.exists || snap.data()!.uid !== p.uid) return reply.status(404).send({ error: "not_found" });
    return { id: snap.id, ...snap.data() };
  });

  app.post<{ Params: { id: string } }>("/v1/jobs/:id/cancel", async (req, reply) => {
    const p = await authenticate(req, false);
    const snap = await deps.db.collection("jobs").doc(req.params.id).get();
    if (!snap.exists || snap.data()!.uid !== p.uid) return reply.status(404).send({ error: "not_found" });
    const job = await refundJob(deps.db, req.params.id, "cancel", now());
    return { id: req.params.id, status: job?.status };
  });

  // ADR 0001: the client runs Stage A on its own wardrobe and sends ≤ 45 compact candidates; the server never reads the wardrobe.
  app.post<{ Body: PlanBody; Headers: { "x-plan-n"?: string } }>(
    "/v1/outfits/plan",
    {
      schema: {
        body: {
          type: "object",
          required: ["occasion", "weather", "candidates", "accessory_count"],
          properties: {
            occasion: { type: "string" },
            weather: {
              type: "object",
              required: ["wear_window"],
              properties: {
                wear_window: {
                  type: "object",
                  required: ["min_feels_like_c", "max_feels_like_c", "precip_prob_max"],
                  properties: { min_feels_like_c: { type: "number" }, max_feels_like_c: { type: "number" }, precip_prob_max: { type: "number" }, wind_max: { type: ["number", "null"] } },
                },
                city: { type: ["string", "null"] },
              },
            },
            anchor_id: { type: ["string", "null"] },
            accessory_count: { type: "string", enum: ["none", "some", "many"] },
            learned_rules: { type: "array", items: { type: "string" }, maxItems: 30 },
            recent_outfit_item_ids: { type: "array", items: { type: "array", items: { type: "string" } }, maxItems: 60 },
            yesterday_item_ids: { type: "array", items: { type: "string" } },
            violations: { type: ["array", "null"] },
            previous_outfits: { type: ["array", "null"] },
            candidates: { type: "array", minItems: 1, maxItems: 45, items: { type: "object", required: ["id", "category", "subcategory", "color_hex", "color_name", "warmth", "formality"] } },
          },
        },
      },
    },
    async (req, reply) => {
      const p = await authenticate(req, false);
      if (!isOccasion(req.body.occasion)) return reply.status(400).send({ error: "bad_request", message: "unknown occasion" });
      const n = Math.max(1, Math.min(3, Number(req.headers["x-plan-n"] ?? 3) || 3));
      const ctx: PlanContext = {
        occasion: req.body.occasion,
        wearWindow: {
          min_feels_like_c: req.body.weather.wear_window.min_feels_like_c,
          max_feels_like_c: req.body.weather.wear_window.max_feels_like_c,
          precip_prob_max: req.body.weather.wear_window.precip_prob_max,
          ...(req.body.weather.wear_window.wind_max != null ? { wind_max: req.body.weather.wear_window.wind_max } : {}),
        },
        ...(req.body.anchor_id ? { anchorId: req.body.anchor_id } : {}),
        accessoryCount: req.body.accessory_count,
        bodyAvoid: [],
        calendarSeason: calendarSeason(now()),
        today: new Date(now()).toISOString().slice(0, 10),
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
      const outcome = await planFromCandidates(deps.planner, candidates, ctx, n);
      req.log?.info?.({ uid_hash: hash(p.uid), calls: outcome.calls, candidates: candidates.length }, "plan");
      return {
        outfits: outcome.outfits.map((o) => ({ ...o.outfit, validator: o.validator })),
        anchor_honored: outcome.anchor_honored,
        anchor_reason: outcome.anchor_reason,
        candidate_count: candidates.length,
        weather: { wear_window: req.body.weather.wear_window },
      };
    },
  );

  // Gemini attribute fallback for garments the device cannot settle (ADR 0001). Free, rate-limited by photos/day (rate limits: TODO).
  app.post<{ Body: { image_base64: string; mime_type: "image/jpeg" | "image/png"; pixel_palette: { primary_hex: string; primary_name: string; secondary_hex: string[] }; detection_label?: string; accurate?: boolean } }>(
    "/v1/items/attributes",
    {
      schema: {
        body: {
          type: "object",
          required: ["image_base64", "mime_type", "pixel_palette"],
          properties: {
            image_base64: { type: "string", maxLength: 2_800_000 },
            mime_type: { type: "string", enum: ["image/jpeg", "image/png"] },
            pixel_palette: { type: "object", required: ["primary_hex", "primary_name"], properties: { primary_hex: { type: "string" }, primary_name: { type: "string" }, secondary_hex: { type: "array", items: { type: "string" } } } },
            detection_label: { type: "string" },
            accurate: { type: "boolean" },
          },
        },
      },
    },
    async (req, reply) => {
      await authenticate(req, false);
      if (!deps.gemini) return reply.status(503).send({ error: "gemini_unavailable", message: "Attribute analysis is not configured on this gateway." });
      try {
        const r = await analyseAttributes(deps.gemini.client, deps.gemini.models, {
          imageBase64: req.body.image_base64, mimeType: req.body.mime_type,
          pixelPalette: { ...req.body.pixel_palette, secondary_hex: req.body.pixel_palette.secondary_hex ?? [] },
          ...(req.body.detection_label ? { detectionLabel: req.body.detection_label } : {}),
          ...(req.body.accurate ? { accurate: true } : {}),
        });
        return { attributes: r.attributes, model: r.model, usage: r.usage };
      } catch (e) {
        const code = (e as { code?: string }).code;
        if (code === "safety_block") return reply.status(422).send({ error: "safety_block", message: "This photo could not be analysed." });
        throw e;
      }
    },
  );

  return app;
}

function calendarSeason(nowMs: number): PlanContext["calendarSeason"] {
  const m = new Date(nowMs).getUTCMonth();
  return m <= 1 || m === 11 ? "winter" : m <= 4 ? "spring" : m <= 7 ? "summer" : "autumn";
}
