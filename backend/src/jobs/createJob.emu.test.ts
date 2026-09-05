// Runs against the Firestore emulator: `npm run test:emulator`.
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { JobError, createJob, nextLocalMidnight, refundJob } from "./createJob.js";

let db: Firestore;
const now = Date.UTC(2026, 9, 1, 12, 0, 0);

async function seedUser(uid: string, grant: number, purchased: number, extra: Record<string, unknown> = {}) {
  await db.collection("users").doc(uid).set({
    grant_balance: { amount: grant, expires_at: now + 30 * 86_400_000 },
    purchased_balance: purchased,
    daily_credits_used: 0,
    daily_reset_at: null,
    tz: "Asia/Jerusalem",
    plan: "free",
    ...extra,
  });
}

async function clear() {
  for (const col of ["users", "jobs", "credit_ledger"]) {
    const docs = await db.collection(col).listDocuments();
    await Promise.all(docs.map((d) => d.delete()));
  }
}

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("FIRESTORE_EMULATOR_HOST is not set; run via npm run test:emulator");
  if (getApps().length === 0) initializeApp({ projectId: "demo-wardrobe" });
  db = getFirestore();
});

beforeEach(clear);

describe("createJob", () => {
  it("free job types debit nothing and are idempotent", async () => {
    await seedUser("u1", 0, 0);
    const a = await createJob(db, { uid: "u1", type: "catalog", idempotencyKey: "k1", queue: "q-catalog", input: { objects: [] } }, now);
    const b = await createJob(db, { uid: "u1", type: "catalog", idempotencyKey: "k1", queue: "q-catalog", input: { objects: [] } }, now + 1000);
    expect(a.created).toBe(true);
    expect(b.created).toBe(false);
    expect(b.job.created_at).toBe(now);
    expect(a.job.credits_charged).toBe(0);
    expect((await db.collection("credit_ledger").get()).size).toBe(0);
  });

  it("a Look debits 5 credits grant-first and writes one ledger row", async () => {
    await seedUser("u2", 7, 20);
    const { job } = await createJob(db, { uid: "u2", type: "look", idempotencyKey: "k2", queue: "q-tryon-free", input: { self_ack: true } }, now);
    expect(job.credits_charged).toBe(5);
    expect(job.bucket_charged).toBe("grant");
    const user = (await db.collection("users").doc("u2").get()).data()!;
    expect(user.grant_balance.amount).toBe(2);
    expect(user.purchased_balance).toBe(20);
    expect(user.daily_credits_used).toBe(5);
    expect(user.daily_reset_at).toBe(nextLocalMidnight(now, "Asia/Jerusalem"));
    const ledger = await db.collection("credit_ledger").get();
    expect(ledger.size).toBe(1);
    expect(ledger.docs[0]!.data()).toMatchObject({ uid: "u2", delta: -5, bucket: "grant", reason: "job_debit", ref_id: "k2", grant_balance_after: 2 });
  });

  it("a second Look with the same key does not debit twice", async () => {
    await seedUser("u3", 10, 0);
    await createJob(db, { uid: "u3", type: "look", idempotencyKey: "k3", queue: "q-tryon-free", input: {} }, now);
    await createJob(db, { uid: "u3", type: "look", idempotencyKey: "k3", queue: "q-tryon-free", input: {} }, now);
    expect((await db.collection("users").doc("u3").get()).data()!.grant_balance.amount).toBe(5);
    expect((await db.collection("credit_ledger").get()).size).toBe(1);
  });

  it("insufficient credits rejects without writing anything", async () => {
    await seedUser("u4", 2, 2);
    await expect(createJob(db, { uid: "u4", type: "look", idempotencyKey: "k4", queue: "q-tryon-free", input: {} }, now)).rejects.toBeInstanceOf(JobError);
    expect((await db.collection("jobs").doc("k4").get()).exists).toBe(false);
    expect((await db.collection("users").doc("u4").get()).data()!.grant_balance.amount).toBe(2);
  });

  it("daily hard cap: 300 credits/day regardless of balance, reset at local midnight", async () => {
    await seedUser("u5", 1000, 1000, { daily_credits_used: 296, daily_reset_at: now + 3600_000 });
    await expect(createJob(db, { uid: "u5", type: "look", idempotencyKey: "k5", queue: "q-tryon-plus", input: {} }, now)).rejects.toThrow(/resets at 00:00/);
    // After the reset time the counter starts over.
    const { job } = await createJob(db, { uid: "u5", type: "look", idempotencyKey: "k5b", queue: "q-tryon-plus", input: {} }, now + 3600_001);
    expect(job.credits_charged).toBe(5);
    expect((await db.collection("users").doc("u5").get()).data()!.daily_credits_used).toBe(5);
  });

  it("40 concurrent Looks against 100 credits: exactly 20 succeed, ledger and balance agree", async () => {
    await seedUser("u6", 50, 50);
    const results = await Promise.allSettled(
      Array.from({ length: 40 }, (_, i) => createJob(db, { uid: "u6", type: "look", idempotencyKey: `c${i}`, queue: "q-tryon-free", input: {} }, now)),
    );
    const ok = results.filter((r) => r.status === "fulfilled").length;
    const failures = results.filter((r): r is PromiseRejectedResult => r.status === "rejected").map((r) => r.reason);
    // Every failure must be a credit rejection, never a transaction abort (that would be a lost sale under a burst).
    for (const f of failures) expect(f, String(f)).toBeInstanceOf(JobError);
    expect(ok).toBe(20);
    const user = (await db.collection("users").doc("u6").get()).data()!;
    expect(user.grant_balance.amount + user.purchased_balance).toBe(0);
    expect(user.daily_credits_used).toBe(100);
    expect((await db.collection("credit_ledger").get()).size).toBe(20);
  });

  it("missing user document is rejected", async () => {
    await expect(createJob(db, { uid: "nobody", type: "catalog", idempotencyKey: "k7", queue: "q-catalog", input: {} }, now)).rejects.toMatchObject({ code: "user_missing" });
  });
});

