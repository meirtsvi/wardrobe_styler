# Essembl — Exhaustive Feature Inventory (research dump)

Compiled 2026-09-05. Method: ~200 WebSearch queries (synthesized snippets from App Store / Google Play / APKPure / apk.watch / soft112 / apps112 / appshunter / justuseapp / screensdesign / mwm.ai / TikTok / Luxembourg press / Crunchbase). Direct WebFetch of every relevant domain was blocked by the egress proxy (apps.apple.com, play.google.com, essembl.com, try.essembl.com, api.essembl.com, screensdesign, mwm.ai, apkpure, apkcombo, soft112, apps112, softonic, appshunter, justuseapp, siliconluxembourg, delano, paperjam, forbes.lu, journal.lu, luxinnovation, crunchbase, dealroom, linkedin, x.com, instagram, tiktok, youtube, itunes.apple.com lookup API). Every fact below is therefore from search-result snippets; quotes are verbatim from those snippets. Confidence: high = seen in 2+ independent snippets or verbatim store text; medium = single snippet; low = inference.

Identifiers
- iOS: App Store id 6479642952. Store name history: "Essembl : AI Styling Assistant" (2024–mid 2026) -> "Essembl: Outfit Planner" (US listing updated ~2026-07-08; some storefronts still show old name). Seller: "Essembl SA". (high) https://apps.apple.com/us/app/essembl-outfit-planner/id6479642952
- Android: package com.essembl.app, developer "Essembl SA", APK available since May 2024. (high) https://play.google.com/store/apps/details?id=com.essembl.app
- Web: essembl.com ("Essembl - Your AI Fashion Advisor"), try.essembl.com ("Essembl - Your Personal Style AI" — web style-quiz funnel), api.essembl.com/l?c=... (deep-link / referral shortener served from their own API host). (high for existence; medium for purpose)
- Support email: contact@essembl.com (store listing); info@essembl.com (company). (medium)
- MWM: mwm.ai/apps/essembl-ai-styling-assistant/6479642952 is an MWM "app page" (MWM = Paris publisher "Music World Media", 50+ apps, 600M downloads, raised ~$67M; acquired Sincerely Studios Nov 2025). No press release found confirming an Essembl acquisition; the MWM page + the "Outfit Planner" rename (an MWM-style ASO name pattern shared with "Pureple: AI Outfit Planner", "AI Dresser: Outfit Planner", "Outfitly: Outfit Planner" on mwm.ai) strongly suggests Essembl is now published/operated by MWM (2026). Seller of record on App Store still "Essembl SA". (medium/low — unconfirmed acquisition) https://mwm.ai/apps/essembl-ai-styling-assistant/6479642952 ; https://mwm.ai/publishing

---

## 1. Feature inventory table

