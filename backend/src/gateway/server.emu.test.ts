// Gateway contract tests against the Firestore emulator: `npm run test:emulator`.
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import type { FastifyInstance } from "fastify";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { fixtureCloset } from "../domain/fixtures.js";
import { CombinerPlanner } from "../planner/planOutfits.js";
import { StaticVerifier } from "./auth.js";
import { buildServer } from "./server.js";

let db: Firestore;
let app: FastifyInstance;
const now = Date.UTC(2026, 9, 1, 12, 0, 0);
const auth = (uid: string) => ({ authorization: `Bearer uid:${uid}`, "x-firebase-appcheck": "test" });
const KEY = "018f6b1e-1111-7000-8000-000000000001";

beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("run via npm run test:emulator");
  if (getApps().length === 0) initializeApp({ projectId: "demo-wardrobe" });
  db = getFirestore();
  app = buildServer({ db, verifier: new StaticVerifier(), planner: new CombinerPlanner(), now: () => now });
  await app.ready();
});
afterAll(async () => app.close());

beforeEach(async () => {
  for (const col of ["users", "jobs", "credit_ledger", "items"]) {
    const docs = await db.collection(col).listDocuments();
    await Promise.all(docs.map((d) => d.delete()));
  }
  await db.collection("users").doc("u1").set({ plan: "free", grant_balance: { amount: 5, expires_at: now + 86_400_000 }, purchased_balance: 0, daily_credits_used: 0, daily_reset_at: null, tz: "UTC", flags: { looks_enabled: false } });
});

describe("auth", () => {
  it("rejects missing tokens", async () => {
    expect((await app.inject({ method: "GET", url: "/v1/me" })).statusCode).toBe(401);
    expect((await app.inject({ method: "GET", url: "/v1/me", headers: { authorization: "Bearer uid:u1" } })).statusCode).toBe(401);
  });
  it("healthz is open", async () => {
    expect((await app.inject({ method: "GET", url: "/healthz" })).json()).toEqual({ ok: true });
  });
});

describe("/v1/me", () => {
  it("shows balances in Looks", async () => {
    const r = await app.inject({ method: "GET", url: "/v1/me", headers: auth("u1") });
    expect(r.statusCode).toBe(200);
    expect(r.json()).toMatchObject({ uid: "u1", plan: "free", looks: { plan: 1, purchased: 0 }, flags: { looks_enabled: false } });
  });
});

describe("/v1/jobs", () => {
  it("requires an Idempotency-Key and self_ack for body-photo types", async () => {
    const noKey = await app.inject({ method: "POST", url: "/v1/jobs", headers: auth("u1"), payload: { type: "catalog" } });
    expect(noKey.statusCode).toBe(400);
    const noAck = await app.inject({ method: "POST", url: "/v1/jobs", headers: { ...auth("u1"), "idempotency-key": KEY }, payload: { type: "look" } });
    expect(noAck.json()).toMatchObject({ error: "self_ack_required" });
  });
  it("creates a Look once (201), replays as 200, and the balance drops to 0 Looks", async () => {
    const h = { ...auth("u1"), "idempotency-key": KEY };
    const first = await app.inject({ method: "POST", url: "/v1/jobs", headers: h, payload: { type: "look", input: { self_ack: true, outfit_id: "o1" } } });
    expect(first.statusCode).toBe(201);
    expect(first.json()).toMatchObject({ id: KEY, status: "queued", queue: "q-tryon-free", credits_charged: 5, bucket_charged: "grant" });
    const replay = await app.inject({ method: "POST", url: "/v1/jobs", headers: h, payload: { type: "look", input: { self_ack: true, outfit_id: "o1" } } });
    expect(replay.statusCode).toBe(200);
    const me = await app.inject({ method: "GET", url: "/v1/me", headers: auth("u1") });
    expect(me.json().looks.plan).toBe(0);
  });
  it("returns 402 with a machine-readable code when out of Looks, and 429 with retry info at the daily cap", async () => {
    await db.collection("users").doc("u1").update({ "grant_balance.amount": 0 });
    const r = await app.inject({ method: "POST", url: "/v1/jobs", headers: { ...auth("u1"), "idempotency-key": KEY }, payload: { type: "look", input: { self_ack: true } } });
    expect(r.statusCode).toBe(402);
    expect(r.json()).toMatchObject({ error: "insufficient", needed: 5, available: 0 });
    await db.collection("users").doc("u1").update({ "grant_balance.amount": 500, daily_credits_used: 300, daily_reset_at: now + 3600_000 });
    const capped = await app.inject({ method: "POST", url: "/v1/jobs", headers: { ...auth("u1"), "idempotency-key": KEY }, payload: { type: "look", input: { self_ack: true } } });
    expect(capped.statusCode).toBe(429);
    expect(capped.json().message).toMatch(/resets at 00:00/);
  });
  it("get and cancel are owner-scoped; cancel refunds", async () => {
    const h = { ...auth("u1"), "idempotency-key": KEY };
    await app.inject({ method: "POST", url: "/v1/jobs", headers: h, payload: { type: "look", input: { self_ack: true } } });
    expect((await app.inject({ method: "GET", url: `/v1/jobs/${KEY}`, headers: auth("u2") })).statusCode).toBe(404);
    expect((await app.inject({ method: "GET", url: `/v1/jobs/${KEY}`, headers: auth("u1") })).json().status).toBe("queued");
    const cancel = await app.inject({ method: "POST", url: `/v1/jobs/${KEY}/cancel`, headers: auth("u1") });
    expect(cancel.json()).toEqual({ id: KEY, status: "cancelled" });
    expect((await app.inject({ method: "GET", url: "/v1/me", headers: auth("u1") })).json().looks.plan).toBe(1);
  });
});

describe("/v1/outfits/plan", () => {
  it("plans from the user's Firestore items and returns validated outfits with the wear window", async () => {
    const batch = db.batch();
    for (const it of fixtureCloset()) {
      batch.set(db.collection("items").doc(it.id), {
        uid: "u1", category: it.category, subcategory: it.subcategory, layer_role: it.layer_role,
        colors: { primary_hex: it.color_hex, primary_name: it.color_name }, pattern: it.pattern, material: it.material,
        warmth: it.warmth, season: it.season, formality: it.formality, owned: true, status: "confirmed",
        availability: { state: it.id === "jeans-navy" ? "laundry" : "available" }, quantity: it.quantity, source: "photo",
      });
    }
    await batch.commit();
    const r = await app.inject({
      method: "POST", url: "/v1/outfits/plan", headers: auth("u1"),
      payload: { occasion: "casual", wear_window: { min_feels_like_c: 9, max_feels_like_c: 21, precip_prob_max: 10 } },
    });
    expect(r.statusCode).toBe(200);
    const body = r.json();
    expect(body.outfits.length).toBeGreaterThanOrEqual(1);
    const o = body.outfits[0];
    expect(o.validator.passed).toBe(true);
    expect(o.slots.some((s: { slot: string }) => s.slot === "outerwear")).toBe(true);
    expect(o.layering_note).toBeTruthy();
    expect(o.slots.map((s: { item_id: string }) => s.item_id)).not.toContain("jeans-navy");
    expect(body.weather.wear_window.min_feels_like_c).toBe(9);
  });
  it("rejects an unknown occasion", async () => {
    const r = await app.inject({ method: "POST", url: "/v1/outfits/plan", headers: auth("u1"), payload: { occasion: "wedding-crasher", wear_window: { min_feels_like_c: 9, max_feels_like_c: 21, precip_prob_max: 10 } } });
    expect(r.statusCode).toBe(400);
  });
});
