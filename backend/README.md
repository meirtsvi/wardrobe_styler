# backend

`ai-gateway` (Cloud Run, TypeScript). PLAN §7. The worker (`image-worker`) is merged into this service until ~10k MAU (§7.1).

## Layout

| Path | Plan | What |
|---|---|---|
| `src/domain/` | §5.4, §5.6 | Stage A retrieval + scoring, validator, combiner, colour maths. Pure; no I/O. |
| `src/planner/planOutfits.ts` | §5.6 | Stage A → Planner → validator → one repair → combiner fallback. `Planner` is an interface; `CombinerPlanner` is the rule-only implementation. The Gemini planner is Phase 2. |
| `src/ledger/credits.ts` | §7.2, §9.2 | Two-bucket credit arithmetic (grant → purchased, refund, revoke, rollover, daily cap). |
| `src/jobs/createJob.ts` | §7.2 | Idempotent job creation in one Firestore transaction: key check → debit → `jobs/{id}` → `credit_ledger`. Job id = idempotency key = future Cloud Tasks task name. |
| `src/gateway/` | §7.2, §7.6 | Fastify server: auth (ID token + App Check, consumed on debit endpoints), `/v1/me`, `/v1/jobs`, `/v1/jobs/:id[/cancel]`, `/v1/outfits/plan`. |
| `src/prompts/registry.ts` | §5.19, §7.2 | Persona block, Stage B system prompt (renders `shared/rules/temperature.json`), structured user content. |
| `firestore.rules`, `storage.rules`, `firestore.indexes.json` | §7.4, §7.5 | Per-uid rules; server-only collections and fields. |

## Commands

```sh
npm install
npm run typecheck
npm test                 # pure unit tests
npm run test:emulator    # Firestore emulator (needs Java) — ledger, jobs, gateway contract tests
npm run emulators        # start Firestore/Auth/Storage emulators for local app work
GATEWAY_STATIC_AUTH=1 FIRESTORE_EMULATOR_HOST=localhost:8080 node --import tsx src/index.ts   # dev server (install tsx first)
```

Docker: `docker build -f backend/Dockerfile .` from the repo root.

## Not yet built (Phase 0 remainder, §11.1)

Cloud Tasks enqueue (task name = idempotency key) and queue sizing; per-user sliding-window rate limits; `price_table` costing of `usage_log` and the reconciliation job; budget ladder endpoint; RevenueCat webhook; account merge/delete; weather snapshot cache; the Gemini adapter (`@google/genai`) with retries/Flex fallback; promptfoo eval harness; 100-concurrent mock load test; the Firestore vector index (`gcloud firestore indexes composite create --collection-group=items --query-scope=COLLECTION --field-config=vector-config='{"dimension":"768","flat":"{}"}',field-path=embedding --field-config=order=ASCENDING,field-path=uid`).
