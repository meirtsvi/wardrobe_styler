// Executes shared/rules/temperature.json (PLAN.md §5.6). The same file is rendered as prompt text by renderTemperatureRulesText().
import rulesJson from "../../../shared/rules/temperature.json" with { type: "json" };
import type { Occasion, Warmth } from "./taxonomy.js";

export const temperatureRules = rulesJson;

export type WearWindow = {
  min_feels_like_c: number;
  max_feels_like_c: number;
  precip_prob_max: number; // percent 0–100
  wind_max?: number;
};

export type Band = (typeof rulesJson.bands)[number]["name"];

export function band(feelsLikeC: number): Band {
  for (const b of rulesJson.bands) {
    const min = "min_c" in b ? b.min_c : -Infinity;
    const max = "max_c" in b ? b.max_c : Infinity;
    if (feelsLikeC >= min && feelsLikeC < max) return b.name;
  }
  return rulesJson.bands[rulesJson.bands.length - 1]!.name;
}

export function spansTwoBands(w: WearWindow): boolean {
  return band(w.min_feels_like_c) !== band(w.max_feels_like_c);
}

const r = rulesJson.rules;

export function outerwearRequired(w: WearWindow): boolean {
  const rule = r.outerwear_required;
  return (
    w.min_feels_like_c < rule.min_feels_like_lt_c ||
    (w.precip_prob_max >= rule.or_precip.precip_prob_max_gte_pct && w.min_feels_like_c < rule.or_precip.min_feels_like_lt_c)
  );
}

export function outerwearAllowed(w: WearWindow, occasion: Occasion): boolean {
  const rule = r.outerwear_allowed;
  return outerwearRequired(w) || w.min_feels_like_c < rule.min_feels_like_lt_c || (rule.or_occasion_in as readonly string[]).includes(occasion);
}

export function outerwearForbidden(w: WearWindow, itemWarmth: Warmth): boolean {
  const rule = r.outerwear_forbidden;
  return w.max_feels_like_c >= rule.max_feels_like_gte_c && itemWarmth !== rule.unless_item_warmth;
}

export function midLayerAllowed(w: WearWindow): boolean {
  return w.min_feels_like_c < r.mid_layer_allowed.min_feels_like_lt_c;
}

export function baseLayerAllowedByTemperature(w: WearWindow): boolean {
  return w.min_feels_like_c < r.base_layer_allowed_by_temperature.min_feels_like_lt_c;
}

export function heavyForbidden(w: WearWindow): boolean {
  return w.max_feels_like_c > r.heavy_warmth_forbidden.max_feels_like_gt_c;
}

export function lightOnlyForbidden(w: WearWindow): boolean {
  return w.min_feels_like_c < r.light_only_forbidden.min_feels_like_lt_c;
}

export function isOpenShoe(subcategory: string): boolean {
  return (r.open_shoes_allowed.subcategories as readonly string[]).includes(subcategory);
}

export function openShoesAllowed(w: WearWindow): boolean {
  const rule = r.open_shoes_allowed;
  return w.min_feels_like_c >= rule.min_feels_like_gte_c && w.precip_prob_max < rule.precip_prob_max_lt_pct;
}

/** The rule table as prose for the Stage B system prompt, so prompt and validator share one source. */
export function renderTemperatureRulesText(): string {
  const bands = rulesJson.bands
    .map((b) => {
      if (!("min_c" in b)) return `${b.name} below ${b.max_c} °C`;
      if (!("max_c" in b)) return `${b.name} above ${b.min_c} °C`;
      return `${b.name} ${b.min_c}–${b.max_c} °C`;
    })
    .join(", ");
  const lines = Object.entries(r).map(([id, rule]) => `- ${rule.text} [${id}]`);
  return [
    `Temperature bands (feels-like): ${bands}.`,
    "Layering rules (evaluate required/allowed against the minimum feels-like of the wear window and forbidden against the maximum):",
    ...lines,
    "When the wear window spans two bands, say how the layers come off during the day in layering_note.",
  ].join("\n");
}
