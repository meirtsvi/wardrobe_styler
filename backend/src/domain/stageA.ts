// Stage A — deterministic candidate retrieval and scoring (PLAN.md §5.6). No model call.
import { deltaE00, hexToLab, paletteScore, seasonalPalette } from "./color.js";
import { formalityAllowed, occasionAllowsSwimUnderwear, taxonomy, type Category } from "./taxonomy.js";
import { heavyForbidden, lightOnlyForbidden, midLayerAllowed, outerwearAllowed } from "./temperature.js";
import type { Candidate, PlanContext, WardrobeItem } from "./types.js";

const MS_PER_DAY = 86_400_000;

export function daysBetween(fromISO: string, toISO: string): number {
  return Math.max(0, Math.floor((Date.parse(toISO) - Date.parse(fromISO)) / MS_PER_DAY));
}

/** Hard filters. The anchor is forced in (it may be unowned, e.g. a "should I buy this?" candidate). */
export function passesHardFilters(item: WardrobeItem, ctx: PlanContext, realCountInCategory: number): boolean {
  if (item.id === ctx.anchorId) return true;
  if (item.deleted) return false;
  // Review-queue items ("new") are still the user's clothes; only archived items are out (relaxed from PLAN §5.6 after real-data testing).
  if (item.status === "archived") return false;
  if (!item.owned) return false;
  if (item.availability !== "available") return false;
  if (item.is_seed && realCountInCategory >= 3) return false;
  if ((item.category === "swim" || item.category === "underwear") && !occasionAllowsSwimUnderwear(ctx.occasion)) return false;
  if (!formalityAllowed(ctx.occasion, item.formality)) return false;
  if (ctx.bodyAvoid.includes(item.subcategory) || (item.fit && ctx.bodyAvoid.includes(item.fit))) return false;
  const w = ctx.wearWindow;
  if (item.warmth === "heavy" && heavyForbidden(w)) return false;
  if (item.category === "outerwear" && !outerwearAllowed(w, ctx.occasion) ) return false;
  if (item.category === "outerwear" && w.max_feels_like_c >= 24 && item.warmth !== "light") return false;
  if (item.category === "mid_layer" && !midLayerAllowed(w)) return false;
  return true;
}

export function coverageScore(item: WardrobeItem, ctx: PlanContext): number {
  const days = item.last_suggested_at ? daysBetween(item.last_suggested_at, ctx.today) : taxonomy.history.coverage_full_days;
  let score = Math.min(1, days / taxonomy.history.coverage_full_days);
  const subDays = ctx.recentSubcategorySuggestions[item.subcategory];
  if (subDays !== undefined && subDays <= taxonomy.history.subcategory_penalty_days) score -= 0.2;
  if (item.quantity >= 2) score += 0.05;
  return Math.max(0, Math.min(1, score));
}

export function paletteTerm(item: WardrobeItem, ctx: PlanContext, anchorHex: string | undefined): number {
  const refs = anchorHex ? [anchorHex] : seasonalPalette(ctx.calendarSeason);
  let score = paletteScore(item.color_hex, refs);
  if (ctx.colorSeason) {
    const lab = hexToLab(item.color_hex);
    if (ctx.colorSeason.best_hex.some((h) => deltaE00(lab, hexToLab(h)) <= 12)) score += 0.15;
    if (ctx.colorSeason.avoid_hex.some((h) => deltaE00(lab, hexToLab(h)) <= 12)) score -= 0.15;
  }
  return Math.max(0, Math.min(1, score));
}

export function feedbackTerm(item: WardrobeItem, ctx: PlanContext): number {
  const f = ctx.feedback[item.id];
  if (!f) return 0;
  if (f.disliked) return -1;
  const v = 0.2 * f.thumbs_up + 0.1 * f.stars_above_3 - 0.5 * f.thumbs_down_in_occasion;
  return Math.max(-1, Math.min(1, v));
}

/** Season tags are advisory: an out-of-season tag costs 0.2 (the temperature rules decide what is wearable). */
export function seasonPenalty(item: WardrobeItem, ctx: PlanContext): number {
  return item.season.length > 0 && !item.season.includes(ctx.calendarSeason) ? 0.2 : 0;
}

export function scoreItem(item: WardrobeItem, ctx: PlanContext, anchorHex: string | undefined): number {
  return 0.4 * coverageScore(item, ctx) + 0.3 * paletteTerm(item, ctx, anchorHex) + 0.3 * feedbackTerm(item, ctx) - seasonPenalty(item, ctx);
}

