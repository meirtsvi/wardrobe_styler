# ADR 0002 — Personal server on the Mac mini, no third-party accounts

Date: 2026-09-05. Status: accepted. Supersedes PLAN.md §7 (Firebase/Cloud Run), §9 (monetisation) and ADR 0001's remaining Firebase references.

## Direction from the owner

Use only models that run on the iPhone, plus one Gemini API key supplied through a `.env` file, and use Gemini for graphics: generating images and putting the wardrobe onto a photo of the user. No other account of any kind: no Firebase, no Firestore, no RevenueCat, no analytics, no database. The server runs on the owner's Mac mini and is reached through a Cloudflare quick tunnel, temporarily.

## What this changes

| Before (PLAN / ADR 0001) | Now |
|---|---|
| Cloud Run gateway + Firestore + Storage + App Check + Remote Config | One Node process on the Mac mini (`backend/`), started by `scripts/run-mac.sh`, exposed by `cloudflared tunnel --url` (quick tunnel, no Cloudflare account, URL changes per run) |
| Firebase Auth + App Check tokens | One shared bearer token from `.env` (`GATEWAY_TOKEN`), entered once in the app's Settings |
| Two-bucket credit ledger, Looks, subscriptions, packs | Removed. A local JSON spend log on the Mac (`backend/data/usage.jsonl`) and a daily USD budget from `.env` (`DAILY_BUDGET_USD`) protect the API key |
| Firestore wardrobe / job queue | Nothing server-side. The wardrobe lives only in SwiftData on the phone; requests are synchronous |
| Gemini model ids in Remote Config | `.env` overrides with defaults in `backend/src/config.ts`; `scripts/probe-models.ts` lists the models the key can see |

## What the server does

- `POST /v1/outfits/plan` — Stage B on Gemini from client candidates (fallback when Foundation Models is unavailable).
- `POST /v1/items/attributes` — names garments the on-device classifier cannot.
- `POST /v1/looks` — virtual try-on: the user's photo plus up to four garment cutouts → one composed image from the Gemini image model. Synchronous, ~25 s.
- `POST /v1/images/cleanup` — optional generative clean-up of a cutout background (user tap only; the wardrobe keeps the real-pixel cutout).
- `GET /v1/usage` — today's estimated spend and the budget.

## What the app does

Everything else: digitisation, colour, duplicates, planning with Foundation Models, weather via WeatherKit, storage in SwiftData. The app works with no server at all; the server adds Gemini naming, Gemini planning as a fallback, and try-on.

## Consequences

- The URL changes every time the quick tunnel restarts; the app's Settings screen takes the new URL. A named tunnel needs a Cloudflare account and is deferred.
- No accounts means no sync and no backup beyond the phone's own backup; export ZIP stays on the list.
- WeatherKit still needs an Apple Developer team for a signed build; until then the weather sliders are manual. That is the only Apple-side dependency and it is not an extra account beyond running the app on a phone.
