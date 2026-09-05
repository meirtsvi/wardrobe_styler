# ADR 0001 — On-device first, Gemini for the rest

Date: 2026-09-05. Status: accepted. Supersedes parts of PLAN.md §5, §6, §7 where they conflict.

## Direction from the owner

Implement without further sign-off; run as much AI as possible on the device; use Gemini for everything the device cannot do.

## What runs where

| Capability | Device (default) | Gemini (fallback or only option) |
|---|---|---|
| Find garments in a photo | Vision `GenerateForegroundInstanceMaskRequest` instances → per-instance boxes; `ClassifyImageRequest` on each crop for a category guess | `gemini-3.8-flash` detection when the device finds no instance, or the classifier is below the confidence gate, or the garment is worn by a person |
| Cutout | Vision mask composited on white (real pixels, never regenerated) | `gemini-3.7-flash` segmentation for worn garments and low-coverage masks |
| Colour | k-means in CIELAB over masked pixels, nearest of 40 names | never (colour is always pixels) |
| Attributes (subcategory, material, pattern, fit, warmth, formality) | Foundation Models (`@Generable` structured output) from the classifier labels + colour + user hints; classifier label → taxonomy mapping when the model is unavailable | `gemini-3.5-flash-lite` on the cutout image when the on-device confidence is below the gate or the user taps "re-analyse" |
| Duplicate detection / similarity | Vision `GenerateImageFeaturePrintRequest` distance | none (embeddings stay on device) |
| Outfit planning | Stage A + Foundation Models Stage B + the validator + one repair, all on device; deterministic combiner as the last resort | `gemini-3.8-flash` Stage B via the gateway when Foundation Models is unavailable (device, locale, Apple Intelligence off) or the local model fails validation twice |
| Daily card | Planned on device on open and by `BGAppRefreshTask`; widget reads the App Group cache | none until the server has a reason to pre-plan |
| Weather | WeatherKit on device (wear window computed locally) | none |
| Stylist chat (v1.1) | Foundation Models with wardrobe tools | Gemini for image-bearing turns and unsupported locales |
| Virtual try-on, twin, clean-up, Outfit Check on photos | — | Gemini image models via the gateway; the only metered features |

## What the device classifier can and cannot see (measured 2026-09-05 on macOS 26.6, Vision `ClassifyImageRequest`, 1,303 identifiers)

Clothing-related identifiers present: `clothing`, `footwear`, `shoes`, `sneaker`, `boot`, `sandal`, `high_heel`, `loafer`, `jeans`, `hoodie`, `polo`, `jacket`, `suit`, `wedding_dress`, `swimsuit`, `wetsuit`, `bag`, `backpack`, `hat`, `baseball_hat`, `cowboy_hat`, `sunhat`, `scarf`, `necktie`, `bowtie`, `glove`, `sock`, `watch`, `sunglasses`, `eyeglasses`. Absent: dress, shirt, blouse, skirt, trousers, sweater, coat, necklace, earrings, belt. Consequence: the device settles category for shoes, bags, hats, jeans, hoodies, jackets and small accessories; for tops, dresses, skirts, knitwear and jewellery the device produces the cutout, colour and feature print, and Gemini Lite names the garment. Foundation Models is text-only and cannot replace that call.

## Consequences

- **The wardrobe is canonical on the device (SwiftData).** The server no longer needs to read the wardrobe to plan, so Firestore holds only accounts, credits, jobs, Looks and consent. Cloud backup/sync of the wardrobe is a later feature; export ZIP stays a v1.1 commitment.
- **Gateway requests carry their inputs.** `/v1/outfits/plan` accepts the client-computed candidate list; image-fallback endpoints accept the image bytes. No pixels are logged.
- **Cost per user drops** to the metered features plus fallbacks; the free tier's AI cost is dominated by whatever share of photos fall back to Gemini, measured in Phase 1 and shown in a debug screen.
- **Quality gates move to the device path.** The §5.18 golden set is run through the Vision + Foundation Models pipeline first; Gemini figures are the fallback comparison, not the baseline.
- **Foundation Models is not guaranteed.** It needs iOS 26 on Apple-Intelligence hardware with the feature enabled and an English (later more) locale. Every local call sits behind `LocalPlanner.availability` and the Gemini path must work end-to-end without it.

## §12.2 decisions taken

1. US English first; Hebrew in v1.2. 2. Solo-developer cadence. 3. Working name stays "Remy"; brand name pending, bundle id `com.meirtsvi.wardrobestyler` until then. 4. $7.99/mo, $39.99/yr, 20 Looks $4.99. 5. Staged signup grant as planned. 6. Own-photo per request by default; twin optional. 7. No FASHN, no SerpApi. 8. No EU residency at launch. 9. 13+ rating, 18+ gate for try-on. 10. Both presentations. 11. Organic-only launch. 12. MVVM with `@Observable`. 13. Gemini key on a billing-enabled project the owner controls (to be created). 14. Two-pillar 1.0 without try-on. 15. Colour analysis stays v1.1.5, free once a quarter. 16. Kids' closets: wardrobe yes, Looks no. 17. Feedback partners only. 18. iPhone-only.