describe("refundJob", () => {
  it("refunds a mixed debit to the same buckets exactly once", async () => {
    await seedUser("u8", 3, 10);
    await createJob(db, { uid: "u8", type: "look", idempotencyKey: "k8", queue: "q-tryon-free", input: {} }, now);
    const first = await refundJob(db, "k8", "refund", now + 1);
    expect(first?.status).toBe("refunded");
    const again = await refundJob(db, "k8", "refund", now + 2);
    expect(again?.status).toBe("refunded");
    const user = (await db.collection("users").doc("u8").get()).data()!;
    expect(user.grant_balance.amount).toBe(3);
    expect(user.purchased_balance).toBe(10);
    expect(user.daily_credits_used).toBe(0);
    const ledger = await db.collection("credit_ledger").orderBy("created_at").get();
    expect(ledger.docs.map((d) => d.data().reason)).toEqual(["job_debit", "refund"]);
  });

  it("cancel refunds a queued job but leaves a running one alone", async () => {
    await seedUser("u9", 10, 0);
    await createJob(db, { uid: "u9", type: "look", idempotencyKey: "k9", queue: "q-tryon-free", input: {} }, now);
    await db.collection("jobs").doc("k9").update({ status: "running" });
    expect((await refundJob(db, "k9", "cancel", now))?.status).toBe("running");
    await db.collection("jobs").doc("k9").update({ status: "queued" });
    expect((await refundJob(db, "k9", "cancel", now))?.status).toBe("cancelled");
    expect((await db.collection("users").doc("u9").get()).data()!.grant_balance.amount).toBe(10);
  });
});

describe("nextLocalMidnight", () => {
  it("returns the next local midnight in the user's timezone", () => {
    const t = Date.UTC(2026, 9, 1, 12, 0, 0); // 15:00 in Jerusalem (UTC+3 in October)
    const midnight = nextLocalMidnight(t, "Asia/Jerusalem");
    expect(new Date(midnight).toISOString()).toBe("2026-10-01T21:00:00.000Z");
    expect(new Date(nextLocalMidnight(t, "UTC")).toISOString()).toBe("2026-10-02T00:00:00.000Z");
  });
});
