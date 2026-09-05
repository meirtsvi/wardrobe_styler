import { describe, expect, it } from "vitest";
import { candidate, context } from "./fixtures.js";
import type { Candidate, PlannedOutfit } from "./types.js";
import { validateOutfit } from "./validator.js";

const top = candidate({ id: "shirt", category: "top", subcategory: "shirt", layer_role: "single", color_name: "blue", color_hex: "#2F5DA8" });
const tee = candidate({ id: "tee", category: "top", subcategory: "tee", layer_role: "base", color_name: "white", color_hex: "#F7F7F5", warmth: "light" });
const bottom = candidate({ id: "jeans", category: "bottom", subcategory: "jeans", color_name: "navy" });
const shoes = candidate({ id: "sneakers", category: "shoes", subcategory: "sneakers", color_name: "white", color_hex: "#F7F7F5" });
const sandals = candidate({ id: "sandals", category: "shoes", subcategory: "sandals", color_name: "tan", color_hex: "#C8A97E", warmth: "light" });
const dress = candidate({ id: "dress", category: "one_piece", subcategory: "dress", color_name: "black", color_hex: "#111111" });
const trench = candidate({ id: "trench", category: "outerwear", subcategory: "trench", color_name: "camel", color_hex: "#C19A6B", warmth: "light" });
const parka = candidate({ id: "parka", category: "outerwear", subcategory: "parka", color_name: "black", color_hex: "#111111", warmth: "heavy" });
const cardigan = candidate({ id: "cardigan", category: "mid_layer", subcategory: "cardigan", layer_role: "mid", color_name: "sage", color_hex: "#9CAF88" });
const earrings1 = candidate({ id: "e1", category: "jewelry", subcategory: "earrings", color_name: "silver" });
const earrings2 = candidate({ id: "e2", category: "jewelry", subcategory: "earrings", color_name: "silver" });
const necklace = candidate({ id: "n1", category: "jewelry", subcategory: "necklace", color_name: "gold" });
const belt = candidate({ id: "belt", category: "accessory", subcategory: "belt", color_name: "brown" });
const gymTee = candidate({ id: "gym-tee", category: "top", subcategory: "tee", layer_role: "base", color_name: "black", formality: "athletic" });

const pool = new Map<string, Candidate>([top, tee, bottom, shoes, sandals, dress, trench, parka, cardigan, earrings1, earrings2, necklace, belt, gymTee].map((c) => [c.id, c]));

function outfit(slots: [string, Candidate][], extra: Partial<PlannedOutfit> = {}): PlannedOutfit {
  return {
    slots: slots.map(([slot, c]) => ({ slot: slot as PlannedOutfit["slots"][number]["slot"], item_id: c.id, reason: `${c.color_name} ${c.subcategory}` })),
    rationale: "Navy and blue, analogous, for a mild day.",
    weather_fit: "good",
    formality: "smart_casual",
    palette: ["navy", "blue"],
    layering_note: null,
    confidence: 0.8,
    ...extra,
  };
}

describe("validateOutfit — structure", () => {
  it("accepts a plain top + bottom + shoes on a mild day", () => {
    const r = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes]]), pool, context());
    expect(r).toEqual({ passed: true, rules_failed: [], advisory_warnings: [] });
  });
  it("rejects unknown items and slot/category mismatches", () => {
    const ghost = candidate({ id: "ghost", category: "top", subcategory: "tee" });
    const r = validateOutfit(outfit([["top", ghost], ["bottom", bottom], ["shoes", shoes], ["bag", belt]]), pool, context());
    expect(r.rules_failed).toContain("unknown_item:ghost");
    expect(r.rules_failed).toContain("slot_category_mismatch:bag");
  });
  it("rejects a dress with trousers (the Essembl bug) and requires shoes", () => {
    const r = validateOutfit(outfit([["one_piece", dress], ["bottom", bottom]]), pool, context());
    expect(r.rules_failed).toContain("one_piece_conflict");
    expect(r.rules_failed).toContain("shoes_missing");
  });
  it("allows up to 3 jewelry with distinct subcategories, but not two pairs of earrings", () => {
    const ok = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["jewelry", earrings1], ["jewelry", necklace]]), pool, context());
    expect(ok.passed).toBe(true);
    const bad = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["jewelry", earrings1], ["jewelry", earrings2]]), pool, context());
    expect(bad.rules_failed).toContain("duplicate_subcategory:jewelry");
  });
  it("requires a layerable top under a base layer", () => {
    const bad = validateOutfit(outfit([["top", tee], ["base_layer", tee], ["bottom", bottom], ["shoes", shoes]]), pool, context());
    expect(bad.rules_failed).toContain("base_layer_without_layerable_top");
  });
  it("enforces the anchor", () => {
    const r = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes]]), pool, context({ anchorId: "dress" }));
    expect(r.rules_failed).toContain("anchor_missing");
  });
  it("enforces formality per occasion", () => {
    const r = validateOutfit(outfit([["top", gymTee], ["bottom", bottom], ["shoes", shoes]]), pool, context({ occasion: "work" }));
    expect(r.rules_failed).toContain("formality:gym-tee");
  });
});