| # | Feature | What it does (as described in sources) | Evidence / source | Confidence |
|---|---------|----------------------------------------|-------------------|------------|
| 1 | Digital wardrobe (core) | "Create a digital wardrobe... add items to your virtual closet for easy management and styling." "Organize your clothes and uncover new combinations you never considered." | App Store / Google Play description | high |
| 2 | Magic Upload — multi-item detection & extraction | "MAGIC UPLOAD allows you to upload any picture of clothes, whether it's clothes on the floor, scattered across your bed, a selfie or a store screenshot and the app will extract all the clothes from it." "the AI will detect all clothes, extract each item, put it cleanly on a white background and add it to your digital wardrobe." Introduced v0.1.55–0.1.57 (May 2025). TikTok: "you just upload a pic—even a messy one—and it turns your clothes into clean, ready-to-style wardrobe pieces. No more manual uploads." | APKPure changelog 0.1.57; App Store what's-new; TikTok @valentin_essembl video 7498749329872620822 | high |
| 3 | Photo/video upload of closet | "Upload photos or videos of your closet to create a digital wardrobe." (Google Play / essembl.com copy) | Google Play description | high (video upload wording), medium (whether video is actually processed) |
| 4 | Background removal + AI item description | "upload photos, allowing the AI to remove backgrounds and provide detailed descriptions, creating a convenient digital wardrobe." Reviewer: "The AI is genuinely good at identifying clothing, correctly recognizing garment type, colors, prints, and general style." But: "the app displayed completely different garments in the wardrobe with different colors, cuts, and construction details" (suggests AI re-renders a clean product image rather than cutting out the original photo). | AppBrain/Softonic description; App Store review snippets | high / medium (re-render behaviour) |
| 5 | Handpicked starter items ("clothes you might already own") | "massively improved first user experience, allowing users to select clothes from handpicked items that the app thinks they might already own" — onboarding lets user tap generic stock items to seed wardrobe before uploading. v0.2.16 (2026). | App Store / APKPure what's-new 0.2.16 | high |
| 6 | Import from other platforms | v0.1.44 (Jan/Feb 2025): "New ways to import clothes were added if you've been using other platforms." (which platforms unspecified) | apk.watch changelog 0.1.44 | medium |
| 7 | Categories | Wardrobe uses categories (tops, pants, shoes, accessories...). Complaints: "There's no dress or romper option for clothing categories, so dresses pair with shorts or pants"; "the 'tops' category includes all shirts, dresses, and jackets which prevents proper layering"; "when scrolling in the pants section, it keeps loading repeats". Dev reply: "feedback about dresses, accessories, and other improvements are on their roadmap." | App Store reviews | high (categories exist; dress category gap as of review time) |
| 8 | Wardrobe filters for large wardrobes | v0.1.84 (2025-10-22): "A new improved way of filtering large wardrobes." v0.1.88 also "improved inventory management with filters" / "inventory filters". | App Store / APKPure what's-new | high |
| 9 | Colour analysis option | Review snippet: "The app has a color analysis option"; "Areas of improvement include editing generated outfits and color-based suggestions". Detail unknown (likely colour matching in outfit gen, not a personal-colour-season analysis). Competitor site says Essembl has "no body analysis". | App Store review snippets; mensfashioner.com/compare/essembl | low/medium |
| 10 | AI outfit generator (occasion / weather / mood) | "Essembl uses AI to generate outfits based on your existing wardrobe... for various occasions and moods." "Whether you're dressing for the weather, an occasion, or just your mood." Occasions cited: "dinner, work, parties, and casual walks", "casual, date night, office, and travel". "smart outfit coordination suggestions based on local weather conditions, event types, and your personal preferences." Generates full look incl. shoes ("it even picks your shoes"). | Store descriptions; TikTok; mwm.ai | high |
| 11 | Outfit explanation cards | "AI-generated outfits include info cards that explain why an item was chosen, providing styling education." | screensdesign.com showcase | high |
| 12 | Geolocation for weather | "Users can enable geolocation to get more accurate outfit recommendations" (release noted 2026-04-04). | App Store what's-new | high |
| 13 | "My Essembl" daily outfits | v0.1.78 (2025-08-28): "Added 'My Essembl', automatically generated daily outfits for you." Review: "the daily auto generated outfits of the day don't generate until around 5pm". | APKPure / App Store what's-new; review | high |
| 14 | Home-screen widget (daily outfit) | v0.1.89 (2025-12-14): "Added widgets to get your daily outfit right on your homescreen." Later: "Improved Daily outfit widget." | App Store what's-new | high |
| 15 | New homescreen + outfit creation flow | v0.1.71 (2025-07-07): "New homescreen and improved outfit creation." | APKPure changelog | high |
| 16 | Accessories in outfit generation | v0.1.40/0.1.43 (Jan–Feb 2025): "accessories are now available for outfit generation". Onboarding asks "how many accessories you want to wear daily" but generator "only gives one default accessory" (review). | apk.watch changelogs; App Store review | high |
| 17 | Saved outfits / "My outfits" | "'My outfits' is now accessible through the AI tools in the wardrobe tab, letting you rate your outfits." (v0.1.46–47). v0.2.16: "Bug fixes for saved outfits and paywall issues." Reviews mention searching saved outfits by piece. | apk.watch; APKPure | high |
| 18 | Outfit Check (rate my outfit) | "upload a selfie and let Essembl rate their outfit." "gives granular feedback across categories like Color, Fit, and Texture, offering actionable advice." v0.1.38 "let the AI rate their outfits". "Streaks for daily outfit checks" (gamification). "generate a preview of outfit check change recommendations" (v0.1.81 era, Sep 2025) — i.e. AI renders an image of the suggested changes. | screensdesign; apk.watch; App Store what's-new | high |
| 19 | Share Outfit Check result | v0.1.39–0.1.41 (Jan 2025): "easier to share the outfit check result with your friends." (share card to socials) | apk.watch changelog | high |
| 20 | Outfit Glow Up (upgrade my look) | v0.1.88 (2025-11-03): "new outfit GLOW UP Feature". "provides a fantastic visual demonstration of value with an interactive before-and-after slider" — AI generates an improved version of your outfit photo. | APKPure; screensdesign | high |
| 21 | Outfit Battle (AI roast) | v0.1.87 (2025-10-30): "new Outfit Battle feature". "gamifies style feedback by letting users pit outfits against each other for an AI 'roast'." Review: "get absolutely roasted by the AI". | App Store what's-new; screensdesign | high |
| 22 | Item Finder / Outfit Finder (shop the look) | v0.1.91 (2025-12-19): "new ITEM FINDER feature where you can take a picture or screenshot of an item and the app will find it for you." v0.1.93–0.2.1: "Introducing the outfit finder, just upload a picture/screenshot of a clothing item you'd like to find and we'll help you find it!" screensdesign: "successfully identifying a handbag from a photo and providing direct shopping links." TikTok: "This Fashion App finds any outfit online and cheaper", "Find anything you see online on Essembl App". "snapping or uploading a photo, and the app identifies the items and helps you locate where to buy them." | multiple | high |
| 23 | Shopping Buddy | v0.2.24 (2026-07-08) onward: "Introducing Essembl Shopping Buddy, which knows all your clothes, your style and what you like to wear, and when you tell it what you need, it gives you shopping recommendations." Earlier "purchase recommendations by analyzing photos of potential new items and suggesting matching pieces or evaluating if it is a good purchase based on your wardrobe" (TikTok Jul 2024: "shop smarter and preview matching outfits from your personal wardrobe"). | App Store what's-new; mwm.ai; TikTok 7388958549176503584 | high |
| 24 | AI stylist chat | "Chat with an AI stylist who provides personalized outfit ideas based on details about an occasion." Persona marketed as "Val" ("Val's Closet - Personal Stylist" TikTok handle, named after founder Valentin) — in-app persona name unconfirmed. | Store descriptions; TikTok | high (chat) / low (persona name) |
| 25 | AI Training Center | v0.1.58 (2025-05-06) / 0.1.60: "added a new AI Training Center". Review: "training the AI part is based on random pieces of clothing and 'styles' rather than your actual preferences" -> a like/dislike (swipe-style) preference trainer on stock items/styles. screensdesign: "reframes loading time as 'training your AI stylist'". | APKPure; reviews; screensdesign | high (exists) / medium (mechanics) |
| 26 | Style quiz / personalization (onboarding) | try.essembl.com: "discover your personal style with AI-powered outfit recommendations by taking a style quiz." In-app onboarding is "lengthy and engaging" (~3m22s to paywall), asks e.g. "how many accessories you want to wear daily", collects email and a selfie. Gender/men's & women's fashion supported. | screensdesign; reviews | high |
| 27 | Capsule wardrobe planning | Marketing copy lists "Capsule Wardrobe Planning for both men's and women's fashion", "Mix & Match Clothes", "Closet Organizer", "Outfit Inspiration". No evidence of a dedicated capsule tool — likely marketing keyword. | Facebook/TikTok caption keyword list | low |
| 28 | Outfit calendar / planner | NO evidence of a date-based calendar. "Outfit Planner" is the 2026 store name only; daily "My Essembl" outfit + widget is the closest thing. | absence across all sources | medium (absence) |
| 29 | Packing lists / travel | NO evidence. "Travel" only appears as an occasion option. | absence | medium (absence) |
| 30 | Lookbooks / collections | NO evidence beyond saved outfits. | absence | medium (absence) |
| 31 | Virtual try-on / avatar | NOT shipped as of sources. Founders "working on a virtual try-on prototype... collaborating with LetzAI, a Luxembourg-based gen AI company, and have readied this feature for wider release" (2025 press). Competitor brief (Jul 2026): "try-on is our core, their roadmap". | Silicon Luxembourg / luxembourgofficial; github basseyriman/VoiceDress brief | high (roadmap only) |
| 32 | Body / skin analysis | None. Competitor: "no body analysis". Selfie is used for Outfit Check, not body typing. | mensfashioner.com | medium |
| 33 | Laundry / wear tracking / statistics | NO evidence. | absence | medium (absence) |
| 34 | Social / community | Not built. Roadmap (2025 press): "integrating social features to allow users to connect and share styles". Review requests social feed. Sharing exists only as share-card of Outfit Check. | luxembourgofficial; reviews | high |
| 35 | Referral: invite 3 friends -> subscription | v0.1.61 (2025-05-26): "earn a subscription by inviting 3 friends to the app." api.essembl.com/l?c=<code> referral links. | App Store what's-new | high |
| 36 | Auth | Email/password sign-up (v0.1.60 "sign up with Email/Password"), Google login (crash fixed v0.1.81, 2025-09-11); Apple Sign-In presumably (required by Apple when Google login offered) — unconfirmed. | APKPure; App Store what's-new | high / medium |
| 37 | Localization | v0.1.40–0.1.43 (Jan–Feb 2025): "translated into multiple languages". App Store metadata (appshunter, at v0.2.5) lists Languages: English only — so UI localized but store listing not. Specific languages unconfirmed. | apk.watch; appshunter | medium |
| 38 | Notifications | No explicit release note. Daily outfit generation implies push; unconfirmed. | — | low |
| 39 | Web app | None found. essembl.com = marketing; try.essembl.com = quiz funnel to app. | — | medium |
| 40 | iPad | "Designed for iPad" per App Store; Mac "not verified". | App Store | high |
| 41 | Gamification | "earning 'streaks' for daily outfit checks"; loading reframed as "training your AI stylist". | screensdesign | high |
| 42 | Ads | appshunter metadata says "in-app purchases with ads" (v0.2.5 era) — unconfirmed; Google Play data safety: shares "financial info, app activity, and app info and performance" with third parties (typical of analytics/ads SDKs). | appshunter; Google Play | low |

