import { describe, expect, it } from "vitest";
import { context, fixtureCloset } from "../domain/fixtures.js";
import type { PlanResponse, PlannedOutfit } from "../domain/types.js";
import { CombinerPlanner, type Planner, type PlannerCall, planOutfits } from "./planOutfits.js";

const good: PlannedOutfit = {
  slots: [
    { slot: "top", item_id: "shirt-blue", reason: "blue shirt" },
    { slot: "bottom", item_id: "jeans-navy", reason: "navy jeans" },
    { slot: "shoes", item_id: "sneakers-white", reason: "white sneakers" },
  ],
  rationale: "Analogous blues for a mild day.",
  weather_fit: "good",
  formality: "smart_casual",
  palette: ["blue", "navy"],
  layering_note: null,
  confidence: 0.9,
};

const dressWithJeans: PlannedOutfit = {
  ...good,
  slots: [
    { slot: "one_piece", item_id: "dress-black", reason: "black dress" },
    { slot: "bottom", item_id: "jeans-navy", reason: "navy jeans" },
    { slot: "shoes", item_id: "sneakers-white", reason: "white sneakers" },
  ],
  rationale: "Black dress with jeans.",
};

class ScriptedPlanner implements Planner {
  public calls: PlannerCall[] = [];
  constructor(private readonly responses: (PlanResponse | Error)[]) {}
  async plan(call: PlannerCall): Promise<PlanResponse> {
    this.calls.push(call);
    const r = this.responses[this.calls.length - 1] ?? this.responses[this.responses.length - 1]!;
    if (r instanceof Error) throw r;
    return r;
  }
}

describe("planOutfits", () => {
  it("accepts valid model output on the first pass", async () => {
    const p = new ScriptedPlanner([{ outfits: [good], anchor_honored: true, anchor_reason: null }]);
    const out = await planOutfits(p, fixtureCloset(), context());
    expect(out.calls).toBe(1);
    expect(out.outfits[0]!.validator).toMatchObject({ passed: true, repaired: false, fallback: false });
  });

  it("repairs once with the violation list, then accepts", async () => {
    const p = new ScriptedPlanner([
      { outfits: [dressWithJeans], anchor_honored: true, anchor_reason: null },
      { outfits: [good], anchor_honored: true, anchor_reason: null },
    ]);
    const out = await planOutfits(p, fixtureCloset(), context());
    expect(out.calls).toBe(2);
    expect(p.calls[1]!.violations).toEqual([{ index: 0, rules_failed: ["one_piece_conflict"] }]);
    expect(out.outfits[0]!.validator).toMatchObject({ passed: true, repaired: true, fallback: false });
  });

  it("falls back to the combiner when the repair is still invalid, and labels it", async () => {
    const p = new ScriptedPlanner([
      { outfits: [dressWithJeans], anchor_honored: true, anchor_reason: null },
      { outfits: [dressWithJeans], anchor_honored: true, anchor_reason: null },
    ]);
    const out = await planOutfits(p, fixtureCloset(), context());
    expect(out.calls).toBe(2);
    expect(out.outfits).toHaveLength(1);
    expect(out.outfits[0]!.validator.fallback).toBe(true);
    expect(out.outfits[0]!.outfit.slots.some((s) => s.slot === "shoes")).toBe(true);
  });

  it("planner errors still render a card", async () => {
    const p = new ScriptedPlanner([new Error("503")]);
    const out = await planOutfits(p, fixtureCloset(), context());
    expect(out.calls).toBe(0);
    expect(out.outfits[0]!.validator.fallback).toBe(true);
  });

  it("keeps valid outfits and drops invalid ones from a mixed n=3 response", async () => {
    const p = new ScriptedPlanner([
      { outfits: [good, dressWithJeans, good], anchor_honored: true, anchor_reason: null },
      new Error("repair failed"),
    ]);
    const out = await planOutfits(p, fixtureCloset(), context());
    expect(out.outfits).toHaveLength(2);
    expect(out.outfits.every((o) => o.validator.passed && !o.validator.fallback)).toBe(true);
  });

  it("reports anchor_honored from the final outfits", async () => {
    const out = await planOutfits(new CombinerPlanner(), fixtureCloset(), context({ anchorId: "dress-black" }));
    expect(out.anchor_honored).toBe(true);
    expect(out.outfits[0]!.outfit.slots.some((s) => s.item_id === "dress-black")).toBe(true);
  });
});
