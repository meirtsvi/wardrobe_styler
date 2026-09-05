// Stage B on Gemini (PLAN §5.6, ADR 0001: the remote fallback when the device model is unavailable or keeps failing validation).
import outfitSchema from "../../../shared/schemas/outfit_plan.schema.json" with { type: "json" };
import type { PlanResponse } from "../domain/types.js";
import type { GeminiClient, Usage } from "../gemini/client.js";
import { stageBSystemPrompt, stageBUserContent } from "../prompts/registry.js";
import type { Planner, PlannerCall } from "./planOutfits.js";

export type GeminiPlannerOptions = {
  model: string; // Remote Config `models.plan`
  thinkingLevel?: "LOW" | "MEDIUM";
  serviceTier?: "flex" | "standard";
  onUsage?: (u: { usage: Usage; model: string; tier: string; repair: boolean }) => void;
};

export class GeminiPlanner implements Planner {
  private readonly system = stageBSystemPrompt();
  constructor(private readonly client: GeminiClient, private readonly opts: GeminiPlannerOptions) {}

  async plan(call: PlannerCall): Promise<PlanResponse> {
    const user = stageBUserContent({ candidates: call.candidates, ctx: call.ctx, learnedRules: [] });
    const repair = call.violations && call.violations.length > 0;
    const parts = [
      `Plan ${call.n} outfit(s).`,
      user,
      ...(repair ? [`The previous answer violated these rules (index → rule ids): ${JSON.stringify(call.violations)}. Fix exactly those outfits and keep the rest.`] : []),
    ];
    const res = await this.client.generateJson<PlanResponse>({
      model: this.opts.model,
      systemInstruction: this.system,
      contents: parts.join("\n\n"),
      responseSchema: stripSchemaMeta(outfitSchema),
      thinkingLevel: this.opts.thinkingLevel ?? "LOW",
      temperature: 1.0,
      maxOutputTokens: 4096,
      ...(this.opts.serviceTier ? { serviceTier: this.opts.serviceTier } : {}),
    });
    this.opts.onUsage?.({ usage: res.usage, model: res.model, tier: res.tier, repair: !!repair });
    return normalise(res.data);
  }
}

/** Gemini rejects $schema/$id/$comment keys. */
export function stripSchemaMeta(schema: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(schema)) {
    if (k.startsWith("$")) continue;
    out[k] = v && typeof v === "object" && !Array.isArray(v) ? stripSchemaMeta(v as Record<string, unknown>) : v;
  }
  return out;
}

function normalise(data: PlanResponse): PlanResponse {
  const outfits = (data.outfits ?? []).map((o) => ({
    slots: (o.slots ?? []).map((s) => ({ slot: s.slot, item_id: String(s.item_id ?? ""), reason: String(s.reason ?? "").slice(0, 60) })),
    rationale: String(o.rationale ?? "").slice(0, 160),
    weather_fit: o.weather_fit ?? "acceptable",
    formality: o.formality ?? "casual",
    palette: Array.isArray(o.palette) ? o.palette.map(String) : [],
    layering_note: o.layering_note ? String(o.layering_note) : null,
    confidence: typeof o.confidence === "number" ? Math.max(0, Math.min(1, o.confidence)) : 0.5,
  }));
  return { outfits, anchor_honored: !!data.anchor_honored, anchor_reason: data.anchor_reason ?? null };
}