---

## 2. Onboarding & paywall

- Flow (screensdesign showcase, 2026): "lengthy and engaging onboarding process"; "At 03:22, the user is prompted to start a 3-day free trial, after which they will be charged for a yearly or weekly plan. The yearly plan is highlighted as 'Most Popular' and its price is broken down into a monthly equivalent." "hard paywall... By gating the entire app experience behind this paywall, Essembl ensures that only highly motivated users who have completed the personalization flow convert." (high) https://screensdesign.com/showcase/essembl-ai-styling-assistant
- Steps evidenced: style quiz questions (personal style), "how many accessories you want to wear daily", gender/men-women, email capture, selfie upload ("After going through the setup, including providing an email and a selfie, users encounter an immediate paywall"), handpicked-items wardrobe seeding (v0.2.16), AI "training" loading screen, then paywall. Exact question list NOT retrievable (screensdesign page blocked). (medium)
- v0.2.2 (2026-03-25): "Big improvement to the first time user experience after onboarding." v0.2.16: "massively improved first user experience". (high)
- Downsell: "'continue with limited features'... sends you to another option to pay $1.66 a month and they claim it's 80% off from $55" (review) -> a discounted annual (~$19.99/yr ≈ $1.66/mo) shown on decline. (medium)
- Free tier: reviews say "cannot use any features without paying... every option labeled 'pro'"; "trials requiring a credit card". Early 2025 versions advertised "completely FREE to use" (v0.1.38–0.1.47) — monetization hardened during 2025. Referral (3 invites) grants subscription. No per-day credit numbers found. (high)

