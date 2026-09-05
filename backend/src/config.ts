// Configuration from .env (ADR 0002). Model ids default to the plan's; override in .env after `npm run probe-models`.
import "dotenv/config";

export type Config = {
  geminiApiKey: string | undefined;
  gatewayToken: string | undefined;
  dailyBudgetUsd: number;
  port: number;
  models: { plan: string; attributesBulk: string; attributesAccurate: string; image: string; imageLite: string };
  dataDir: string;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  return {
    geminiApiKey: env.GEMINI_API_KEY || undefined,
    gatewayToken: env.GATEWAY_TOKEN || undefined,
    dailyBudgetUsd: Number(env.DAILY_BUDGET_USD ?? 5),
    port: Number(env.PORT ?? 8787),
    models: {
      plan: env.GEMINI_PLAN_MODEL ?? "gemini-3.8-flash",
      attributesBulk: env.GEMINI_ATTRIBUTES_MODEL ?? "gemini-3.5-flash-lite",
      attributesAccurate: env.GEMINI_ATTRIBUTES_ACCURATE_MODEL ?? "gemini-3.8-flash",
      image: env.GEMINI_IMAGE_MODEL ?? "gemini-3.1-flash-image",
      imageLite: env.GEMINI_IMAGE_LITE_MODEL ?? "gemini-3.1-flash-lite-image",
    },
    dataDir: env.DATA_DIR ?? "data",
  };
}
