import { describe, expect, it } from "vitest";
import { CreditError, canGenerate, debit, effectiveGrant, looksFromCredits, refund, renewGrant, revoke } from "./credits.js";

const now = 1_800_000_000_000;

describe("credits", () => {
  it("converts credits to Looks", () => {
    expect(looksFromCredits(12)).toBe(2);
    expect(looksFromCredits(-7)).toBe(-2);
  });
  it("debits grant first, then mixed, then purchased", () => {
    const b = { grant: 7, grant_expires_at: now + 86_400_000, purchased: 20 };
    const d1 = debit(5, b, now);
    expect(d1.bucket).toBe("grant");
    expect(d1.balances).toEqual({ grant: 2, grant_expires_at: b.grant_expires_at, purchased: 20 });
    const d2 = debit(5, d1.balances, now);
    expect(d2.bucket).toBe("mixed");
    expect([d2.grant_used, d2.purchased_used]).toEqual([2, 3]);
    expect(debit(5, d2.balances, now).bucket).toBe("purchased");
  });
  it("treats expired grants as zero", () => {
    const b = { grant: 50, grant_expires_at: now - 1, purchased: 5 };
    expect(effectiveGrant(b, now)).toBe(0);
    const d = debit(5, b, now);
    expect(d.bucket).toBe("purchased");
    expect(() => debit(5, d.balances, now)).toThrow(CreditError);
  });
  it("refund restores the same buckets", () => {
    const b = { grant: 3, grant_expires_at: null, purchased: 10 };
    const d = debit(5, b, now);
    expect(refund(d, d.balances)).toEqual(b);
  });
  it("revoke goes negative on purchased only and blocks generation", () => {
    const b = revoke(25, { grant: 40, grant_expires_at: null, purchased: 20 });
    expect(b).toEqual({ grant: 40, grant_expires_at: null, purchased: -5 });
    expect(canGenerate(b, now)).toBe(false);
    expect(() => debit(5, b, now)).toThrow(/negative/);
  });
  it("daily hard cap is independent of balance and carries the reset message", () => {
    const b = { grant: 1000, grant_expires_at: null, purchased: 1000 };
    expect(() => debit(5, b, now, 296)).toThrow(/resets at 00:00/);
    expect(debit(5, b, now, 295).bucket).toBe("grant");
  });
  it("renewal rolls unexpired grant over", () => {
    expect(renewGrant({ grant: 60, grant_expires_at: now + 1, purchased: 0 }, 200, now, now + 30 * 86_400_000).grant).toBe(260);
    expect(renewGrant({ grant: 60, grant_expires_at: now - 1, purchased: 0 }, 200, now, now).grant).toBe(200);
  });
});