## 3. Pricing (App Store IAP list)

- US: "Essembl Premium (Yearly) $29.99"; "Essembl Premium AI (Weekly) $9.99". India: ₹2,999 yearly; ₹499 weekly. 3-day free trial. Reviews also cite "$50"/"$55" annual list price and $1.66/mo (80% off) downsell — likely regional/updated pricing. Two IAP names ("Premium" vs "Premium AI") suggest a newer AI-tier SKU replaced the older one rather than two concurrent tiers. (high for listed prices; medium for interpretation) https://apps.apple.com/us/app/essembl-outfit-planner/id6479642952 ; https://apps.apple.com/in/app/essembl-ai-styling-assistant/id6479642952
- Monthly plan: not seen in IAP list. (medium)
- TikTok giveaway "1 month of Premium" (May 2025). (high)

## 4. Navigation structure (partial)

- Bottom tabs evidenced: Home ("new homescreen" v0.1.71; My Essembl daily outfits), Wardrobe tab (contains "AI tools" menu: My outfits/saved outfits, outfit generator, Outfit Check, Glow Up, Battle, Item Finder), AI stylist chat, Profile/settings (subscription, referral). Exact tab labels unconfirmed. (medium/low)
- Screens: onboarding quiz -> paywall; wardrobe grid with category sections & filters; item detail; Magic Upload flow (photo -> detected items -> confirm); outfit generator (occasion/mood/weather picker -> outfit with explanation cards -> save/share); Outfit Check (selfie -> scores Color/Fit/Texture -> change preview -> share card); Glow Up (before/after slider); Outfit Battle (two photos -> roast); Item Finder (photo/screenshot -> matches + shop links); Shopping Buddy (chat: "tell it what you need"); widget config. (medium)

