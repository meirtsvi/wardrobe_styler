import { describe, expect, it } from "vitest";
import { context, fixtureCloset, item } from "./fixtures.js";
import { coverageScore, feedbackTerm, passesHardFilters, stageA } from "./stageA.js";

describe("stageA hard filters", () => {
  it("never returns laundry, archived, unowned, deleted or wrong-season items", () => {
    const closet = [
      ...fixtureCloset(),
      item({ id: "laundry-tee", category: "top", subcategory: "tee", availability: "laundry" }),
      item({ id: "archived", category: "top", subcategory: "tee", status: "archived" }),
      item({ id: "new-unreviewed", category: "top", subcategory: "tee", status: "new" }),
      item({ id: "wishlist", category: "top", subcategory: "tee", owned: false }),
      item({ id: "gone", category: "top", subcategory: "tee", deleted: true }),
      item({ id: "summer-only", category: "top", subcategory: "tee", season: ["summer"] }),
    ];
    const ids = stageA(closet, context({ calendarSeason: "autumn" })).map((c) => c.id);
    for (const bad of ["laundry-tee", "archived", "new-unreviewed", "wishlist", "gone", "summer-only"]) expect(ids).not.toContain(bad);
  });
  it("forces an unowned anchor in", () => {
    const closet = [...fixtureCloset(), item({ id: "candidate-blazer", category: "outerwear", subcategory: "blazer", owned: false, warmth: "light" })];
    const ids = stageA(closet, context({ anchorId: "candidate-blazer" })).map((c) => c.id);
    expect(ids).toContain("candidate-blazer");
  });
  it("drops heavy items on a warm day and keeps only light outerwear at 24 °C+", () => {
    const warm = context({ wearWindow: { min_feels_like_c: 17, max_feels_like_c: 26, precip_prob_max: 0 } });
    const ids = stageA(fixtureCloset(), warm).map((c) => c.id);
    expect(ids).not.toContain("parka-black");
    expect(ids).toContain("cardigan-sage"); // mid layer stays allowed while the minimum is below 22 °C
    expect(ids).toContain("trench-camel"); // light outerwear survives the 24 °C rule
  });
  it("honours body avoid list and swim/underwear exclusion", () => {
    const closet = [...fixtureCloset(), item({ id: "bikini", category: "swim", subcategory: "bikini" })];
    const ids = stageA(closet, context({ bodyAvoid: ["shorts"] })).map((c) => c.id);
    expect(ids).not.toContain("shorts-khaki");
    expect(ids).not.toContain("bikini");
    // Swim passes the hard filters for beach/gym (§5.6) but has no outfit slot in v1, so Stage A's per-category take() never returns it.
    const beach = context({ occasion: "beach", wearWindow: { min_feels_like_c: 25, max_feels_like_c: 30, precip_prob_max: 0 } });
    expect(passesHardFilters(closet.find((i) => i.id === "bikini")!, beach, 0)).toBe(true);
  });
  it("excludes seeds once the user owns 3 real items in that category", () => {
    const closet = [...fixtureCloset(), item({ id: "seed-top", category: "top", subcategory: "tee", is_seed: true })];
    expect(stageA(closet, context()).map((c) => c.id)).not.toContain("seed-top");
    const sparse = [item({ id: "only-top", category: "top", subcategory: "tee" }), item({ id: "seed-top", category: "top", subcategory: "tee", is_seed: true })];
    expect(stageA(sparse, context()).map((c) => c.id)).toContain("seed-top");
  });
});

describe("stageA scoring and diversity", () => {
  it("coverage rewards items not suggested for 14 days and penalises same-subcategory repeats", () => {
    const fresh = item({ category: "top", subcategory: "tee", last_suggested_at: null });
    const recent = item({ category: "top", subcategory: "tee", last_suggested_at: "2026-09-30" });
    const ctx = context({ today: "2026-10-01" });
    expect(coverageScore(fresh, ctx)).toBeCloseTo(1);
    expect(coverageScore(recent, ctx)).toBeCloseTo(1 / 14);
    const penalised = coverageScore(fresh, context({ recentSubcategorySuggestions: { tee: 1 } }));
    expect(penalised).toBeCloseTo(0.8);
  });
  it("feedback: disliked items score -1, thumbs-down in occasion -0.5", () => {
    const it1 = item({ id: "x", category: "top", subcategory: "tee" });
    expect(feedbackTerm(it1, context({ feedback: { x: { thumbs_up: 0, thumbs_down_in_occasion: 0, stars_above_3: 0, disliked: true } } }))).toBe(-1);
    expect(feedbackTerm(it1, context({ feedback: { x: { thumbs_up: 1, thumbs_down_in_occasion: 1, stars_above_3: 0, disliked: false } } }))).toBeCloseTo(-0.3);
  });
  it("returns ≤ 45 candidates with jewelry spanning ≥ 2 subcategories and rotates earrings", () => {
    const closet = fixtureCloset();
    const cands = stageA(closet, context());
    expect(cands.length).toBeLessThanOrEqual(45);
    const jewelry = cands.filter((c) => c.category === "jewelry");
    expect(jewelry.length).toBe(4);
    expect(new Set(jewelry.map((j) => j.subcategory)).size).toBeGreaterThanOrEqual(2);
  });
  it("15 pairs of earrings: rotation over 30 days surfaces ≥ 10 distinct pairs", () => {
    const closet = fixtureCloset();
    const seen = new Set<string>();
    let day = new Date("2026-10-01");
    const recentSub: Record<string, number> = {};
    for (let d = 0; d < 30; d++) {
      const today = day.toISOString().slice(0, 10);
      const cands = stageA(closet, context({ today, recentSubcategorySuggestions: recentSub }));
      const pick = cands.filter((c) => c.subcategory === "earrings").sort((a, b) => b.score - a.score)[0];
      if (pick) {
        seen.add(pick.id);
        const it = closet.find((i) => i.id === pick.id)!;
        it.last_suggested_at = today;
      }
      day = new Date(day.getTime() + 86_400_000);
    }
    expect(seen.size).toBeGreaterThanOrEqual(10);
  });
});
