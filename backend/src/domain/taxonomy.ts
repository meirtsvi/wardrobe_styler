// Types derived from shared/schemas/taxonomy.json (PLAN.md §5.3, §5.6).
import taxonomyJson from "../../../shared/schemas/taxonomy.json" with { type: "json" };

export const taxonomy = taxonomyJson;

// Literal unions are declared here (JSON imports widen to string); taxonomy.test.ts asserts they match the JSON lists.
export const CATEGORIES = ["one_piece", "top", "mid_layer", "outerwear", "bottom", "shoes", "bag", "jewelry", "accessory", "swim", "underwear", "other"] as const;
export const SLOTS = ["one_piece", "top", "base_layer", "mid_layer", "outerwear", "bottom", "shoes", "bag", "jewelry", "accessory"] as const;
export const LAYER_ROLES = ["base", "single", "mid", "outer"] as const;
export const WARMTH = ["light", "mid", "warm", "heavy"] as const;
export const FORMALITY = ["casual", "smart_casual", "business", "formal", "athletic"] as const;
export const SEASONS = ["spring", "summer", "autumn", "winter"] as const;
export const OCCASIONS = ["work", "casual", "date", "event", "travel", "sport", "beach", "gym", "formal", "evening"] as const;
export const ACCESSORY_COUNTS = ["none", "some", "many"] as const;
export const ITEM_STATUS = ["new", "auto", "confirmed", "archived"] as const;
export const AVAILABILITY_STATES = ["available", "laundry", "repair", "packed", "lent"] as const;

export type Category = (typeof CATEGORIES)[number];
export type Slot = (typeof SLOTS)[number];
export type LayerRole = (typeof LAYER_ROLES)[number];
export type Warmth = (typeof WARMTH)[number];
export type Formality = (typeof FORMALITY)[number];
export type Season = (typeof SEASONS)[number];
export type Occasion = (typeof OCCASIONS)[number];
export type AccessoryCount = (typeof ACCESSORY_COUNTS)[number];
export type ItemStatus = (typeof ITEM_STATUS)[number];
export type AvailabilityState = (typeof AVAILABILITY_STATES)[number];

export const CLOTHING_SLOTS: readonly Slot[] = ["one_piece", "top", "base_layer", "mid_layer", "outerwear", "bottom"];

export function isOccasion(value: string): value is Occasion {
  return (OCCASIONS as readonly string[]).includes(value);
}

export function slotAcceptsCategory(slot: Slot, category: Category): boolean {
  const allowed = (taxonomy.slot_categories as Record<string, readonly string[]>)[slot] ?? [];
  return allowed.includes(category);
}

export function slotMaxItems(slot: Slot): number {
  return (taxonomy.slot_max_items as Record<string, number>)[slot] ?? 1;
}

/** Formality allowed for an occasion: in the occasion's set, or one step from its primary target (§5.6 "±1 step"). Athletic only where the set names it. */
export function formalityAllowed(occasion: Occasion, formality: Formality): boolean {
  const set = (taxonomy.occasion_formality as Record<string, readonly string[]>)[occasion] ?? [];
  if (set.includes(formality)) return true;
  if (formality === "athletic") return false;
  const order = taxonomy.formality_order as readonly string[];
  const primary = set[0];
  if (primary === undefined || primary === "athletic") return false;
  const a = order.indexOf(primary);
  const b = order.indexOf(formality);
  return a >= 0 && b >= 0 && Math.abs(a - b) <= 1;
}

export function occasionAllowsSwimUnderwear(occasion: Occasion): boolean {
  return (taxonomy.occasion_allows_swim_underwear as readonly string[]).includes(occasion);
}

export function accessoryLimits(count: AccessoryCount): { jewelry: number; accessory: number } {
  return taxonomy.accessory_count[count];
}

export function defaultLayerRole(category: Category, subcategory: string): LayerRole | null {
  if (category !== "top" && category !== "mid_layer") return null;
  const role = (taxonomy.top_layer_role_defaults as Record<string, LayerRole | undefined>)[subcategory];
  return role ?? (category === "mid_layer" ? "mid" : "single");
}
