# Monetization & growth for an AI wardrobe / stylist iOS app — research dump (as of 2026-09-05)

## 0. Method, evidence quality, and caveats (read first)

- **Tooling constraints this session**: the WebSearch budget was already exhausted (200/200) before this task began, and the egress proxy blocks revenuecat.com, superwall.com, adapty.io, apps.apple.com, play.google.com and every app-intelligence site. Only github.com / raw.githubusercontent.com were reachable.
- **Evidence therefore comes from three layers**:
  1. **Prior first-hand research already in this scratchpad** (iTunes Lookup API snapshots 2026-07-21/22, App Store IAP blocks, review-RSS mining, official-site fetches, third-party competitor docs committed to GitHub in 2026). Files: `competitors.md`, `essembl-reviews.md`, `essembl-features.md`, `gh/loomies-16-growth.md`, `gh/loomies-21-pricing.md`, `gh/loomies-22-redteam.md`, `gh/loomies-23-baseline.md`, `backend-architecture.md`, `gemini-image-gen.md`, `virtual-try-on.md`, `ios-platform.md`, `ios/guidelines.txt` (Apple App Review Guidelines text).
  2. **Third-party syntheses of the RevenueCat State of Subscription Apps 2025/2026, Adapty State of In-App Subscriptions 2026, Superwall studies and Apple-guideline changes, committed to public GitHub repos in 2026** (downloaded to `research/growth/`): `rc-sosa2025-benchmarks.json` (page-referenced extraction of the RC 2025 PDF, North-America cuts), `paywall-research-2026.md` + `paywall-category-deep-dives.md` (app-paywall-pilot, 2026-04-16, 50 sources), `quiz-benchmarks-2026.md` + `quiz-teardowns.md` (autonomous-quiz-funnels), `superwall-4000-paywalls.md` (Superwall podcast testimony, 2026-02-08), `paywall-evidence-sources.md`, `solo-dev-playbook.md` (RC 2026 + Airship 2026 + ASO 2026), `furiai-benchmarks.md` (source audit of retention/CPI/pricing benchmarks, 2026), `ads-apple-skill.md` (SplitMetrics 2025 ASA data), `rc-codelab-monetization.md` (RevenueCat's own codelab), `ojo-puttogether.md` (2026-08-16 competitive teardown of a wardrobe app with credits).
  3. **Model knowledge (cutoff June 2026)** only where labelled; never used for a number that a source could not back.
- **Confidence legend**: **H** = primary text (Apple guideline text, RevenueCat codelab, first-hand store snapshot) or 2+ independent secondary docs agreeing; **M** = single secondary doc quoting a vendor report with page/URL; **L** = practitioner skill files, podcast testimony, or model knowledge. Vendor aggregate benchmarks are cohort medians, not causal — treat as order-of-magnitude anchors.
- Prices are US App Store snapshots (mostly 2026-07-21/22 and 2026-08); the category raised prices 30–40% in two years (Pureple), so re-verify before publishing.

---

## 1. Pricing benchmarks in the category (US App Store unless noted)

### 1.1 Per-app price sheet

| App | Free tier | Weekly | Monthly | Yearly | One-time / credits | Trial | Source / conf |
|---|---|---|---|---|---|---|---|
| **Essembl** (Essembl SA, Lux.; likely MWM-published since 2026) | None in practice: hard paywall after ~3:22 onboarding; "continue with limited features" button is a second (discounted) paywall. Early-2025 builds were free; monetization hardened during 2025. Referral: 3 invites grants a subscription. | Weekly SKUs exist (India ₹299/wk; US weekly price not captured; soft112 IAP list shows tiers $9.99–$59.99 whose periods are unclear) | — | "Essembl Premium" **$29.99/yr** (soft112 IAP); reviewers cite "$39", "$50", "40 CHF", and a "$80" post-trial charge (currency unclear); decline-offer **$1.66/mo "80% off $55"** ≈ $19.99/yr; India ₹2,999–3,999/yr | — | **3-day trial on annual only**, card required; no trial on weekly; no trial-end reminder (complaint) | `essembl-reviews.md` §6–7, `essembl-features.md` §2 (screensdesign showcase, App Store reviews via justuseapp/appshunter, soft112) — **M** |
| **Whering** | Everything free, unlimited items, no ads, **no subscription SKU** | — | — | — | "Style Pass" AI credits **10/$2.99, 50/$7.99, 100/$12.99**; Outfit Maker $4.99 one-time; Supporter tiers $0.99–$49.99 | n/a | `competitors.md` §1.1, `loomies-21` §1 (iTunes API + IAP block 2026-07-22) — **H** |
| **Acloset** | Free up to **100 items** + interstitial ads | — | Basic **$3.99**, Premium **$9.99**, Expert **$24.99** | Basic **$27.99**, Premium **$59.99**, Expert **$147.99** (annual = 42–51% off) | "beans" **100/$1.99 … 500/$9.99** for Beautify/try-on; a $100 lifetime seen in a review | not shown on page | `competitors.md` §1.2, `loomies-21` — **H** |
| **Alta / Alta Daily** | Entirely free, zero IAP (VC-subsidised; $11M seed 2025-06; affiliate + B2B) | — | — | — | — | — | `competitors.md` §1.6, `loomies-21` — **H** (a "$3–5/mo avatar tier by region" is **L/unconfirmed**) |
| **Indyx** | Free **unlimited** items/outfits/calendar/packing | — | Insider **$12.99** | **$74.99** (48% of 12×monthly); Black-Friday $54 seen | Human services: Lookbook Mini $60, Lookbook $150+, 1:1 $60–110, Catalog digitization $295/100 items | not shown | `competitors.md` §1.3, `loomies-21` — **H** |
| **Stylebook** | n/a (paid download) | — | — | — | **$4.99 one-time**, zero IAP, no ads; men's app another $4.99; no update since 2025-06 | none | `loomies-21` §1.1 — **H** |
| **Cladwell** | "Glass-window" free: closet + 2 capsules + 7 outfits / 1 outfit-per-day + 7-day log; Ask Cladwell 5 msgs/mo | — | **$7.99** (+ $21.99 quarterly; legacy $2.99/$9.99 SKUs still listed) | **$59.99** ("less than $5 a month") | — | not shown | `competitors.md` §1.5 — **H** |
| **Style DNA** | Paywall **before results** (selfie collected first) | Web funnel "£7/week"-style intro → $28.95/mo billed outside Apple | **$7.99 / $9.99 / $19.99** (3 SKUs) + 3-month $14.99/$19.99 | **$19.99 / $29.99 / $39.99** | à-la-carte guides $9.99–12.99 | pay-before-results; 9 overlapping SKUs; ~28% of recent reviews are billing complaints | `competitors.md` §1.13 — **H** |
| **Aiuta** | B2B try-on SDK/API for retailers; **pricing not published** (enterprise) | — | — | — | — | — | `competitors.md` §1.14 — **H** existence / **L** price |
| GetWardrobe | Free 100 items+outfits, no card | — | $4.99 | **$34.99** (store) vs $49.99 (web) | AI credits 20/$4.99, 60/$9.99, 150/$19.99, 500/$59.99, 1000/$89.99 | 7-day on annual | `loomies-21` — **H** |
| Pureple | Unlimited items, heavy ads, Style Me/calendar gated | **$6.99/wk** (named 1★ trigger) | $14.99 | $89.99 | legacy Pro $14.99 | 7-day on annual | `loomies-21` — **H** |
| Dripmatiq (on-device try-on) | 25 outfit suggestions + **3 try-ons/mo** | — | Pro **$6.99** (unlimited suggestions, 25 try-ons/mo); Elite **$15.99** (100 try-ons/mo) | — | — | — | `gh/dripmatiq-blog.md` (vendor, 2026-07-04) — **M** |
| PutTogether (Aprobee, SG) | metered | — | **$9.99 / $16.99 / $25.99 / $34.99** (entry tier = 25 garments) | — | credits **$1.99–$19.99** on top of subscription | — | `growth/ojo-puttogether.md` (2026-08-16) — **M** |
| FitCheck clones (≥8 apps) | varies | **$3.99–4.99/wk** | — | **$29.99–39.99** | credit packs **5/$1.99 → 200/$69.99** | — | `competitors.md` §1.21 — **H** |
| Nouva | 30 items / 3 outfits per week | — | £6.99 | — | — | — | **M** |
| OpenWardrobe | freemium + trial | — | $12.99 | $79 | $199 lifetime | yes | **M** |
| Aesty | none | — | — | ~$50–250/yr (Pro/Max) | — | none | **M** |

### 1.2 Structural read of the category (H unless noted)

- **Annual ≈ 48–63% of 12× monthly** (Indyx 48%, Acloset 50%, Pureple 50%, GetWardrobe 58%, Cladwell 63%). Mainstream monthly median ≈ **$9.99**, annual median ≈ **$59.99**, but reviewer willingness-to-pay clusters at **$30–50/yr** ("$39 would be reasonable if it worked" — Essembl reviewer; "$60/yr… very little changes" — Cladwell; ~$8/mo is the resentment line). `competitors.md` §5, `loomies-21` §2.
- **Weekly SKUs ($3.99–7.99/wk) appear only in the lowest-rated apps** (Pureple 3.94★, FitCheck clones, Style DNA web funnel, Essembl) and are a named 1★ trigger ("6.99 A WEEK… insane"). Dripmatiq's blog warns readers that competitors "bill weekly at a rate that looks like a monthly price". (Contrast with the cross-category data in §2: weekly plans are 55.6% of subscription revenue globally — the category's users punish it in reviews even though it monetises.)
- **"Unlimited items, free" is the entry ticket among the best-rated apps** (Whering 4.67★, Indyx 4.78★, Alta 4.88★) vs 100-item walls (Acloset 4.40★, GetWardrobe 4.29★) — correlation, not causation. Caps are migrating from storage to **AI compute (credits/quotas)**.
- **Credits are the category's new dual-track disease**: Whering, Acloset, GetWardrobe, PutTogether, FitCheck all run subscription + consumable credits, producing 9–10 SKUs each and billing confusion. Implied price per AI action ≈ **$0.09–0.40**. PutTogether's "$9.99/mo for 25 garments + credits" is called "the softest target in their entire business" by a competitor teardown. `ojo-puttogether.md` §3.
- **Trials**: norm = free tier without card + 3–7-day trial on annual only (Pureple, GetWardrobe, Essembl); card-required trials and "limited features" fake-outs draw deception complaints. Style DNA and Essembl (pay-before-results) are the two most-cited trust failures.
- **Buy-once vacuum**: nothing modern between Stylebook $4.99 (frozen) and $14.99; "if y'all have to start charging, only as a flat fee" (Whering reviewer). A one-time "Core" unlock is a differentiator, but AI features cannot be buy-once (per-call cost).
- Zero-price anchors: Alta (VC) and Whering (credits/donations) train users to expect cataloguing for $0; only try-on volume, premium analytics, or human services justify paid tiers (`competitors.md` §5).