## 5. Version / what's-new timeline (Android APK dates unless noted)

| Version | Date | Notes |
|---|---|---|
| launch | 2024-05-24 (iOS release date per appshunter); APK since May 2024 | "early tester" TikTok May 2024; outfit generator redesign Jun 2024; shopping preview Jul 2024 |
| 0.1.38 | ~Jan 2025 | "completely FREE to use"; "let the AI rate their outfits" (Outfit Check) |
| 0.1.39–0.1.41 | Jan 2025 | share outfit check with friends; accessories in outfit generation; multi-language |
| 0.1.42 | 2025-01-18 | free; bugfixes |
| 0.1.43 | Jan–Feb 2025 | vibration bug fixes, accessories, translations |
| 0.1.44 | Feb 2025 | import clothes from other platforms |
| 0.1.46–0.1.47 | 2025-02-16 | "My outfits" under AI tools in wardrobe tab; rate outfits |
| 0.1.55–0.1.57 | 2025-05-03 | MAGIC UPLOAD |
| 0.1.58 | 2025-05-06 | AI Training Center |
| 0.1.60 | 2025-05-14 | AI Training Center; email/password sign-up; fixes |
| 0.1.61 | 2025-05-26 | earn subscription by inviting 3 friends |
| 0.1.71 | 2025-07-07 | new homescreen, improved outfit creation |
| 0.1.72 / 0.1.74 | 2025-07-23 / 07-26 | (no notes) |
| 0.1.78 | 2025-08-28 | "My Essembl" auto daily outfits |
| 0.1.81 | 2025-09-11 | Google login crash fix; preview of outfit-check change recommendations |
| 0.1.84 | 2025-10-22 | filtering large wardrobes |
| 0.1.87 | 2025-10-30 | Outfit Battle |
| 0.1.88 | 2025-11-03 | GLOW UP; My Essembl; inventory filters (one soft112 snippet attributes Shopping Buddy text to 0.1.88 — treated as mirror-site error) |
| 0.1.89 | 2025-12-14 | home-screen widgets |
| 0.1.91 | 2025-12-19 | ITEM FINDER |
| 0.1.93 | 2025-12-23 | outfit finder (iOS wording) |
| 0.1.96–0.1.99 | 2026-02-11 → 02-24 | outfit finder iterations |
| 0.2.0 / 0.2.1 | 2026-03-05 / 03-25 | outfit finder |
| 0.2.2 | 2026-03-25 | first-time UX after onboarding |
| ~0.2.5 | Apr 2026 | geolocation for recommendations (2026-04-04); size 118 MB, iOS 15+, 4+ |
| 0.2.13–0.2.16 | May–Jun 2026 | handpicked items; magic upload in onboarding; geolocation; saved-outfits & paywall fixes |
| 0.2.19 | 2026-06-18 | (no notes) |
| 0.2.24 | 2026-07-08 | Shopping Buddy; iOS listing renamed "Essembl: Outfit Planner" |
| 0.2.26 / 0.2.27 / 0.2.28 | 2026-07-16 / 08-04(–12) / 09-02 | Shopping Buddy; improved daily outfit widget |

