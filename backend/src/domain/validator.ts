// Outfit validator (PLAN.md §5.6 "Validator (code; the model is not trusted)"). Mirrored in ios/Packages/Domain.
import { CLOTHING_SLOTS, accessoryLimits, formalityAllowed, slotAcceptsCategory, slotMaxItems, taxonomy, type Slot } from "./taxonomy.js";
import {
  baseLayerAllowedByTemperature,
  heavyForbidden,
  isOpenShoe,
  lightOnlyForbidden,
  midLayerAllowed,
  openShoesAllowed,
  outerwearAllowed,
  outerwearForbidden,
  outerwearRequired,
  spansTwoBands,
} from "./temperature.js";
import { palette } from "./color.js";
import type { Candidate, PlanContext, PlannedOutfit, ValidationResult } from "./types.js";

const COLOR_WORDS = Object.keys(palette.named).map((n) => n.replace(/_/g, " "));

function tokens(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .split(/[\s-]+/)
    .filter(Boolean)
    .map((t) => (t.endsWith("s") && t.length > 3 ? t.slice(0, -1) : t)); // crude singular
}

/** True when `phrase` (one or more words) appears as consecutive tokens in `text`. */
function mentions(text: string, phrase: string): boolean {
  const t = tokens(text);
  const p = tokens(phrase);
  if (p.length === 0) return false;
  outer: for (let i = 0; i + p.length <= t.length; i++) {
    for (let j = 0; j < p.length; j++) if (t[i + j] !== p[j]) continue outer;
    return true;
  }
  return false;
}

export function validateOutfit(
  outfit: PlannedOutfit,
  candidates: ReadonlyMap<string, Candidate>,
  ctx: PlanContext,
  opts: { advisory?: boolean } = {},
): ValidationResult {
  const failed: string[] = [];
  const advisory: string[] = [];
  const fail = (rule: string) => {
    if (!failed.includes(rule)) failed.push(rule);
  };

  const resolved = outfit.slots.map((s) => ({ ...s, item: candidates.get(s.item_id) }));
  for (const s of resolved) {
    if (!s.item) fail(`unknown_item:${s.item_id}`);
    else if (!slotAcceptsCategory(s.slot, s.item.category)) fail(`slot_category_mismatch:${s.slot}`);
  }
  const items = resolved.flatMap((s) => (s.item ? [{ slot: s.slot, item: s.item }] : []));
  const has = (slot: Slot) => items.some((i) => i.slot === slot);
  const of = (slot: Slot) => items.filter((i) => i.slot === slot);

  // Duplicate (slot, subcategory) and per-slot caps.
  for (const slot of taxonomy.slots as readonly Slot[]) {
    const entries = of(slot);
    if (entries.length > slotMaxItems(slot)) fail(`duplicate_slot:${slot}`);
    const subs = entries.map((e) => e.item.subcategory);
    if (new Set(subs).size !== subs.length) fail(`duplicate_subcategory:${slot}`);
  }

  // Structural rules.
  if (has("one_piece") && (has("bottom") || has("top") || has("base_layer"))) fail("one_piece_conflict");
  if (has("base_layer")) {
    const top = of("top")[0]?.item;
    if (!top || !(top.layer_role === "single" || top.layer_role === "mid")) fail("base_layer_without_layerable_top");
  }
  if (!has("one_piece") && !(has("top") && has("bottom"))) fail("missing_top_or_bottom");
  if (has("outerwear") && !(has("top") || has("one_piece"))) fail("outerwear_without_top");
  if (!has("shoes")) fail("shoes_missing");

  // Anchor.
  if (ctx.anchorId && !items.some((i) => i.item.id === ctx.anchorId)) fail("anchor_missing");

  // Formality.
  for (const { item } of items) {
    if (!formalityAllowed(ctx.occasion, item.formality)) fail(`formality:${item.id}`);
  }

  // Temperature table (shared/rules/temperature.json).
  const w = ctx.wearWindow;
  if (outerwearRequired(w) && !has("outerwear")) fail("outerwear_required");
  if (has("outerwear")) {
    if (!outerwearAllowed(w, ctx.occasion)) fail("outerwear_not_allowed");
    for (const { item } of of("outerwear")) if (outerwearForbidden(w, item.warmth)) fail("outerwear_forbidden");
  }
  if (has("mid_layer") && !midLayerAllowed(w)) fail("mid_layer_not_allowed");
  if (has("base_layer")) {
    const top = of("top")[0]?.item;
    const base = of("base_layer")[0]?.item;
    const structural = top && base && (top.layer_role === "single" || top.layer_role === "mid") && base.layer_role === "base";
    if (!baseLayerAllowedByTemperature(w) && !structural) fail("base_layer_not_allowed");
  }
  if (heavyForbidden(w) && items.some((i) => i.item.warmth === "heavy")) fail("heavy_warmth_forbidden");
  const clothing = items.filter((i) => CLOTHING_SLOTS.includes(i.slot));
  if (lightOnlyForbidden(w) && clothing.length > 0 && clothing.every((i) => i.item.warmth === "light")) fail("light_only_forbidden");
  for (const { item } of of("shoes")) if (isOpenShoe(item.subcategory) && !openShoesAllowed(w)) fail("open_shoes_not_allowed");
  if (spansTwoBands(w) && !(outfit.layering_note && outfit.layering_note.trim())) fail("layering_note_missing");

  // Accessory count.
  const limits = accessoryLimits(ctx.accessoryCount);
  if (ctx.accessoryCount === "none" && (has("jewelry") || has("accessory"))) fail("accessories_not_wanted");
  else {
    if (of("jewelry").length > limits.jewelry) advisory.push(`jewelry_over_preference:${limits.jewelry}`);
    if (of("accessory").length > limits.accessory) advisory.push(`accessory_over_preference:${limits.accessory}`);
  }

  // History.
  const ids = new Set(items.map((i) => i.item.id));
  for (const past of ctx.recentOutfits) {
    if (past.length === ids.size && past.every((id) => ids.has(id))) {
      fail("repeat_within_14_days");
      break;
    }
  }
  const reused = ctx.yesterdayItemIds.filter((id) => ids.has(id)).length;
  if (reused > taxonomy.history.max_reused_from_yesterday) fail("too_many_from_yesterday");

  // Text: non-empty, and rationale truth.
  if (!outfit.rationale.trim()) fail("rationale_empty");
  for (const s of outfit.slots) if (!s.reason.trim()) fail(`reason_empty:${s.slot}`);
  const text = [outfit.rationale, ...outfit.slots.map((s) => s.reason), outfit.layering_note ?? ""].join(" ");
  const inOutfitColors = new Set(items.map((i) => i.item.color_name.replace(/_/g, " ")));
  const inOutfitSubs = new Set(items.map((i) => i.item.subcategory.replace(/_/g, " ")));
  const allSubs = new Set(Object.values(taxonomy.subcategories).flat().map((s) => s.replace(/_/g, " ")));
  for (const c of COLOR_WORDS) if (!inOutfitColors.has(c) && mentions(text, c)) fail(`rationale_truth:color:${c}`);
  for (const sub of allSubs) if (!inOutfitSubs.has(sub) && mentions(text, sub)) fail(`rationale_truth:item:${sub}`);

  if (opts.advisory) return { passed: true, rules_failed: [], advisory_warnings: [...failed, ...advisory] };
  return { passed: failed.length === 0, rules_failed: failed, advisory_warnings: advisory };
}
