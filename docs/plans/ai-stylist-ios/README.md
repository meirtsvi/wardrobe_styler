# AI stylist for iOS — plan bundle

Plan date: 2026-09-05. No code has been written; this folder is the plan and the evidence behind it.

The brief: build a native iOS app that does everything [Essembl](https://essembl.com/) does (digitise a wardrobe from photos, generate weather- and occasion-aware outfits, AI stylist chat, Shopping Buddy, rate/upgrade outfits, find items in photos, Outfit Battle, outfit planner) plus real virtual try-on, with a Gemini API key covering every runtime AI call.

## Files

| File | What it is |
|---|---|
| [`PLAN.md`](PLAN.md) | The full plan (13 numbered sections, ≈ 33k words). Start with §1 (executive summary), §2 (what Essembl does and what we change), §3 (scope) and §12.2 (decisions only you can make). |
| [`research/essembl-features.md`](research/essembl-features.md) | Feature inventory of Essembl: every feature with evidence, onboarding/paywall flow, navigation, version timeline, pricing, tech clues. |
| [`research/essembl-reviews.md`](research/essembl-reviews.md) | What Essembl's users love and complain about, with quoted reviews, and the "do better" list the plan is built around. |
| [`research/competitors.md`](research/competitors.md) | Feature matrix and pricing benchmarks for Whering, Acloset, Indyx, Stylebook, Cladwell, Alta, Style DNA, Aiuta, Google Doppl/Photos Wardrobe and others. |
| [`research/gemini-vision.md`](research/gemini-vision.md) | Gemini models for detection, segmentation, structured output, chat, embeddings, caching, Batch/Flex tiers, rate limits, prices. |
| [`research/gemini-image-gen.md`](research/gemini-image-gen.md) | Nano Banana image models (`gemini-3.1-flash-image`, `gemini-3-pro-image`, `gemini-3.1-flash-lite-image`): capabilities, limits, prices, safety, try-on prompt patterns. |
| [`research/virtual-try-on.md`](research/virtual-try-on.md) | Every viable try-on route: Vertex `virtual-try-on-001` (Vertex-only, not API-key), Nano Banana composition, FASHN and other vendors, open-source models and their licences. |
| [`research/ios-platform.md`](research/ios-platform.md) | iOS 26 stack: Vision subject lifting, Foundation Models, WeatherKit, StoreKit 2, App Check, background tasks, App Store guidelines, privacy manifests, CI. |
| [`research/backend-architecture.md`](research/backend-architecture.md) | Firebase vs Supabase vs custom, the AI gateway pattern, image pipeline, data model, cost controls, cost model. |
| [`research/shopping-commerce.md`](research/shopping-commerce.md) | Shop-the-look and Shopping Buddy options: Gemini grounding, SerpApi Lens, affiliate networks, disclosure rules. |
| [`research/monetization-growth.md`](research/monetization-growth.md) | Category pricing benchmarks, paywall evidence, credit models, retention loops, ASO and launch tactics, KPI targets. |

The research notes mention `<session-scratch>/…` paths. Those were working copies (unzipped SDK sources, cloned GitHub docs, price snapshots) used during research and are not committed; every claim that depends on them also cites the public URL.

## Headline decisions

| Decision | Choice |
|---|---|
| Platform | SwiftUI, iOS 26 minimum, iPhone-only until v1.3, MVVM with `@Observable`; Firestore + Cloud Storage as the source of truth, SwiftData as an offline cache, no CloudKit. |
| AI access | One Cloud Run gateway holds the Gemini key; the app never calls Gemini directly. Per-user metering, idempotency, retries, budget ladder and kill switch live there. |
| Models | `gemini-3.8-flash` (detect, plan, verify, chat), `gemini-3.7-flash` (segmentation masks), `gemini-3.5-flash-lite` (bulk tagging), `gemini-embedding-2` (duplicates, similarity), `gemini-3.1-flash-image` (try-on renders), `gemini-3-pro-image` (HD, digital twin), `gemini-3.1-flash-lite-image` (background clean-up). All IDs in Remote Config. |
| Digitisation | Gemini finds the garments; the cutout keeps the user's real pixels (on-device Vision masks per detected box, Gemini segmentation as fallback). Colour comes from pixels, never from the model. High-confidence items commit automatically; only doubtful ones go to a review queue. |
| Outfits | Deterministic candidate retrieval, one Gemini planning call that returns three outfits, and a code validator that enforces weather, layering, formality, availability and rotation rules. Every card shows the temperature range, a rationale and a reason per item. |
| Virtual try-on | Prompt-composition on Nano Banana 2 with a verifier model that is itself measured against human labels, two renders max per Look, rendered as a background job. Vertex `virtual-try-on-001` is Vertex-only (needs a GCP service account, not an API key), one garment per call, and listed for discontinuation 2027-01-20, so it is a v1.3 spike, not the foundation. |
| Monetisation | Free: unlimited wardrobe and a daily outfit, then 3 free try-on Looks at signup and 1 per month. Plus: $7.99/mo or $39.99/yr (7-day trial on annual only), 40 Looks/month, "Plan my week". Non-expiring Look packs. Price shown on onboarding screen 2; one soft paywall after the first outfit interaction; no hard wall, no exit-offer theatre. |
| Release shape | Store 1.0 = Digitise + Outfits (+ week strip, widget). Try-on ships to external TestFlight in the same programme and reaches the store as 1.0.5 once its quality gates hold on real beta photos. Chat, calendar, "Should I buy this?" in v1.1; colour analysis and manual builder in v1.1.5; Item Finder, Outfit Check/Glow Up/Battle, packing, Hebrew RTL in v1.2; Shopping Buddy chat, lookbooks, iPad in v1.3. |

## Timeline and cost

| Item | Figure |
|---|---|
| Two engineers, kickoff 2026-09-14 | 1.0 submitted ≈ week 19 (2027-01-18), public ≈ week 22; 1.0.5 (try-on) submitted ≈ week 27 |
| Solo developer | 8–9 months to 1.0, 10–12 months to 1.0.5 |
| AI cost per free user | ≈ $0.11 (light) to $0.28 (activated) per month |
| AI cost per Plus user | ≈ $1.50–1.75 (median), ≈ $4.6–4.7 (allowance maxed) |
| Blended AI cost | ≈ $0.25–0.38 per monthly active user |
| Infrastructure | ≈ $100/mo at 1k MAU, $150–400 at 10k, $0.7–1.2k at 100k with a CDN |
| Launch quarter (20k installs) | Gemini ≈ $3–5k, infra ≈ $1k |

The honest finding (§10.5): at the freemium median paid share the app is roughly break-even on AI cost at 100k MAU. The levers that keep it positive are named and wired into Remote Config from day one.

## Decisions needed from you

§12.2 lists 18 open questions. The ones that change the work most:

1. Team shape: solo or two engineers, and whether there is budget for a part-time designer, a labelling contract and paid rating sessions.
2. Ship 1.0 without try-on (Digitise + Outfits at week 19) or hold for one launch with try-on (≈ 8 weeks later).
3. Pricing sign-off: $7.99/mo, $39.99/yr, 20 Looks for $4.99, or open at $44.99/yr.
4. Launch markets: US English first, with Hebrew RTL in v1.2, or Israel earlier.
5. Whether two non-Google vendors are acceptable as optional adapters: FASHN as a try-on reliability fallback and SerpApi Google Lens for visual product search. The plan works with neither.
6. Brand name (it also fixes the stylist persona's name) and whether the Apple Developer account is an organisation.
7. Gemini billing: the API key must belong to a billing-enabled Google Cloud project you control; Tier 2 spend (> $250 cumulative plus 30 days) should start in week 1.

## How the evidence was gathered

The research ran on 2026-09-05 from a sandbox whose egress proxy blocked most vendor and store sites (Apple, Google AI docs, Firebase docs, essembl.com, app-store mirrors). Facts therefore come from primary sources reachable on GitHub and PyPI: the `google-genai` 2.22.0 SDK source, the Gemini cookbook, the Firebase iOS SDK, a 2026-09-04 mirror of Apple's developer docs, the App Review Guidelines text of 2026-06-08, and dated third-party price snapshots (litellm, promptfoo). Every price, limit and model claim carries a confidence mark; everything at medium or low confidence is listed again in §13.3 as a "verify before coding" item, with the live Gemini pricing page as the first week-0 task.
