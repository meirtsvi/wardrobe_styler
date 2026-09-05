# Backend architecture for a wardrobe / AI-stylist iOS app on Gemini — options, pipeline, data model, costs (as of 2026-09-05)

## 0. Method, sources, confidence

WebSearch budget was already exhausted (200/200) when this task started, and Google/Apple/vendor doc hosts are egress-blocked. Every fact below therefore comes from one of these reachable, dated sources; anything else is marked **unconfirmed (memory)**.

| Source | What it gives | Local copy |
|---|---|---|
| `research/gemini-vision.md`, `research/gemini-image-gen.md`, `research/virtual-try-on.md` (sibling reports, 2026-09-05; they cite SDK source, cookbook, litellm) | model IDs, per-token/per-image prices, token math, Firebase AI Logic Swift surface, VTO constraints | same dir |
| BerriAI/litellm `model_prices_and_context_window.json` (entries cite ai.google.dev pricing) | Gemini prices | `research/litellm_prices.json` |
| firebase/firebase-functions `src/v2/providers/{https,tasks,options}.ts` (main, fetched 2026-09-05) | callable `enforceAppCheck`, `consumeAppCheckToken`, `heartbeatSeconds`, streaming; `onTaskDispatched` `rateLimits`/`retryConfig`; `concurrency`, `minInstances`, `secrets` | `research/backend/ff_*.ts` |
| firebase/firebase-ios-sdk `FirebaseAI/` (2026-09-04) + FirebaseAuth (GitHub code search) | `useLimitedUseAppCheckTokens`, `TemplateGenerativeModel`, `Auth.revokeToken(withAuthorizationCode:)` | `research/gh/firebase-ios-sdk` |
| googleapis App Check discovery docs (`firebaseappcheck.v1`/`v1beta`, via GitHub code search) | `limited_use`/`jti` replay protection, `verifyAppCheckToken` → `already_consumed`, supported service IDs incl. `firebaseml.googleapis.com` (Firebase AI Logic) | quoted below |
| googleapis/nodejs-firestore `dev/src/reference/{query,vector-query}.ts` | `findNearest` API: `limit` ≤ 1000, `COSINE`/`EUCLIDEAN`/`DOT_PRODUCT`, `distanceThreshold`, `distanceResultField` | `research/backend/firestore_*.ts` |
| firebase/extensions `delete-user-data/README.md` | account-deletion cascade | `research/backend/delete_user_data.md` |
| supabase/supabase `packages/shared-data/{plans,pricing}.ts`, docs `functions/limits.mdx`, `storage/uploads/file-limits.mdx`, `platform/compute-and-disk.mdx`, `manage-your-usage/*.mdx` (master, 2026-09-05) | plan quotas, overage prices, Edge Function limits, compute prices | `research/backend/supa_*` |
| superfly/docs `about/pricing.html.markerb` (main, 2026-09-05) | Fly egress, volumes, reservations, MPG note | `research/backend/fly_pricing.md` |
| PostHog/posthog.com `src/hooks/productData/product_analytics.tsx` | "1 million events free every month" | `research/backend/posthog_pa.tsx` |
| upstash/ratelimit-js README | sliding-window HTTP rate limiting pattern | `research/backend/upstash_ratelimit.md` |
| Third-party GitHub docs that transcribe Google Cloud prices "as of 2026" (pravinva/osipi-connector `GCP_DEPLOYMENT.md`, Project-Vizcaya/One-Vizcaya `COST.md`, yaalalabs/agent-kernel READMEs) | Cloud Run / Firestore / Storage / Functions list prices | quoted below, **medium** |

Confidence legend: **[high]** read in a primary source; **[medium]** third-party transcription or two agreeing secondaries; **[low]** memory, not re-verified today.

---

## 1. TL;DR recommendation

**Build option A′: Firebase for identity/data/storage/config + one Cloud Run service (Node/TypeScript or Python/FastAPI) as the only thing that ever talks to Gemini/Vertex/FASHN.** Do *not* let the client call Gemini through Firebase AI Logic for anything that costs more than ~$0.01 per call (image generation, try-on, cataloging); optionally use Firebase AI Logic only for text-only streaming chat if you accept project-level-only cost control. Reasons, in priority order:

1. **The economics force server-side metering.** At the stated usage profile the Gemini bill is ≈ **$0.9–1.8 per active user per month** (§8), i.e. $9k–18k/month at 10k MAU — more than plausible subscription revenue at that scale. Every image call must be gated by a server-side credit ledger, per-user rate limit and idempotency key. Firebase AI Logic has no per-user quota or budget mechanism (nothing in the SDK, App Check API, or changelogs — §2.2); it only protects against *non-app* callers.
2. **Half the features are server-only anyway**: Vertex `virtual-try-on-001` (OAuth/ADC only — `virtual-try-on.md` §1), `gemini-embedding-2`, Batch API, Files API, explicit context caches, verifier+retry loops, FASHN fallback — none exist in the Firebase AI Logic Swift SDK (`gemini-vision.md` §13).
3. **Firebase still wins for everything else** at 0→100k MAU: Sign in with Apple, Firestore (with native vector search), Cloud Storage, App Check, Remote Config + A/B Testing, Analytics/Crashlytics/FCM (all free), Cloud Tasks task-queue functions, and the delete-user-data extension for GDPR/App Store 5.1.1(v).
4. **Supabase (B)** is a good alternative if the team prefers SQL/pgvector; its blocker is Edge Functions (256 MB, 2 s CPU, no `sharp`) — you would still add a Cloud Run/Fly worker, so it is "B + C". **Pure custom (C)** is right only if you already run Postgres/Redis elsewhere or need EU-only vendors.
5. Put images behind a **zero-egress object store or CDN** — at 100k MAU image egress from GCS is the single largest non-AI line (~$2k/mo, §8).

Recommended concrete stack: Firebase Auth (Apple) · Firestore (`eur3` or `nam5`) · Cloud Storage for Firebase (+ lifecycle rules; consider R2/CDN for renders) · Cloud Run `ai-gateway` (TS, `@google/genai`, concurrency 80, min-instances 1, Secret Manager for the Gemini key) · Cloud Tasks queues per job class · Firestore vector search for "similar items" · Remote Config for model IDs/prompt versions/kill-switch · RevenueCat for subscriptions + paywall experiments · Firebase Analytics + PostHog · Crashlytics · Cloud Logging/Monitoring + Billing budgets.

---

## 2. Option A — Firebase-centric

### 2.1 Building blocks (what is verified)