describe("validateOutfit — temperature table", () => {
  it("requires outerwear at 5 °C and forbids a light-only outfit", () => {
    const cold = context({ wearWindow: { min_feels_like_c: 5, max_feels_like_c: 7, precip_prob_max: 0 } });
    const r = validateOutfit(outfit([["top", tee], ["bottom", bottom], ["shoes", shoes]]), pool, cold);
    expect(r.rules_failed).toContain("outerwear_required");
  });
  it("wear-window 9 → 21 °C: outerwear present and layering mentioned passes; missing layering note fails", () => {
    const shoulder = context({ wearWindow: { min_feels_like_c: 9, max_feels_like_c: 21, precip_prob_max: 10 } });
    const slots: [string, Candidate][] = [["top", top], ["bottom", bottom], ["shoes", shoes], ["outerwear", trench]];
    expect(validateOutfit(outfit(slots, { layering_note: "9° at 8 am, 21° by lunch — the trench comes off" }), pool, shoulder).passed).toBe(true);
    expect(validateOutfit(outfit(slots), pool, shoulder).rules_failed).toContain("layering_note_missing");
  });
  it("forbids a heavy parka above 15 °C and non-light outerwear at 24 °C+", () => {
    const warm = context({ wearWindow: { min_feels_like_c: 17, max_feels_like_c: 25, precip_prob_max: 0 } });
    const r = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["outerwear", parka]]), pool, warm);
    expect(r.rules_failed).toContain("heavy_warmth_forbidden");
    expect(r.rules_failed).toContain("outerwear_forbidden");
    const ok = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["outerwear", trench]], { layering_note: "trench off by noon" }), pool, warm);
    expect(ok.passed, ok.rules_failed.join(",")).toBe(true);
  });
  it("forbids a mid layer at 22 °C+ minimum and outerwear at 18 °C+ for casual", () => {
    const hot = context({ wearWindow: { min_feels_like_c: 23, max_feels_like_c: 30, precip_prob_max: 0 } });
    const r = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["mid_layer", cardigan], ["outerwear", trench]]), pool, hot);
    expect(r.rules_failed).toContain("mid_layer_not_allowed");
    expect(r.rules_failed).toContain("outerwear_not_allowed");
  });
  it("blocks sandals in the rain", () => {
    const rainy = context({ wearWindow: { min_feels_like_c: 18, max_feels_like_c: 24, precip_prob_max: 70 } });
    const r = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", sandals]]), pool, rainy);
    expect(r.rules_failed).toContain("open_shoes_not_allowed");
  });
});

describe("validateOutfit — preferences, history, text", () => {
  it("accessory_count none forbids jewelry; 'some' only warns above 2", () => {
    const none = validateOutfit(outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["jewelry", necklace]]), pool, context({ accessoryCount: "none" }));
    expect(none.rules_failed).toContain("accessories_not_wanted");
    const some = validateOutfit(
      outfit([["top", top], ["bottom", bottom], ["shoes", shoes], ["jewelry", necklace], ["jewelry", earrings1], ["jewelry", candidate({ id: "w", category: "jewelry", subcategory: "watch", color_name: "silver" })]]),
      new Map([...pool, ["w", candidate({ id: "w", category: "jewelry", subcategory: "watch", color_name: "silver" })]]),
      context({ accessoryCount: "some" }),
    );
    expect(some.passed).toBe(true);
    expect(some.advisory_warnings).toContain("jewelry_over_preference:2");
  });
  it("rejects a 14-day repeat and more than two items from yesterday", () => {
    const slots: [string, Candidate][] = [["top", top], ["bottom", bottom], ["shoes", shoes]];
    const repeat = validateOutfit(outfit(slots), pool, context({ recentOutfits: [["shirt", "jeans", "sneakers"]] }));
    expect(repeat.rules_failed).toContain("repeat_within_14_days");
    const yesterday = validateOutfit(outfit(slots), pool, context({ yesterdayItemIds: ["shirt", "jeans", "sneakers", "belt"] }));
    expect(yesterday.rules_failed).toContain("too_many_from_yesterday");
    const twoOk = validateOutfit(outfit(slots), pool, context({ yesterdayItemIds: ["shirt", "jeans"] }));
    expect(twoOk.passed).toBe(true);
  });
  it("rationale truth: colours and items mentioned must be in the outfit", () => {
    const slots: [string, Candidate][] = [["top", top], ["bottom", bottom], ["shoes", shoes]];
    const lying = validateOutfit(outfit(slots, { rationale: "The camel trench warms up the navy jeans." }), pool, context());
    expect(lying.rules_failed).toContain("rationale_truth:color:camel");
    expect(lying.rules_failed).toContain("rationale_truth:item:trench");
    const empty = validateOutfit(outfit(slots, { rationale: "  " }), pool, context());
    expect(empty.rules_failed).toContain("rationale_empty");
  });
  it("advisory mode never fails, it only warns (manual builder)", () => {
    const r = validateOutfit(outfit([["one_piece", dress], ["bottom", bottom]]), pool, context(), { advisory: true });
    expect(r.passed).toBe(true);
    expect(r.advisory_warnings).toContain("one_piece_conflict");
  });
});