export function inSeasonalPalette(item: WardrobeItem, ctx: PlanContext): boolean {
  return paletteScore(item.color_hex, seasonalPalette(ctx.calendarSeason)) >= 0.85;
}

function toCandidate(item: WardrobeItem, ctx: PlanContext, score: number): Candidate {
  return {
    id: item.id,
    category: item.category,
    subcategory: item.subcategory,
    layer_role: item.layer_role,
    color_name: item.color_name,
    color_hex: item.color_hex,
    pattern: item.pattern,
    material: item.material,
    warmth: item.warmth,
    formality: item.formality,
    last_suggested_days: item.last_suggested_at ? daysBetween(item.last_suggested_at, ctx.today) : null,
    wear_count: item.wear_count,
    quantity: item.quantity,
    in_palette: inSeasonalPalette(item, ctx),
    score,
  };
}

/** Filter, score and take the top N per category with the §5.6 diversity constraints. Result ≤ 45 items, anchor always included. */
export function stageA(items: WardrobeItem[], ctx: PlanContext): Candidate[] {
  const realCounts = new Map<Category, number>();
  for (const it of items) if (!it.is_seed && !it.deleted && it.owned) realCounts.set(it.category, (realCounts.get(it.category) ?? 0) + 1);

  const anchor = ctx.anchorId ? items.find((i) => i.id === ctx.anchorId) : undefined;
  const anchorHex = anchor?.color_hex;
  const lightOnlyBanned = lightOnlyForbidden(ctx.wearWindow);

  const scored = items
    .filter((it) => passesHardFilters(it, ctx, realCounts.get(it.category) ?? 0))
    .map((it) => ({ item: it, score: scoreItem(it, ctx, anchorHex) }))
    .sort((a, b) => b.score - a.score);

  const byCategory = (c: Category) => scored.filter((s) => s.item.category === c);
  const n = taxonomy.stage_a_top_n;
  const picked: { item: WardrobeItem; score: number }[] = [];

  const take = (c: Category, count: number) => picked.push(...byCategory(c).slice(0, count));

  // Tops: top 8 with at least 2 base-layer-capable ones.
  const tops = byCategory("top");
  const chosenTops = tops.slice(0, n.top);
  const baseCapable = chosenTops.filter((t) => t.item.layer_role === "base").length;
  if (baseCapable < n.top_min_base_capable) {
    const extraBase = tops.filter((t) => t.item.layer_role === "base" && !chosenTops.includes(t)).slice(0, n.top_min_base_capable - baseCapable);
    for (const b of extraBase) {
      const idx = [...chosenTops].reverse().findIndex((t) => t.item.layer_role !== "base");
      if (idx >= 0) chosenTops.splice(chosenTops.length - 1 - idx, 1, b);
    }
  }
  picked.push(...chosenTops);

  take("bottom", n.bottom);
  take("one_piece", n.one_piece);
  take("mid_layer", n.mid_layer);
  take("outerwear", n.outerwear);
  take("shoes", n.shoes);
  take("bag", n.bag);

  // Jewelry: top 4 across ≥ 2 subcategories (rotates fifteen pairs of earrings instead of one).
  const jewelry = byCategory("jewelry");
  const chosenJewelry = jewelry.slice(0, n.jewelry);
  const subs = new Set(chosenJewelry.map((j) => j.item.subcategory));
  if (subs.size < n.jewelry_min_subcategories) {
    const other = jewelry.find((j) => !subs.has(j.item.subcategory));
    if (other && chosenJewelry.length > 0) chosenJewelry.splice(chosenJewelry.length - 1, 1, other);
  }
  picked.push(...chosenJewelry);
  take("accessory", n.accessory);

  if (anchor && !picked.some((p) => p.item.id === anchor.id)) picked.unshift({ item: anchor, score: scoreItem(anchor, ctx, anchorHex) });

  // When the minimum is below 8 °C, drop light-only clothing from the candidate set only if warmer alternatives exist in that category.
  const result = picked.filter((p) => {
    if (!lightOnlyBanned || p.item.warmth !== "light" || p.item.id === anchor?.id) return true;
    return !picked.some((q) => q.item.category === p.item.category && q.item.warmth !== "light");
  });

  return result.map((p) => toCandidate(p.item, ctx, p.score));
}
