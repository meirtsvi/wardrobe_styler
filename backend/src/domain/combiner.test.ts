import { describe, expect, it } from "vitest";
import { combine } from "./combiner.js";
import { context, fixtureCloset, item } from "./fixtures.js";
import { stageA } from "./stageA.js";
import { validateOutfit } from "./validator.js";

function run(ctxPartial: Parameters<typeof context>[0] = {}, closet = fixtureCloset()) {
  const ctx = context(ctxPartial);
  const cands = stageA(closet, ctx);
  const outfit = combine(cands, ctx);
  return { ctx, cands, outfit };
}

describe("combiner", () => {
  it("always produces a validator-passing outfit on the fixture closet, mild day", () => {
    const { ctx, cands, outfit } = run();
    expect(outfit).not.toBeNull();
    const r = validateOutfit(outfit!, new Map(cands.map((c) => [c.id, c])), ctx);
    expect(r.passed, r.rules_failed.join(",")).toBe(true);
    expect(outfit!.slots.some((s) => s.slot === "shoes")).toBe(true);
  });
  it("cold morning (3 → 9 °C): outerwear present, layering note written", () => {
    const { ctx, cands, outfit } = run({ wearWindow: { min_feels_like_c: 3, max_feels_like_c: 9, precip_prob_max: 20 } });
    expect(outfit).not.toBeNull();
    expect(outfit!.slots.some((s) => s.slot === "outerwear")).toBe(true);
    expect(outfit!.layering_note).toBeTruthy();
    expect(validateOutfit(outfit!, new Map(cands.map((c) => [c.id, c])), ctx).passed).toBe(true);
  });
  it("hot day (26 → 32 °C): no outerwear, no mid layer, passes", () => {
    const { ctx, cands, outfit } = run({ wearWindow: { min_feels_like_c: 26, max_feels_like_c: 32, precip_prob_max: 0 } });
    expect(outfit).not.toBeNull();
    expect(outfit!.slots.some((s) => s.slot === "outerwear" || s.slot === "mid_layer")).toBe(false);
    expect(validateOutfit(outfit!, new Map(cands.map((c) => [c.id, c])), ctx).passed).toBe(true);
  });
  it("laundry scenario: an item in the laundry never appears", () => {
    const closet = fixtureCloset().map((i) => (i.id === "jeans-navy" ? { ...i, availability: "laundry" as const } : i));
    const { outfit } = run({}, closet);
    expect(outfit!.slots.map((s) => s.item_id)).not.toContain("jeans-navy");
  });
  it("anchor: builds around the dress when asked", () => {
    const { outfit } = run({ anchorId: "dress-black" });
    expect(outfit!.slots.find((s) => s.slot === "one_piece")?.item_id).toBe("dress-black");
    expect(outfit!.slots.some((s) => s.slot === "bottom")).toBe(false);
  });
  it("accessory_count none: no jewelry or accessories", () => {
    const { outfit } = run({ accessoryCount: "none" });
    expect(outfit!.slots.some((s) => s.slot === "jewelry" || s.slot === "accessory")).toBe(false);
  });
  it("returns null when the closet cannot satisfy the rules (no shoes)", () => {
    const closet = [item({ category: "top", subcategory: "tee" }), item({ category: "bottom", subcategory: "jeans" })];
    expect(run({}, closet).outfit).toBeNull();
  });
});