| Piece | Verified facts | Conf. |
|---|---|---|
| **Firebase Auth – Sign in with Apple** | Standard provider. Apple requires token revocation on account deletion; the SDK has `Auth.auth().revokeToken(withAuthorizationCode:)` and `RevokeTokenRequest` ("Apple and authorization code are the only provider and token type we support for now") — firebase-ios-sdk `FirebaseAuth/Sources/Swift/Auth/Auth.swift`, `Backend/RPC/RevokeTokenRequest.swift`. | high |
| **Firestore** | Prices (third-party 2026 transcriptions agreeing): reads **$0.06/100k**, writes **$0.18/100k**, deletes **$0.02/100k**, storage **$0.18/GiB-mo**; free tier 50k reads / 20k writes / 20k deletes per day, 1 GiB. | medium |
| **Firestore vector search** | `collection.findNearest({vectorField, queryVector, limit, distanceMeasure: 'COSINE'|'EUCLIDEAN'|'DOT_PRODUCT', distanceResultField, distanceThreshold})`; "`limit` … must be a positive integer with a maximum value of 1000"; "Only documents whose vectorField is a VectorValue of the same dimension as queryVector participate" (nodejs-firestore `query.ts`). Requires a single-field vector index (`gcloud firestore indexes composite create --field-config vector-config='{"dimension":768,"flat":"{}"}'`); max dimension 2048 and pre-filters via `where` — **[low/memory]**. Each vector query bills reads for returned docs. Client SDKs (Swift) do not run vector queries — do it in the Cloud Run service with the Admin SDK. | high (API) / low (limits) |
| **Cloud Storage for Firebase** | $0.026/GB-mo stored, **$0.12/GB download** egress, 5 GB / 1 GB-per-day free (Vizcaya COST.md 2026 transcription). Storage Rules gate per-UID paths; resumable uploads from iOS; lifecycle rules for auto-delete. | medium |
| **Cloud Functions 2nd gen / Cloud Run** | Functions v2 *are* Cloud Run services. `options.ts`: `concurrency` default 80 when CPU ≥ 1 (max 1,000; must be 1 if cpu < 1), `minInstances` ("billed for memory allocation and 10% of CPU allocation" while idle), `maxInstances`, `timeoutSeconds`, `secrets` (Secret Manager binding), `cpu`. Cloud Run list prices (third-party 2026): **$0.000024/vCPU-s, $0.0000025/GiB-s, $0.40/M requests**, free 2M requests + 360k GiB-s/month. Cloud Functions invocations $0.40/M after 2M free. | high (API) / medium (prices) |
| **Callable functions + App Check** | `https.ts`: `enforceAppCheck?: boolean`, `consumeAppCheckToken?: boolean` ("Setting [enforceAppCheck] to true will cause the callable function" to reject missing/invalid tokens; consume = one-shot replay protection), `heartbeatSeconds` for long streaming responses, `CallableRequest.acceptsStreaming` (streaming callables via `response.sendChunk`). `invoker: "public"|"private"`. | high |
| **Cloud Tasks queue functions** | `tasks.ts`: `onTaskDispatched(opts, handler)` with `retryConfig {maxAttempts, minBackoffSeconds, maxBackoffSeconds, maxDoublings, maxRetrySeconds}` and `rateLimits {maxConcurrentDispatches, maxDispatchesPerSecond}`; enqueuer needs `roles/cloudtasks.enqueuer` + `roles/cloudfunctions.invoker`. Cloud Tasks price ≈ $0.40/M operations after 1M free **[low]**. | high / low |
| **App Check** | Service IDs App Check can protect include `firebaseml.googleapis.com` (Firebase AI Logic), Firestore, Storage, Auth (discovery doc). Limited-use tokens: "*Limited use* App Check tokens with the same `jti` will be counted as the same token for the purposes of replay protection"; `verifyAppCheckToken` returns `already_consumed` and "only supports … Play Integrity, App Attest, DeviceCheck, reCAPTCHA …". iOS SDK: `FirebaseAI.firebaseAI(backend:, useLimitedUseAppCheckTokens: true)` — "Migrating to limited-use tokens sooner minimizes disruption when support for replay protection" lands. Production providers: App Attest / DeviceCheck; debug provider only for dev (quickstart-ios README). No cost **[low]**. | high |
| **Remote Config / A/B Testing / Analytics / Crashlytics / FCM** | Free (Vizcaya table; general knowledge). Remote Config + Analytics power A/B Testing and personalization. | medium |
| **Delete User Data extension** | "Deletes data keyed on a userId from Cloud Firestore, Realtime Database, or Cloud Storage when a user deletes their account"; paths with `{UID}`, recursive mode, auto-discovery by field, optional search-function URL; Blaze required. | high |

### 2.2 Firebase AI Logic (client → Gemini without your own server): tradeoffs

What it gives you **[high]** (`gemini-vision.md` §13; SDK source): the Gemini key never ships (requests go to a Firebase proxy, `projects/{projectID}/models/{model}`), App Check attestation + limited-use tokens, Firebase Auth token forwarded, `generateContent`/streaming/chat/function calling/Google Search/URL context, Nano Banana image output, Server Prompt Templates (public preview: `templateGenerativeModel().generateContent(templateID:inputs:)`, also streaming and chat with history) so prompt text stays server-side, hybrid on-device Apple Foundation Models + Gemini, Blaze billing at Gemini API prices (Spark plan gets the free tier).

Gaps that matter for a paid consumer app:

