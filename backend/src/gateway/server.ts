// ai-gateway (PLAN §7.1, §7.6). Phase 0 skeleton: health, /v1/me, job create/get/cancel, synchronous outfit plan.
// Queue dispatch (Cloud Tasks), rate limits, weather, chat, webhooks and the Gemini planner are added in later phases.
import Fastify, { type FastifyInstance } from "fastify";
import type { Firestore } from "firebase-admin/firestore";
import { isOccasion, type AccessoryCount } from "../domain/taxonomy.js";
import type { PlanContext, WardrobeItem } from "../domain/types.js";
import { effectiveGrant, looksFromCredits } from "../ledger/credits.js";
import { JOB_TYPES, JobError, type JobType, createJob, refundJob } from "../jobs/createJob.js";
import { type Planner, planOutfits } from "../planner/planOutfits.js";
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
  creditPrices?: Record<string, number>;
  now?: () => number;
};

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

  app.post<{
    Body: {
      occasion: string;
      wear_window: { min_feels_like_c: number; max_feels_like_c: number; precip_prob_max: number; wind_max?: number };
      anchor_id?: string;
      n?: number;
    };
  }>(
    "/v1/outfits/plan",
    {
      schema: {
        body: {
          type: "object",
          required: ["occasion", "wear_window"],
          properties: {
            occasion: { type: "string" },
            wear_window: {
              type: "object",
              required: ["min_feels_like_c", "max_feels_like_c", "precip_prob_max"],
              properties: { min_feels_like_c: { type: "number" }, max_feels_like_c: { type: "number" }, precip_prob_max: { type: "number" }, wind_max: { type: "number" } },
            },
            anchor_id: { type: "string" },
            n: { type: "integer", minimum: 1, maximum: 3 },
          },
        },
      },
    },
    async (req, reply) => {
      const p = await authenticate(req, false);
      if (!isOccasion(req.body.occasion)) return reply.status(400).send({ error: "bad_request", message: "unknown occasion" });

      const [itemsSnap, profileSnap] = await Promise.all([
        deps.db.collection("items").where("uid", "==", p.uid).get(),
        deps.db.collection("users").doc(p.uid).collection("profile").doc("profile").get(),
      ]);
      const items = itemsSnap.docs.map((d) => itemFromDoc(d.id, d.data()));
      const profile = profileSnap.data() ?? {};
      const ctx: PlanContext = {
        occasion: req.body.occasion,
        wearWindow: req.body.wear_window,
        ...(req.body.anchor_id ? { anchorId: req.body.anchor_id } : {}),
        accessoryCount: (profile.accessory_count as AccessoryCount | undefined) ?? "some",
        bodyAvoid: (profile.body?.avoid as string[] | undefined) ?? [],
        ...(profile.color_season ? { colorSeason: { best_hex: profile.color_season.best_hex ?? [], avoid_hex: profile.color_season.avoid_hex ?? [] } } : {}),
        calendarSeason: calendarSeason(now()),
        today: new Date(now()).toISOString().slice(0, 10),
        feedback: {},
        recentSubcategorySuggestions: {},
        recentOutfits: [],
        yesterdayItemIds: [],
      };
      const outcome = await planOutfits(deps.planner, items, ctx, req.body.n ?? 3);
      return {
        outfits: outcome.outfits.map((o) => ({ ...o.outfit, validator: o.validator })),
        anchor_honored: outcome.anchor_honored,
        anchor_reason: outcome.anchor_reason,
        candidate_count: outcome.candidates.length,
        weather: { wear_window: req.body.wear_window },
      };
    },
  );

  return app;
}

function calendarSeason(nowMs: number): PlanContext["calendarSeason"] {
  const m = new Date(nowMs).getUTCMonth();
  return m <= 1 || m === 11 ? "winter" : m <= 4 ? "spring" : m <= 7 ? "summer" : "autumn";
}

/** Firestore items/{id} → WardrobeItem (PLAN §7.5). Missing AI fields get conservative defaults so a half-tagged item never crashes planning. */
export function itemFromDoc(id: string, d: FirebaseFirestore.DocumentData): WardrobeItem {
  return {
    id,
    category: d.category ?? "other",
    subcategory: d.subcategory ?? "other",
    layer_role: d.layer_role ?? null,
    color_hex: d.colors?.primary_hex ?? "#8C8C8C",
    color_name: d.colors?.primary_name ?? "grey",
    pattern: d.pattern ?? "solid",
    material: d.material ?? "unknown",
    fit: d.fit,
    warmth: d.warmth ?? "mid",
    season: d.season ?? [],
    formality: d.formality ?? "casual",
    owned: d.owned ?? true,
    status: d.status ?? "new",
    availability: d.availability?.state ?? "available",
    quantity: d.quantity ?? 1,
    is_seed: d.source === "seed",
    wear_count: d.wear_count ?? 0,
    last_suggested_at: d.last_suggested_at ? new Date(d.last_suggested_at).toISOString().slice(0, 10) : null,
    deleted: !!d.deleted_at,
  };
}
