# backend — personal gateway

Runs on the Mac mini (ADR 0002). One process, one bearer token, Gemini behind a daily budget, no database. `scripts/run-mac.sh` starts it with a Cloudflare quick tunnel.

| Endpoint | What | Gemini model (`.env` override) |
|---|---|---|
| `GET /healthz` | liveness, whether a key is configured | — |
| `GET /v1/usage` | today's estimated spend vs `DAILY_BUDGET_USD` | — |
| `POST /v1/outfits/plan` | Stage B from client candidates; rules-only when no key | `GEMINI_PLAN_MODEL` |
| `POST /v1/items/attributes` | name a garment cutout the device could not | `GEMINI_ATTRIBUTES_MODEL` / `_ACCURATE_MODEL` |
| `POST /v1/looks` | try-on: your photo + ≤ 4 cutouts → one image | `GEMINI_IMAGE_MODEL` |
| `POST /v1/images/cleanup` | put a cutout on a clean white background | `GEMINI_IMAGE_LITE_MODEL` |

Usage is appended to `backend/data/usage.jsonl` (git-ignored) and costed from `shared/config/price_table.v1.json`; once the budget is reached every Gemini endpoint answers 429 until local midnight.

```sh
cp .env.example .env    # GEMINI_API_KEY, GATEWAY_TOKEN (openssl rand -hex 32)
npm install
npm run probe-models    # lists models visible to the key and checks the configured ids
npm start               # http://127.0.0.1:8787
npm test
```

Layout: `src/domain/` (Stage A, validator, combiner, colour), `src/planner/` (orchestration + Gemini planner), `src/gemini/` (client with retries/Flex fallback, image generation), `src/gateway/attributes.ts`, `src/server.ts`, `src/usage.ts`, `src/probeModels.ts`.
