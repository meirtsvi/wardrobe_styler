// Credit arithmetic (PLAN §7.2, §9.2). Pure; the Firestore transaction in jobs/createJob.ts applies it. Mirrors ios/Packages/Domain/Credits.swift.

export type CreditBucket = "grant" | "purchased" | "mixed";

export type CreditBalances = {
  grant: number;
  grant_expires_at: number | null; // epoch ms
  purchased: number;
};

export type CreditDebit = {
  balances: CreditBalances;
  bucket: CreditBucket;
  grant_used: number;
  purchased_used: number;
};

export class CreditError extends Error {
  constructor(
    public readonly code: "insufficient" | "purchased_negative" | "daily_cap_reached",
    message: string,
    public readonly details: Record<string, number> = {},
  ) {
    super(message);
  }
}

export const CREDITS_PER_LOOK = 5;
export const DAILY_HARD_CAP_CREDITS = 300; // = 60 Looks, independent of balance (§7.2)

/** Default credit prices per metered job type (§9.2); production reads the same table from Remote Config. */
export const DEFAULT_CREDIT_PRICES: Record<string, number> = {
  look: CREDITS_PER_LOOK,
  look_hd: 2 * CREDITS_PER_LOOK,
  twin: 2 * CREDITS_PER_LOOK,
  glowup: CREDITS_PER_LOOK,
};

export function effectiveGrant(b: CreditBalances, nowMs: number): number {
  if (b.grant_expires_at !== null && b.grant_expires_at <= nowMs) return 0;
  return Math.max(0, b.grant);
}

export function looksFromCredits(credits: number): number {
  return credits >= 0 ? Math.floor(credits / CREDITS_PER_LOOK) : -Math.ceil(-credits / CREDITS_PER_LOOK);
}

export function canGenerate(b: CreditBalances, nowMs: number): boolean {
  return b.purchased >= 0 && effectiveGrant(b, nowMs) + b.purchased > 0;
}

/** Debit order grant → purchased. Throws without changing anything when short, when purchased is negative, or over the daily cap. */
export function debit(amount: number, b: CreditBalances, nowMs: number, dailyUsed = 0): CreditDebit {
  if (!(amount > 0)) throw new Error("debit amount must be positive");
  if (b.purchased < 0) throw new CreditError("purchased_negative", "A refund left your purchased Looks negative; top up to continue.");
  if (dailyUsed + amount > DAILY_HARD_CAP_CREDITS) {
    throw new CreditError("daily_cap_reached", "You've used today's Looks — resets at 00:00", { daily_used: dailyUsed, cap: DAILY_HARD_CAP_CREDITS });
  }
  const grant = effectiveGrant(b, nowMs);
  const available = grant + b.purchased;
  if (available < amount) throw new CreditError("insufficient", "Not enough Looks.", { needed: amount, available });
  const fromGrant = Math.min(grant, amount);
  const fromPurchased = amount - fromGrant;
  const bucket: CreditBucket = fromPurchased === 0 ? "grant" : fromGrant === 0 ? "purchased" : "mixed";
  return {
    balances: { grant: grant - fromGrant, grant_expires_at: b.grant_expires_at, purchased: b.purchased - fromPurchased },
    bucket,
    grant_used: fromGrant,
    purchased_used: fromPurchased,
  };
}

/** Refund on terminal failure in the same shape and buckets (§7.2). */
export function refund(d: CreditDebit, b: CreditBalances): CreditBalances {
  return { ...b, grant: b.grant + d.grant_used, purchased: b.purchased + d.purchased_used };
}

/** Apple refund/revoke hits purchased only and may go negative (§7.2). */
export function revoke(amount: number, b: CreditBalances): CreditBalances {
  return { ...b, purchased: b.purchased - amount };
}

/** Monthly grant: whatever is still unexpired rolls over (≤ 1 month by construction) and the new grant is added (§9.2). */
export function renewGrant(b: CreditBalances, grant: number, nowMs: number, expiresAtMs: number): CreditBalances {
  return { grant: effectiveGrant(b, nowMs) + grant, grant_expires_at: expiresAtMs, purchased: b.purchased };
}
