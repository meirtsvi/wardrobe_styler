// Cloud Run entry point for ai-gateway. Firebase Admin uses ADC on Cloud Run; locally point FIRESTORE_EMULATOR_HOST at the emulator.
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { FirebaseVerifier, StaticVerifier } from "./gateway/auth.js";
import { buildServer } from "./gateway/server.js";
import { CombinerPlanner } from "./planner/planOutfits.js";

if (getApps().length === 0) initializeApp();

const useStaticAuth = process.env.GATEWAY_STATIC_AUTH === "1" && process.env.NODE_ENV !== "production";
if (useStaticAuth) console.warn("GATEWAY_STATIC_AUTH=1: static verifier in use (dev only)");

const app = buildServer({
  db: getFirestore(),
  verifier: useStaticAuth ? new StaticVerifier() : new FirebaseVerifier(),
  planner: new CombinerPlanner(), // TODO(phase 2): GeminiPlanner behind Remote Config model id
});

const port = Number(process.env.PORT ?? 8080);
app.listen({ port, host: "0.0.0.0" }).then(() => console.log(`ai-gateway listening on ${port}`));
