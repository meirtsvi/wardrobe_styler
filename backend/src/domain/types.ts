// Domain value types (PLAN.md §7.5 items/outfits, §5.6 candidate tags). Firestore documents are mapped to these at the gateway boundary.
import type { AccessoryCount, AvailabilityState, Category, Formality, ItemStatus, LayerRole, Occasion, Season, Slot, Warmth } from "./taxonomy.js";
import type { WearWindow } from "./temperature.js";

export type WardrobeItem = {
  id: string;
  category: Category;
  subcategory: string;
  layer_role: LayerRole | null;
  color_hex: string; // colors.primary_hex
  color_name: string; // colors.primary_name
  pattern: string;
  material: string;
  fit?: string;
  warmth: Warmth;
  season: Season[];
  formality: Formality;
  owned: boolean;
  status: ItemStatus;
  availability: AvailabilityState;
  quantity: number;
  is_seed: boolean;
  wear_count: number;
  last_suggested_at: string | null; // ISO date
  deleted: boolean;
};

/** Compact tag block sent to Stage B (§5.6 "≤ 45 items with compact tags"). */
export type Candidate = {
  id: string;
  category: Category;
  subcategory: string;
  layer_role: LayerRole | null;
  color_name: string;
  color_hex: string;
  pattern: string;
  material: string;
  warmth: Warmth;
  formality: Formality;
  last_suggested_days: number | null;
  wear_count: number;
  quantity: number;
  in_palette: boolean;
  score: number;
};

export type PlannedSlot = { slot: Slot; item_id: string; reason: string };

export type PlannedOutfit = {
  slots: PlannedSlot[];
  rationale: string;
  weather_fit: "good" | "acceptable" | "poor";
  formality: Formality;
  palette: string[];
  layering_note: string | null;
  confidence: number;
};

export type PlanResponse = {
  outfits: PlannedOutfit[];
  anchor_honored: boolean;
  anchor_reason: string | null;
};

export type ItemFeedback = {
  thumbs_up: number;
  thumbs_down_in_occasion: number;
  stars_above_3: number; // sum over saved-outfit ratings of max(0, stars - 3)
  disliked: boolean;
};

export type ColorSeason = { best_hex: string[]; avoid_hex: string[] };

export type PlanContext = {
  occasion: Occasion;
  wearWindow: WearWindow;
  anchorId?: string;
  accessoryCount: AccessoryCount;
  bodyAvoid: string[]; // subcategories or fits the user never wants suggested
  colorSeason?: ColorSeason;
  calendarSeason: Season;
  today: string; // ISO date, for coverage arithmetic
  feedback: Record<string, ItemFeedback>;
  recentSubcategorySuggestions: Record<string, number>; // subcategory → days since another item of it was suggested
  recentOutfits: string[][]; // item-id sets shown in the last 14 days
  yesterdayItemIds: string[];
};

export type ValidationResult = {
  passed: boolean;
  rules_failed: string[];
  advisory_warnings: string[];
};