Priority order read-out: wardrobe + generator (2024) -> Outfit Check & sharing (Q1 2025) -> Magic Upload & AI training & referral (Q2 2025) -> home/daily outfit (Q3 2025) -> viral tools: Battle, Glow Up, widgets, Item Finder (Q4 2025) -> onboarding/conversion polish + geolocation (H1 2026) -> Shopping Buddy / commerce (Q3 2026).

## 6. Tech clues

- Framework: unconfirmed. Circumstantial: version numbering shared across iOS/Android with identical notes, "vibration bug fixes", Android package com.essembl.app, small 2–10-person team -> cross-platform (Flutter most likely; low confidence).
- Backend: own API host api.essembl.com (link/referral endpoints). AI vendors not disclosed; Viktor Dufour: "the reduction in AI costs has allowed Essembl to bring AI-powered style assistance to consumers" (LLM+vision APIs, image generation for Glow Up/change previews). Try-on prototype with LetzAI (Luxembourg gen-AI). (medium)
- Data collection: Google Play data safety — "may share financial info, app activity, and app info and performance with third parties"; App Store: privacy practices "not verified by Apple"; consumption data shared with Apple for refunds; location (opt-in geolocation), photos/selfies, email. (medium)
- Metadata: iOS 15.0+, 118 MB (v0.2.5), age 4+, iPad, Languages: English (store). Android APK ~65 MB (2025) -> ~90 MB (late 2025). (high)

## 7. Metrics & company

- Ratings: App Store 4.5/5, "10.5K reviews", "1M+ downloads" (appshunter/mwm: "750k+ downloads, 4.5/5"); Google Play 4.34/5 on 6.1K ratings; justuseapp safety score 33.4/100 on 283 reviews. (high)
- Growth: 500K sign-ups in 6 months with zero marketing spend, 40M organic social views (2024–25); 600K activated accounts & 4M AI outfits in year 1; 1M users/downloads (mid-2025); target 10M in 2 years; "1.5M+ downloads, 100k Instagram followers" (TikTok bio, 2026). Markets: US, Germany, France, Egypt (Egyptian influencer partnership). (high)
- Company: Essembl SA, Luxembourg, founded 2024 by brothers Valentin Dufour (CEO/marketing, TikTok face) & Viktor Dufour; Fabien Schon on team; 2–10 employees; Fit 4 Start #15 (Oct 2024, winner); Startup World Cup Luxembourg 2025 special mention/coup de coeur (May 2025); Pre-seed $116,758 (2025-07-15, Crunchbase); worked with Uniqlo Benelux; raising seed. (high) https://www.crunchbase.com/organization/essembl ; https://www.siliconluxembourg.lu/essembl-the-personal-fashion-advisor-in-your-pocket/
- Recurring complaints (build-avoid list): paywall after long onboarding; generator fixates on same items; no dress category; only one accessory; wardrobe images mismatch; daily outfit arrives late (~5pm); slow generation; unresponsive support; "AI just agrees with whatever you show it".
