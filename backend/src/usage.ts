// Local spend log and daily budget (ADR 0002). Append-only JSONL on the Mac; no database.
import { appendFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import priceTable from "../../shared/config/price_table.v1.json" with { type: "json" };
import type { Usage } from "./gemini/client.js";

export type UsageRow = {
  at: string; // ISO
  feature: "plan" | "attributes" | "look" | "cleanup" | "probe";
  model: string;
  tokens: Usage;
  images_out: number;
  image_size: string | null;
  cost_usd_est: number;
  latency_ms: number;
  price_table_version: number;
};

type ModelPrice = { input?: number; output?: number; image_out?: Record<string, number> };

/** Cost estimate from the versioned price table (USD per 1M tokens, USD per image). Unknown models cost 0 and are flagged. */
export function estimateCost(model: string, tokens: Usage, imagesOut = 0, imageSize: string | null = null): { cost: number; priced: boolean } {
  const p = (priceTable.models as Record<string, ModelPrice>)[model];
  if (!p) return { cost: 0, priced: false };
  const text = ((tokens.in - tokens.cached) * (p.input ?? 0) + tokens.cached * ((p as { cached_input?: number }).cached_input ?? (p.input ?? 0) * 0.1) + (tokens.out + tokens.thought) * (p.output ?? 0)) / 1e6;
  const perImage = imageSize && p.image_out ? (p.image_out[imageSize] ?? Object.values(p.image_out)[0] ?? 0) : p.image_out ? Object.values(p.image_out)[0] ?? 0 : 0;
  return { cost: text + imagesOut * perImage, priced: true };
}

export class UsageLog {
  private readonly file: string;
  constructor(dataDir: string) {
    if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });
    this.file = join(dataDir, "usage.jsonl");
  }

  record(row: Omit<UsageRow, "at" | "price_table_version">): UsageRow {
    const full: UsageRow = { at: new Date().toISOString(), price_table_version: priceTable.version, ...row };
    appendFileSync(this.file, JSON.stringify(full) + "\n");
    return full;
  }

  rows(): UsageRow[] {
    if (!existsSync(this.file)) return [];
    return readFileSync(this.file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l) as UsageRow);
  }

  /** Spend since local midnight. */
  spentToday(now = new Date()): { usd: number; calls: number } {
    const start = new Date(now); start.setHours(0, 0, 0, 0);
    const today = this.rows().filter((r) => new Date(r.at) >= start);
    return { usd: today.reduce((s, r) => s + r.cost_usd_est, 0), calls: today.length };
  }
}
