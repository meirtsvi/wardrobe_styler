// Test fixtures shared by the domain tests and (later) the eval-scenario runner.
import type { AccessoryCount, Category, Formality, LayerRole, Occasion, Warmth } from "./taxonomy.js";
import type { Candidate, PlanContext, WardrobeItem } from "./types.js";

let seq = 0;

export function item(partial: Partial<WardrobeItem> & { category: Category; subcategory: string }): WardrobeItem {
  seq += 1;
  const layer_role: LayerRole | null = partial.layer_role ?? (partial.category === "top" ? "single" : partial.category === "mid_layer" ? "mid" : null);
  return {
    id: partial.id ?? `${partial.category}-${partial.subcategory}-${seq}`,
    layer_role,
    color_hex: "#1F2A44",
    color_name: "navy",
    pattern: "solid",
    material: "cotton",
    warmth: "mid" as Warmth,
    season: [],
    formality: "smart_casual" as Formality,
    owned: true,
    status: "confirmed",
    availability: "available",
    quantity: 1,
    is_seed: false,
    wear_count: 0,
    last_suggested_at: null,
    deleted: false,
    ...partial,
  };
}

export function candidate(partial: Partial<Candidate> & { category: Category; subcategory: string }): Candidate {
  const it = item(partial as Partial<WardrobeItem> & { category: Category; subcategory: string });
  return {
    id: it.id,
    layer_role: it.layer_role,
    color_name: it.color_name,
    color_hex: it.color_hex,
    pattern: it.pattern,
    material: it.material,
    warmth: it.warmth,
    formality: it.formality,
    last_suggested_days: null,
    wear_count: 0,
    quantity: it.quantity,
    in_palette: true,
    score: 0.5,
    ...partial,
  };
}

export function context(partial: Partial<PlanContext> = {}): PlanContext {
  return {
    occasion: "casual" as Occasion,
    wearWindow: { min_feels_like_c: 18, max_feels_like_c: 21, precip_prob_max: 10 },
    accessoryCount: "some" as AccessoryCount,
    bodyAvoid: [],
    calendarSeason: "autumn",
    today: "2026-10-01",
    feedback: {},
    recentSubcategorySuggestions: {},
    recentOutfits: [],
    yesterdayItemIds: [],
    ...partial,
  };
}

/** A small mixed closet: tops, bottoms, a dress, layers, shoes incl. sandals, bag, 15 pairs of earrings + a necklace. */
export function fixtureCloset(): WardrobeItem[] {
  const items: WardrobeItem[] = [
    item({ id: "tee-white", category: "top", subcategory: "tee", layer_role: "base", color_hex: "#F7F7F5", color_name: "white", warmth: "light", formality: "casual" }),
    item({ id: "shirt-blue", category: "top", subcategory: "shirt", layer_role: "single", color_hex: "#2F5DA8", color_name: "blue", warmth: "mid", formality: "smart_casual" }),
    item({ id: "sweater-grey", category: "top", subcategory: "sweater", layer_role: "single", color_hex: "#8C8C8C", color_name: "grey", warmth: "warm", material: "wool", formality: "smart_casual" }),
    item({ id: "jeans-navy", category: "bottom", subcategory: "jeans", color_hex: "#1F2A44", color_name: "navy", material: "denim", warmth: "mid", formality: "casual" }),
    item({ id: "chinos-tan", category: "bottom", subcategory: "chinos", color_hex: "#C8A97E", color_name: "tan", warmth: "mid", formality: "smart_casual" }),
    item({ id: "shorts-khaki", category: "bottom", subcategory: "shorts", color_hex: "#B7A97A", color_name: "khaki", warmth: "light", formality: "casual" }),
    item({ id: "dress-black", category: "one_piece", subcategory: "dress", color_hex: "#111111", color_name: "black", warmth: "light", formality: "smart_casual" }),
    item({ id: "cardigan-sage", category: "mid_layer", subcategory: "cardigan", layer_role: "mid", color_hex: "#9CAF88", color_name: "sage", warmth: "mid", material: "knit" }),
    item({ id: "trench-camel", category: "outerwear", subcategory: "trench", color_hex: "#C19A6B", color_name: "camel", warmth: "light", formality: "smart_casual" }),
    item({ id: "parka-black", category: "outerwear", subcategory: "parka", color_hex: "#111111", color_name: "black", warmth: "heavy", formality: "casual" }),
    item({ id: "sneakers-white", category: "shoes", subcategory: "sneakers", color_hex: "#F7F7F5", color_name: "white", warmth: "mid", formality: "casual", quantity: 2 }),
    item({ id: "boots-brown", category: "shoes", subcategory: "boots", color_hex: "#6B4A2B", color_name: "brown", material: "leather", warmth: "warm", formality: "smart_casual", quantity: 2 }),
    item({ id: "sandals-tan", category: "shoes", subcategory: "sandals", color_hex: "#C8A97E", color_name: "tan", warmth: "light", formality: "casual", quantity: 2 }),
    item({ id: "tote-black", category: "bag", subcategory: "tote", color_hex: "#111111", color_name: "black", material: "leather" }),
    item({ id: "necklace-gold", category: "jewelry", subcategory: "necklace", color_hex: "#C9A227", color_name: "gold" }),
    item({ id: "belt-brown", category: "accessory", subcategory: "belt", color_hex: "#6B4A2B", color_name: "brown", material: "leather" }),
  ];
  for (let i = 1; i <= 15; i++) {
    items.push(item({ id: `earrings-${i}`, category: "jewelry", subcategory: "earrings", color_hex: "#BFC4C9", color_name: "silver", quantity: 2 }));
  }
  return items;
}
