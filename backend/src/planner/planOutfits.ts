// Stage A → Stage B → validator → one repair → deterministic combiner (PLAN §5.6). The model is behind the Planner interface so the
// orchestration is tested with fakes and the Gemini adapter can be swapped or mocked in the load test.
import { combine } from "../domain/combiner.js";
import { stageA } from "../domain/stageA.js";
import type { Candidate, PlanContext, PlanResponse, PlannedOutfit, WardrobeItem } from "../domain/types.js";
import { validateOutfit } from "../domain/validator.js";

export type PlannerCall = {
  candidates: Candidate[];
  ctx: PlanContext;
  n: number;
  /** Present on the repair call: rule ids that failed per outfit index. */
  violations?: { index: number; rules_failed: string[] }[];
};

export interface Planner {
  plan(call: PlannerCall): Promise<PlanResponse>;
}

export type PlannedResult = {
  outfit: PlannedOutfit;
  validator: { passed: boolean; rules_failed: string[]; repaired: boolean; fallback: boolean; advisory_warnings: string[] };
};

export type PlanOutcome = {
  outfits: PlannedResult[];
  candidates: Candidate[];
  anchor_honored: boolean;
  anchor_reason: string | null;
  calls: number;
};

/** Plan `n` outfits from a wardrobe (server-side Stage A). Always returns at least one outfit when the closet can satisfy the rules. */
export async function planOutfits(planner: Planner, items: WardrobeItem[], ctx: PlanContext, n = 3): Promise<PlanOutcome> {
  return planFromCandidates(planner, stageA(items, ctx), ctx, n);
}

/** Plan from a client-computed candidate list (ADR 0001: the device runs Stage A; the server never reads the wardrobe). */
export async function planFromCandidates(planner: Planner, candidates: Candidate[], ctx: PlanContext, n = 3): Promise<PlanOutcome> {
  const byId = new Map(candidates.map((c) => [c.id, c]));
  let calls = 0;

  const check = (o: PlannedOutfit) => validateOutfit(o, byId, ctx);

  let response: PlanResponse;
  try {
    response = await planner.plan({ candidates, ctx, n });
    calls++;
  } catch {
    response = { outfits: [], anchor_honored: false, anchor_reason: "planner_error" };
  }

  let results: PlannedResult[] = response.outfits.map((outfit) => {
    const v = check(outfit);
    return { outfit, validator: { passed: v.passed, rules_failed: v.rules_failed, repaired: false, fallback: false, advisory_warnings: v.advisory_warnings } };
  });

  // One repair call with the violation list appended (§5.6).
  const violations = results.map((r, index) => ({ index, rules_failed: r.validator.rules_failed })).filter((v) => v.rules_failed.length > 0);
  if (calls > 0 && violations.length > 0) {
    try {
      const repaired = await planner.plan({ candidates, ctx, n, violations });
      calls++;
      for (const v of violations) {
        const candidate = repaired.outfits[v.index];
        if (!candidate) continue;
        const check2 = check(candidate);
        results[v.index] = {
          outfit: candidate,
          validator: { passed: check2.passed, rules_failed: check2.rules_failed, repaired: true, fallback: false, advisory_warnings: check2.advisory_warnings },
        };
      }
      if (repaired.anchor_honored) response = { ...response, anchor_honored: true, anchor_reason: repaired.anchor_reason };
    } catch {
      // fall through to the combiner
    }
  }

  // Anything still invalid is replaced by the combiner; if the model returned nothing, the combiner provides one outfit.
  results = results.filter((r) => r.validator.passed);
  if (results.length === 0) {
    const fallback = combine(candidates, ctx);
    if (fallback) {
      results.push({ outfit: fallback, validator: { passed: true, rules_failed: [], repaired: false, fallback: true, advisory_warnings: [] } });
    }
  }

  const anchorHonored = ctx.anchorId ? results.some((r) => r.outfit.slots.some((s) => s.item_id === ctx.anchorId)) : true;
  return {
    outfits: results.slice(0, n),
    candidates,
    anchor_honored: anchorHonored,
    anchor_reason: anchorHonored ? null : (response.anchor_reason ?? "anchor could not be placed"),
    calls,
  };
}

/** Rule-only planner: Stage A + combiner, no model. The daily "reused" tier and the offline/ladder fallback (§5.6 "Reuse rule", §7.8). */
export class CombinerPlanner implements Planner {
  async plan(call: PlannerCall): Promise<PlanResponse> {
    const outfit = combine(call.candidates, call.ctx);
    return { outfits: outfit ? [outfit] : [], anchor_honored: !!outfit, anchor_reason: outfit ? null : "no valid combination" };
  }
}