---

## 2. Paywall best practices 2025–2026 (RevenueCat / Adapty / Superwall data)

### 2.1 RevenueCat State of Subscription Apps 2025 — North America category cuts (from a page-referenced extraction of the PDF, `growth/rc-sosa2025-benchmarks.json`; **M**)

| NA category | Download→trial (median / p90) | Trial→paid median | Download→paid D35 median / p90 | Refund rate median | Trial length mix |
|---|---|---|---|---|---|
| **Social & Lifestyle** (Apple "Lifestyle" maps here) | **1.9% / 20.3%** | **38.3%** | **0.9% / 5.5%** | **3.34%** | 49.2% ≤4 days, 43.6% 5–9 days |
| Shopping | 8.1% | 18.2% | 0.5% | 2.24% | 49.8% 5–9 d, 36.7% 10–16 d |
| Health & Fitness | 3.9% | 39.9% | 1.0% | 4.71% | 81.2% 5–9 d |
| Photo & Video | 1.2% | 26.8% | 0.7% | 3.43% | 48.3% ≤4 d |
| Utilities | 3.7% | 39.1% | 1.1% | 3.16% | — |

Other RC 2025 facts quoted by multiple docs: 82% of trials start day 0; 17–32-day trials convert 45.7% vs 25.5% for <4-day; hard paywall D35 download→paid 12.1% vs freemium 2.2%; "only 1.7% of downloads convert to paying within 30 days; top apps 4.2%" (RevenueCat's own codelab, **H**); 35% of apps mix subscriptions with consumables/lifetime (Social & Lifestyle 39.4%); family plans +52% retention; annual preselected → 60–70% pick annual; ~9/10 subs sell at full price; Productivity 77% monthly. Sources: `paywall-evidence-sources.md`, `couch-monetization.md`, `furiai-benchmarks.md`, `rc-codelab-monetization.md`.

### 2.2 RevenueCat State of Subscription Apps 2026 (115k+ apps, $16B+, published 2026-03) — as quoted in `paywall-research-2026.md`, `quiz-benchmarks-2026.md`, `solo-dev-playbook.md`, `teamz-rc-deep-research.md` (**M**, 3–4 independent docs agree)

- **Hard paywall vs freemium**: download→paid D35 **10.7% vs 2.1%** (top-10% hard paywalls 38.7%); D14 RPI $2.32 vs ~$0.27; D60 RPI **$3.09 vs $0.38**; **year-1 retention identical (~27% vs 28%)** — hard paywall is a conversion/cash-flow choice, not a retention one.
- **Trial length → trial-to-paid**: ≤4 days **25.5%**; 5–9 days **37.4%** (upper quartile 52.8%); 17–32 days **42.5%**. Yet ≤4-day trials rose to 46.5% of apps (cash-cycle pressure). 3-day trials: **55.4% cancel on day 0**; 7-day: 39.8%. 89–90% of trial starts happen day 0.
- **Price tier → LTV**: high-priced apps D35 conversion 2.8% and year-1 RLTV **$62.19** vs mid $28.75 vs low $10.69 — "premium positioning pays even with lower conversion".
- **Retention by plan (12-mo)**: annual **44.1%**, monthly 17.0%, weekly **3.4%**. Cross-category first monthly renewal median ≈53%.
- **Median prices**: weekly $5.00–5.90; monthly $7–10 (NA ≈ **$9.99**, APAC $6.72, IN/SEA $3.75); yearly $31.60–34.80 (NA ≈ **$39.99**, IN/SEA $18.32).
- Regions: NA download→trial 7.1%, D35 paid 2.8%, D14 RPI $0.38; iOS D35 2.6% vs Android 0.9% (trial→paid equal ~32.5%); iOS ≈ 85% of subscription revenue.
- Paywall UI prevalence: highlighted pricing 74.5%, multi-plan 59.2%, trial messaging 54%, testimonials 5.9–16.9%, countdown timers ≤1.4%. 2-plan paywalls are the most common (41–60% of apps).
- Involuntary churn: **14% of App Store cancellations** are billing failures (31% on Play).
- **AI apps**: +41% year-1 RLTV ($30.16 vs $21.37) but ~36% faster monthly churn; Adapty: AI install→trial 5.31% (vs 10.92% avg), annual+trial LTV $66.70 vs $49.92 — "less trial culture, more direct purchase + annual".
- Market: ~14,700 app launches/month in Jan 2026; pre-2020 apps take 69% of category revenue; 2025+ launches 3%.

### 2.3 Adapty State of In-App Subscriptions 2026 (16k apps, $3B, published 2026-03-14) — `paywall-research-2026.md`, `quiz-benchmarks-2026.md` (**M**)

- Global medians: weekly **$7.48**, monthly **$12.99**, annual **$38.42** (EU 29–39% above NA).
- **Weekly plans = 55.6% of subscription revenue** (43.3% in 2023); but 65% of weekly users cancel within 30 days; D380 retention annual 19.9% / monthly 14.2% / weekly 5.5%. "Weekly $5.99 + 3-day trial" = 1.5× average LTV config ($54.50 12-mo LTV). Higher-priced weekly tiers retain +12% at first renewal.
- Install→trial 10.9% global (NA 14.5%); trial→paid 25.6% (H&F 35%, Entertainment 19.1%); 90% of trials start day 0; 44.5% of all purchases day 0.
- **Hard vs soft**: hard paywalls +21% 1-year LTV per subscriber ($41.90 vs $20.00; p90 $89.90) but **soft paywalls out-convert hard by ~50% on view→payment**. Adapty's onboarding-paywall-with-trial average: 1.78% install→paid.
- **Lifestyle category**: direct buyers ~21% more valuable at 12 months than trial users → "test no-trial direct-to-paid or reverse trial" (`paywall-category-deep-dives.md`).
- A/B win-rates by LTV: localization **62.3%**, trial structure 59.6%, plan duration 58.7%, number of plans 57.1%, price 45.5%, visual/copy 34.6%; apps running 14+ experiments/yr earn up to 40× more (correlation).
- Discounts: post-close welcome offer to non-converters only = +10–15% ARPU; discount on the main paywall trains users to expect lower prices.
- Median app monthly revenue $492; top 10% take 94.5% of revenue.

### 2.4 Superwall studies and practitioner testimony (**M/L**; vendor marketing)

- Product count (32.3M paywall opens, 15 apps): 1→2 products **+61%** conversion, 2→3 **+44%** (uncontrolled; watch LTV parity).
- Transaction-abandon paywalls (18 companies, 525k users, 2024-08): ~17% of total revenue from abandon paywalls; their refund rate 3.3% vs 6.8% control.
- Superwall feature claims: trial reminders **+48% revenue / +46% trial conversions**; annual preselected → +70% annual mix; targeting unsubscribed users +240% trial starts; "average +20% revenue floor" from their test framework.
- 4,000-paywall designer (2026-02-08 podcast): average paywall conversion he sees ≈ **8%**, a couple of iterations lift to 15–20%; simplification beats persuasion ("users don't read"); bullet list > comparison table; **"No commitment, cancel anytime"** line and generic "Continue" CTA are near-universal bumps (one test +10%; a bare "try for 50% off + screenshot" beat a feature table by 111%); plain SwiftUI-native paywalls beat custom designs twice; order plans by length; one-time offers 25–33% off, never on the main paywall; AI-wrapper market settled at **$29.99–40/yr** for text apps, image/video apps price higher; niche custom-prompt apps sustain $20–22/mo; ~50% of trial starters cancel; cascade pattern (annual paywall → "not ready for a year?" drawer with monthly → 25–33% one-time offer). `superwall-4000-paywalls.md`.
- Blinkist "honest paywall" timeline (Today → Day 5 reminder → Day 7 charge): **+23% trial starts, −55% complaints, +4% trial retention, push opt-in 6% → 74%**; 33% of cancellations had been day-0 panic. `paywall-research-2026.md` §7, `quiz-teardowns.md`.
- Placement: FitnessAI moved paywall before onboarding → 2× install-to-trial; Rootd dismissible paywall at front → 5× revenue (single cases, **L**). Paywall fatigue degrades after ~2 exposures/user (Nami ML 2026).
- Onboarding quiz length among top earners: Cal AI 28 steps (~2:15) hard paywall + 3-day trial timeline; Noom 77 steps; Flo 70 screens; Essembl ~3:22. Practitioner rule for most apps: **3–5 personalization questions max, each visibly affecting the experience** (`eronred-onboarding-skill.md`), and "long onboarding only works when every screen earns its keep" (`quiz-teardowns.md`).

### 2.5 Apple enforcement shift (2026) — **H** for guideline text, **M** for enforcement timeline

- Mid-January 2026: mass rejections of **free-trial toggle paywalls** under Guideline 3.1.2; Apple's reason: "The purchase screen includes a toggle to add or remove a free trial… This design is confusing and may prevent users from understanding that they are committing to an auto-renewing subscription." iOS only. Field observations: delayed close button >5 s, pricing font <16pt, two full paywalls back-to-back, guilt-trip decline copy correlate with rejection (`paywall-research-2026.md` §6).
- Guideline 3.1.2(a): subscription period ≥7 days; 3.1.2(c): "clearly describe what the user will get for the price"; 3.1.2 anti-scam clause: apps that "trick users into purchasing a subscription under false pretenses or engage in bait-and-switch… will be removed"; Developer Code of Conduct: never "trick them into making unwanted purchases… raise prices in a tricky manner, charge for features or content that are not delivered" (`ios/guidelines.txt` lines 173–186, 365).

### 2.6 How to avoid Essembl's "paywall after long onboarding" complaint (synthesis)

What users actually object to (from `essembl-reviews.md` §2.1/§6; VERY HIGH frequency on both stores): (a) paying before seeing anything; (b) email + selfie collected before the price is disclosed; (c) the "continue with limited features" button that is itself a discounted paywall; (d) "80% off from $55" discount theatre; (e) 3-day card-required trial with **no reminder** → "$80" surprise; (f) refund only by emailing support; (g) being charged while the core feature is broken. Price level itself is not the objection.

Design that is consistent with both the complaint data and the 2026 benchmarks:
1. **Price transparency before effort**: show the price and the free tier on onboarding screen 2–3 (a "what's free / what's Plus" card), not at minute 3:22. Blinkist-style timeline on the trial paywall; local notification 24 h before the trial converts; "No commitment, cancel anytime" + "then $X/yr, billed [date]".
2. **Value before ask**: deliver the first real outfit (ideally on-body render) before the paywall — PutTogether's "portrait before paywall" is the mechanic every teardown says to copy (`ojo-puttogether.md` §4.1, §5.2); Cal AI/Noom show the "your plan is ready" moment first. A soft paywall at the activation moment converts ~50% better on view→pay (Adapty), and Lifestyle direct buyers are worth more than trial users anyway.
3. **Quiz ≤5 questions, no selfie/email before value**: sign-in optional (Sign in with Apple only when sync is needed); selfie only when colour analysis/try-on is requested, with a one-line data note (5.1.1). Guideline 5.1.2(i) already forbids requiring push/location.
4. **A real free tier, not a fake-out**: unlimited wardrobe + daily outfit-of-the-day forever; gate compute (renders/try-on), not access. Never a "limited features" button that opens another paywall.
5. **Honest pricing UI**: one real price per plan; no "80% off $55" anchors unless the reference price is real (Apple 2.3.1/Code of Conduct); no fake countdowns; annual preselected with monthly visible; no weekly at launch.
6. **In-app manage/cancel/refund path** (StoreKit `manageSubscriptionsSheet`, `beginRefundRequest`), support form in Settings, visible known-issues banner — Essembl's week-long silence to a paying user is a recurring 1★.
7. Reserve the "hard wall" pattern for a later A/B on high-intent paid traffic only; RC 2026 says hard paywalls win on cash, not on retention, and the category's reviews punish it.

---

## 3. AI cost per user vs ARPU — how to gate expensive features

### 3.1 Unit costs (from `backend-architecture.md` §5/§8, `gemini-image-gen.md` §3/§6, `virtual-try-on.md`, `gh/steam-vto-cost.md`; **M**, prices dated 2026-06/08)

| Action | Model / path | Cost per action |
|---|---|---|
| Wardrobe photo ingestion (on-device masks + Gemini detect/attributes/embedding, 20% seg fallback) | `gemini-3.8-flash` + `gemini-3.5-flash-lite` + `gemini-embedding-2` | **≈ $0.003–0.004 / photo** |
| Generative "clean-up" cutout (optional, on tap) | `gemini-3.1-flash-lite-image` 1K | $0.034 |
| Outfit generation, text/plan only (weather via function call) | `gemini-3.8-flash` | **≈ $0.004** |
| Outfit collage/preview render 512 px | `gemini-3.1-flash-image` 512 (batch −50%) | $0.045–0.049 (≈ $0.022 batch) |
| Stylist chat message (~3k ctx, 20% search-grounded) | `gemini-3.8-flash` | ≈ $0.006 |
| On-body try-on (person + garment), 1K, verifier + 20% retry | `gemini-3.1-flash-image` ("Nano Banana 2") | **≈ $0.09** (Pro `gemini-3-pro-image` ≈ $0.16; FASHN tryon-v1.6 $0.075; FASHN Try-On Max $0.075/step so a 4-item look ≈ $0.30; fal image-apps-v2 $0.04; Kling Kolors $0.07; Alibaba OutfitAnyone Plus ≈ $0.071; Vertex `virtual-try-on-001` price unconfirmed) |
| Digital-twin avatar (one-time per user) | `gemini-3-pro-image` 2K | $0.134 |
| WeatherKit | 500k calls/month included with the developer program (memory, **L**) | ~$0 at MVP |

Blended per-user monthly AI cost at a "typical heavy" profile (30 photos, 20 outfit renders, 50 chat msgs, 5 try-ons): **≈ $0.9–1.8 / active user / month**; realistic cohort budgets: **free ≈ $0.30, paid ≈ $1–2** (`backend-architecture.md` §8). Gemini spend dwarfs infrastructure at every scale; image egress is the only infra line that matters.

### 3.2 ARPU side

- Category monthly median $9.99 / annual $59.99 vs realistic WTP $30–50/yr (§1.2). After Apple Small Business Program (15% under $1M/yr): $7.99/mo nets ≈ $6.79; $39.99/yr nets ≈ $34 ≈ $2.83/mo.
- RC 2026: NA D14 RPI $0.38 (freemium), D60 RPI $0.38 freemium vs $3.09 hard; Social & Lifestyle download→paid D35 median 0.9% (p90 5.5%). Blended revenue per install for a freemium wardrobe app is therefore **$0.10–0.50 in the first two months** — which is why AI cost per *free* user must stay ≲ $0.30/month and per paid user ≲ 25% of net price.
- Whering claims CAC ≈ £0.40 with 80–100% organic; at that CAC a $0.30/mo free-user AI cost is the dominant variable cost.

### 3.3 Gating rule set (recommendation)

1. **Free forever, unmetered (cheap, ≤ $0.01/action)**: unlimited items and ingestion with on-device masks (server-side attribute tagging is ~$0.003/photo — cap generative clean-up at e.g. 20/month), daily outfit-of-the-day as text + deterministic collage, calendar/wear log/cost-per-wear, packing lists, 1 stylist chat thread/day (≈ $0.03/day worst case), weather.
2. **Metered by credits ("Looks")**: anything that produces a generated image — on-body try-on (5 credits ≈ $0.09 cost), 512-px outfit preview render (2 credits), generative clean-up (1 credit), twin regeneration (5). Server-side ledger (Firestore transaction / Postgres `UPDATE … WHERE balance >= cost RETURNING`), idempotency key per action, refund on terminal failure, price list in Remote Config (`backend-architecture.md` §4).
3. **Subscription = monthly credit allowance + unmetered cheap features + premium quality** (Pro image model, 2K exports, no watermark on shared cards). Consumable top-up packs for overflow (non-expiring — Guideline 3.1.1: "Any credits… purchased via in-app purchase may not expire").
4. **Cost controls**: per-uid and per-App-Check-token rate limits; monthly budget alerts on the Gemini project; Remote Config kill switches per feature; resolution/model downgrade tiers per plan; Batch API (−50%) for bulk imports and off-peak pre-rendering of tomorrow's look; cache (person, garment) render pairs by content hash; verifier retries capped at 1; free-tier renders at 512 px only.
5. **Guardrail metric**: Gemini cost per new subscriber alongside conversion in every paywall experiment (`backend-architecture.md` §9).

---

## 4. Retention loops

Evidence and mechanics (H/M unless noted):

- **Activation threshold**: Whering's founder: retention improves "exponentially" once a user has digitized **40 items**; Acloset CEO: "a whole new world opens up… more than 50 items"; Indyx blog: average wardrobe ≈175 items, a 100-item cap kills adoption. Everything in onboarding should converge on 40 items within 7 days (`loomies-16` §1.1, `competitors.md` §6). **M** (founder self-report).
- **Category retention reality**: Acloset ~11% MAU/registered (4.5M / 500K); Style DNA ~9.4% active/downloads at peak; no wardrobe app publishes retention; cross-category D30 median ≈ 4% (strong line 5–8%); Lifestyle D1 20.9% / D30 4.5% (Statista via `furiai-benchmarks.md`). `loomies-23` §1–2.
- **Daily outfit-of-the-day push (weather-aware)**: Cladwell's most-loved form is "3 outfits today + one-tap reset" ("I open the app and get dressed. Done."); Alta's daily push is 8% of 5★ mentions; Essembl's "My Essembl" daily outfits drew a complaint that they "don't generate until around 5pm" → **pre-render overnight at a low-traffic hour so the card is already there at 7 am** (`solo-dev-playbook.md` §10). Weather correctness is a top 1★ trigger (Acloset "wool in 82°F", Cladwell "weather stuck", Essembl "never accurate for my location") — show the temperature on the card. Airship 2026 (via `solo-dev-playbook.md`, **L**): right-time send +51.7% CTR; a single personalised push in week 1 → +71% 2-month retention; best hours 8–9 am / 6–8 pm; kill templates <1.5% CTR. Guideline 5.1.2(i): push cannot be required.
- **Veto is mandatory**: every surviving "dress me" product keeps a cheap veto (Cladwell 3-of-1 + reset, Alta restyle, Stitch Fix returns); "swap this piece"/"another look" must be one tap; track **wear-as-is rate** (>30% = autopilot segment is real; <10% = demote push to a planning reminder) (`loomies-22` §5.3).
- **Calendar**: Acloset and Alta read the schedule for occasion; PutTogether reads the calendar ("occasion without user effort"); Indyx's 5★ reviews are calendar-driven working-women mornings; calendar-as-source-of-stats (Stylebook) makes the wear log the aha. EventKit read access needed (`ios-platform.md` §6).
- **Streaks**: Essembl added Outfit Check "daily streaks"; Duolingo-style streaks work when tied to a real daily ritual (log today's outfit), not to consumption. No category-specific streak lift data found (**gap**).
- **Widgets**: Alta ships a home-screen widget; Essembl a "Daily outfit widget" (with loading complaints); Ojo's teardown argues "widget-first" positioning ("the outfit app you never have to open") is unclaimed; a practitioner claims one widget redesign raised D7 retention "by several percentage points" (Stormy/Freecash, **L**). WidgetKit + Lock Screen accessories + Live Activity for batch-cutout progress (`BGContinuedProcessingTask`, iOS 26) — Guideline 2.5.16 widgets must relate to app content (`ios-platform.md` §6).
- **"What should I wear" Siri shortcut**: App Intents (`AppIntent`, `AppShortcutsProvider`), only intents the app can fulfil (2.5.11); Visual Intelligence `IntentValueQuery` (iOS 26) lets the system camera search the wardrobe ("find this jacket in my closet"); no competitor has a voice-first ritual (`competitors.md` §4.12). Hebrew not supported by Apple Foundation Models → fall back to Gemini.
- **Social sharing of outfit cards**: Whering's growth came from users' own closet videos; Indyx's "outfit selfie" and Alta's "Best Dressed" are share surfaces; Ojo's teardown: "the output is the marketing" — make exactly one artefact postable (a 1080×1920 story card; PutTogether's named archetypes get screenshotted). Free tier shares with a small watermark; Plus removes it (Photo & Video pattern: "gate the SAVE/EXPORT step, not the create step" — `quiz-teardowns.md` Pattern D). Weekly recap ("Unpacked", Spotify-Wrapped style) is Whering's periodic hook.
- **TikTok-friendly outputs (outfit battle / roast)**: Combyne's daily themed outfit challenges with votes are its main retention engine (86.8k ratings, teen audience); Essembl's founder account is most of its TikTok footprint; "outfit check/rate my fit" content is already a genre — an AI "roast my fit" or "A vs B battle" card is cheap ($0.004 text or one render) and inherently shareable, but the category evidence says the 25–45 professional segment shares far less than Gen Z (`loomies-16` §5.2). Treat as acquisition content, not core retention.
- **Data trust as retention**: two data wipes turned Smart Closet (1M installs) into a zombie; export (ZIP/CSV) and CloudKit sync are retention insurance (`competitors.md` §8).

---

## 5. Acquisition

### 5.1 ASO (first-hand iTunes Search API snapshots, US, 2026-07-21/22 — **H**)

- "outfit planner" top 10: Whering (4.67★/10,756) → Fits (4.61/4,707) → Combyne (4.76/86,836) → Alta (4.88/10,783) → Pureple → Indyx → My Wardrobe → Stylebook ($4.99) → **Essembl (4.57/2,062)** → Acloset. "digital closet": Whering → Alta → SimpleCloset → Indyx → Fits → Clozzie. "wardrobe app": Whering → Fits → Indyx → Alta → Wardrobe Fashion → Stylebook. Head terms are locked by 4 free, high-rated apps; **ASO is defence, not a growth engine**; target long-tail combos: "work outfit planner", "closet inventory", "capsule wardrobe planner", "clothing organizer", "what to wear today", "outfit ideas from my clothes", "virtual try on my clothes", "AI wardrobe app", "outfit generator from my clothes" (`loomies-16` §3, `loomies-23` §4, `closet-os-marketing.md`). Keyword volumes could not be retrieved (Apple Ads console needed).
- Rating velocity is the growth signal: Alta +79 ratings/day, Whering +21/day, Essembl +67/day (two-snapshot caveat), Fits +8, Stylebook +2 (`loomies-23` §2).
- Listing rules from 2026 ASO data (`solo-dev-playbook.md` §4, **L**): first 3 screenshots gate install; social proof on screenshot 1 lifts conversion up to 90%; App Store page→install ≈ 25–27%, impression→install 3.6–3.8% (Adapty 2026-01, **M**); don't bid "free X" keywords; mine competitors' 1★/3★ reviews for listing copy (Essembl's: "your real clothes, not AI look-alikes"; "see everything before you pay"; "no selfie, no card to start").
- Apple rebranded Apple Search Ads to **Apple Ads** (April 2025); up to **2 ads per search query rolling out March 2026**; Creative Sets deprecated in favour of Custom Product Pages (up to 70); 78% of App Store search volume comes from devices with Personalized Ads off (`ads-apple-skill.md`, **L**).

### 5.2 Paid UA benchmarks

| Channel | Benchmark | Source / conf |
|---|---|---|
| Apple Ads (search results), all categories 2025 | TTR 9.7%, CVR 66.2%, **CPT $2.25, CPA $3.76** | SplitMetrics 2025 data (pub. 2026-02) via `loomies-23` and `ads-apple-skill.md` — **M** |
| Apple Ads, **Lifestyle** category | CPT $0.80–1.80, TTR 2–3.5%, install CVR 45–60%, **target CPI $2–5**; Shopping CPT $0.80–2.00 (AppTweak Shopping CPT median $2.05, 2025); Tier-1 countries CPT 2–3× global | practitioner skill 2026-04 — **L** |
| Meta CPI | $1–5 normal, $10+ competitive; US Meta CPM $10–15, apparel CPC $1.07 / CTR 1.14% → CPI ≈ $3–4.5 | WASK / Affect Group Q1 2026 / LocaliQ via `loomies-23` §3 — **M** |
| US all-channel avg CPI | $5.28 (2024); iOS global CPI $1.50–3.50; NA $2.50–5.00; TikTok Ads CPI $0.50–2.50 (2025 series $1.75–4.00); Facebook $1.00–3.00 | Linkrunner / Business of Apps 2025-02 via `furiai-benchmarks.md` — **M** |
| Wellness-app CPI | $1.50–4.00 | `soma-app` plan — **L** |

Unit-economics verdict (`loomies-23` §3): at 2.5% install→paid × $40/yr = $1/install vs CPI $3–4.5, paid UA is 3–4× under water even before Apple's cut → **Meta/TikTok only as $500–1k signal tests optimised for `trial_started`, not scale**; Apple Ads long-tail is the only paid placement that can approach payback; structural priority is organic.

### 5.3 Organic / earned / UGC / referral

- **Whering**: "over half a million installs a month, entirely free"; "80–100% of traffic organic"; "CAC of forty pence"; "a couple of hundred thousand downloads from a single TikTok video" (user-made, not the brand account); path = Vogue/Harper's/Forbes press → creators → TikTok closet videos (`loomies-16` §1.1, founder interview, **M**).
- **Indyx**: NYT Wirecutter feature 2026-05-07 + stylist-blogger deep reviews + SEO blog ("The Best Wardrobe Apps" page ranks the category term); only 1.4k ratings but the highest-authority backing — for 25–45 professionals, Wirecutter-type reviews outweigh TikTok virality.
- **Fits (US)**: founded off a viral TikTok; official account 109 followers → brand accounts don't drive installs, users' closet content does.
- Content pools: #capsulewardrobe 1.08B+ TikTok views; #closettour 468.9k posts; IG closet-tour reels 116k; YouTube capsule creators (Audrey Coyne 827k subs) — no public app-partnership ROI (`loomies-16` §2). Recommended creator format: "digitize my closet with me" / 30-day challenge with per-creator onboarding codes; 5–10 mid-tier (10–100k) creators, not head creators.
- **Stylist / professional-organizer channel**: GetWardrobe Stylist Mode ($69.99/mo) and Indyx's stylist marketplace prove a B2B2C path; no wardrobe app has entered the NAPO organizer channel (`loomies-16` §4). Seed plan: 10–20 stylists/organizers × 15–30 clients each.
- **Reddit**: r/femalefashionadvice, r/AskWomenOver30, r/capsulewardrobe host the "Indyx vs Whering" comparison threads; users state data export and no item cap as prerequisites.
- **Referral**: Essembl grants a subscription for 3 invites (`essembl-features.md` §2); CLOSET.OS plan targets 30% referral-driven signups via "refer 3 friends → skip the waitlist"; Adjust: only 30% of apps have a measurable k-factor, median **k = 0.45** among those; k 0.15–0.25 "good", 0.4 "great" (`furiai-benchmarks.md` §4). Reasonable target: k ≥ 0.2 from share cards + "style your friend" invites; reward with credits (Looks), not subscription time (keeps Apple billing clean and cost-bounded).
- **Web funnel**: Style DNA's web-billed funnel ("doesn't show in Apple subscriptions, can't cancel") is the category's worst trust failure; RC's IAP-vs-web A/B: IAP-only netted more than web-only even after Apple's cut (`quiz-benchmarks-2026.md`). Keep 100% Apple IAP at launch.

---

## 6. Analytics KPIs and target funnel numbers

Funnel: install → onboarding complete → wardrobe digitized (3 → 40 items) → first outfit → (share/widget/push opt-in) → trial → paid → renewal. Targets below combine category anchors (§1–2), the launch-baseline file (`loomies-23` §0, GO/watch/FAIL bands) and practitioner bands (`eronred-*`, `solo-dev-playbook.md`). Beta/TestFlight cohorts read 1.5–2× higher; paid-UA cohorts lower — read organic cohorts only.

| Stage / metric | Target (GO) | Watch | FAIL / re-plan | Anchor |
|---|---|---|---|---|
| App open → first interaction | ≥85% | 70–85% | <70% | practitioner (**L**) |
| Onboarding completion (≤5 questions, price shown) | ≥70% | 50–70% | <50% | Quiver real-world 80% on a short flow; industry avg ~34% (**M/L**) |
| Install → first outfit shown (D0, zero-catalog/seeded) | ≥50% | 30–50% | <30% | PutTogether "portrait before paywall"; Ojo zero-catalog spec (**L**) |
| Install → 3 items digitized | ≥40% | 25–40% | <25% | `loomies-23` |
| **Install → 40 items within 7 days (north-star activation)** | ≥20% | 10–20% | <10% | Whering 40-item threshold; activation median 25% (**M**) |
| Push opt-in (pre-permission screen, after first outfit) | ≥50% (Blinkist timeline: 74%) | 30–50% | <30% | practitioner; Blinkist case (**M**) |
| Widget installed by D7-retained users | ≥25% (set after 4 weeks) | — | — | no public benchmark (**inferred**) |
| Outfit card share rate (WAU) | ≥8–10% | — | — | inferred |
| D1 / D7 / D30 retention (all installs) | ≥30% / ≥12% / ≥8% | 20–30 / 8–12 / 4–8 | <20 / <8 / <4 | UXCam/Adjust medians 25/8/4; Lifestyle D30 4.5% |
| D30 retention, activated (≥40 items) | ≥30% | 15–30% | <15% → core loop falsified | `loomies-23` (inferred) |
| Wear-as-is rate on daily push; "another look" rate | ≥25% adoption; swap rate <60% | — | swap >60% = naive generator | `loomies-22`/`23` |
| Install → trial start (annual-only 7-day trial, soft paywall at activation) | ≥5% | 2–5% | <2% | NA Social & Lifestyle median 1.9% (freemium), NA overall 7.1%, Adapty NA 14.5% (**M**) |
| Trial → paid | ≥35% | 25–35% | <25% | NA Social & Lifestyle 38.3%; 5–9-day trials 37.4% (**M**) |
| Install → paid D35 (freemium) | ≥2.5% | 1–2.5% | <1% | RC freemium median 2.1%, Lifestyle 0.9%, p90 5.5% (**M**) |
| Annual share of new subscriptions | ≥60% | 40–60% | <40% (onboarding failed to sell) | RC: annual preselect → 60–70% annual; H&F 68% annual (**M**) |
| Paid monthly churn | <7% (m3) → <5% (m12) | — | >10% | RC monthly 12-mo retention 17%, annual 44% (**M**) |
| Refund rate | <3% | 3–5% | >5% | RC Social & Lifestyle median 3.34% (**M**) |
| Involuntary churn recovery | ≥30% of billing failures | — | — | practitioner; Apple 14% of cancels are billing (**M**) |
| AI cost per MAU (blended) / per paid user | ≤$0.40 / ≤$1.50 | — | >$0.60 / >$2.50 | `backend-architecture.md` §8 |
| Gemini cost per new subscriber | track per experiment | — | — | guardrail metric |
| CPI guardrail (tests only) | ≤$5; $/activated user ≤$25 | — | stop spend | `loomies-23` §0 |
| Price-related share of 1★ reviews | <5% | — | >10% two weeks → roll back price | `loomies-21` §4 |
| k-factor | ≥0.2 | 0.1–0.2 | — | Adjust median 0.45 among apps with any (**M**) |

Event spec (minimum): `install`, `onboarding_step`, `price_card_viewed`, `first_outfit_shown`, `item_added` (count), `activation_40_items`, `outfit_generated` (mode: text/collage/render/tryon; credits), `outfit_worn_as_is`, `outfit_swapped`, `push_permission`, `widget_added`, `card_shared`, `siri_intent`, `paywall_viewed` (placement, variant), `trial_started`, `paid_started` (plan), `credits_purchased`, `credits_debited`, `renewal`, `cancel_intent`, `refund`, plus per-call `usage_log` (model, tokens, cost, prompt_version). Read RevenueCat webhooks (`INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `BILLING_ISSUE`, `EXPIRATION`, `REFUND`) into the same warehouse.

---

## 7. Tools

| Tool | What it does for this app | Facts / status | Conf |
|---|---|---|---|
| **RevenueCat** (`purchases-ios`, Swift, iOS 13+, SPM mirror `purchases-ios-spm`) | Server-side receipt validation; entitlements; Offerings/Placements (different offering per paywall location); **Paywalls** (remote, no release); **Experiments** (server-side A/B on offerings, LTV-aware); **Targeting** (country, platform, app version, custom attributes; win-back for expired); **Customer Center** (in-app manage/cancel with survey + retention offers, promotional offers); webhooks; Web Billing. Codelab guidance: "personalizing… with a user's first name can boost conversions up to 17%"; "paywall experiments… up to 40%". Recent changelog: RevenueCatUI web-view paywalls, rules engine operators, Customer Center shows one-time purchases. | Pricing: free up to ~$2.5k monthly tracked revenue then ≈1% of MTR (two 2026 docs); one 2026 playbook says "free up to $10K MTR" — **unconfirmed; verify at revenuecat.com/pricing** | **H** features (README/codelab) / **L** pricing |
| **Superwall** (`Superwall-iOS` v4, iOS 13+) | Remote paywall editor + placements ("register" events), paywall A/B, trial-start/conversion analytics, transaction-abandon paywalls, **free-trial reminders** feature, works alongside RevenueCat or StoreKit | Pricing not retrievable (site blocked) — **unconfirmed**; a 2026 playbook claims "free tier covers first 1K trials" for Adapty/Superwall | **M** features / **L** pricing |
| **Adapty** (`AdaptySDK-iOS`, MIT) | No-code Flow/Paywall Builder, native rendering, price/duration/offer A/B without release, real-time analytics by attribution/segment, cross-platform sync, paywall library | Pricing not retrievable — **unconfirmed** | **M** |
| **Firebase Remote Config + A/B Testing + Analytics** | Free; real-time config; drive model IDs (Gemini deprecation cadence: `gemini-2.5-flash-image` dies 2026-10-02), prompt versions, credit prices, allowances, kill switches, resolution tiers, rollout %; A/B paywall variant id with Analytics conversion event from RC webhooks; personalization | `backend-architecture.md` §2/§9 (**M**) | **M** |
| Native alternative | StoreKit 2 `SubscriptionStoreView(groupID:)`, `SubscriptionOfferView`, `Transaction.currentEntitlements`, `beginRefundRequest`, App Store Server Notifications V2 via `apple/app-store-server-library-swift`; win-back offers (iOS 18+) | `ios-platform.md` §7 | **H** |
| Analytics | Firebase Analytics/Crashlytics (free) + PostHog (≤1M events free) or Mixpanel; BigQuery billing export + usage_log for cost per feature/cohort | `backend-architecture.md` | **M** |
| Push | APNs/FCM (free); OneSignal free to 10k subscribers (**L**) | | |

Recommendation: RevenueCat as the billing/entitlement source of truth (webhooks grant credits on renewal), RevenueCat Paywalls + Experiments for the first 6 months (single vendor, no extra SDK), Superwall only if placement-level paywall iteration becomes the bottleneck; Remote Config for everything AI-cost related; Customer Center for cancel/refund flows (directly answers Essembl's support complaints). Enrol in the Small Business Program (15%).

---

## 8. Risks

### 8.1 App Store rules (guideline text in `ios/guidelines.txt`; **H**)

- **3.1.1**: all unlocks via IAP; **"Any credits… purchased via in-app purchase may not expire"** → consumable credit packs must be non-expiring (monthly allowances that are part of a subscription are a different construct — describe them as included usage, and keep purchased packs perpetual); restore mechanism required; tips allowed.
- **3.1.2(a)**: subscription period ≥7 days (no daily plans), ongoing value, works across the user's devices; may bundle consumable credits with a subscription; **(b)** seamless upgrade/downgrade, no accidental double subscriptions (one subscription group); **(c)** clearly describe what the user gets before subscribing; anti-scam clause (bait-and-switch, false pretenses) → removal.
- **2026 enforcement**: free-trial toggles rejected; delayed close buttons, tiny pricing, stacked paywalls, guilt copy are rejection correlates (**M**).
- **2.3.2**: description/screenshots must indicate which features need purchase (Essembl reviewers' "false advertising" complaint is a 2.3.2 risk). **2.3.1**: promoting a false price is grounds for removal (discount theatre).
- **5.1.1**: data minimisation, consent for photos/selfies; **5.1.1(v)** account deletion; **5.1.2(i)**: cannot require push/location/tracking; ATT for any tracking. **2.5.11** Siri intents only for things the app does; **2.5.14** camera consent + indicator; **2.5.16** widgets relate to content; **2.5.18** if ads: no sensitive-data targeting.
- Code of Conduct: no tricking users into purchases, tricky price rises, charging for undelivered features — the exact Essembl complaint set.
- Practical: annual price-increase flows require user consent via StoreKit; grandfather existing subscribers; avoid simultaneous per-user price A/B in this category (Style DNA / GetWardrobe "same product, different price" backlash) — prefer phased pricing (`loomies-21` §4).

### 8.2 Refund abuse

- Category refund medians (RC 2025 NA): Social & Lifestyle **3.34%**, Shopping 2.24%, H&F 4.71%; transaction-abandon-paywall buyers refund at 3.3% vs 6.8% (Superwall). Apple refunds revoke entitlements (`Transaction.revocationDate`, `REFUND` server notification; `didRevokeEntitlementsForProductIdentifiers`) — `ios/apple-dev-docs` (**H**).
- Exposure specific to credits: a user can buy a pack, burn renders, then refund. Mitigations: debit the credit ledger on `REFUND`/`REVOKE` (allow negative balance, block further generation), never grant unlimited renders on trial (allowance ≤ what the trial should demo), respond to Apple's consumption requests (App Store Server API "Send Consumption Information" within the ~12-hour window after `CONSUMPTION_REQUEST` — **L/memory**, verify), keep a per-account lifetime refund counter, and reduce "buyer's remorse" refunds with a post-purchase reinforcement screen (Duolingo/Opal pattern) and Blinkist-style trial reminders (−55% complaints).
- Weekly plans and card-required 3-day trials without reminders are the category's billing-dispute generators (Essembl "$80", Pureple "$95.39", Style DNA web billing).

### 8.3 AI cost spikes and model risk

- Heavy users at $0.9–1.8/mo exceed net annual revenue ($2.83/mo); a viral moment on the free tier multiplies free-user cost (PutTogether's server-side illustration "could be financially painful" in a viral spike — `ojo-puttogether.md`). Controls: allowances + credits, per-uid rate limits, budget alerts, kill switches, batch/off-peak rendering, 512-px previews, caching, verifier-retry caps, and a "render on tap" default rather than auto-rendering every suggestion (`backend-architecture.md`, `steam-vto-cost.md`).
- Model churn: Gemini image model IDs deprecate on ~12-month cycles (preview IDs died 2026-06-25; `gemini-2.5-flash-image` shutdown 2026-10-02) — IDs must live in Remote Config; provider outage fallbacks (FASHN/fal) with different privacy terms (fal stores payloads 30 days unless `X-Fal-Store-IO: 0`).
- Quality risk is also cost risk: users refund and 1★ when renders "don't look like me"/replace real garments (Essembl's most damaging review) — keep original pixels for the wardrobe and reserve generative output for try-on/previews.
- Platform risk: Google Photos "Wardrobe" (announced 2026-04-29) and Search/Shopping try-on make photo try-on free infrastructure; moat must be closet data + the daily ritual, not pixels (`competitors.md` §7).

---

## 9. Recommendations

### 9.1 Pricing (launch, US; phased tests after 6 weeks)

| Tier | Price | Includes | Rationale |
|---|---|---|---|
| **Free** (no card, no account required) | $0 | Unlimited items; on-device cutouts + AI tags (generative clean-up 20/mo); daily weather-aware outfit-of-the-day (text + collage) with one-tap swap; calendar/wear log/cost-per-wear; packing lists; 1 stylist-chat thread/day; widget + Siri; **3 on-body "Looks" at signup (the wow before any paywall) + 1 Look/week**; shared cards carry a small watermark | Matches the "unlimited items, free" entry ticket of the 4.7–4.9★ apps; keeps free-user AI cost ≈ $0.10–0.30/mo; answers Essembl's #1 complaint |
| **Plus** | **$7.99/mo** or **$39.99/yr** (≈ 42% of 12× monthly, "under $3.40/month"), **7-day free trial on annual only**, annual preselected, monthly visible, **no weekly SKU** | **40 Looks/month** (on-body try-on, 2K previews), unlimited collage previews, stylist chat unlimited (fair use 50 msgs/day), Pro model for try-on, watermark-free share/export, occasion planner + calendar auto-outfits, priority processing | Monthly sits under the $8 resentment line and at the AI-app price tolerance; annual lands inside the $30–50 WTP band and at the AI-wrapper market's $30–40/yr settling point, above GetWardrobe ($34.99) and below Acloset Premium ($59.99)/Indyx ($74.99); high-tier pricing earns ~6× low-tier LTV (RC 2026); trial on annual only is the category norm and the Adapty/Superwall recommendation; 7 days (37.4% median trial→paid) rather than 3 (55% day-0 cancels) |
| **Look packs** (consumable, non-expiring) | **20 / $4.99, 60 / $11.99, 150 / $24.99** ($0.17–0.25 per Look vs ≈ $0.09 cost → 55–65% gross margin after 15%) | Overflow for Plus and for free users who want more try-ons without subscribing | Category credit price band $0.09–0.40; non-expiry satisfies 3.1.1; keeps the base price honest ("add-on packs at >95% margin save the cancel flow" — RC 2026 playbook) |
| Later (month 6+) | "Core" one-time $9.99 unlock for local premium analytics/fit tools; family plan; annual price test $34.99 vs $39.99 vs $49.99 (phased, grandfathered) | | Buy-once vacuum $5–15; RC: family plans +52% retention |

Paywall mechanics: value-first **soft** paywall shown at the first activation moment (after the first on-body Look), dismissible, 2 plans, "Most popular" on annual, per-month framing of annual, Blinkist timeline (Today → Day 5 reminder → Day 7 charge) with local notification, "No commitment, cancel anytime", generic "Continue" CTA, bullet benefits (no comparison table), SwiftUI-native look, price shown on onboarding screen 2–3, ≤5 quiz questions, no selfie/email before value; exit drawer with monthly only (no discount on main paywall; a one-time 25–33% welcome offer to non-converters after 24 h is optional and must show a real reference price). Max 2 paywall exposures per user per week; contextual paywall only when a Look is requested with 0 credits.

### 9.2 Credit model ("Looks")

- 1 Look = 5 credits internally; try-on 1K = 5, twin regeneration = 5, 2K outfit preview = 2, 512-px preview = 1, generative clean-up = 1, text/collage outfit = 0 (unmetered, fair-use), chat = 0 (rate-limited).
- Grants: signup 15 credits (3 Looks); Plus renewal 200 credits/month via RevenueCat webhook (unused included credits roll over ≤1 month; purchased pack credits never expire); referral 25 credits per activated invitee (cap 5); share-card virality bonus optional.
- Ledger: append-only `credit_ledger` with reasons (grant_signup, grant_renewal, purchase, referral, job_debit, refund, revoke, admin); debit atomically at job creation with idempotency key; refund on terminal failure; negative balance on Apple refund/revoke.
- Economics check: Plus monthly net $6.79 − worst-case allowance cost 40 × $0.09 = $3.60 → still ≥47% margin at the cap; expected median use ~10–15 Looks → cost $0.90–1.35; annual net $2.83/mo → margin positive at median, negative only for cap-maxers on annual (accept; monitor P90 and lower annual allowance to 30/mo if P90 > 30). Free cohort ≈ $0.10–0.30/mo.
- All prices/allowances in Remote Config; kill switch to 512-px or FASHN fallback; batch pre-render of tomorrow's collage (not on-body) at −50%.

### 9.3 First-90-day growth plan (organic-first)

1. Pre-launch: 10–20 stylist/organizer seeds (free Plus + client workspace promise), TestFlight waitlist with "refer 3 → skip the queue", three Reddit communities, position statement ("your real clothes, not AI look-alikes; see everything before you pay").
2. Launch: ASO on long-tail terms; screenshots lead with the on-body Look + social proof; Apple Ads exact-match long-tail with CPA goal ≤$5/install, pause anything >2× target; $500–1k Meta/TikTok creative test optimised for `trial_started`.
3. Content: 5–10 mid-tier creators on "digitize my closet with me"; one postable artefact (outfit story card / weekly recap); pitch Wirecutter/Verge/Lifehacker with the privacy + honesty angle.
4. Weekly readout against §6 bands; one paywall/onboarding experiment per 2 weeks; no price A/B across users, only phased changes with grandfathering.

---

## 10. Open questions / gaps

- Exact current US Essembl SKUs (weekly price, whether $29.99/yr is still live vs the "$39/$50" reviewers cite) — page blocked; region/A-B dependent.
- RevenueCat/Superwall/Adapty 2026 pricing tiers — unconfirmed (two candidates for RC: free to $2.5k MTR then 1%; "free up to $10K MTR").
- Apple Ads keyword volumes/CPT for the specific long-tail terms — needs the Apple Ads console after launch.
- No public retention data for any wardrobe app; 40-item threshold is a single founder claim; wear-as-is/widget/streak lift numbers do not exist for this category — calibrate all "inferred" targets after 4 weeks of own telemetry.
- Vertex `virtual-try-on-001` per-image price still unconfirmed.
- Whether the Lifestyle "direct buyers > trial users" finding (Adapty) holds for an AI-image app — run a no-trial vs annual-trial experiment once volume allows (≥200 subs/variant).

## 11. Source index

Local first-hand/secondary research (scratchpad): `research/competitors.md`, `essembl-reviews.md`, `essembl-features.md`, `gh/loomies-16-growth.md`, `gh/loomies-21-pricing.md`, `gh/loomies-22-redteam.md`, `gh/loomies-23-baseline.md`, `gh/lopesloro-precos.md`, `gh/dripmatiq-blog.md`, `backend-architecture.md`, `gemini-image-gen.md`, `virtual-try-on.md`, `gh/steam-vto-cost.md`, `ios-platform.md`, `ios/guidelines.txt`, `ios/apple-dev-docs` (StoreKit revocation docs).

GitHub-hosted syntheses downloaded 2026-09-05 to `research/growth/` (with the primary URLs they cite):
- RevenueCat State of Subscription Apps 2025 PDF extraction — https://www.revenuecat.com/pdf/state-of-subscription-apps-2025.pdf (via best-trading-indicator-tools/devrel-hackaton-adapty)
- RevenueCat State of Subscription Apps 2026 — https://www.revenuecat.com/state-of-subscription-apps/ ; 10-minute summary https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026/ ; renewal rates by category https://www.revenuecat.com/blog/growth/average-subscription-renewal-rates-by-app-category ; R.I.P. toggle paywall https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/ ; paywall tests https://www.revenuecat.com/blog/growth/paywall-tests-grow-app-revenue/ ; IAP vs web test https://www.revenuecat.com/blog/growth/iap-vs-web-purchases-conversion-test/ (via Nikolai-Iakubovskii/app-paywall-pilot, gquthier/autonomous-quiz-funnels, omkardharmesh/paramathma, Teamz-Lab-LTD, pfurini/furiai-skills)
- RevenueCat Monetization Strategies codelab — https://github.com/RevenueCat/codelab (rc/monetization-strategies/codelab.md)
- RevenueCat iOS SDK README/changelog — https://github.com/RevenueCat/purchases-ios
- Adapty State of In-App Subscriptions 2026 — https://adapty.io/state-of-in-app-subscriptions/ ; paywall experiments playbook https://adapty.io/blog/paywall-experiments-playbook/ ; toggle rejection https://adapty.io/blog/your-toggle-paywall-is-about-to-get-rejected/ ; H&F benchmarks https://adapty.io/blog/health-fitness-app-subscription-benchmarks/ ; App Store conversion https://adapty.io/blog/app-store-conversion-rate/
- Adapty iOS SDK README — https://github.com/adaptyteam/AdaptySDK-iOS
- Superwall product-count study https://superwall.com/blog/how-many-products-should-you-offer-on-your-paywall ; abandon paywalls https://superwall.com/blog/17-revenue-boost-with-transaction-abandon-paywalls-a-case-study/ ; free-trial reminders https://superwall.com/features/free-trial-reminders ; Superwall-iOS README https://github.com/superwall/Superwall-iOS ; podcast "I made 4,000 app paywalls" (2026-02-08, via BrandonKimble/Crave)
- Blinkist honest paywall — https://growth.design/case-studies/trial-paywall-challenge
- Apple App Review Guidelines — https://developer.apple.com/app-store/review/guidelines/ (local text copy); Apple auto-renewable subscriptions https://developer.apple.com/app-store/subscriptions/ ; Small Business Program https://developer.apple.com/app-store/small-business-program/
- SplitMetrics Apple Search Ads cost benchmarks (2025 data, pub. 2026-02) and AppTweak CPT (via yahav123147/paid-ads-cro-skills ads-apple skill and loomies-23)
- Business of Apps CPI research (2025-02) https://www.businessofapps.com/ads/cpi/research/cost-per-install/ ; Adjust retention handbook https://www.adjust.com/resources/guides/user-retention/ ; Adjust k-factor via pfurini/furiai-skills
- Whering founder interview — https://earlyrounds.co.uk/conversation/bianca-rangecroft-whering ; NYT Wirecutter Indyx review https://www.nytimes.com/wirecutter/reviews/indyx-digital-wardrobe-app-review/
- PutTogether teardown — mikedeleamon/Ojo docs/competitive-puttogether.md (2026-08-16); CLOSET.OS marketing plan — lucylow/complete-dev-closet-os
- Airship push benchmarks 2026 and ASO 2026 rules via omkardharmesh/paramathma solo-dev playbook (practitioner compilation)
