// Cloud Run entry point for ai-gateway. Firebase Admin uses ADC on Cloud Run; locally point FIRESTORE_EMULATOR_HOST at the emulator.
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { FirebaseVerifier, StaticVerifier } from "./gateway/auth.js";
import { buildServer } from "./gateway/server.js";
import { GeminiClient } from "./gemini/client.js";
import { GeminiPlanner } from "./planner/geminiPlanner.js";
import { CombinerPlanner } from "./planner/planOutfits.js";
import remoteConfig from "../../shared/config/remote_config.defaults.json" with { type: "json" };

if (getApps().length === 0) initializeApp();

const useStaticAuth = process.env.GATEWAY_STATIC_AUTH === "1" && process.env.NODE_ENV !== "production";
if (useStaticAuth) console.warn("GATEWAY_STATIC_AUTH=1: static verifier in use (dev only)");

// GEMINI_API_KEY is injected from Secret Manager on Cloud Run (PLAN §7.1); without it the gateway plans with rules only and
// reports attribute analysis as unavailable. Model ids come from Remote Config defaults until the Remote Config client is wired.
const apiKey = process.env.GEMINI_API_KEY;
const gemini = apiKey ? GeminiClient.fromApiKey(apiKey) : undefined;
if (!gemini) console.warn("GEMINI_API_KEY not set: rule-only planner, no attribute fallback");

const app = buildServer({
  db: getFirestore(),
  verifier: useStaticAuth ? new StaticVerifier() : new FirebaseVerifier(),
  planner: gemini ? new GeminiPlanner(gemini, { model: remoteConfig.models.plan }) : new CombinerPlanner(),
  ...(gemini ? { gemini: { client: gemini, models: { bulk: remoteConfig.models.attributes_bulk, accurate: remoteConfig.models.attributes_accurate } } } : {}),
});

const port = Number(process.env.PORT ?? 8080);
app.listen({ port, host: "0.0.0.0" }).then(() => console.log(`ai-gateway listening on ${port}`));
