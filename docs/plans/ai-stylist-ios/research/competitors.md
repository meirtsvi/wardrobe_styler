# AI wardrobe / outfit planner / virtual stylist — feature universe (as of 2026-09-05)

## 0. Method, sources, and confidence caveats (read first)

- WebSearch budget for this session was already exhausted (200/200) before this task started, and the egress proxy blocks essentially every vendor site, app-store mirror, press site and archive (all returned 403 on CONNECT). Only github.com / raw.githubusercontent.com (and cloud.google.com, which 404'd on the page needed) were reachable.
- Evidence therefore comes from **third-party competitor-research documents committed to public GitHub repos in 2026** (most compiled from first-hand iTunes Lookup API / App Store review-RSS / official-site fetches, dated 2026-02 to 2026-08), plus the Essembl review file already in this scratchpad, plus model knowledge (cutoff June 2026) used only to fill labelled gaps. Every non-obvious claim below cites the GitHub doc (which in turn cites the primary URL) and carries a confidence tag.
- Local copies of every source doc: `<session-scratch>/research/gh/`. Key files: `loomies-01/13/14/15/21/04/16/23-*.md` (huhuhulululu/Loomies, 2026-07-21/22, first-hand iTunes API + review RSS), `dotfyles-india-market.md` (HarshalRathore/dotfyles, 2026-08-15, iTunes API + Play pages), `culcept-competitors-2026.md` (2026-03-17), `capsulezero-ux-validation.md` (Feb 2026 review mining), `vestia-benchmark.md` (July 2026, French), `lopesloro-concorrentes.md` (2026-08-11, Portuguese), `plechiki-competitive.md` (Apr 2026, store-listing facts), `dollrobe-research.md` (2026-03-24), `styledna-analysis.md` (2026-07-28), `tryit-provider-survey.md` (2026-06-16, VTO API prices), `fashioncoach-vto.md` (2026-04-10), `steam-vto-cost.md` (2026-08-19), `headcutter-alta.md` (2026-03-08), `techcrunch-googlephotos-wardrobe.md` (2026-04-29), `doppl-launch.md` (2025-06-26), `dressapp-import.md`, `dripmatiq-blog.md` (2026-07-04), `tshuldberg-mycloset.md` (2026-02-22).
- Prices are US App Store snapshots (mostly 2026-07-21/22 and 2026-08-15) and change often; the category has shown 30-40% price increases over two years (Pureple). Re-verify on device before quoting publicly.
- Vendor user counts ("10M users", "7M users") are marketing claims, unverified.

Confidence legend: **H** = first-hand store/API data or official docs cited by the source doc, corroborated by 2+ independent docs; **M** = single doc or secondary source; **L** = model knowledge or contested/unconfirmed.

---

## 1. Per-app profiles

### 1.1 Whering (Whering Ltd, London; iOS/Android/web app since 2024; Chrome extension)
- **Core**: digital closet; "Dress Me" shuffle (category sliders + shuffle, Clueless-inspired); outfit planner/calendar; packing lists with packing reminders; lookbooks/moodboards/wishlists; cost-per-wear, wear rate, "intake tracking" (new vs pre-loved), wardrobe colour palette, "closet longevity"; "Unpacked" periodic wear recap (Spotify-Wrapped style); social: public profiles, friends style you / you style friends, copy items from friends' closets; sustainability framing (repair/resale/donation links, 60-day no-buy challenges). Sources: loomies-01, vestia-benchmark, plechiki, capsulezero-ux-validation. **H**
- **AI**: auto background removal + "Enhance" (turns snapshot into product-style image); auto-tagging (category, colours, style, fit, neckline, sleeve, pattern, occasion per capsulezero) — accuracy widely criticised ("colours random and very different from actual"); "W-Pick" weather-based AI suggestion; July 2026 release notes: "Planner now suggests outfits based on your wardrobe and the weather"; post-funding roadmap: mood/weather/occasion AI styling, retail-grade image enhancement, **camera-roll bulk extraction**, **virtual try-on**, in-app resale, chatbot "Mona". Sources: loomies-14 (release notes, funding stories), vestia-benchmark. **H/M**
- **Digitization**: photo + auto cutout; **batch from camera roll**; search a claimed "100M+ item" community/retailer database; add from retailer links; Chrome extension. One-item-at-a-time tag editing is a complaint; users request bulk edit. **H**
- **VTO**: none shipped as of 2026-07; explicitly in the $7M seed roadmap (2026-07-07, eBay Ventures + Google AI Futures Fund; cumulative ~$14M; 19 staff; "10M+" users claimed). **H**
- **Pricing**: fully free, no ads, **no subscription SKU**; monetises via consumable AI credits (10/$2.99, 50/$7.99, 100/$12.99 — "Style Pass"), a $4.99 one-time "Outfit Maker", and donation-style "Supporter" tiers $0.99–$49.99; affiliate shopping; long-term bet is recommerce/data (CEO: "not just what people buy, but what people actually wear"). An older £30/yr basic + £120/yr "Expert" + 100-item cap no longer appears in the US store (loomies-14/21). Capsule-zero's Feb-2026 note of "VIP £6.99/week" is unconfirmed/possibly stale. **H** (current) / **L** (historic tiers)
- **Platform**: iOS 4.67★ / ~10.8K US ratings (2026-07-22); Play ~4.3–4.5★ / 23–26K reviews; English-only UI. **H**
- **UX patterns**: 5 tabs (Thoughts feed / My Planner / Shop / Styling / Your Wardrobe); onboarding = account + style quiz, then push to mass cataloguing; stacked-carousel Dress Me; founder-stated retention cliff at **40 digitized items**. **M**
- **Weaknesses**: Dress Me "really random"; auto-tag/colour errors; imperfect cutouts and colour distortion from bg removal; crashes/duplication/slow loads (worse on Android); no data export; weather feature shipped then pulled then re-shipped; privacy is structural soft spot (data-monetisation model). **H**

### 1.2 Acloset (Looko Inc., Seoul; iOS/Android; 18 languages)
- **Core**: AI closet; daily outfit by **weather + calendar schedule**; outfit builder + "generate around this piece" with refresh; OOTD style calendar; wear stats (cost-per-wear, frequency, neglected items, spend); travel packing by trip-day weather; social outfit feed; AI stylist chat ("what should I wear today?", "make it more formal?"); personal colour + body/fit ("骨格") diagnosis (one free); AI shopping advisor / purchase check; multiple closets; secondhand marketplace was **closed 2024-07** in favour of AI recommendations. Sources: loomies-01/14, vestia, plechiki, culcept. **H**
- **AI**: best-in-class cutout + "Beautify" (re-rendered e-shop-quality image; Beautify Pro 2025-09) — but Beautify criticised for cartoonish detail loss and it consumes credits; auto-tag category/colour/season/style; **single full-body photo → avatar virtual try-on** shipped 6.28 (2026-07); recommendation engine "AI Upgrade" in late 2025 widely reported to have *degraded* results (wool in 82°F, mismatched temperatures shown in-app). **H**
- **Digitization**: photo (even on hanger/mirror), product screenshot, internal item search, **batch upload**, Chrome extension, **Gmail/order-history import (Amazon, Zara, Shein, ASOS…)**. CEO: "a whole new world opens up once you've added more than 50 items" (aha threshold). Complaints: extraction fails if other garments in frame; colours shift; free-tier cutout quality poor. **H**
- **VTO**: avatar-style try-on from one full-body photo (2026-07); earlier "virtual try-on" listed on Play. **H**
- **Pricing** (US App Store 2026-07-22): free up to **100 items** (hard cap, plus ads); Basic $3.99/mo or $27.99/yr; Premium $9.99/mo or $59.99/yr; Expert $24.99/mo or $147.99/yr; "beans" credits 100/$1.99 … 500/$9.99 for Beautify/try-on; a $100 lifetime mentioned in a review. Dec-2023 retroactive paywall (500-item users locked out of their data) is the most-cited trust break. **H**
- **Platform**: iOS 4.39–4.40★ / ~4.4K US ratings; Play 4.8★ / 38K+ reviews, 1M+ installs, Editor's Pick 2023; claims 7M users / 90M+ garments (site) vs 4.5M registered / 500K MAU (Korean press, 2026-02) → ~11% MAU/registered. **H**
- **UX patterns**: Closet / Outfit / Calendar / Feed / Profile; independent UX study scored navigation confusing (7.7/10); email-only sign-in complaint; 30 releases in 14 months. **M**
- **Weaknesses**: AI outfit quality ("nonsensical"), 100-item wall ("spent two hours uploading… max of 100 items"), ads (~20s interstitials on free), price doubled → cancellations, crashes on upload, cluttered social feed, nurse asked to exclude a uniform closet from generation (no per-closet opt-out). **H**

### 1.3 Indyx (Indyx Inc., US; iOS-first, Android; web)
- **Core**: unlimited free digital closet; drag-and-drop outfit boards (pinch-to-resize, flat-lay aesthetic); collections/capsules; calendar with OOTD selfies; packing lists; cost-per-wear, closet value, garment age, composition analytics (advanced dashboard paid); friends' shared closets, "Open Closets", social styling; P2P resale at 0% commission; **human stylist marketplace** (Lookbook 10 outfits from your closet $150+, Lookbook Mini 3 outfits $60, The Feed subscription styling ~$15–25/mo, The Call 1:1 $60–110); "The Catalog" white-glove in-home digitization $295 per 100 items (+$2/item, select metros); 8-week Style Workshop; Style Quiz. Sources: loomies-01/14/21, vestia, dotfyles, womanonrails. **H**
- **AI**: auto background removal (PhotoRoom-based per vestia) + AI auto-tagging rated the most accurate in category (type, colour, brand, fabric); **explicitly no AI outfit generation** ("style is a human art that can never be replaced by an algorithm"); "Virtual Selfies" (2026-07): overlay an outfit on your own photo ("rushed 7am mirror moment"). Users push back on AI ("chill it w the AI"). **H**
- **Digitization**: photo (auto cutout/tag), product image/URL import, **email receipt forwarding** (forward purchase confirmation → item auto-created; unique in category), spreadsheet import (dollrobe), Chrome extension, or paid Archivist. **No bulk photo upload** (~2 min/item) is the #1 complaint; 250+ items makes drag slow (30s). **H**
- **VTO**: photo overlay only (Virtual Selfies), no generative/avatar try-on. **H**
- **Pricing**: free unlimited items/outfits/calendar/packing; **Insider $12.99/mo or $74.99/yr** (advanced analytics, unlimited outfit selfies, Lookbook access, resale perks); Black-Friday $54/yr seen; AU$119.99/yr called "steep". Complaint: basic analytics behind paywall "defeats the purpose"; July 2026 "paywall creep" on calendar/assign-selfie. **H**
- **Platform**: iOS 4.77–4.78★ / ~1.45K US ratings (highest rating, smallest base); Play 100K+; NYT Wirecutter feature 2026-05-07; no disclosed funding. **H**
- **UX patterns**: cleanest/most editorial UI in category; magic-link login (disliked); "aerial closet" view; calendar-as-source-of-stats; workday-morning use cases dominate 5★ reviews. **H**
- **Weaknesses**: single-item upload, paywalled analytics, occasional stalls/URL import breaks, Android less mature, stylists not size-inclusive per some reviews, retention drop after initial cataloguing. **H**

### 1.4 Stylebook (left brain / right brain LLC; iOS only, since 2009; separate "Stylebook Men" app)
- **Core**: 90+ features: custom categories/sub-categories, rich metadata + bulk edit, item statuses (clean/dirty/dry-clean/loaned/in-storage/archived), magazine-style collage looks, Outfit/Style Shuffle (random, not AI), calendar (pivot: one daily log feeds cost-per-wear, most/least worn, colour/brand/price distribution, "not worn in X"), packing lists with shareable infographic, body measurements + brand sizes, web clipping. v10 (2025-03) added iCloud sync, AI cutout, **AI text→image item generation** (Apple Intelligence), archive, bulk/drag-drop import, dark mode (10.1, 2025-06). Sources: loomies-01/13/21, culcept, vestia. **H**
- **AI**: AI background removal (can't be disabled — complaint), AI-generated product images; **no AI styling, no weather**. **H**
- **Digitization**: photo/camera-roll, web clip, "Import Wardrobe Basics" beta, AI-generated image; historically manual cutout "fussy"; users report 2–12 hours for a full closet. **H**
- **VTO**: none. **H**
- **Pricing**: **$4.99 one-time**, zero IAP, no ads, no trial; men's app another $4.99. #2 paid Lifestyle app in US (2026-07-21). Praised as "best $5 I ever spent"; no update in 13+ months (last 2025-06-15). **H**
- **Platform**: iOS 4.68★ / ~8.7K ratings; on-device/local-first (iCloud optional). **H**
- **Weaknesses**: setup labour, dated UI ("spreadsheet energy"), no Android/web, no smart suggestions, v10 sync duplicates/losses, gendered apps. **H**

### 1.5 Cladwell (Cladwell Inc., US; iOS/Android)
- **Core**: capsule-wardrobe method: 30–35+ prebuilt capsule templates and a 15–16K generic item library you tick ("quick but fake" closet), replace with photos later; "Outfits Today" 1–3 daily outfits by local weather + wear history; mini-capsules (season/work/travel); logging + stats (% worn, CPW, palette) after ~10 logs; "storage" status to test decluttering; "Ask Cladwell" ChatGPT stylist (5 msgs/mo free, 50/mo paid; packing/trip prompts); style quiz with inclusive visuals; progressive cold start via daily micro-tasks (swipe outfits, add prices) in batches of ~30. Sources: loomies-13, vestia, culcept. **H**
- **AI**: 2025-04 "snap photos → AI auto-categorises" bulk intake; ChatGPT chat; rules-based weather recommender. **H**
- **Digitization**: generic-library selection first; photos second; AI mis-categorisation not correctable until 5.12.0. **H**
- **VTO**: none. **H**
- **Pricing**: free = closet + 2 capsules + 7 outfits / 1 outfit-per-day + 7-day log ("glass-window" free tier); **$7.99/mo, $59.99/yr** (site says "less than $5 a month"; also $21.99 quarterly; legacy SKUs $2.99/$19.99/$9.99 still listed); $49/mo human-stylist tier removed from site. Acquired 2019 at ~$330K ARR; 1M+ downloads claimed; Play 100K+. **H**
- **Weaknesses**: 4-year unresolved "can't cancel / keeps charging" complaints; weather stuck/wrong; same 2–3 shoes every outfit; "algorithm refuses to learn"; generic stock images destroy personal connection; shrinking review volume (2021: 83 → 2026H1: 7). iOS 4.27★ / ~1K. **H**

### 1.6 Alta / Alta Daily (Flagship AI Inc., NYC; iOS/Android/web; launched 2025-03-13)
- **Core**: "AI stylist + digital closet for date nights, interviews, trips"; daily outfits from **closet + weather + schedule + lifestyle + budget + body shape + brands**; event prompts ("date night in Paris"); anchor-item generation; restyle any suggestion; **closet mode** toggle (own clothes only vs mixed with shoppable items); month-ahead look calendar; multi-city trip packing lists + lookbooks (luggage-size aware, shareable link); wardrobe gap analysis; wishlist price-drop alerts; CPW/wear stats; "Best Dressed" social sharing; home-screen widget; 4,000+ brands shopping; B2B "Style with Alta" widget on brand PDPs (Public School), Poshmark, Altuzarra, CFDA partnerships. Sources: loomies-15/22, headcutter-alta, dotfyles. **H**
- **AI**: 12+ proprietary fashion models, "stylists-in-the-loop" RL; auto cutout + tagging; weekly releases ("more realistic avatars"). **H/M**
- **Digitization**: photo, **email receipt import**, database search, camera. **H**
- **VTO**: **avatar built from headshot + body photo + measurements**; try on own clothes and new items. **H**
- **Pricing**: **entirely free, zero IAP** (VC-subsidised: $11M seed 2025-06, Menlo; affiliate/B2B revenue; ~$3.1M 2025 revenue est., unverified). One doc cites a "$3–5/mo from" tier for avatar features "by region" (L, unconfirmed). Users already "worried about future charges". **H**
- **Platform**: iOS 4.88–4.9★ / 10.9K–12.2K ratings within ~16 months (fastest growth in category: +79 ratings/day in July 2026); TIME Best Inventions 2025 special mention. **H**
- **Weaknesses**: automated outfits "don't work in real life" (navy top + black shoes), repeats same outfit, outfits padded with items to buy ("only made outfits with one piece of my clothing and the rest was stuff they wanted me to buy"), avatar body distortion complaints, suspected astroturf reviews; monetisation still unproven. **M**

### 1.7 OpenWardrobe (OpenWardrobe Inc., US; iOS)
- **Core**: closet + outfits, cost-per-wear, wear calendar/tracking, shared closets / style your friends, "Style Blueprint" (colours, body shape, style personality), Style Lab (premium), **Poshmark resale integration**, alterations/repairs booking (US). **M** (dotfyles 2026-08-15, loomies-15, axensz README)
- **AI**: "LolaAI" conversational stylist trained on your wardrobe; extracts features at import time. **M**
- **Pricing**: freemium; "Circle" **$12.99/mo, $79/yr, $199 lifetime**; free trial. **M**
- **Platform**: iOS 4.0★ / ~170 ratings (small). Open-source Flutter+Supabase repo (github.com/OpenWardrobe/app) stalled since 2025-02. **M**
- **Weaknesses**: small base; positioning overlaps everyone; no VTO evidence.

### 1.8 Combyne (combyne GmbH, Munich; iOS/Android)
- **Core**: social outfit-collage toy: "Combyner" canvas with 35+ categories from an 800–1,000-brand catalogue (+ own uploads with cutout), feed, likes/Superlikes, DMs, "style soulmate" matching, **daily themed Outfit Challenges** with votes (main retention engine), click-through to 50+ partner shops. Not a real-wardrobe manager; no AI styling. **H** (vestia, plechiki, dotfyles)
- **Pricing**: free + ads + Premium (est. $2.99–$19.99) + consumable Superlikes + affiliate. **M**
- **Platform**: ~86.8K iOS ratings 4.76★; 10M+ Play installs; teen audience; no iOS update since mid-2024 (vestia). **H**
- **Relevance**: zero-cold-start pattern (prefilled catalogue), challenge mechanics; weakness = catalogue items, not your clothes; moderation/minors concerns.

### 1.9 Smart Closet (Rabbit Tech Inc.; iOS/Android)
- **Core**: add from ShopStyle brand catalogue / photo / web clip; one-click cutout (mediocre); fully editable categories & sub-categories; rule-based "Random Look" generator (season/palette/occasion rules); calendar + reminders; packing lists (most-loved); stats; multi-closet via multiple accounts (2025-11). **H** (loomies-13, vestia, culcept)
- **AI**: none beyond cutout. **H**
- **Pricing**: iOS **$2.99 one-time** (since 2025-11 revival) + Pro $0.99/mo or $9.99/yr for backup/sync; Android free with ads. **H**
- **Status**: **cautionary tale** — 2022-12 update wiped data/killed calendar; 2025-09-30 MongoDB Realm EOL killed login/sync, users lost years of data including paid backups; 3 emergency releases 2025-11 then dormant; US iOS growth ~zero (+16 ratings in 22 months); 2025 review mean 1.82★. **H**

### 1.10 Pureple (ICECLIP LLC; iOS/Android; since 2013, rebranded "AI Outfit Planner")
- **Core**: 4 intake paths (camera, library, **"Wizard" checklist of basics**, web import "Gap skinny jeans" → product image); semi-manual slider cutout; richest tagging (custom categories unlimited; season/occasion/colour/brand/size/price/material/rating/pattern; "location"/availability fields per older listings — current listing omits location, may be custom filters); **"Style Me"**: pick categories → generated combos from your closet → swipe left/right, learns from swipes (improves over months, slow to converge, up to 3 min); AI try-on on a **generic model** (6.0.6, 2025-09); calendar; packing; opt-in community (ask community / let others style my closet); weather recs. **H** (loomies-01/13, vestia, plechiki)
- **Pricing**: free with heavy ads + quotas; Premium **$6.99/week, $14.99/mo, $89.99/yr** (7-day trial on annual) — up 30–40% since 2024 ($4.99/$9.99/$69.99); calendar moved from free into Pro in fall 2025; 10 messy SKUs; $95.39 billing dispute. **H**
- **Platform**: iOS 3.94★ / 6.1K; Play 1M+ / ~2.5★; "3M+ users" claimed. **H**
- **Weaknesses**: ads on every click, retroactive paywall, data loss on sync, batch upload of 40+ crashes, photo orientation bug 2 years, suggestions feel random early, suspected fake reviews under users' names (2026-05). **H**

### 1.11 GetWardrobe (Outfit Makers LLC; iOS/Android/macOS/Web sync)
- **Core**: four-platform sync; canvas outfit editor; calendar + local weather; **Family Wardrobe** (per-member profiles); packing; CPW/%worn stats (sortable); custom occasion tags; **Sizes Notebook** (body measurements, brand sizes, body-shape verdict — recorded but not used by recommender); **Stylist Mode** (manage ≤10 client closets, $69.99/mo or $690/yr); global offline search; privacy repositioning 2026-05 ("nothing tracks you for ads; diagnostics off by default"). ~15 releases in 12 months (most active tool-type app). **H** (loomies-13/21, dotfyles, plechiki)
- **AI**: auto cutout + "AI details everything: category, colour, season, fabric… seconds not minutes"; AI Outfit Generator (10–30 outfits/run; Starter free, Standard/Pro cost credits; filtered by weather/occasion/mood); **Virtual Try-On** (2025-11; "virtual model or your own body photo"); AI photo enhancement/auto-crop; virtual avatar (2026-02). **H**
- **Pricing**: free 100 items+outfits lifetime, no card; Premium **$4.99/mo or $34.99/yr** (App Store) vs **$49.99/yr "regular", $4.17/mo billed yearly** on website (two-track pricing); AI credits 20/$4.99, 60/$9.99, 150/$19.99, 500/$59.99, 1000/$89.99; annual has trial. **H**
- **Platform**: iOS 4.29★ / 754 US ratings (all 44 US reviews in 2026 are templated 5★ — suspected incentivised); Play 1M+ / 4.86K; Russian-speaking origin; "3M users" claimed. **H**
- **Weaknesses**: 100-item wall, cutout inaccuracy, sluggish after updates, tags irrecoverable after deletion, historic ad bombardment and 7-day trial auto-charge. **H**

### 1.12 Lookscope (Lookscope Inc.; iOS only; ~2017)
- **Core**: "Change Room" swipe-to-assemble across six body-part slots (Head, Top-Inner, Top-Outer, Top-Bottom, Bottom, Feet, Other); filters colour/season/style/brand; "PICK" for the day; unlimited closet/lookbook spaces; "import photos in seconds"; Apple Editor's Recommendation of the Week (Dec 2024). **M** (dare-chat1.md, which cites lookscopeapp.com and store reviews)
- **AI**: automatic outfit generation "optimised for speed"; no evidence of LLM/VTO. **M**
- **Pricing**: freemium; Premium (price not captured) unlocks unlimited categories, weather forecast, custom collections/brands. **L**
- **Weaknesses**: rigid taxonomy (single "Other" bucket for bags/belts/jewellery), no custom tags, can't tag whole outfits. **M**

### 1.13 Style DNA (AI Style by DNA S.L., Spain; iOS/Android; EN/DE/IT)
- **Core**: selfie → 12-season colour type + body type (8+ figures, camera or manual) + Kibbe-style archetype in ~35 s; "Style Formula" (colour+print+fabric+shape); swatch palette → shoppable items; 5 daily outfit ideas tagged Work/Workout/Party/etc.; occasion ideas; makeup pairing; AI stylist chat (GPT-4-class); in-store "snap to check" purchase verdict; shopping across claimed 26K brands / 231 retailers with % match; digital closet (Upper/Lower/Footwear/Accessories, "coordinates with N items"); capsule guides (static). **H** (styledna-analysis, loomies-01/14, dotfyles)
- **Digitization**: photo with clunky cropping/metadata editing; no wear tracking; no weather. **M**
- **VTO**: none — "try-on" is analysis; users say the body model "doesn't reflect actual body shape despite custom measurements". **H**
- **Pricing**: paywall *before* results; 9 overlapping SKUs: monthly $7.99/$9.99/$19.99; 3-month $14.99/$19.99; annual $19.99/$29.99/$39.99; à-la-carte guides $9.99–$12.99; web funnel ($1–10 intro → $28.95/mo) billed outside Apple → "doesn't show in Apple subscriptions, can't cancel". Peak (2024-06): 3.2M downloads, 300K active, 70K paying, €3.4M pre-seed, ~$3M/yr revenue. **H**
- **Platform**: iOS 4.29★ / 7.4K (≈53% of recent reviews 1–2★, ~28% billing); Trustpilot 2.0. **H**
- **Weaknesses**: subscription trap reputation, generic/dated outfits ("frumpy"), inconsistent colour verdicts, no community, no sustainability. **H**

### 1.14 Aiuta (B2B virtual try-on / studio-visuals platform)
- **What**: SDKs (iOS, Android, Flutter; Web "coming soon") + REST API for retailer-embedded try-on; claims "up to 7x faster than the average competitor", pose/body-shape preservation; also "Studio" product-visual generation and a "Unified" API; requires product IDs pre-registered with Aiuta "for training try-on models"; deployed "at major retailers" (per a competitor's comparison blog). Pricing not published (enterprise). Sources: github.com/aiuta-com/docs README + docs/index.md (fetched 2026-09-05); astriaai/articles comparison. **H** (existence/positioning) / **L** (pricing)
- **Relevance**: not a consumer wardrobe app; a candidate VTO supplier alongside FASHN, Vertex, fal, Nova Canvas (see §7).

### 1.15 "Wardrobe AI" / WardrobeAI
- Only evidence: listed among "a long tail of low-trust, low-quality AI closet/try-on utilities (many with 1–5 ratings)" on Indian storefronts (dotfyles 2026-08-15). No feature/pricing detail retrievable. Treat as generic AI-wrapper closet app; **unconfirmed**. **L**

### 1.16 Google — Doppl, Search/Shopping "Try on", Google Photos Wardrobe, Vertex API
- **Doppl (Google Labs)**: launched 2025-06-26 (US, iOS/Android): upload one full-body photo, try on any outfit from a photo/screenshot, generates stills and short AI videos, save/share; expanded to more countries + shoes 2025-10; selfie-only input from 2025-12; added a TikTok-style shoppable AI discovery feed; **announced shutdown 2026-03-23, shut down 2026-04-30, apps delisted, user data inaccessible**; official line: try-on continues in Search/Shopping. AppBrain showed only 10K+ Android installs. Sources: doppl-launch (TechCrunch 2025-06-26), loomies-15 (support.google.com/labs/answer/16537062, jetstream.blog). **H**
- **Google Search/Shopping "Try on you"**: upload a photo → digital version of you; try tops/bottoms/dresses/jackets/shoes on product listings and in AI Mode; US/UK/India (India Dec 2025, no ethnic wear); merchant participation passive via Merchant Center (images ≥512px, ideally ≥1024px) — **no merchant/developer API**; I/O 2026 (May) added AI-Mode shopping with virtual try-ons + agentic checkout (Universal Commerce Protocol / Agent Payments Protocol / Universal Cart). Sources: tryit-provider-survey, loomies-15, dotfyles. **H**
- **Google Photos "Wardrobe"** (announced 2026-04-29, debut on Motorola Razr 2026; Android "later this summer", then iOS, under Collections): auto-builds a digital closet from clothes detected in your photo library, filter by category (tops, bottoms, jewellery…), mix-and-match outfits, save to moodboards by occasion (travel, events, date nights, work), share with friends, **and virtually try on the outfits**. TechCrunch names Acloset, Combyne, Pureple, "Wearing" [Whering], Alta as competitors. Sources: techcrunch-googlephotos-wardrobe.md, googlephotos-wardrobe-razr.md. **H** (announcement) / **L** (whether live on iOS by Sept 2026 — unconfirmed)
- **Vertex AI Virtual Try-On API**: model `virtual-try-on-001` GA 2026-01-20 (preview `virtual-try-on-preview-08-04` deprecated 2026-03-19; discontinuation planned 2027-01-20); inputs person image + up to 4 product images (≤10 MB, base64/GCS); SynthID/C2PA watermark; default quota ~50 req/min; per-image price not confirmed (~$0.04–0.08 est.). Also Gemini "Nano Banana" image models used for selfie→full-body try-on compositions ($0.034–$0.151/image). Sources: GitHub code search hits on GoogleCloudPlatform/generative-ai notebook and gcp-changelog; tryit-provider-survey; loomies-04; dotfyles. **H** (IDs/dates) / **L** (price)

### 1.17 Amazon
- Consumer: "Virtual Try-On for Shoes" (AR, app), StyleSnap visual search, "Magic Fit / Fit Review" size guidance; retailer-side, no API (fashioncoach-vto, dotfyles). **M**
- Developer: **Amazon Nova Canvas virtual try-on** (AWS, launched 2025-07) — person + garment image → try-on with style options; ~$0.04–0.06/image; commercial-OK; quality less proven than FASHN (fashioncoach-vto citing aws.amazon.com what's-new 2025-07). **M**
- Model knowledge (L, unconfirmed): Amazon Fashion has piloted generative "AI try-on" for apparel on select listings in 2025–26; not verified here.

### 1.18 Zalando
- Evidence: Zalando Research launched a ChatGPT-powered fashion assistant (2023-04); a 2026 Chinese industry note states "Zalando 2026 fully rolled out AI virtual try-on" (kaneliu120.github.io, secondary, **L**); Zalando × Vestiaire Collective circular-fashion partnership reported 2026-06 (xiaxianlin/news digest, **L**). Model knowledge: Zalando has offered a size-and-fit "body-measurement via two photos" feature and generative try-on tests since 2024–25 (**L**, unconfirmed). No first-hand Zalando data reachable.

### 1.19 Pinterest
- "Styled for you" (announced 2025-10-27): AI assembles complete outfits from a user's saved fashion Pins, swap individual pieces; "Boards made for you" (editor+AI curated, weekly outfit inspiration, shoppable); US/Canada rollout; CEO goal "AI-enabled shopping assistant"; AI-content labels and "see fewer AI pins" controls. Established mechanics: Lens/Flashlight visual search with crop, Shop the Look (auto CV tags, up to 25/image; 3–4× engagement), **body-type filter (+66% engagement) and skin-tone filter (+70% usage)**, board-based personalisation. Boundary: works on *aspirational saved product images*, not owned clothes — "one step from wardrobe management". Sources: loomies-15 (TechCrunch 2025-10-27), vestia-benchmark. **H/M**

### 1.20 Depop / Vestiaire Collective (resale features)
- Depop: launched a **Pinterest-style fashion collaging/styling tool** (TechCrunch 2025-09-24) — resale platforms are grabbing the styling entry point. **M** (loomies-15)
- Vestiaire: no AI wardrobe/try-on feature evidence found; corporate facts: GMV just under €1B (2025), ~€200M revenue, first annual profit targeted 2026, 25M+ members (dyntr/Vendaro research). Third-party tools (Oly, "Blair" bot) cross-list to Vestiaire/Depop/Grailed/Vinted/eBay. **M**
- Model knowledge (L): both use AI listing assistants (auto-title/description/price from photos); Vinted has amateur-photo image search. Pattern relevant to wardrobe apps: Whering→eBay, Indyx P2P resale, OpenWardrobe→Poshmark, Alta→Poshmark all connect closet data to resale supply.

### 1.21 2025–2026 newcomers and adjacent
- **Fits – Outfit Planner & Closet** (L. & J. Henne UG, Germany; iOS 4.61★ / 4.7K, since 2023): AI stylist suggestions, AI colour/category/brand detection, outfit calendar, **virtual try-on**, swipe-slot assembly; ranks #2 for "outfit planner"/"wardrobe app" ASO; freemium IAP. **H**
- **Nouva** (nouva.app): colour-harmony score for every outfit; "light setup: add up to 30 items → outfits immediately"; free 30 items / 3 outfits per week; **Plus £6.99/mo**; 150 items on Plus (essembl file). **M**
- **Layered** (indie, Vadim Drobinin, iOS, spring 2026, PH #7): **builds the closet from selfies/lifestyle photos** instead of white-background item shots; travel capsules by destination + luggage limit; CPW; next-day outfit widget; free 5 interactions then paywall. **M**
- **Doji** (Doji Labs, $14M Thrive seed 2025-05): 6 selfies + 2 body photos → ~30-min hyper-real avatar; try on designer items or any URL; browser extension; social; no wardrobe mgmt; iOS 4.1★ / 146 ratings (low traction); complaints "makes everyone skinnier", "doesn't look like me", miniskirts become long skirts. **H**
- **Gensmo** ("first fashion AI agent"): try-on + full looks + shopping; claims 750K downloads / 4.7★. **M**
- **Essembl** (Luxembourg): flat-lay bulk extraction (AI re-renders look-alikes — main complaint), outfit generator, Outfit Check scoring, colour analysis, Shopping Buddy; hard paywall after long onboarding; ~$29.99/yr, weekly SKUs, 3-day trial on annual (see essembl-reviews.md). **H**
- **Dripmatiq** (2026): on-device processing; "FitMatic" renders outfits from your own closet on your own photo; free 25 suggestions + 3 try-ons/mo; **Pro $6.99/mo (25 try-ons), Elite $15.99/mo (100 try-ons)**. **M** (vendor blog)
- **Kya Pehne** (India, iOS 2026-08-06): ethnic-wear taxonomy, wear diary, care/repair, packing, Wardrobe Locator, family profiles; free 50 items + 10 AI stylings; ₹100/mo or ₹1,000/yr intro. **H**
- **FitCheck cluster** (≥8 same-named indie apps): $3.99–4.99/week or $29.99–39.99/yr; credit packs 5/$1.99 → 200/$69.99; feature lists (scan closet, brand/size detection, try-on on model, weather, calendar, luggage-weight packing, widget) show the feature list is now template-able by 1–2 person teams. **H**
- **Aesty** (aesty.ai, iOS): try-on via OpenAI/Gemini APIs per its privacy policy; Pro/Max ~$50–250/yr; no free trial. **M**
- **Klodsy**, **Save Your Wardrobe** (pivoted to B2B aftersales/repairs, LVMH client), **Clueless Clothing**, **xlook**, **Wardrowbe**, **looqs**, **outfitmaker.ai (€7.99–14.99/mo)**, **Vesta**, **SimpleCloset**, **Clozzie**, **My Wardrobe (Appfit)**, **Haze Couture** (body-scan mannequin, dead after 1 month, $199.99), **PointAI "My Wardrobe"** (physics-based VTO infra powering Amazon/Flipkart/Myntra, ~$11M, Aug 2026). **M/L**
- **Open source**: Libre-Closet (AGPL, self-hosted PWA), tandpfun/wardrobe (gpt-image normalisation of garment photos, 1.3K★), zebangeth/ai-closet (RN, MIT), opentryon (adapters for FASHN/Vertex/Nova/Kling/Nano Banana). **H**

---

## 2. Feature matrix (✔ = has, △ = partial/weak/roadmap, ✘ = none, ? = unknown)

| Feature | Whering | Acloset | Indyx | Stylebook | Cladwell | Alta | OpenWardrobe | Combyne | Smart Closet | Pureple | GetWardrobe | Lookscope | Style DNA | Fits | Google Photos Wardrobe* |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Photo → auto cutout | ✔ | ✔ (best) | ✔ (best) | ✔ (v10) | △ | ✔ | ✔ | ✔ | △ | △ manual | ✔ | ✔ | △ | ✔ | ✔ |
| AI auto-tag (cat/colour/etc.) | ✔ (noisy) | ✔ | ✔ (most accurate) | ✘ | ✔ (2025) | ✔ | ✔ | ✘ | ✘ | ✔ | ✔ | ? | △ | ✔ | ✔ |
| Bulk / camera-roll intake | ✔ | ✔ | ✘ (paid service) | ✔ | ✔ | ? | ? | ✘ | ✘ | △ crashes | △ | ? | ✘ | ? | ✔ (auto from library) |
| Retailer/URL/product-DB import | ✔ (100M DB, Chrome) | ✔ | ✔ (URL) | ✔ (web clip) | ✔ (generic lib) | ✔ (DB) | ? | ✔ (catalogue) | ✔ (ShopStyle) | ✔ | ✘ | ✘ | ✔ shop | ? | ✘ |
| Email-receipt / order import | ✘ | ✔ (Gmail/orders) | ✔ (forward receipts) | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ |
| Manual outfit canvas/collage | ✔ | ✔ | ✔ (drag, resize) | ✔ | △ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ canvas | ✔ slots | ✘ | ✔ slots | ✔ |
| Random/shuffle generator | ✔ Dress Me | ✔ | ✘ | ✔ | ✘ | ✘ | ? | ✘ | ✔ rules | ✔ Style Me | ✔ | ✔ | ✘ | ✔ | ? |
| AI/LLM outfit generation | △ (new) | ✔ | ✘ (by design) | ✘ | ✔ | ✔ core | ✔ Lola | ✘ | ✘ | ✔ | ✔ credits | △ | ✔ | ✔ | ✔ |
| Weather-aware daily outfit | △ (2026-07) | ✔ | ✘ | ✘ | ✔ core | ✔ | ? | ✘ | △ | ✔ paid | ✔ | ✔ premium | ✘ | ? | ? |
| Calendar-aware (schedule/events) | ✘ | ✔ | ✘ | ✘ | ✘ | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ |
| Occasion/mood prompt | △ | ✔ chat | ✘ | ✘ | △ | ✔ | ✔ | ✘ | △ rules | △ | ✔ tags | △ | ✔ | ? | △ moodboards |
| AI stylist chat | △ roadmap | ✔ | ✘ | ✘ | ✔ GPT | ✔ | ✔ | ✘ | ✘ | ✘ | ✘ | ✘ | ✔ | ? | ✘ |
| Learns from feedback (swipes/wear) | △ | △ | ✘ | ✘ | △ | △ | ? | ✘ | ✘ | ✔ swipes | ? | ✘ | ✘ | ? | △ |
| Explains "why this outfit" | ✘ | ✘ | n/a | ✘ | ✘ | △ | ? | ✘ | ✘ | ✘ | ✘ | ✘ | △ | ✘ | ✘ |
| Outfit calendar / wear log | ✔ | ✔ | ✔ (+selfies) | ✔ pivot | ✔ | ✔ | ✔ | ✘ | ✔ | ✔ (paid) | ✔ | △ | ✘ | ✔ | ✘ |
| Cost-per-wear & stats | ✔ | ✔ | ✔ (adv. paid) | ✔ best | △ paid | ✔ | ✔ | ✘ | ✔ | △ | ✔ | ✘ | ✘ | ? | ✘ |
| Packing lists | ✔ | ✔ (weather/day) | ✔ | ✔ | △ chat | ✔ (NL, luggage) | ? | ✘ | ✔ | ✔ | ✔ premium | ✘ | ✘ | ? | △ travel board |
| Wishlist / gap analysis / buy-check | ✔ | ✔ | ✔ | △ | ✔ test piece | ✔ + price alerts | ? | n/a | ✔ | ✘ | ✘ | ✔ wished items | ✔ snap-check | ? | ✘ |
| Shopping / affiliate | ✔ | ✔ | ✘ | ✘ | △ | ✔ 4K brands | △ | ✔ | ✔ | ✘ | ✘ | ✘ | ✔ 231 retailers | ? | ✔ (Google) |
| Resale integration | △ (eBay roadmap) | ✘ (closed 2024) | ✔ P2P 0% | ✘ | ✘ | ✔ Poshmark | ✔ Poshmark | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ |
| Colour/body analysis | △ palette stats | ✔ | ✘ | ✘ | △ palette | △ body shape input | ✔ Blueprint | ✘ | ✘ | ✘ | △ Sizes Notebook | ✘ | ✔ core | ✘ | ✘ |
| Body measurements / sizes | ✘ | ✘ | ✘ | ✔ fields | ✘ | ✔ (avatar) | ? | ✘ | ✘ | size tag | ✔ | ✘ | ✔ | ✘ | ✘ |
| Virtual try-on (any) | △ roadmap | ✔ avatar (1 photo) | △ photo overlay | ✘ | ✘ | ✔ avatar (head+body+measurements) | △ Style Lab? | "virtual dressing room" = collage | ✘ | ✔ generic model | ✔ (credits, own photo or model) | ✘ | ✘ | ✔ | ✔ |
| Human stylist services | ✘ | ✘ (Expert tier AI) | ✔ core | ✘ | △ removed | △ in-the-loop | ✘ | ✘ | ✘ | community | ✔ Stylist Mode B2B | ✘ | ✘ | ✘ | ✘ |
| Social / community | ✔ | ✔ feed | △ open closets | ✘ | ✘ | △ share | ✔ friends | ✔ core | △ share | ✔ opt-in | △ | ✘ | ✘ | △ | ✔ share |
| Multi-closet / family | ✘ | ✔ | ✘ | ✘ (M/F apps) | ✘ | ✘ | ✘ | ✘ | △ accounts | ✘ | ✔ Family (paid) | ✘ | ✘ | ✘ | ✘ |
| Storage location field | ✘ | ✘ | ✘ | △ status | ✘ | ✘ | ✘ | ✘ | ✘ | △ | ✘ | ✘ | ✘ | ✘ | ✘ |
| Widget | ? | ? | ? | ✘ | ? | ✔ | ? | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | ? | n/a |
| Web/desktop | ✔ | △ | ✔ | ✘ | ✘ | ✔ | ? | ✘ | ✘ | ✘ | ✔ 4 platforms | ✘ | ✘ | ? | ✔ |
| Data export | ✘ (complaint) | ? | ? | ✔ (local) | ? | ? | ? | ✘ | △ paid backup | △ paid | ? | ? | ✘ | ? | n/a |
| On-device / privacy stance | ✘ (data model) | ✘ | ✘ | ✔ local | ✘ | ✘ | ✘ | ✘ | ✘ | ✘ | △ marketing | ? | ✘ (selfie before paywall) | ? | Google account |
| Free tier item cap | none | 100 | none | n/a ($4.99) | features gated | none | trial | none | none | none (+ads) | 100 | none? | features gated | ? | none |

*Google Photos Wardrobe: announced feature set, not yet verified live.

---

## 3. Table-stakes features (present in ≥70% of active competitors, or absence draws 1★ reviews)

1. Photo intake with **automatic background removal** and editable **AI auto-tags** (category, colour, season, brand); a failed cutout is cited negatively in every app's reviews (vestia).
2. **Some bulk path** (camera-roll multi-select, batch capture, or catalogue/URL import) — single-item upload is Indyx's #1 complaint; Acloset CEO's 50-item and Whering's 40-item activation thresholds make speed-to-40 the KPI.
3. **Manual outfit builder** (collage or slot-based) + saved outfits/lookbooks.
4. **Outfit calendar / wear log** feeding **cost-per-wear, most/least worn, unworn-in-X** stats — the most-cited "aha moment"; gating basic stats produces the worst reviews (Indyx, Acloset).
5. **Daily outfit suggestion with local weather** (Cladwell, Acloset, Alta, GetWardrobe, Pureple, Whering 2026); weather must be *correct* — wrong temperatures are a top 1★ trigger.
6. **Packing / trip lists**.
7. **Wishlist + "does this fit my closet" purchase check**.
8. Generous free tier: **no 100-item cap** (Whering/Indyx/Alta at 4.67–4.88★ vs Acloset/GetWardrobe at 4.29–4.40★ with caps); no ads; no retroactive paywalls; subscription purchasable/cancellable through Apple only; annual ≈ 50–60% of 12× monthly; trial only on annual.
9. Reliability basics: cloud backup that actually restores, no data loss on update, export, fast lists at 250+ items, responsive support (Smart Closet/Pureple/Style DNA collapses were all trust failures, not feature gaps).
10. Sync/web access is becoming expected (GetWardrobe 4 platforms, Whering web, Indyx web, Alta web; Stylebook's lack is a standing complaint).
11. By 2026, **some form of try-on** appears on most listings (Acloset, Alta, GetWardrobe, Pureple, Fits, Google) — expectation is forming even though quality varies; "virtual try-on" on a listing now means anything from collage to avatar (dripmatiq).

---

## 4. Differentiators nobody does well (validated gaps)

1. **Outfit quality with visible logic.** Universal complaint: "really random" (Whering), "nonsensical"/"wool in 82°F" (Acloset), "safe/boring, same 2–3 shoes" (Cladwell), "navy top + black shoes" (Alta), "hyper-fixates on one item" (Essembl). No app explains *why* an outfit works, enforces dress-code/occasion constraints, guarantees the anchor item appears, avoids duplicate slots, or rotates coverage across the whole closet. Explainable, constraint-respecting generation with per-slot feedback is open (capsulezero insight #4, essembl P1 list).
2. **True photorealistic full-body try-on of *your own* clothes, feet included.** Doji/Alta avatars "make everyone skinnier"/"don't look like me"; Pureple uses a generic model; Indyx only overlays; Acloset just shipped one-photo avatar (2026-07); Google Photos Wardrobe promises it but unverified. Nobody combines owned-closet + realistic on-body render + garment fidelity (colour/cut preserved) + shoes/accessories. Also open: multi-garment single pass (most APIs are one garment per call; FASHN Try-On Max covers shoes/bags/accessories at $0.075/step).
3. **Digitization that doesn't feel like homework**: camera-roll/lifestyle-photo extraction (Layered, Whering roadmap, Google Photos), receipt/email/order-history sync (only Indyx, Acloset, Alta), preserving the *real* garment pixels rather than regenerating look-alikes (Essembl's biggest complaint), background processing with a review queue, sub-15-second per item, migration from other apps (DressApp's bookmarklet is the only importer seen; no app supports export/import standards).
4. **Fit / size intelligence**: measurements are recorded (GetWardrobe Sizes Notebook, Stylebook, Style DNA) but never drive recommendations or visualisation; Haze Couture tried body-scan and died; True Fit/MySize are B2B-only. "Will this fit / flatter my proportions, honestly" is unclaimed (loomies-13/15, voyeur).
5. **Occasion/calendar-structured mornings for working women**: Indyx's 5★ reviews are 9-to-5 women; users ask Whering for occasion/mood filters; Acloset can't exclude a nurse's scrubs closet; Alta has the tagline but recommendations are polluted with items to buy. Occasion as a hard constraint + calendar integration + per-closet scoping is open.
6. **Physical storage location / seasonal rotation / multi-closet (by place, not person)**: only Pureple (weak field) and Chinese apps (搭搭, 尽简衣橱); Stylebook has a 3-state status; professional organisers have no app channel.
7. **Privacy / on-device**: category monetises wardrobe data (Whering→eBay/Google data, Alta affiliate, Smart Closet ads); Style DNA collects selfie before paywall; a mycloset doc cites "45% of potential users hesitate due to privacy" (unverified). GetWardrobe only markets it; Dripmatiq/Stylebook do local processing; nobody pairs on-device with modern AI.
8. **Honest, simple monetisation**: buy-once supply vacuum between $4.99 (Stylebook, frozen) and $14.99; single transparent SKU; trial-end reminders; in-app cancel/refund path — every incumbent with credits+subscription has 9–10 SKUs and billing complaints.
9. **Colour intelligence used in styling** (not just a report): Style DNA/Essembl produce a season report that never feeds the generator; Nouva scores harmony but is tiny; capsule-zero calls colour "underserved across the entire market".
10. **Editorial-grade visual quality**: "no competitor scores above 4/5 on design"; Indyx closest; Whering "cutesy"; Cladwell/Stylebook "dated" (capsulezero scorecard).
11. **Care/repair/lifecycle** (Save Your Wardrobe pivoted to B2B; Whering has repair links) and **resale-ready listings from closet data** (Whering/eBay, Indyx P2P, Alta/OpenWardrobe→Poshmark are early).
12. **Voice-first / hands-free morning ritual**: no evidence of any competitor using voice for occasion input or piece-swapping (Essembl/Acloset chat is text). Consistent with a third-party positioning brief ("VoiceDress", July 2026) found on GitHub.

---

## 5. Pricing benchmarks (US App Store snapshots 2026-07/08 unless noted)

| Model | Examples | Range |
|---|---|---|
| **Weekly** | Pureple $6.99/wk; FitCheck clones $3.99–4.99/wk; Style DNA web funnel "£7/week"; Whering historic "VIP £6.99/wk" (unconfirmed) | $3.99–$7.99/wk — appears only in the lowest-rated apps and is a named 1★ trigger ("6.99 A WEEK… insane") |
| **Monthly** | Acloset Basic $3.99 / Premium $9.99 / Expert $24.99; GetWardrobe $4.99; Cladwell $7.99; Dripmatiq $6.99 / $15.99; Style DNA $7.99–$19.99; Indyx $12.99; OpenWardrobe $12.99; Pureple $14.99; Nouva £6.99; outfitmaker.ai €7.99–14.99; Kya Pehne ₹100–200 | $3.99–$24.99; median mainstream tier ≈ **$9.99**; "$5/month" is the category's psychological ceiling phrase (Cladwell "less than $5", GetWardrobe "$4.17/mo") |
| **Annual** | Acloset $27.99 / $59.99 / $147.99; GetWardrobe $34.99 (store) / $49.99 (web); Style DNA $19.99–$39.99; Cladwell $59.99; Indyx $74.99; OpenWardrobe $79; Pureple $89.99; Aesty ~$50–250 | $27.99–$89.99; median ≈ **$59.99**; annual ≈ 48–63% of 12× monthly (Indyx 48%, Acloset 50%, Pureple 50%, GetWardrobe 58%, Cladwell 63%) |
| **One-time** | Stylebook $4.99 (+$4.99 men's); Smart Closet $2.99; OpenWardrobe lifetime $199; Pureple legacy Pro $14.99; Whering Outfit Maker $4.99 | $2.99–$14.99 (+$199 lifetime outlier); no modern buy-once offer between $5 and $15 |
| **Credits (consumables)** | Whering 10/$2.99, 50/$7.99, 100/$12.99; Acloset beans 100/$1.99 … 500/$9.99; GetWardrobe 20/$4.99 … 1000/$89.99; FitCheck 5/$1.99 … 200/$69.99 | ≈ $0.09–$0.40 per AI action; three of the top apps now run subscription + credits dual-track, producing 9–10 SKUs each |
| **Services** | Indyx Catalog $295/100 items (+$2/item), Lookbook $150+, Mini $60, 1:1 $60–110, styling sub $15–25/mo; GetWardrobe Stylist Mode $69.99/mo or $690/yr; Cladwell ex-$49/mo human stylist | — |
| **Free tiers** | Whering, Indyx, Alta: unlimited items, no ads; Acloset, GetWardrobe: 100 items; Nouva: 30 items / 3 outfits/wk; Kya Pehne: 50 items + 10 stylings; Cladwell: 1 outfit/day + 5 chat msgs/mo; Pureple: unlimited items but ads + gated Style Me/calendar; Dripmatiq: 25 suggestions + 3 try-ons/mo; Layered: 5 interactions | "Unlimited items, free" is now the entry ticket among the best-rated apps; caps are placed on AI compute (credits/quotas) instead of storage |
| **Trials** | Annual-only 7-day (Pureple, GetWardrobe); Essembl 3-day on annual, none on weekly; Style DNA/Essembl pay-before-results; GetWardrobe "no credit card, no trial, no catch" free tier | Norm: free tier without card + 3–7-day trial on annual only; card-required trials and "limited features" fake-outs draw deception complaints |
| **Reviewer WTP signals** | "$39 would be reasonable if it worked" (Essembl); "$60/yr… very little changes" (Cladwell); "if y'all have to start charging, only as a flat fee" (Whering); Stylebook "best $5 I ever spent"; MDPI review study: ~34% of negative reviews concern subscription/paywalls | Realistic band $30–50/yr; ≥$60/yr questioned; ~$8/mo is the resentment line (loomies-21) |

Alta (VC-subsidised, free) and Whering (credits + donations) anchor consumer expectations at $0 for cataloguing; the cost benchmark for AI is low (ingestion ≈ $0.0002–0.001/item, LLM styling ≈ $0.001–0.003/interaction, generated image $0.03–0.10, try-on $0.04–0.075/image) so paid tiers are justified only by try-on volume, human services, or premium analytics (dotfyles §6, fashioncoach §6: 1,500 premium users × 2–3 VTO/day at FASHN prices costs 85–121% of ₩3,900/mo revenue → VTO-heavy apps must meter try-ons).

---

## 6. How digitization accuracy and speed are handled and marketed

**Marketing claims**
- GetWardrobe: "Snap a photo — AI details everything: category, color, season, fabric… so cataloguing takes seconds, not minutes."
- Acloset: "digitize with almost zero friction", Beautify → e-shop-quality images, order-history import; CEO's stated aha threshold 50 items.
- Indyx: "most accurate tagging" (third-party consensus), receipt forwarding, white-glove Archivist as the ultimate friction-remover; official blog argues a 100-item cap kills adoption because the average wardrobe is ~175 items.
- Whering: "add from 100M+ items", camera-roll batch, Enhance; funding earmarked for "camera-roll extraction of items".
- Stylebook v10: "AI image generation" — describe an item to get a product image without photographing it.
- Lookscope: "import photos… in seconds"; Pureple: "Fastest Virtual Closet Creation"; Layered: build closet from selfies; Essembl/Google Photos: detect every item in a flat-lay or photo library automatically.
- Cladwell/Combyne/Pureple Wizard: avoid photos altogether by ticking generic or brand-catalogue items (fast but "fake closet" = top complaint at Cladwell).

**Measured / reported reality**
- Time per item: Indyx ~2 min/item, "1.5 hours for 9 items" worst case; Stylebook 2–3 h per 200 items, "12 hours to add all my clothes"; Acloset "two hours and hadn't done my pants yet"; Essembl "about 50 pieces in 10 min before bed" (best reported).
- Batch limits: Pureple crashes at 40+ photos; Essembl ~10 items per run; Whering requires triggering batch cutout per batch.
- Accuracy complaints: colours "random and very different from actual" (Whering), dress→skirt loop uncorrectable (Cladwell), extraction fails with other garments in frame (Acloset), regenerated look-alikes instead of real garments (Essembl), cardigans tagged as shirts (Whering), limited colour vocab (Indyx), photos darkened/colour-distorted by bg removal (Whering).
- Performance at scale: Indyx drag 30 s at 250+ items; Whering tag edits 5–15 min (older Android reports); Pureple "Style Me" 3 min; Acloset "stuck at 90% analyzed".
- Research consensus (loomies-01 §5): intake must be **<10–15 s per item with all defaults AI-prefilled and the user only confirming**; activation KPI = 40 items within 7 days (Whering founder), with 20% activation as GO line (loomies-23).

**Design patterns that work**
- Three intake paths side by side (photo / link-or-catalogue / receipt) — capsulezero "must-build".
- Inline, instant correction of auto-tags; flag low-confidence detections rather than committing silently; keep original pixels and offer "clean-up" as an edit, not a regeneration (essembl P0).
- Background server-side processing with a notification and a review queue; dHash de-duplication (DressApp importer); closed-vocabulary brand/category autocomplete (vestia, Vinted pattern).
- Progressive cold start: daily micro-task batches (Cladwell), preset basics wizard (Pureple), product images "make the wardrobe look better" and increase return visits (capsulezero insight #2).
- Closet must be useful at 0 items (catalogue-first, style quiz → first value in <3–10 min) — otherwise abandonment before the 40-item cliff.

---

## 7. Virtual try-on approaches and supplier benchmarks

| Approach | Who | Notes |
|---|---|---|
| 2D flat-lay collage (no body) | Stylebook, Indyx, Whering, Smart Closet, Combyne "virtual dressing room" | Zero cost, zero privacy risk; expresses composition not fit |
| Photo overlay on own selfie | Indyx Virtual Selfies (2026-07) | Cheap, honest, low realism |
| Generic model try-on | Pureple, GetWardrobe (virtual model), FitCheck clones | "see it on a model using AI" — not your body |
| Avatar from headshot+body+measurements | Alta (proprietary, "more realistic avatars" weekly), Doji (6 selfies+2 body photos, ~30 min async), Acloset (single full-body photo, 2026-07) | Trust issues: "makes everyone skinnier", "doesn't look like me", garment length changes |
| Photoreal diffusion on own photo | Google Search/Shopping "Try on you" (free infra; selfie-only since 2025-12; shoes supported), Google Photos Wardrobe (announced), Dripmatiq FitMatic (claims on-device), Doppl (dead) | Google has commoditised photo try-on as free infrastructure; moat must be closet data + daily habit, not pixels (loomies-15) |
| Parametric body (SMPL/croquis) | Nobody in category; Haze Couture failed | SMPL family is non-commercial without Meshcapade licence; FFIT body-shape rules exist (loomies-04) |

**Supplier prices (2026-04 to 2026-08 snapshots; re-verify)**: FASHN Try-On v1.6 $0.075/image (volume to ~$0.049; ~5–17 s; tops/bottoms/one-pieces; Tier III $1,249/mo for 25,594 credits); FASHN Try-On Max $0.075/step fast-1k or $0.15 balanced (clothes, shoes, hats, jewellery, bags; ~10 s/step; 4-item outfit ≈ $0.30/40 s); fal.ai image-apps-v2 try-on $0.04; Kling Kolors $0.07; Leffa (MIT) $0.10; Amazon Nova Canvas $0.04–0.06; Alibaba OutfitAnyone Plus ¥0.50 (~$0.071, ~90 s, top+bottom combo); Google Vertex `virtual-try-on-001` price unconfirmed (~$0.04–0.08 est.), 50 req/min default quota, SynthID; Gemini 3.1 Flash Image ("Nano Banana 2") $0.067–0.151/image with up to 4 character-consistency refs (selfie + garments composition); Replicate IDM-VTON $0.025/run but **CC BY-NC-SA — no commercial use**; CatVTON/OOTDiffusion also non-commercial. Caching (person, garment) pairs is the main cost lever. Latency of 5–20 s per garment means multi-piece looks run 20–60 s unless a multi-garment model (Pruna P-Image-Try-On: up to 11 garments per call; Nano Banana composition) is used.

**User pain points with VTO** (fashioncoach §5): pose distortion, lighting mismatch, no fit information, no top+bottom simultaneous try-on, worse on non-standard bodies. Privacy: full-body upload is the highest-risk tier; FASHN says no training on customer content unless opt-in, 60-min output retention; fal stores payloads 30 days unless `X-Fal-Store-IO: 0`.

---

## 8. Cross-cutting lessons for the plan

1. Feature lists are now template-able (FitCheck cluster ships scan+try-on+weather+packing+widget with 1–2 people); moat = data trust, intake speed, recommendation quality, and honest pricing.
2. Data trust is the category's life-or-death line: Smart Closet's two data wipes turned a 1M-install app into a zombie; Style DNA burned an 8-year brand with dual-track billing in 18 months; Acloset's retroactive paywall still dominates its reviews three years later.
3. The "AI" label is a double-edged sword: Acloset's "AI Upgrade" degraded results and spawned 1★ waves; Indyx users ask for *less* AI. Hide AI in outcomes; make weather/occasion correctness non-negotiable.
4. Google (Search/Shopping, Photos Wardrobe) and Pinterest (Styled for you) are the platform threats; Google explicitly abandoned the standalone app form (Doppl) but is absorbing closet+try-on into Photos. Alta is the most convergent startup (free, weekly releases, receipts import, avatar, occasion tagline) but is structurally tied to affiliate revenue, which pollutes recommendations — a wedge for a closet-only, buy-nothing stylist.
5. Growth in this category is organic/earned (Whering CAC ≈ £0.40, 80–100% organic; Indyx via Wirecutter); paid UA doesn't pay back at $5 buy-once or $40/yr (loomies-23).
