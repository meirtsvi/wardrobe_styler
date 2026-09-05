// Deterministic rule-based combiner (PLAN.md §5.6: the fallback after a failed repair, and the "reused" daily tier). The card always renders.
import { accessoryLimits, type Slot } from "./taxonomy.js";
import { band, midLayerAllowed, outerwearAllowed, outerwearRequired, spansTwoBands } from "./temperature.js";
import { validateOutfit } from "./validator.js";
import type { Candidate, PlanContext, PlannedOutfit, PlannedSlot } from "./types.js";

function sorted(cands: Candidate[], category: string): Candidate[] {
  return cands.filter((c) => c.category === category).sort((a, b) => b.score - a.score);
}

function reason(slot: Slot, c: Candidate, ctx: PlanContext): string {
  const w = ctx.wearWindow;
  switch (slot) {
    case "outerwear":
      return `${c.warmth} layer for ${Math.round(w.min_feels_like_c)} °C`;
    case "mid_layer":
      return `mid layer for a ${band(w.min_feels_like_c)} start`;
    case "shoes":
      return `${c.color_name.replace(/_/g, " ")} ${c.subcategory.replace(/_/g, " ")} for ${ctx.occasion}`;
    default:
      return `${c.color_name.replace(/_/g, " ")} ${c.subcategory.replace(/_/g, " ")}, ${ctx.occasion}-ready`;
  }
}

function build(core: { slot: Slot; item: Candidate }[], cands: Candidate[], ctx: PlanContext): PlannedOutfit | null {
  const w = ctx.wearWindow;
  const slots: PlannedSlot[] = core.map(({ slot, item }) => ({ slot, item_id: item.id, reason: reason(slot, item, ctx) }));
  const used = new Set(core.map((c) => c.item.id));
  const add = (slot: Slot, item: Candidate | undefined) => {
    if (!item || used.has(item.id)) return;
    used.add(item.id);
    slots.push({ slot, item_id: item.id, reason: reason(slot, item, ctx) });
  };

  const shoes = sorted(cands, "shoes");
  add("shoes", shoes[0]);

  if (outerwearAllowed(w, ctx.occasion)) {
    const outer = sorted(cands, "outerwear").find((o) => !(w.max_feels_like_c >= 24 && o.warmth !== "light"));
    if (outer && (outerwearRequired(w) || w.min_feels_like_c < 15)) add("outerwear", outer);
  }
  if (midLayerAllowed(w) && w.min_feels_like_c < 15 && !slots.some((s) => s.slot === "outerwear")) add("mid_layer", sorted(cands, "mid_layer")[0]);

  const limits = accessoryLimits(ctx.accessoryCount);
  add("bag", sorted(cands, "bag")[0]);
  const jewelry = sorted(cands, "jewelry");
  const jewelSubs = new Set<string>();
  for (const j of jewelry) {
    if (jewelSubs.size >= Math.min(limits.jewelry, 2)) break;
    if (jewelSubs.has(j.subcategory)) continue;
    jewelSubs.add(j.subcategory);
    add("jewelry", j);
  }
  if (limits.accessory > 0) add("accessory", sorted(cands, "accessory")[0]);

  const colours = [...new Set(slots.map((s) => cands.find((c) => c.id === s.item_id)?.color_name.replace(/_/g, " ")).filter(Boolean))];
  const layering = spansTwoBands(w)
    ? `${Math.round(w.min_feels_like_c)}° early, ${Math.round(w.max_feels_like_c)}° later: shed the outer layer as it warms.`
    : null;
  const outfit: PlannedOutfit = {
    slots,
    rationale: `Rule-based pick: ${colours.slice(0, 3).join(", ")} for ${ctx.occasion}, ${Math.round(w.min_feels_like_c)}–${Math.round(w.max_feels_like_c)} °C.`,
    weather_fit: "acceptable",
    formality: core[0]?.item.formality ?? "casual",
    palette: colours.map(String),
    layering_note: layering,
    confidence: 0.5,
  };

  // Drop optional slots one by one until the validator passes.
  const optional: Slot[] = ["accessory", "jewelry", "bag", "mid_layer", "outerwear"];
  const byId = new Map(cands.map((c) => [c.id, c]));
  let result = validateOutfit(outfit, byId, ctx);
  for (const slot of optional) {
    if (result.passed) break;
    if (!result.rules_failed.some((r) => r.includes(slot))) continue;
    outfit.slots = outfit.slots.filter((s) => s.slot !== slot);
    result = validateOutfit(outfit, byId, ctx);
  }
  return result.passed ? outfit : null;
}

/** Try one-piece and top+bottom cores in score order; return the first outfit the validator accepts. */
export function combine(cands: Candidate[], ctx: PlanContext): PlannedOutfit | null {
  const anchor = ctx.anchorId ? cands.find((c) => c.id === ctx.anchorId) : undefined;
  const tops = sorted(cands, "top");
  const bottoms = sorted(cands, "bottom");
  const onePieces = sorted(cands, "one_piece");

  const cores: { slot: Slot; item: Candidate }[][] = [];
  const pushIfAnchorOk = (core: { slot: Slot; item: Candidate }[]) => {
    if (anchor && !core.some((c) => c.item.id === anchor.id) && ["top", "bottom", "one_piece"].includes(anchor.category)) return;
    cores.push(core);
  };
  for (const op of onePieces) pushIfAnchorOk([{ slot: "one_piece", item: op }]);
  for (const t of tops.slice(0, 4)) for (const b of bottoms.slice(0, 4)) pushIfAnchorOk([{ slot: "top", item: t }, { slot: "bottom", item: b }]);

  // Anchor in a non-core slot: force it into the candidate pool front so `add` picks it first.
  const pool = anchor ? [anchor, ...cands.filter((c) => c.id !== anchor.id)].map((c, i) => (i === 0 ? { ...c, score: Number.MAX_SAFE_INTEGER } : c)) : cands;

  for (const core of cores) {
    const outfit = build(core, pool, ctx);
    if (outfit) return outfit;
  }
  return null;
}