| Gap | Evidence / reasoning | Severity |
|---|---|---|
| **No per-user quota, budget or credit metering** | Nothing in the Swift SDK, App Check API, Functions SDK or changelogs exposes per-UID limits for `firebaseml.googleapis.com`; limits are the project's Gemini API tier (RPM/TPM + the tier spend caps: Tier 1 ≈ $250/mo, $10 per rolling 10 min — RBT/devgraphics notes in `gemini-image-gen.md` §5, **medium**). One abusive or buggy client can spend the whole project budget; you cannot "charge credits" atomically because the call never passes through your code. Firestore-rule counters are racy and bypassable. | blocking for image features |
| **Abuse surface** | App Check raises the bar (App Attest on real devices) but a rooted/jailbroken device or a replayed/farmed token still hits your bill; limited-use tokens + replay protection help, but the replay-protection feature for AI Logic was still "upcoming" in the SDK comment. Google's own guidance is that App Check is not a guarantee **[low]**. | high |
| **Prompt secrecy** | Prompts in the binary are trivially extractable. Server Prompt Templates fix this but are *public preview*; template *inputs* (the user's wardrobe JSON) are still shaped client-side. | medium |
| **Missing APIs** | No embeddings, Files API, Batch (−50%), explicit caches, Interactions API, VTO/`recontext_image`, FASHN. | high |
| **Job semantics** | 10–30 s image generations run inside the app process; backgrounding kills them; no idempotency, no queue, no retry policy you control, no verifier/retry loop server-side. | high |
| **Observability** | No per-user prompt/usage log unless the client posts one; harder cost attribution and evals. | medium |
| **Model/prompt agility** | Model IDs and prompts change monthly (`gemini-2.5-flash-image` dies 2026-10-02; preview IDs died 2026-06-25) — you can drive IDs via Remote Config, but behaviour changes still need app releases. | medium |

**Where Firebase AI Logic is still a fine choice**: (a) text-only stylist chat streaming for signed-in users when you accept project-level caps and use `useLimitedUseAppCheckTokens: true` + Server Prompt Templates; (b) prototypes; (c) on-device/hybrid `GenerativeModelSession`. Even then, log usage to Firestore from the client and reconcile daily against the Cloud Billing export.

### 2.3 Firebase-centric shape that works (A′)

```
iOS (SwiftUI)                         Google Cloud project (== Firebase project)   External
────────────                          ──────────────────────────────────────────   ────────
Sign in with Apple ──► Firebase Auth ─┐
PHPicker / Camera                      │ ID token + App Check token on every call
 └─ HEIC→JPEG ≤1536px, Vision          │
    person/foreground masks,           ▼
    thumbnails, hashing        ┌──────────────────────────┐   Secret Manager (GEMINI_API_KEY,
                               │ Cloud Run  ai-gateway     │   FASHN_KEY) ── ADC SA → Vertex
Resumable upload ─────────────►│  /v1/jobs  (POST, idem-key)│───────────────► Gemini Developer API
  gs://bucket/u/{uid}/raw/…    │  /v1/chat  (SSE stream)   │   (3.8-flash, 3.5-flash-lite,
                               │  /v1/credits, /v1/me      │    3.1-flash-image, embedding-2)
Firestore listeners ◄──────────│  authz: verifyIdToken +   │───────────────► Vertex/Agent Platform
  jobs/{id}.status, items, …   │  verifyAppCheckToken      │   (virtual-try-on-001, EU region)
                               │  ratelimit + credit ledger│───────────────► FASHN / fal (fallback)
Remote Config (model ids,      │  prompt registry (versioned)
  prompt versions, kill switch)│  usage log (no pixels)    │
                               └────────────┬──────────────┘
                                            │ enqueue (Cloud Tasks queues:
                                            │  q-catalog, q-render, q-tryon, q-embed)
                                            ▼
                               ┌──────────────────────────┐
                               │ Cloud Run  image-worker   │  sharp/libvips: crop, normalize,
                               │  (task handler, 2 vCPU)   │  thumbs, WebP; writes derived
                               └────────────┬──────────────┘  objects + Firestore docs
                                            ▼
             Cloud Storage (raw: 24h lifecycle · derived: permanent) + CDN/R2 for reads
             Firestore (users, items, outfits, jobs, credits ledger, vectors)
             BigQuery (Analytics + Billing export) · Cloud Logging/Monitoring · Budgets → Pub/Sub → kill-switch fn
             Firebase Analytics/Crashlytics/FCM · PostHog (product analytics, flags) · RevenueCat (subs, paywalls)
```

Why one Cloud Run service instead of many Cloud Functions: the AI calls are long (5–30 s) and I/O-bound — a single 1 vCPU / 1 GiB instance with `concurrency: 80` waits on 80 Gemini calls at once, so compute is ~2 orders of magnitude cheaper than Functions gen-1-style concurrency 1; one deployable also makes SSE streaming, shared rate-limit state, and prompt registry simpler. Keep `image-worker` separate (CPU-bound sharp work, 2 vCPU, concurrency 4–8). Firebase Functions v2 can express both (they *are* Cloud Run), so either deploy path is fine; plain Cloud Run gives you a normal HTTP framework and easier local dev.

---

## 3. Option B — Supabase (Postgres + pgvector + Storage + Edge Functions) + worker

Verified plan facts (supabase/supabase `packages/shared-data/plans.ts`, `pricing.ts`, docs, fetched 2026-09-05) **[high]**:

| Item | Free | Pro ($25/mo org, "Includes one project running on Micro compute") |
|---|---|---|
| MAU (users who sign in or refresh a token in the cycle) | 50,000 | 100,000 included, then **$0.00325/MAU**; third-party (Apple) MAUs same |
| Database | 500 MB, shared CPU/500 MB RAM (Nano) | 8 GB disk included, then $0.125/GB; compute add-ons: Micro $0.01344/h (~$10), Small ~$15, Medium ~$60, Large ~$110 (8 GB, 2 dedicated cores), XL ~$210, 2XL ~$410 |
| Egress | 5 GB + 5 GB cached | 250 GB uncached (then **$0.09/GB**) + 250 GB cached via Smart CDN (then **$0.03/GB**) |
| File storage | 1 GB, 50 MB max file | 100 GB included, then **$0.0213/GB**; max file 500 GB; image transformations 100 origin images incl., then $5/1,000 |
| Edge Function invocations | 500,000 | 2 M included, then **$2 per 1 M** (billed in 1 M packages) |
| Backups/logs | — | daily backups 7 d, 7-day log retention; PITR $100/mo per 7 days; log drains $60/drain |
| Team plan | — | $599/mo (SOC2/ISO, SSO) |

Edge Function runtime limits (docs `functions/limits.mdx`) **[high]**: **256 MB memory, 2 s CPU time per request, 400 s wall clock on paid (150 s free), 150 s request idle timeout (504)**, "Node Libraries that require multithreading are not supported. Examples: libvips, sharp", no Web Workers, 100 secrets/project.

Implications:
- Edge Functions are fine as the thin **Gemini proxy** (I/O-bound waits do not count toward the 2 s CPU limit; 400 s wall clock covers Nano Banana Pro) and for SSE streaming; they are **not** fine for the image pipeline (decode/crop/resize/WebP would blow 2 s CPU and can't use sharp). Do pixel work on-device (recommended anyway) or in a separate worker (Fly Machine / Cloud Run) — so B is really "B + C-worker".
- Postgres + pgvector gives real relational modelling (outfits ↔ items, ledgers with constraints, SQL analytics) and HNSW indexes (`<=>` cosine); Supabase docs warn that IVFFlat/HNSW + naive `WHERE` filters can return fewer rows than requested — use iterative scans or `hnsw.ef_search`. Row Level Security replaces Firestore rules.
- Auth: Sign in with Apple supported (third-party MAU pricing line). Realtime replaces Firestore listeners for job status.
- Region choice at project creation (EU regions available) is a genuine GDPR plus.
- Cost at 10k MAU ≈ $25 + Small/Medium compute ($15–60) + storage (~650 GB → ~$12) + cached egress (2 TB → ~$52) + invocations (3 M → $2) ≈ **$110–150/mo**; at 100k MAU ≈ $25 + Large/XL ($110–210) + storage (6.5 TB → ~$136) + cached egress (20 TB → ~$600) + invocations (30 M → $56) + worker ≈ **$950–1,100/mo + worker ($50–200)**. (Traffic assumptions in §8.) **medium**.

## 4. Option C — Custom FastAPI/Node on Cloud Run or Fly.io + Postgres + S3/R2 + queue

- **Cloud Run** prices as in §2.1 (medium). A 1 vCPU/1 GiB service with `--concurrency 80 --min-instances 1` ≈ $60–75/mo always-on (2.6 M s × $0.000024 + 1 GiB × 2.6 M s × $0.0000025 ≈ $63 + $6.5; idle CPU-throttled instances are cheaper — **low**). Request-driven cost at 10k MAU (≈3 M AI + API calls, 15 s avg, concurrency 80) is a few dollars. Cloud Run Jobs or a second service for the worker.
- **Fly.io** (superfly/docs pricing page, 2026-09-05) **[high]**: Machines billed per preset + ~$5/30 d per extra GB RAM; stopped Machines $0.15/GB rootfs/30 d; volumes $0.15/GB-mo; snapshots $0.08/GB-mo (first 10 GB free, charged from 2026-01-01); egress **$0.02/GB (NA/EU)**, $0.04 APAC, $0.12 Africa/India; dedicated IPv4 $2/mo; 40% discount for reserved blocks ($36/yr → $5/mo shared credits; $144/yr → $20/mo performance credits); Managed Postgres priced separately ("lives outside your apps"); unmanaged Fly Postgres 3-node ≈ $82–164/mo; support plans $29/$199/$2,500. Preset prices (e.g. `shared-cpu-1x` 256 MB ≈ $1.94/mo, `performance-1x` 2 GB ≈ $31/mo) are rendered by a partial not in the public repo — **unconfirmed (memory)**.
- **Object storage**: Cloudflare R2 ≈ $0.015/GB-mo, **zero egress**, Class A $4.50/M, Class B $0.36/M **[low]** — the reason to prefer R2 (or Tigris on Fly, which bills egress via Fly at $0.02/GB) for render/thumbnail delivery at 100k MAU (§8).
- **Queue**: Cloud Tasks (HTTP target, per-queue `maxDispatchesPerSecond`/`maxConcurrentDispatches`, retry policy; the same knobs as §2.1) or Redis (BullMQ / Upstash QStash). **Rate limiting**: Upstash `@upstash/ratelimit` "connectionless (HTTP based)… `Ratelimit.slidingWindow(10, "10 s")`… use a userID, apiKey or ip address for individual limits" (README) — works from Cloud Run, Fly, Edge Functions alike.
- **Postgres**: Neon/Supabase/Cloud SQL/Fly MPG + pgvector.
- Cost at 10k MAU ≈ $130–250/mo (2 small app machines + managed Postgres $40–80 + R2 $10–20 + Redis $10); at 100k ≈ $500–900/mo. **medium-low**. You own auth (or still use Firebase Auth/Supabase Auth), push, analytics wiring, and ops.

## 5. Option D — AI-gateway patterns (apply to A′/B/C alike)

| Concern | Pattern | Notes / evidence |
|---|---|---|
| **AuthN/AuthZ** | Every request carries Firebase ID token + App Check token; gateway calls `verifyIdToken` and `verifyAppCheckToken` (Admin SDK; `consume: true` for credit-spending endpoints → `alreadyConsumed`). | App Check API `already_consumed` semantics **[high]**. |
| **Per-user rate limiting** | Two layers: (1) sliding window per UID per endpoint in Redis/Upstash (e.g. chat 20/min, jobs 10/min, 200 AI calls/day); (2) queue-level `rateLimits.maxDispatchesPerSecond` per job class to stay under the Gemini project RPM/spend caps. Return 429 with `Retry-After`; log every 429 per UID for abuse scoring. | Firebase Tasks `RateLimits` **[high]**; Upstash pattern **[high]**. |
| **Credit metering** | Firestore transaction (or Postgres `UPDATE … WHERE balance >= cost RETURNING`) that (a) checks `idempotency_key` not seen, (b) debits `cost_credits`, (c) creates the `jobs/{id}` doc — atomically. Refund on terminal failure (`SAFETY`, provider 5xx after retries). Ledger is append-only (`credit_ledger`), balance is a materialized field. Price list in Remote Config (e.g. photo=1, outfit-preview=2, try-on=5 credits). | Design; RevenueCat webhooks grant credits on renewal. |
| **Idempotency keys** | Client generates UUIDv7 per user action and stores it locally; `POST /v1/jobs` with `Idempotency-Key` returns the existing job if seen (24 h TTL). Same key is reused for the Cloud Task name → Cloud Tasks de-duplicates. | Cloud Tasks task-name dedupe **[low]**. |
| **Retries/backoff** | Retry Gemini on 408/429/500/502/503/504 (cookbook `Error_handling`, `gemini-vision.md` §7) with exponential backoff + full jitter (0.5 s → 8 s, max 3–4 attempts), honour `Retry-After`; Flex tier 503 → fall back to standard; NB Pro slow → move to `q-render-slow` queue; never retry `SAFETY`/`IMAGE_SAFETY`/`PROHIBITED_CONTENT`. Queue-level `retryConfig` handles worker crashes. | **[high]** for status list. |
| **Streaming chat** | `POST /v1/chat` → `text/event-stream`; gateway consumes `generateContentStream` and forwards `delta`, `usage`, `grounding`, `done` events; heartbeat every 15 s. Cloud Run supports HTTP/1.1 chunked streaming; Firebase callable streaming uses `response.sendChunk` + `heartbeatSeconds` and the iOS `Functions` SDK `stream()` API **[medium]**. Persist the final message server-side (client may disconnect). | Functions `https.ts` **[high]**. |
| **Prompt versioning** | `prompts/{name}/versions/{n}` docs (template, model, config, schema, changelog); each usage log records `prompt_version`; Remote Config pins the active version per feature and per cohort (A/B). Firebase Server Prompt Templates are the managed equivalent (preview). | |
| **Evals** | promptfoo (has a Gemini image provider, `gemini-image-gen.md` §12) over a golden set of ~200 wardrobe photos with labelled attributes + 50 try-on pairs; metrics: attribute accuracy per field, JSON-schema validity, refusal rate, verifier pass rate, p50/p95 latency, cost/call; run on every prompt/model change; sample 1% of production jobs (with consent) into the eval set. | |
| **Logging without pixels** | Log: uid hash, job id, prompt version, model, `usage_metadata` (prompt/candidate/thought/cached tokens), finish/block reason, latency, cost estimate, image *hashes* and dimensions — never bytes or base64. Raw uploads live in a bucket with a 24 h lifecycle delete; derived cutouts/thumbnails are user data (deleted with the account). Keep Cloud Logging at 30 d; export cost rows to BigQuery. | |
| **Cost caps & alerts** | (1) Gemini tier spend caps (Tier 1 ≈ $250/mo) as a hard backstop — request Tier 2/3 before launch; (2) Cloud Billing budget with Pub/Sub → Cloud Function that flips Remote Config `ai_kill_switch` and pauses Cloud Tasks queues at 100%; (3) per-user daily hard cap (e.g. 300 credits) independent of balance; (4) `maxInstances` on Cloud Run; (5) daily reconciliation: sum(usage log cost) vs Billing export; alert if drift > 10%. | Budgets are alerts, not hard stops **[low]**. |
| **Abuse** | Age gate (18+ for try-on), App Check enforced on Firestore/Storage/Functions/AI Logic, per-device new-account velocity, refuse >N photos with no face/garment (cheap `gemini-3.5-flash-lite` gate or on-device Vision), block-list of UIDs, disable API key rotation drills. | |

Managed gateways (LiteLLM proxy budgets/virtual keys, Portkey, Helicone) add per-key budgets and logging but not per-*end-user* auth; they are useful once you run multiple providers (Gemini + FASHN + fal) — **medium**, docs not fetched (LiteLLM docs paths 404'd under the guessed names).

---

## 6. Image processing pipeline (wardrobe photo → catalogued item → embeddings)

Model IDs/prices per `gemini-vision.md` §11/§14 and `gemini-image-gen.md` §4 (litellm-derived, **medium**; token math **high**).

```
 on-device (iOS, free, private)                       │ cloud (Cloud Run + Gemini)
 ─────────────────────────────                        │ ───────────────────────────
 1 PHPicker/Camera → HEIC/JPEG                        │
 2 downscale long edge 1536 px, JPEG q0.85 (~250 KB)  │
   strip EXIF GPS, keep orientation; sha256           │
 3 Vision: VNGenerateForegroundInstanceMask /         │
   VNDetectHumanRectangles → "single garment?"        │
   quick gate, provisional cut-out + 512px thumb      │
 4 upload raw+mask (resumable) → gs://…/raw/{uid}/{sha}│
 5 POST /v1/jobs {type:"catalog", idem, object}  ─────►  6 debit credits, enqueue q-catalog
                                                       │  7 detect: gemini-3.8-flash, JSON schema
                                                       │    [{box_2d,label}] MEDIA_RESOLUTION_MEDIUM
                                                       │    (560 tok), thinking MINIMAL, temp 0.5
                                                       │  8 crop each box (sharp) → per-item crops
                                                       │  9 background: prefer device mask (step 3);
                                                       │    if mask coverage/IoU with box < 0.6 →
                                                       │    gemini-3.7-flash segmentation mask
                                                       │    (PNG prob map) → feather → composite on
                                                       │    white/transparent; generative cleanup
                                                       │    (gemini-3.1-flash-lite-image) only on
                                                       │    user tap "clean up" ($0.034)
                                                       │ 10 normalize: 1024² canvas, pad 8%, sRGB,
                                                       │    WebP q80 + 256px thumb + dominant colors
                                                       │ 11 attributes: gemini-3.5-flash-lite (bulk)
                                                       │    or 3.8-flash (brand/material), response_
                                                       │    json_schema + enums + propertyOrdering,
                                                       │    MEDIUM res, thinking MINIMAL
                                                       │ 12 embed: gemini-embedding-2 (image + caption
                                                       │    → one 3072-d vector, store 768-d truncation)
                                                       │ 13 write items/{id}, images/{id}, vector;
 14 Firestore listener → UI shows item  ◄─────────────    job.status=done; push if app backgrounded
```

**Structured attribute schema** (JSON mode; keep enums small so Flash-Lite is reliable):
`{category: enum[top,bottom,dress,outerwear,shoes,bag,accessory,jewelry,swim,underwear,other], subcategory: string, primary_color: string, color_hex: string, secondary_colors: string[], pattern: enum[solid,stripe,check,floral,graphic,animal,dot,abstract,other], material: enum[cotton,denim,wool,knit,leather,silk,linen,synthetic,unknown], fit: enum[slim,regular,relaxed,oversized], length: string, season: enum[]…, formality: enum[casual,smart_casual,business,formal,athletic], occasions: string[], brand_guess: string|null, brand_confidence: number, condition_notes: string, box_2d: int[4]}` with `propertyOrdering` = category → colors → pattern → material → fit → season → formality → brand.

**Cost per wardrobe photo** (standard tier; batch/flex −50%):

| Step | Model / method | Tokens | Cost |
|---|---|---|---|
| Detect boxes | `gemini-3.8-flash`, MEDIUM 560 in + ~150 out | $0.00042 + $0.00056 | **$0.0010** (HIGH res: $0.0016) |
| Segmentation mask (fallback, ~20% of photos) | `gemini-3.7-flash`, 560 in + ~1,500 out (mask base64) | $0.00042 + $0.0056 | $0.006 × 0.2 = **$0.0012** blended |
| Attributes (per item; 1.3 items/photo) | `gemini-3.5-flash-lite`, 560 in + ~250 out JSON | $0.00017 + $0.00063 | **$0.0010** (3.8-flash: $0.0018) |
| Embedding | `gemini-embedding-2`, 1 image + 60 tok caption | $0.00012 + ~$0.00001 | **$0.00013** |
| Generative cutout (optional) | `gemini-3.1-flash-lite-image` 1K | per image | $0.0336 (NB2 512px: $0.045) |
| **Total, device masks** | | | **≈ $0.003–0.004** |
| **Total, always-generative cutout** | | | ≈ $0.04 (10× more — avoid by default) |
| Pixel ops (sharp on Cloud Run, ~1.5 s CPU) | | | ≈ $0.00004 |

**Latency budget** (p50 targets; Gemini figures are third-party, `gemini-image-gen.md` §5): on-device prep + upload 1–2 s → detect 1.5–3 s → crop/normalize 0.5 s → attributes 1–2 s (parallel per item) → embed 0.5 s → **≈ 4–7 s to "item ready"**; show the on-device provisional cut-out immediately at step 3 so perceived latency is ~1 s. Bulk import (≥20 photos): Batch API queue, results within hours at −50%.

**Outfit generation** (VoiceDress: occasion → one look, on-body): (1) text plan with `gemini-3.8-flash`, thinking LOW, wardrobe summary ≈ 5–20k tokens (implicit caching; explicit cache only for long sessions — storage $/token-hour unconfirmed), tools = weather function call → ≈ $0.004; (2) preview render `gemini-3.1-flash-image` 512 px, 4:5, refs = person twin + ≤5 garments → $0.045 + ~$0.004 inputs; (3) full look 1K on tap → $0.067; Pro for "share/export" $0.134. Latency: plan 2–4 s, 512 render 4–8 s, 1K 8–15 s, Pro 15–30 s → queue + push for Pro.

**Try-on** (`virtual-try-on.md` §9): default NB2 1K with verifier (`gemini-3.8-flash`, 2 images HIGH ≈ $0.002) + one retry (20%) ≈ **$0.09**; Pro ≈ $0.16; FASHN `tryon-v1.6` $0.075 (5–17 s); Vertex `virtual-try-on-001` price **unconfirmed** (not on public pricing page per truefoundry) — tops/bottoms/shoes only, one garment per call, OAuth from Cloud Run with EU region option.

**On-device vs cloud split**: on-device = capture guidance (pose/person checks), HEIC decode, resize, EXIF strip, hashing, provisional masks/thumbnails, local cache of derived images, optional Apple Foundation Models for offline small talk; cloud = everything that needs Gemini/Vertex/FASHN, canonical derived assets, embeddings/vector search, credit/ledger, prompt registry.

---

## 7. Data model

Written as Postgres-flavoured tables; Firestore mapping: top-level collections `users`, `items`, `outfits`, `lookbooks`, `calendar`, `chats` (+ subcollection `messages`), `tryons`, `jobs`, `ledger`, `subscriptions`, `picks`, `prompts` — every user-owned doc carries `uid` for rules and for the delete-user-data extension (`{UID}` paths or auto-discovery on field `uid`).

```
users            (id=uid, apple_sub, email_hash, display_name, locale, region, dob_bucket|age_verified bool,
                  consent {photos_cloud, analytics, marketing, at}, style_profile_id, credits_balance int,
                  plan enum[free,plus,pro], flags jsonb, created_at, deleted_at)
style_profile    (id, uid, body {height_cm, sizes jsonb}, palette_prefs, disliked_tags[], twin_image_id,
                  twin_generated_at, quiz jsonb, summary_text (≤2k tok, fed to prompts), embedding vec(768))
items            (id, uid, category, subcategory, colors jsonb, color_hex, pattern, material, fit, season[],
                  formality, occasions[], brand_guess, brand_confidence, attrs_prompt_version, source
                  enum[photo,shopping_import,manual], wear_count, last_worn_on, favorite, archived,
                  embedding vec(768) [Firestore: VectorValue], created_at, updated_at)
item_images      (id, item_id, uid, kind enum[raw,cutout,normalized,thumb,twin], storage_path, width, height,
                  bytes, sha256, mask_source enum[device,gemini_seg,generative,none], expires_at, created_at)
outfits          (id, uid, title, occasion, weather jsonb, generated_by {model, prompt_version, job_id}|null,
                  rationale_text, preview_image_id, render_image_id, status enum[draft,saved,worn,rejected],
                  rating smallint, created_at)
outfit_items     (outfit_id, item_id, slot enum[top,bottom,dress,outer,shoes,bag,accessory], position)
lookbooks        (id, uid, name, cover_image_id, is_public bool, share_token, created_at)
lookbook_outfits (lookbook_id, outfit_id, position)
calendar_entries (id, uid, date, outfit_id, occasion, location, weather_snapshot jsonb, reminder_at, worn bool)
chat_sessions    (id, uid, title, context_kind enum[stylist,outfit,shopping], cache_name|null, cache_expires_at,
                  prompt_version, model, token_totals jsonb, created_at, last_message_at)
chat_messages    (id, session_id, uid, role enum[user,model,tool], parts jsonb (text, image refs, function calls,
                  thought_signature), grounding jsonb|null, usage jsonb, latency_ms, created_at)
tryon_results    (id, uid, job_id, person_image_id, item_ids[], outfit_id|null, provider enum[nb2,nb_pro,vertex_vto,
                  fashn], model_id, output_image_id, verifier jsonb {passed, reasons}, retries, safety_reason|null,
                  cost_usd_est, created_at, expires_at)
jobs             (id, uid, type enum[catalog,segment,outfit_plan,render,tryon,embed,twin], idempotency_key UNIQUE,
                  status enum[queued,running,done,failed,refunded], input jsonb (storage paths, params), result jsonb,
                  error {code, retryable}, attempts, credits_charged, cost_usd_est, prompt_version, model_id,
                  queue, created_at, started_at, finished_at)
credit_ledger    (id, uid, delta int, reason enum[grant_signup,grant_renewal,purchase,job_debit,refund,admin],
                  ref_id (job_id|transaction_id), balance_after, created_at)      -- append-only
subscriptions    (uid, provider enum[revenuecat,storekit], product_id, entitlement, status, period_start, period_end,
                  original_transaction_id, auto_renew bool, updated_at)          -- mirrored from RC webhooks
shopping_picks   (id, uid, query, source enum[google_search,retailer_feed], title, brand, price, currency, url,
                  image_url, item_gap enum[...], outfit_id|null, embedding vec(768), clicked_at, dismissed_at)
usage_log        (id, uid_hash, job_id|session_id, feature, model_id, prompt_version, tokens {in,out,thought,cached},
                  images_in, images_out, search_queries, cost_usd_est, finish_reason, latency_ms, created_at)
prompts          (name, version, model_default, template, config jsonb, response_schema jsonb, changelog, created_at)
```

Notes: store embeddings truncated to 768-d (Matryoshka) to keep Firestore docs small (768 × 8 B ≈ 6 KB) and pgvector HNSW fast; keep `items` reads cheap by keeping heavy fields (`attrs_raw`, model rationale) in `item_details/{id}`; wardrobe summary for prompts is derived (`users.wardrobe_summary_text`, regenerated on item change) so chat prompts stay ≈ 3–8k tokens.

---

## 8. Cost model per 1,000 active users/month at the stated usage (30 wardrobe photos, 20 outfit generations, 50 chat messages, 5 try-ons)

Gemini prices: litellm snapshot 2026-09-05 citing ai.google.dev pricing (`gemini-vision.md` §11, `gemini-image-gen.md` §4) — **medium**; verify on ai.google.dev/pricing before budgeting.

| Feature (per user/month) | Unit cost | Qty | $/user | $/1k users |
|---|---|---|---|---|
| Wardrobe photo pipeline (device masks, 20% Gemini seg fallback, Flash-Lite attrs, embedding) | $0.0035 | 30 | $0.105 | **$105** |
| Outfit generation — plan only (3.8-flash text, weather via function call) | $0.004 | 20 | $0.08 | $80 |
| Outfit generation — + 512 px NB2 preview render | $0.049 | 20 | $0.98 | **$980** (batch/off-peak: ~$490) |
| Stylist chat message (3.8-flash, thinking LOW, ~3k ctx, 20% search-grounded @ $0.014) | $0.006 | 50 | $0.30 | **$300** |
| Try-on (NB2 1K + verifier + 20% retry) | $0.09 | 5 | $0.45 | **$450** (Pro: $800; FASHN: $375; Vertex VTO: unconfirmed) |
| Embedding/search maintenance, twin regeneration (Pro, 1/quarter) | — | — | ~$0.05 | $50 |
| **Gemini total, text-only outfits** | | | **≈ $0.98** | **≈ $985** |
| **Gemini total, rendered outfit previews** | | | **≈ $1.88** | **≈ $1,885** |
| Free-tier profile (10 photos, 3 previews, 10 chats, 1 try-on) | | | ≈ $0.32 | ≈ $320 |

Infrastructure (excluding Gemini), per month, **medium/low** confidence, assumptions: ~300 API calls/user, 1,000 Firestore reads + 300 writes/user, 65 MB stored/user (100 items × 0.5 MB + 3 months of renders), 200 MB image downloads/user:

| Line | Option A′ (Firebase + Cloud Run) 10k MAU | 100k MAU | Option B (Supabase Pro + worker) 10k | 100k | Option C (Fly/Cloud Run + Neon + R2) 10k | 100k |
|---|---|---|---|---|---|---|
| Auth | $0 (Firebase Auth OAuth providers free; Identity Platform tiers not needed) [low] | $0 | $0 (≤100k MAU incl.) | $0–325 | Firebase Auth $0 / Supabase Auth | same |
| Database | Firestore ≈ $10 (10 M reads $6, 3 M writes $5, 8 GB $1.4 minus free) | ≈ $100 | Small–Medium compute $15–60 | Large–XL $110–210 (+ read replica) | Neon/Cloud SQL $20–70 | $150–400 |
| Object storage | GCS 650 GB ≈ $17 | 6.5 TB ≈ $170 | 650 GB ≈ $12 | 6.5 TB ≈ $136 | R2 650 GB ≈ $10 | ≈ $100 |
| Image egress | 2 TB × $0.12 ≈ **$240** (or ~$80–120 with Cloud CDN; ~$0 via R2) | 20 TB ≈ **$2,400** (CDN ~$1k; R2 ~$0) | 2 TB cached × $0.03 ≈ $52 | 20 TB ≈ $600 | Fly $0.02/GB ≈ $40 or R2 $0 | $400 or $0 |
| Compute (gateway + worker) | Cloud Run ≈ $70–120 (1 min-instance + worker bursts) | ≈ $300–600 | Edge Functions $2 + worker $30–70 | $56 + $150–300 | 2× perf-1x ≈ $62 + worker $30 | $250–500 |
| Queue / cache / secrets / logs | Cloud Tasks + Secret Manager + Logging ≈ $5–20 | $50–150 | Upstash/Redis ≈ $10 | $50 | Upstash ≈ $10 | $50 |
| Plan fee | $0 (Blaze) | $0 | $25 | $25 (+$599 Team if SOC2 needed) | $0 | $0 |
| **Infra total** | **≈ $350–420** (≈ $130–200 with R2/CDN) | **≈ $3,000–3,500** (≈ $700–1,200 with R2/CDN) | **≈ $150–230** | **≈ $1,100–1,700** | **≈ $170–250** | **≈ $900–1,500** |
| Analytics/crash/flags | Firebase Analytics/Crashlytics/Remote Config $0; PostHog ≤1 M events free | PostHog ≈ 30–50 M events → ~$0.5–1.5k [low] | same | same | same | same |
| Subscriptions | RevenueCat free to $2.5k MTR then ~1% of MTR [low] | ~1% MTR | same | same | same | same |

Takeaways: Gemini spend (≈ $1–2 per *heavy* active user) dwarfs infrastructure at every scale; the only infra line that matters is image egress, which is why A′ should serve images through Cloud CDN or R2 rather than raw GCS download egress. Blended MAU cost will be far lower than the "typical usage" figure because most MAU are light; budget on cohorts (free ≈ $0.3, paid ≈ $1–2) and enforce them with credits.

---

## 9. Auth, privacy, residency

- **Sign in with Apple**: Firebase Auth provider; on account deletion call `revokeToken(withAuthorizationCode:)` (Apple App Store requirement) then delete the Firebase user → Delete User Data extension purges Firestore paths (`users/{UID}`, `items` by field `uid` via auto-discovery), Storage prefixes (`{DEFAULT}/u/{UID}`), plus a search-function URL hook for anything else; also purge vector docs, RevenueCat alias, PostHog person (API), and BigQuery exports (scheduled query). App Store Guideline 5.1.1(v) account deletion in-app (`virtual-try-on.md` §7).
- **GDPR/CCPA**: lawful basis = contract for wardrobe processing; explicit consent screen for body photos/try-on (Art. 9-adjacent sensitivity, not biometric unless used for identification — never run face recognition); DPAs: Google Cloud/Firebase DPA (paid Gemini API = Cloud DPA terms per `gemini-vision.md` §12, **low**), Supabase DPA, RevenueCat, PostHog (EU cloud available — **low**). Data-subject export = JSON of the tables in §7 + signed URLs.
- **Photo deletion**: raw uploads auto-delete after 24 h (bucket lifecycle); try-on person photos are ephemeral unless the user opts in to a stored "twin"; every derived image has an `expires_at`; generated try-ons expire after 30–90 days unless saved; App Check + per-UID Storage rules; signed URLs (15 min) for reads.
- **Gemini data use** (`gemini-vision.md` §12, **low**): use a billing-enabled (paid) project from day one — free-tier prompts may be used to improve Google products; paid tier is not, subject to limited abuse-monitoring logs. Interactions API `store: false` where used (`gemini-image-gen.md` §3b).
- **EU data residency**: Gemini Developer API has no location selector (global) — **[high]** that none exists in SDK/Firebase; Vertex/Agent Platform supports regional endpoints (Firebase JS tests encode `agentplatform/europe-west1`; default is `global`; "most new Gemini models do not support us-central1" — changelog) and Google's Vertex model pages list "ML processing: Europe multi-region" for some models (mirrored docs, `research/gh/radar_vto_preview.md`); which EU regions host Gemini 3.x and `virtual-try-on-001` today is **unconfirmed** — check the model pages. For EU-only processing: Vertex backend (ADC from Cloud Run in `europe-west1`) + Firestore `eur3` + Storage `EU` + Cloud Run `europe-west1`; Supabase EU region; Fly `ams`/`fra`. Note Vertex regional endpoints carry ≈1.1× price uplift vs global (litellm, **medium**).

## 10. Observability, analytics, crash reporting, flags, A/B

- **Backend observability**: Cloud Logging structured logs (job id, uid hash, model, tokens, cost, finish reason), Cloud Monitoring SLOs (job success rate, p95 by job type, 429 rate, Gemini error rate), Cloud Trace (request → Gemini spans), Error Reporting; BigQuery: Billing export + usage_log for cost per feature/user cohort; daily reconciliation job; alerts: spend/hour, refusal rate, verifier fail rate, queue depth/age.
- **Product analytics**: Firebase Analytics (free, feeds Remote Config/A-B Testing, BigQuery export) as the base; **PostHog** for funnels/retention/session replay/flags — "1 million events free every month… then it's pay-as-you-go, and the price goes down as you use more… Anonymous events cost way less… Set billing limits" (posthog.com repo, **high**). Mixpanel free tier exists (≈1 M events/mo) — **unconfirmed (memory)**. Send server-side events (job_done, credits_spent, tryon_refused) from the gateway so analytics does not depend on the client.
- **Crash reporting**: Firebase Crashlytics (free) — also captures non-fatal AI errors with job id breadcrumbs; MetricKit for hangs.
- **Feature flags & remote params**: Firebase Remote Config (model IDs, prompt versions, credit prices, kill switches, resolution tiers per plan, rollout %) with real-time updates; PostHog flags as alternative. Keep all Gemini model IDs in Remote Config because of the deprecation cadence (`gemini-2.5-flash-image` shutdown 2026-10-02).
- **Paywall A/B**: RevenueCat Paywalls + Experiments (remote paywalls, no app release; pricing ≈ 1% of MTR above a free allowance — **unconfirmed**), or Superwall/Adapty; alternatively Remote Config A/B Testing on paywall variant id with Analytics conversion event `subscription_started` from RevenueCat webhooks. Guardrail metric: Gemini cost per new subscriber (from usage_log) alongside conversion.

## 11. Comparison matrix

| Criterion | A′ Firebase + Cloud Run | A Firebase AI Logic only | B Supabase (+worker) | C Custom (Fly/Cloud Run + PG + R2) |
|---|---|---|---|---|
| Time to first working build | fast (Auth/Firestore/Storage SDKs) | fastest | fast | slowest |
| Per-user quotas / credits / idempotency | yes (gateway) | **no** | yes (Edge Fn + PG) | yes |
| Image pipeline | Cloud Run worker (sharp) | client only | needs external worker (256 MB/2 s CPU, no sharp) | yes |
| VTO (Vertex), embeddings, batch, caches | yes | no | yes (from worker/Edge) | yes |
| Streaming chat | SSE from Cloud Run / streaming callable | native | Edge Fn streaming | yes |
| Vector search | Firestore `findNearest` (≤1000 results, server SDK) | — | pgvector HNSW (best) | pgvector |
| Relational integrity (ledger, outfits) | transactions, app-enforced | — | SQL constraints | SQL |
| Prompt secrecy | server | Server Prompt Templates (preview) | server | server |
| EU residency | Firestore `eur3` + Cloud Run EU + Vertex EU | Vertex backend location | EU project region | any |
| Infra cost @10k / 100k MAU | ~$150–400 / $0.7–3.5k (egress-driven) | lowest | ~$150–230 / $1.1–1.7k | ~$170–250 / $0.9–1.5k |
| Ops burden | low | lowest | low–medium | medium–high |
| Lock-in | Firebase Auth/Firestore | high | Postgres (portable) | lowest |

---

## 12. Open questions / unconfirmed (verify before budgeting)

1. Live Gemini prices and rate-limit tiers (ai.google.dev/pricing, aistudio.google.com/rate-limit) — litellm snapshot only; `gemini-3.5-flash` at $1.50/$9 vs 3.6–3.8 at $0.75/$3.75 looks odd. Context-cache storage $/token-hour.
2. Vertex `virtual-try-on-001` price and EU region availability; which EU regions serve Gemini 3.x on Vertex.
3. Firebase AI Logic: whether the console now offers any per-user/per-app quota (no evidence); replay-protection GA status; Server Prompt Templates GA date.
4. Google Cloud list prices (Cloud Run, Firestore, GCS egress, Cloud Tasks, Secret Manager, Logging) — third-party 2026 transcriptions only; Cloud CDN egress tiers.
5. Firestore vector index limits (2048 dims, pre-filter support), Cloud Tasks dedupe window — memory.
6. Fly Machine preset prices, R2 prices, RevenueCat/Mixpanel/PostHog paid tiers — memory.
7. Gemini API paid-tier abuse-log retention and EEA terms wording.
8. Firebase iOS `Functions.stream()` API shape for streaming callables (Cloud Run SSE is the safe path).

## 13. Sources

- Sibling reports: `research/gemini-vision.md`, `research/gemini-image-gen.md`, `research/virtual-try-on.md`
- https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json (local `research/litellm_prices.json`)
- https://github.com/firebase/firebase-functions/blob/master/src/v2/providers/https.ts , …/tasks.ts , …/options.ts
- https://github.com/firebase/firebase-ios-sdk — `FirebaseAI/Sources/FirebaseAI.swift`, `Types/Internal/AppCheck.swift`, `TemplateGenerativeModel.swift`, `FirebaseAuth/Sources/Swift/Auth/Auth.swift`, `FirebaseAuth/Sources/Swift/Backend/RPC/RevokeTokenRequest.swift`
- https://github.com/firebase/firebase-js-sdk — `packages/ai/CHANGELOG.md`, `packages/ai/src/helpers.test.ts`
- https://github.com/firebase/quickstart-ios/blob/main/firebaseai/README.md (App Check guidance)
- https://github.com/googleapis/google-api-nodejs-client/blob/main/src/apis/firebaseappcheck/v1.ts ; https://github.com/googleapis/google-api-go-client/blob/main/firebaseappcheck/v1beta/firebaseappcheck-api.json (limited-use/replay, verifyAppCheckToken, service IDs)
- https://github.com/googleapis/nodejs-firestore/blob/main/dev/src/reference/query.ts , …/vector-query.ts
- https://github.com/firebase/extensions/blob/master/delete-user-data/README.md
- https://github.com/supabase/supabase — `packages/shared-data/plans.ts`, `packages/shared-data/pricing.ts`, `apps/docs/content/guides/functions/limits.mdx`, `apps/docs/content/guides/storage/uploads/file-limits.mdx`, `apps/docs/content/guides/platform/compute-and-disk.mdx`, `apps/docs/content/guides/platform/manage-your-usage/{monthly-active-users,egress,storage-size,edge-function-invocations}.mdx`, `apps/docs/content/guides/database/extensions/pgvector.mdx`
- https://github.com/superfly/docs/blob/main/about/pricing.html.markerb
- https://github.com/PostHog/posthog.com/blob/master/src/hooks/productData/product_analytics.tsx
- https://github.com/upstash/ratelimit-js/blob/main/README.md
- Third-party GCP price transcriptions (2026): https://github.com/pravinva/osipi-connector/blob/main/GCP_DEPLOYMENT.md , https://github.com/Project-Vizcaya/One-Vizcaya/blob/main/COST.md , https://github.com/yaalalabs/agent-kernel (ak-deployment READMEs), https://github.com/cabradna/misuper_AIOCR (phase-03 pricing plan)
- https://github.com/gvillarroel/gcp-radar (mirrored Vertex release notes / model pages, local `research/gh/radar_*.md`)
