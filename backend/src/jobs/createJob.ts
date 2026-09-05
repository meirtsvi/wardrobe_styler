// Idempotent job creation with the two-bucket credit debit in one Firestore transaction (PLAN §7.2 "Credit metering", "Idempotency").
// The job document id IS the idempotency key (a client UUIDv7); the same string becomes the Cloud Tasks task name so the queue de-duplicates.
import { FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";
import { type CreditBalances, type CreditBucket, CreditError, DEFAULT_CREDIT_PRICES, debit } from "../ledger/credits.js";

export const JOB_TYPES = [
  "catalog", "segment", "plan", "week_plan", "look", "twin", "cleanup", "finder", "check", "glowup", "battle",
  "purchase_check", "color_season", "daily", "reembed", "import", "export",
] as const;
export type JobType = (typeof JOB_TYPES)[number];

export type JobStatus = "queued" | "running" | "done" | "failed" | "refunded" | "cancelled";

export type JobDoc = {
  uid: string;
  type: JobType;
  idempotency_key: string;
  status: JobStatus;
  queue: string;
  input: Record<string, unknown>;
  result: Record<string, unknown> | null;
  error: { code: string; retryable: boolean } | null;
  attempts: number;
  credits_charged: number;
  bucket_charged: CreditBucket | null;
  charged: { grant: number; purchased: number };
  cost_usd_est: number | null;
  model_id: string | null;
  prompt_version: string | null;
  created_at: number;
  started_at: number | null;
  finished_at: number | null;
};

export type UserCreditFields = {
  grant_balance: { amount: number; expires_at: number | null };
  purchased_balance: number;
  daily_credits_used: number;
  daily_reset_at: number | null;
  tz: string;
};

export type CreateJobInput = {
  uid: string;
  type: JobType;
  idempotencyKey: string;
  queue: string;
  input: Record<string, unknown>;
  /** Credits to charge; defaults to DEFAULT_CREDIT_PRICES[type] or 0. Production passes the Remote Config price. */
  creditPrice?: number;
};

export class JobError extends Error {
  constructor(public readonly code: "user_missing" | "credits", message: string, public readonly cause?: CreditError) {
    super(message);
  }
}

const IDEMPOTENCY_WINDOW_MS = 24 * 3600 * 1000;
/** All of one user's debits contend on users/{uid}; the default 5 attempts abort legitimate requests under a burst (seen at 40 concurrent). */
const TXN_OPTIONS = { maxAttempts: 30 };

/** Next local midnight for an IANA timezone, as epoch ms. */
export function nextLocalMidnight(nowMs: number, tz: string): number {
  const fmt = new Intl.DateTimeFormat("en-US", { timeZone: tz, hour12: false, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" });
  const parts = Object.fromEntries(fmt.formatToParts(new Date(nowMs)).map((p) => [p.type, p.value]));
  const hour = Number(parts.hour) % 24;
  const sinceMidnightMs = ((hour * 60 + Number(parts.minute)) * 60 + Number(parts.second)) * 1000 + (nowMs % 1000);
  return nowMs - sinceMidnightMs + 24 * 3600 * 1000;
}

function balancesOf(u: UserCreditFields): CreditBalances {
  return { grant: u.grant_balance.amount, grant_expires_at: u.grant_balance.expires_at, purchased: u.purchased_balance };
}

export async function createJob(db: Firestore, req: CreateJobInput, nowMs = Date.now()): Promise<{ job: JobDoc; created: boolean }> {
  const jobRef = db.collection("jobs").doc(req.idempotencyKey);
  const userRef = db.collection("users").doc(req.uid);
  const price = req.creditPrice ?? DEFAULT_CREDIT_PRICES[req.type] ?? 0;

  return db.runTransaction(async (tx: Transaction) => {
    const existing = await tx.get(jobRef);
    if (existing.exists) {
      const job = existing.data() as JobDoc;
      if (job.uid === req.uid && nowMs - job.created_at < IDEMPOTENCY_WINDOW_MS) return { job, created: false };
      // Same key from another user or older than the window: treat as a fresh key collision and refuse silently by returning the stored job only to its owner.
      if (job.uid !== req.uid) throw new JobError("credits", "Idempotency key belongs to another account.");
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new JobError("user_missing", "User document must exist before creating jobs.");
    const user = userSnap.data() as UserCreditFields;

    let dailyUsed = user.daily_credits_used ?? 0;
    let dailyResetAt = user.daily_reset_at;
    if (dailyResetAt === null || dailyResetAt === undefined || nowMs >= dailyResetAt) {
      dailyUsed = 0;
      dailyResetAt = nextLocalMidnight(nowMs, user.tz || "UTC");
    }

    const job: JobDoc = {
      uid: req.uid,
      type: req.type,
      idempotency_key: req.idempotencyKey,
      status: "queued",
      queue: req.queue,
      input: req.input,
      result: null,
      error: null,
      attempts: 0,
      credits_charged: 0,
      bucket_charged: null,
      charged: { grant: 0, purchased: 0 },
      cost_usd_est: null,
      model_id: null,
      prompt_version: null,
      created_at: nowMs,
      started_at: null,
      finished_at: null,
    };

    if (price > 0) {
      let d;
      try {
        d = debit(price, balancesOf(user), nowMs, dailyUsed);
      } catch (e) {
        if (e instanceof CreditError) throw new JobError("credits", e.message, e);
        throw e;
      }
      job.credits_charged = price;
      job.bucket_charged = d.bucket;
      job.charged = { grant: d.grant_used, purchased: d.purchased_used };
      tx.update(userRef, {
        "grant_balance.amount": d.balances.grant,
        purchased_balance: d.balances.purchased,
        daily_credits_used: dailyUsed + price,
        daily_reset_at: dailyResetAt,
      });
      tx.set(db.collection("credit_ledger").doc(), {
        uid: req.uid,
        delta: -price,
        bucket: d.bucket,
        reason: "job_debit",
        ref_id: req.idempotencyKey,
        grant_balance_after: d.balances.grant,
        purchased_balance_after: d.balances.purchased,
        created_at: nowMs,
      });
    } else if (dailyResetAt !== user.daily_reset_at) {
      tx.update(userRef, { daily_credits_used: dailyUsed, daily_reset_at: dailyResetAt });
    }

    tx.set(jobRef, job);
    return { job, created: true };
  }, TXN_OPTIONS);
}

/** Terminal failure or cancel: refund in the same shape and buckets, once (PLAN §7.2 "Refund on terminal failure"). */
export async function refundJob(db: Firestore, jobId: string, reason: "refund" | "cancel", nowMs = Date.now()): Promise<JobDoc | null> {
  const jobRef = db.collection("jobs").doc(jobId);
  return db.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(jobRef);
    if (!snap.exists) return null;
    const job = snap.data() as JobDoc;
    if (job.status === "done" || job.status === "refunded" || job.status === "cancelled") return job;
    if (reason === "cancel" && job.status === "running") return job; // account deletion waits for running jobs (§7.6)

    const status: JobStatus = reason === "cancel" ? "cancelled" : "refunded";
    const update: Partial<JobDoc> = { status, finished_at: nowMs };
    if (job.credits_charged > 0) {
      const userRef = db.collection("users").doc(job.uid);
      tx.update(userRef, {
        "grant_balance.amount": FieldValue.increment(job.charged.grant),
        purchased_balance: FieldValue.increment(job.charged.purchased),
        daily_credits_used: FieldValue.increment(-job.credits_charged),
      });
      tx.set(db.collection("credit_ledger").doc(), {
        uid: job.uid,
        delta: job.credits_charged,
        bucket: job.bucket_charged,
        reason: "refund",
        ref_id: jobId,
        grant_balance_after: null, // increments: resolved by the reconciliation job, not read back inside the transaction
        purchased_balance_after: null,
        created_at: nowMs,
      });
    }
    tx.update(jobRef, update);
    return { ...job, ...update };
  }, TXN_OPTIONS);
}
