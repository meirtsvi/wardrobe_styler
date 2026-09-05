# Gemini native image generation / editing ("Nano Banana" family) for a wardrobe app — research as of 2026-09-05

Method note: WebSearch budget was exhausted before this task started and ai.google.dev / cloud.google.com / policies.google.com are egress-blocked, so **no Google doc page was read directly**. Evidence comes from (a) the `google-genai` 2.22.0 SDK source (built 2026-09-04) and the `python-genai`, `google-gemini/cookbook`, `firebase-ios-sdk` repos cloned 2026-09-04/05, (b) third-party repos on GitHub that state they verified against Google docs on a given date (dates quoted), (c) the litellm price catalogue snapshot in `research/gh/litellm_prices.json`. Every claim carries a confidence tag. Nothing below is a Google quote unless marked as such.

Local evidence files: `research/sdk/genai_src/google/genai/{types.py,models.py,_gaos/types/interactions/*.py}`, `research/raw/*` (fetched third-party files), `research/raw/nb_nanobanana.txt` and `research/raw/nb_vto.txt` (cookbook notebooks converted to text).

---

## 1. Model IDs and status

| Model ID | Marketing name | Status 2026-09-05 | Evidence / confidence |
|---|---|---|---|
| `gemini-2.5-flash-image` | Nano Banana (original) | **Deprecated, scheduled shutdown 2026-10-02.** Still callable. generateContent only in practice (no `imageSize`). | litellm `deprecation_date: 2026-10-02` for `gemini/gemini-2.5-flash-image`; banana-claude `gemini-models.md` "verified 2026-08-29 against Google's primary documentation": "Google schedules gemini-2.5-flash-image to shut down on 2026-10-02". SDK Interactions enum still lists it. **High.** |
| `gemini-2.5-flash-image-preview` | — | Shut down (reported 2026-01-15). | evolv3ai planning doc; Firebase changelog mentions the preview id historically. **Medium.** |
| `gemini-3-pro-image` | Nano Banana Pro | **GA.** Stable id. | SDK `_gaos/types/interactions/model.py` lists `"gemini-3-pro-image"` (comment "Gemini 3 Pro Image") and alias `"nano-banana-pro-preview"` (comment "Gemini 3 Pro Image Preview"); cookbook `Get_Started_Nano_Banana.ipynb` (2026-09-04) uses `gemini-3-pro-image`; google/skills `gemini-api/SKILL.md` "Use gemini-3-pro-image (aka Nano Banana Pro)". **High.** |
| `gemini-3-pro-image-preview` | Nano Banana Pro preview | Deprecated 2026-05-28, **shut down 2026-06-25**. | promptfoo `gemini-image.ts`: "The -preview aliases were shut down by Google on June 25, 2026"; claude-blog `gemini-models.md` (2026-07-08); litellm `deprecation_date 2026-06-25`. **High.** |
| `gemini-3.1-flash-image` | Nano Banana 2 | **GA** (preview 2026-02-26 → stable 2026-05-28). Google's recommended default. | SDK enum; python-genai README example uses it; lobehub `releasedAt: '2026-05-28'`; promptfoo docs "Google … recommends gemini-3.1-flash-image as the replacement" for Imagen 4. **High.** |
| `gemini-3.1-flash-image-preview` | — | Shut down 2026-06-25. | promptfoo, claude-blog, litellm. **High.** |
| `gemini-3.1-flash-lite-image` | Nano Banana 2 Lite | **GA.** Cheapest tier, 1K only. Not in the SDK Interactions enum (banana-claude routes it via generateContent), though sickn33 examples call it via Interactions. | promptfoo, google/skills SKILL.md, cookbook model dropdown, banana-claude. **High** that it exists/GA; **medium** on Interactions support. |
| `gemini-3.5-flash-image`, `gemini-3.5-pro-image`, "Nano Banana 3" | — | **No evidence of any newer image model.** GitHub code search for `gemini-3.5-flash-image` / `gemini-3.5-pro-image` / `nano-banana-3` → 0 real hits; "Nano Banana 3" hits are marketing misnomers for 3.x. SDK 2.22.0 (2026-09-04) enum stops at `gemini-3.1-flash-image` even though text models reach `gemini-3.8-flash`. | **High** that nothing newer is in the official SDK/cookbook; **medium** that nothing newer exists at all (no web search possible). |
| `imagen-4.0-{generate,ultra-generate,fast-generate}-001` | Imagen 4 | Deprecated 2026-06-15, **shut down on the Gemini Developer API 2026-08-17**; Firebase AI Logic removed Imagen APIs in 12.18.0 ("Imagen models being shut down in August 2026"). Earlier deprecation page (2026-05-08 snapshot) said 2026-06-24; later sources say 08-17. | promptfoo docs, claude-blog, devgraphics (`IMAGEN_SHUTDOWN = "2026-08-17"`), Firebase CHANGELOG 12.18.0, mulmocast plan. **High** that Imagen 4 is gone from the Gemini API. |
| `imagen-3.0-capability-001` (edit/inpaint), `virtual-try-on-001` | Imagen edit / Vertex VTO | Vertex (renamed "Gemini Enterprise Agent Platform") only. VTO GA 2026-01-20, listed discontinuation 2027-01-20. python-genai marks `generate_images`/`edit_image` deprecated ("will be removed in the next major version"). | SDK `models.py` docstring for `recontext_image` ("Virtual Try-On … model='virtual-try-on-001'"), python-genai CHANGELOG, opentryon integrate doc (2026-08-29). **High.** |

**Bottom line:** three live production ids — `gemini-3.1-flash-lite-image`, `gemini-3.1-flash-image`, `gemini-3-pro-image` — plus deprecated `gemini-2.5-flash-image` until 2026-10-02.

---

## 2. Capability matrix

| Capability | 2.5 Flash Image | 3.1 Flash-Lite Image | 3.1 Flash Image (NB2) | 3 Pro Image (NB Pro) |
|---|---|---|---|---|
| Output sizes | fixed ~1K (1024²@1:1), no `imageSize` | 1K only | **512, 1K, 2K, 4K** | 1K, 2K, 4K |
| Aspect ratios | 10 (1:1,2:3,3:2,3:4,4:3,4:5,5:4,9:16,16:9,21:9) | 10 (docs conflict: model page says 14) | **14** (adds 1:4,4:1,1:8,8:1) | 10 (some sources say 14) |
| Max reference images | "works best with up to 3" | up to 14 object refs; no character/style refs | up to 14 total: **10 object + 4 character (people)** | up to 14 total: **6 object + 5 character (people)**; style refs up to 3 (per banana-claude; devgraphics attributes 3 style refs to Flash instead — conflict) |
| Identity/character consistency | weak (3 refs) | not optimized | yes (4 people) | best (5 people) |
| Thinking | no | minimal/high (docs conflict on default) | **thinking_level minimal/high**, `include_thoughts` | always-on reasoning, no client-selectable level; emits up to 2 interim "thought" images |
| Google Search grounding | no | no | **web + image search** (`search_types.image_search`) | web search only |
| Video input → image | no | conflict (guide says yes, model page no) | yes (YouTube URL) | no documented route |
| Mask-based inpainting | no — prompt-only "semantic masking" | no | no | no |
| Transparent background | no (all models) | no | no | no |
| Text rendering | fair | fair | good | best (independent reviews rank it top for text/infographics) |
| Batch API (generateContent, 50% off) | yes | yes | yes | yes |
| Interactions API | listed in enum | not listed | yes | yes |

Sources: cookbook `Get_Started_Nano_Banana.ipynb` (2026-09-04): "Compose and merge images … (maximum 3 with flash, 14 with pro)"; "You can now mix up to 6 images in high-fidelity and 14 with minor changes"; "Nano-Banana 2 … introduces a low-latency 512p resolution mode"; "Image search grounding (exclusive to the Nano-Banana 2 model)"; resolution table (below). Per-role reference counts: banana-claude `gemini-models.md` (verified 2026-08-29), agentclaw `nano_banana.md`, devgraphics `gemini.py` (2026-08-20), dotfyles-india notes ("[verified docs]"). **High** for sizes/ratios/thinking/grounding; **medium-high** for the 10+4 / 6+5 reference split.

### Exact pixel dimensions (cookbook table, 2026-09-04 — high confidence)

| Ratio | 512 | 1K | 2K | 4K |
|---|---|---|---|---|
| 1:1 | 512×512 | 1024×1024 | 2048×2048 | 4096×4096 |
| 2:3 | 424×632 | 848×1264 | 1696×2528 | 3392×5056 |
| 3:2 | 632×424 | 1264×848 | 2528×1696 | 5056×3392 |
| 3:4 | 448×600 | 896×1200 | 1792×2400 | 3584×4800 |
| 4:3 | 600×448 | 1200×896 | 2400×1792 | 4800×3584 |
| 4:5 | 464×576 | 928×1152 | 1856×2304 | 3712×4608 |
| 5:4 | 576×464 | 1152×928 | 2304×1856 | 4608×3712 |
| 9:16 | 384×688 | 768×1376 | 1536×2752 | 3072×5504 |
| 16:9 | 688×384 | 1376×768 | 2752×1536 | 5504×3072 |
| 21:9 | 792×336 | 1584×672 | 3168×1344 | 6336×2688 |
| 1:4 (NB2) | 256×1024 | 512×2048 | 1024×4096 | 2048×8192 |
| 4:1 (NB2) | 1024×256 | 2048×512 | 4096×1024 | 8192×2048 |
| 1:8 / 8:1 (NB2) | 192×1536 | 384×3072 | 768×6144 | 1536×12288 |

"Tokens are independent of the aspect ratio and only depend on the model and the resolution." Default is 1K; the model otherwise matches input-image size, else 1:1. Uppercase `K` is required (`1k` rejected — devgraphics).

---

## 3. Request shapes (verified against SDK source)

### 3a. generateContent (classic; still "fully supported", what Firebase iOS uses)

`google.genai.types.GenerateContentConfig` (types.py ~L6618–6650): `response_modalities: list[str]` (`"TEXT"`, `"IMAGE"`), `image_config: ImageConfig`, `thinking_config: ThinkingConfig(thinking_level=…, include_thoughts=…)`, `tools=[{"google_search": {}}]`.

`types.ImageConfig` (types.py L5794): 
- `aspect_ratio: str` — docstring lists `"1:1","2:3","3:2","3:4","4:3","9:16","16:9","21:9"` (docstring is stale; 4:5, 5:4 and the NB2 strip ratios are accepted per cookbook/Firebase enum)
- `image_size: str` — `"1K" | "2K" | "4K"` (docstring; `"512"` also accepted on NB2 per Firebase `ImageSize.size512 = "512"` and SDK `ImageSize.IMAGE_SIZE_FIVE_TWELVE`)
- `person_generation: "ALLOW_ALL" | "ALLOW_ADULT" | "ALLOW_NONE"` — CHANGELOG: "Add PersonGeneration to ImageConfig for Vertex Gempix" (Vertex only)
- `prominent_people`, `output_mime_type`, `output_compression_quality`, `image_output_options` — all "not supported in Gemini API" (Vertex only)

Python:
```python
client.models.generate_content(
    model="gemini-3.1-flash-image",
    contents=[prompt, PIL.Image.open("person.jpg"), PIL.Image.open("garment.jpg")],
    config=types.GenerateContentConfig(
        response_modalities=["IMAGE"],            # or ["TEXT","IMAGE"]
        image_config=types.ImageConfig(aspect_ratio="3:4", image_size="1K"),
        thinking_config=types.ThinkingConfig(thinking_level="high"),   # NB2 only
    ))
for part in response.parts:
    if part.thought: continue           # skip interim draft images
    if img := part.as_image(): img.save(...)
```
REST JSON (`generationConfig.responseModalities`, `generationConfig.imageConfig: {aspectRatio, imageSize}`) — cookbook Batch_mode notebook shows `'generation_config': {'response_modalities': ['TEXT','IMAGE']}` inside batch requests.

**Newer generateContent contract** (SDK `types.ResponseFormat` L11351 / `ImageResponseFormat` L11240): `generation_config.response_format = [{"image": {"aspect_ratio": "ASPECT_RATIO_THREE_BY_FOUR", "image_size": "IMAGE_SIZE_ONE_K", "mime_type": "IMAGE_JPEG", "delivery": "INLINE"|"URI"}}]` using the typed enums (`AspectRatio`, `ImageSize`, `Delivery`). Lore-Hex `vertex_gemini.go` comment: "Gemini's current GenerateContent contract configures that through responseFormat (not the older preview-only imageConfig spelling)". `response_mime_type`/`response_schema` are marked "Deprecated: Use response_format instead". Only `IMAGE_JPEG` exists in the mime enum (banana-claude SECURITY.md; devgraphics). **Medium-high** — both spellings currently work per third parties; Firebase iOS still sends `imageConfig`.

### 3b. Interactions API (POST `/v1beta/interactions`; Google's recommended surface for new work)

SDK `_gaos/types/interactions/imageresponseformat.py`: `response_format = {"type": "image", "aspect_ratio": <14 ratios>, "image_size": "512"|"1K"|"2K"|"4K", "mime_type": "image/jpeg" (only value), "delivery": …}`. `ImageConfig` inside `generation_config` is marked `@deprecated` in the SDK. Other body fields: `model` (in body), `input` (string or `[{type:"text"},{type:"image", data, mime_type}]`), `store: false` (otherwise Google retains request/response for a default 55 days; options 7/14/28/55), `previous_interaction_id` for multi-turn, `system_instruction`, `tools: [{"type":"google_search","search_types":["image_search"]}]`, `generation_config.thinking_level`, `generation_config.seed` (seed exists but no image guide documents it — devgraphics).

Response: walk `steps[] → type=="model_output" → content[] → type=="image"`; the SDK synthesizes `interaction.output_image` ("added by the SDK"). Steps of type `thought` also carry up to two interim images — do not grab the first image block (devgraphics `gemini.py`, 2026-08-20). Search-grounded requests carry mandatory 30-day retention regardless of `store:false`; Grounded Results/Search Suggestions must be shown only to the requesting user (banana-claude).

### 3c. Firebase AI Logic iOS SDK (`firebase-ios-sdk`, 2026-09-04)

`FirebaseAI/Sources/Types/Public/ImageConfig.swift`: `public struct ImageConfig { aspectRatio: AspectRatio?; imageSize: ImageSize? }`; `AspectRatio` kinds: `"1:1","9:16","16:9","3:4","4:3","2:3","3:2","4:5","5:4","1:4","4:1","1:8","8:1","21:9"`; `ImageSize` kinds `"512","1K","2K","4K"`. Used via `GenerationConfig(responseModalities: [.text, .image], thinkingConfig:, imageConfig:)` (GenerationConfig.swift L181–182). `FinishReason.imageSafety = "IMAGE_SAFETY"`, `.noImage = "NO_IMAGE"`. Firebase 12.18.0 removed Imagen; 12.5 renamed module to `FirebaseAILogic`; 12.17 renamed `Backend.vertexAI` → `Backend.agentPlatform` (default location `global`). No Interactions API surface in Firebase iOS yet (grep found none). Firebase App Check is now a dependency (12.15). **High.**

### 3d. Finish/block reasons to handle (SDK `FinishReason` L488ff, `BlockedReason`)
`STOP`, `SAFETY`, `PROHIBITED_CONTENT`, `RECITATION`, `IMAGE_SAFETY`, `IMAGE_PROHIBITED_CONTENT`, `NO_IMAGE`, `IMAGE_RECITATION`, `IMAGE_OTHER`; prompt block reasons `IMAGE_PROHIBITED_INPUT_CONTENT`, `GENERATED_IMAGE_SAFETY`, `GENERATED_IMAGE_PROHIBITED`. Refusals come back HTTP 200 with a finishReason and no `inlineData` part (pp-editor research). Gemini counts image bytes against `maxOutputTokens` — small chat defaults (128/1024) yield HTTP 200 with no image (Lore-Hex comment). **High.**

---

## 4. Pricing (USD, standard tier, Gemini Developer API)

Per-image prices below are Google's published per-image equivalents (image output is billed per token: 1K/2K NB Pro = 1,120 tokens, 4K = 2,000; NB2 1K = 1,120, 2K = 1,680, 4K = 2,520 tokens). Sources: promptfoo `gemini-image.ts` ("Source: ai.google.dev/gemini-api/docs/pricing"), fbgallet `api-keys-and-pricing.md`, litellm snapshot, lobehub, rendi (fetched 2026-07-21), claude-blog (2026-07-08), devgraphics (2026-08-20), dotfyles notes. All agree. **High** unless noted.

| Model | Output per image | Text input /M | Image input /M | Text output /M | Batch |
|---|---|---|---|---|---|
| `gemini-3.1-flash-lite-image` | **$0.0336** (1K only) | $0.25 | $0.25 | $1.50 | 50% (in $0.125/M) |
| `gemini-3.1-flash-image` | **512: $0.045 · 1K: $0.067 · 2K: $0.101 · 4K: $0.151** ($60/M image-output tokens) | $0.50 | $0.50 | $3.00 | 50% (litellm: in $0.25/M, out $1.50/M) |
| `gemini-3-pro-image` | **1K/2K: $0.134 · 4K: $0.24** ($120/M) | $2.00 | $1.10 (fbgallet) / litellm ≈$0.0011 per input image | $12.00 | 50% (litellm: in $1.00/M, out $6.00/M) |
| `gemini-2.5-flash-image` (deprecated) | **$0.039** (1,290 tokens @ $30/M) | $0.30 | $0.30 | — | 50% |
| Imagen 4 fast/std/ultra (shut down) | $0.02 / $0.04 / $0.06 | — | — | — | not batchable |
| Search grounding | $14 per 1,000 grounded queries (litellm `search_context_cost_per_query 0.014`, Gemini 3 models; $35/1k on 2.5) | | | | |

Per input image: 560 tokens for ≤384px tiles / typical photo ≈ 258–1,120 tokens; litellm lists $0.00056 per input image on NB2 and $0.0011 on Pro (**medium** — derived values). A 1-person + 1-garment try-on on NB2 at 1K ≈ $0.067 + ~$0.001 input ≈ **$0.07**; on Pro ≈ **$0.14**; on Lite ≈ **$0.035**. Thinking tokens are billed as text output ("you are paying for the thought token (but not the images in them)" — cookbook).

No free tier for image generation: "Current image model pricing tables show no free API inference tier. A key can be created without charge, but image calls need a billing-enabled project" (banana-claude, 2026-08-29). **High.**

---

## 5. Latency, rate limits, batch

**Latency** (no first-party numbers; all third-party, **low–medium**):
- IMG.LY pilot-0 suite p50 (~111 runs, fal endpoints), quoted in aircover `43_Image_Models.md` (2026-08-29, survived an adversarial refutation pass): Nano Banana 2 Lite **4.0 s**, Gemini 2.5 Flash Image **7.4 s**, Nano Banana 2 **13.2 s**, Nano Banana Pro **23.3 s** (GPT Image 1.5 34 s slowest).
- Ne4nf logo-design plan: 2.5 Flash Image ~6 s; NB2 preview 23–56 s (avg 37.6 s, "preview-phase variability"); Pro "3–12 s" (implausible vs other sources).
- pp-editor research: "~10–30 s for 1K" on Gemini, sync only.
- Rule of thumb for UX: 512px NB2 for interactive previews (~4–8 s), Pro 15–30 s → queue-and-notify.

**Rate limits** (**medium**): Google no longer publishes per-model RPM/TPM/RPD tables — "Rate limits depend on a variety of factors (such as your usage tier) and can be viewed in Google AI Studio" (quoted in RBT and unified-llm-api notes). Spend cap per rolling 10-minute window: Tier 1 **$10** (≈149 NB2 1K images / 10 min), Tier 2/3 $200; monthly billing caps Tier 1 $250, Tier 2 $2,000, Tier 3 $20k+; Tier 2 needs $100 spend + 3 days, Tier 3 $1,000 + 30 days (RBT doc; devgraphics `_RATE_HINT`). litellm lists `rpm: 1000, tpm: 4,000,000` for `gemini/gemini-3-pro-image` and `gemini-3.1-flash-image` (tier unknown). claude-blog's "Tier 1 150–300 RPM" is unsourced (**low**).

**Batch**: Nano Banana models work with the Gemini Batch API (generateContent JSONL with `generation_config.response_modalities`), 50% discount; Imagen/Veo/Lyria were not batchable; Interactions has no batch (cookbook `Batch_mode.ipynb`; banana-claude). Cookbook tip: "use 512px resolution in conjunction with the Batch API to lower your costs to the minimum … and then ask Nano-Banana to upscale the ones you need". **High.**

---

## 6. SynthID, C2PA, disclosure

- Every Gemini-generated/edited image carries an invisible **SynthID** watermark; it cannot be disabled via the Developer API and survives rescaling/compression (agentclaw "Generated images include SynthID watermarking"; claude-blog; banana-claude "Google documents SynthID on all generated images"). Vertex Imagen/VTO expose `add_watermark` (SDK `RecontextImageConfig.add_watermark: "Whether to add a SynthID watermark"`), Gemini image models do not. **High.**
- **C2PA Content Credentials** are attached to Nano Banana Pro images produced in the Gemini app, Vertex/Agent Platform and Google Ads; banana-claude warns not to assume C2PA on every Developer API response without byte-level verification. Vertex `virtual-try-on-001` output carries C2PA. **Medium.**
- Re-encoding/cropping in the app may strip C2PA metadata but not SynthID.
- Store/policy implications (**unverified — Apple/Google policy pages were blocked; from prior knowledge, treat as to-be-confirmed**): Google Play's Generative AI content policy requires apps that generate AI content to provide an in-app way for users to report/flag offensive generated content and to comply with the Inappropriate Content policy; Apple App Review 1.2 (UGC) expects filtering, reporting and blocking for user-generated/AI-generated imagery, and Apple's 2025 age-rating questionnaire asks whether the app can generate images; EU AI Act Art. 50 (applicable from Aug 2026) requires disclosure that content is AI-generated for deepfake-style imagery of real people. Practical reading: keep SynthID intact, add an "AI-generated" badge on try-on renders, keep a report button, and never present a try-on as the actual product photo.

---

## 7. Safety and policy fit for try-on

What the API enforces (**high**, from SDK enums + multiple implementers):
- Two layers: configurable `safetySettings` on the prompt (harm categories) and a **non-configurable output filter on the generated image** (`IMAGE_SAFETY`, `GENERATED_IMAGE_SAFETY`, `IMAGE_PROHIBITED_CONTENT`). "Known to be overly cautious — Google acknowledged 'filters became way more cautious than we intended' … Celebrity blocking tightened significantly with NB2" (claude-blog). No API parameter unlocks Layer 2.
- Person controls (`person_generation` ALLOW_ADULT/ALLOW_ALL/ALLOW_NONE, `prominent_people`) exist only on Vertex/Agent Platform; on the Developer API you get Google's defaults, which permit adults in ordinary clothing.
- Image Search grounding "does not support retrieving real-world images of people for generated-image use" (banana-claude).
- Google's Generative AI Prohibited Use Policy (page blocked; from knowledge, **medium**) forbids sexually explicit content, non-consensual intimate imagery, sexualization of minors, and deceptive impersonation. Editing a *consenting adult user's own photo* into a fully-clothed outfit is squarely within normal use (Google itself ships selfie try-on in Search/Shopping). Photos of minors: no explicit blanket ban on clothing edits, but the output filter is stricter around minors and the policy risk is high → recommend 18+ gating and no minor try-on.
- Field evidence on **underwear/swimwear/lingerie**: ChangeRoom (`vton.py`) treats `IMAGE_SAFETY`, `PROHIBITED_CONTENT`, "nudity/sexual/lingerie/underwear/sheer/see-through" as expected rejections, rewrites prompts to "intimate apparel"/"swim outfit", and adds a "MODESTY CONTRACT … OVERLAY-ONLY: add a thin opaque lining/underlayer or increase fabric opacity" before falling back to xAI Grok for NSFW-flagged jobs. closior and WS-APP prompts hard-code "The person remains fully clothed at all times". Expect a meaningful block rate for swimwear/lingerie categories; design the UX to degrade gracefully (show flat-lay instead of try-on for those categories). **High** that blocks occur; rate unquantified.

---

## 8. Quality evidence and failure modes for try-on (from shipped implementations)

| Source | Model | Finding |
|---|---|---|
| DridhaTeamHQ/Tria-pilot `FACE_CONSISTENCY_PLAN.md` | `gemini-3-pro-image-preview` (default; flash fallback) | "Eyes and face are changing a lot in try-on output; face is mismatching despite identity-preservation logic." Mitigations built: face crop as 2nd reference, "FACE LOCK"/"EYES" prompt blocks, temperature 0.01, face-drift metric + retry, and a separate **face-restore (face swap) stage** because prompt-only identity was insufficient. |
| madanojas-tech/closior `try-on-garment.ts` (2026-07-10) | hybrid: `gemini-2.5-flash-image` for 1–2 garments, `gemini-3-pro-image-preview` for ≥3 garments or dress/full-body ("reliable but ~3.4x the cost") | Failure modes: **"old garment left underneath"** (original pants visible under skirt/dress), **collage/diptych/before-after outputs**, canvas/crop/zoom changes, invented tattoos/markings on newly exposed skin, body reshaping. They run a `gemini-2.5-flash` verifier ("did the model actually strip the ORIGINAL lower-body garment?") and a stricter retry prompt. |
| akshatt123/WS-APP `tryon.js` | `gemini-2.5-flash-image` via generateContent | Prompt rules reveal failure modes: design "printed/pasted flat onto existing clothes" instead of worn; wrong **sleeve length**; recolouring/restyling the garment. |
| tryonlabs/opentryon `api_server.py` | Nano Banana adapters | Garment photos that contain a model **leak the model's body/face** into output; needs "EXTRACT ONLY the garment". Partial-garment (top onto dress) requires explicit complementary-garment instruction. |
| huntrbrooks/ChangeRoom `vton.py` | `gemini-3.1-flash-image-preview` via OpenRouter (fallback tier) | Body slimming/beautifying drift ("Do not slim, widen, lengthen … the person's true body size"); background used to disguise shape; intimate-apparel safety blocks. |
| Google cookbook | NB2/NB Pro | "Exact counts, spelling, identity, geometry, and small text can still fail. Inspect the actual output." High-fidelity for up to 6 refs, degraded beyond. |
| adrianchang/vintage-searcher (2026-08-10) | `gemini-3.1-flash-image` | Used for **background removal to white** on listing photos; gray vs pure-white tested; "pasted-cutout look" risk. |
| pp-editor / K-Dense / lmarena refs | NB Pro | #2 on lmarena T2I (1235 ELO), best-in-class for text/infographics; FLUX Kontext benchmarks beat "Gemini-Flash Image" on character/object preservation in edits (BFL's own bench). |

Hands: no specific Nano Banana hand-failure reports surfaced in the corpus; the recurring drift is **face/eyes, body shape, garment fidelity (sleeves, prints, length), residual old garments, and layout (collage)**. **Medium.**

### Prompt patterns that work (consensus across closior, WS-APP, opentryon, ChangeRoom, giulioco skill, cookbook)
1. Order inputs **person first, then garment(s), then text**; label them by index: "IMAGE 1 = the person (identity lock). IMAGE 2 = garment — CLOTHING REFERENCE ONLY."
2. State what must not change: "same face, hair, skin tone, body shape, pose, hands, background, crop, camera angle; do not beautify or slim."
3. State the replacement scope: "REPLACE the current top entirely; keep bottoms and shoes; the person remains fully clothed."
4. Garment fidelity list: "match colour, print, logos, neckline, button placket, exact sleeve length and hem length; render as a worn 3-D garment with folds and shadows, not a flat overlay."
5. Full-body garments: "the dress is the ONLY garment covering torso and legs; remove all existing tops/pants underneath."
6. Anti-collage: "Output EXACTLY ONE image with ONE person, same aspect ratio as IMAGE 1. No collage, diptych, grid or before/after."
7. Identity phrasing that helps NB Pro: "Keep the facial features of the person in the uploaded image exactly consistent"; add a tight face crop as a second character reference; low temperature.
8. Studio normalisation: generate a canonical "digital twin" once (neutral seamless backdrop, soft even light, full body, 3:4) and reuse it as IMAGE 1 for every try-on — closior does this and reports it stabilises results.
9. Verify + retry: cheap VLM check (`gemini-2.5-flash`/`gemini-3.x-flash`) for "old garment visible?", "face similar?", "one person?", then one stricter retry.
10. For product cutouts: "pure white background RGB 255,255,255, soft contact shadow, product only, centred"; no alpha is possible — chroma-key or on-device segmentation afterwards.

---

## 9. Imagen / Vertex comparison

| Need | Gemini Developer API (Nano Banana) | Vertex / Agent Platform |
|---|---|---|
| Mask-based inpainting (`EditMode` INPAINT_INSERTION/REMOVAL/OUTPAINT/BGSWAP/PRODUCT_IMAGE, `MaskReferenceImage`, `MaskReferenceConfig.mask_mode` BACKGROUND/FOREGROUND/SEMANTIC, `segmentation_classes`, `mask_dilation`) | **Not available** — `edit_image` never existed on the Developer API; Nano Banana is prompt-only | Was `imagen-3.0-capability-001` via `client.models.edit_image`; SDK marks it deprecated; Imagen shutdown Aug 2026 — treat as gone |
| Product background swap | prompt: "place this product on a pure white background" (NB2/Lite) | `EDIT_MODE_BGSWAP` / `EDIT_MODE_PRODUCT_IMAGE` (deprecated) or `recontext_image` product recontext |
| Dedicated virtual try-on | none | `virtual-try-on-001` via `client.models.recontext_image(source=RecontextImageSource(person_image, product_images=[ProductImage]))`; `prompt` "Not supported for Virtual Try-On"; 1–4 samples, `person_generation`, `add_watermark`; auth = GCP ADC, not `GEMINI_API_KEY`; GA 2026-01-20, discontinue 2027-01-20 |
| Upscale | none | `upscale_image` "only supported in Gemini Enterprise Agent Platform" |
| Segmentation | ask a Gemini text model for masks (cookbook VTO notebook does referring-expression segmentation with Gemini) | `segment_image` (Vertex only) |

Firebase AI Logic (iOS) also dropped Imagen; its migration guide points to Nano Banana. The official cookbook `examples/Virtual_Try_On.ipynb` is the *old* recipe (Gemini segmentation mask + Imagen 3 inpainting on Vertex) and is effectively obsolete. **High.**

---

## 10. Recommended model per generative task (wardrobe app)

| Task | Recommended | Why / settings | ≈cost/img |
|---|---|---|---|
| White-background product cutout of a user-photographed garment | Prefer **on-device segmentation** (no AI cost); if generative cleanup wanted: `gemini-3.1-flash-lite-image` 1K or `gemini-3.1-flash-image` 512 | Nano Banana has no alpha output; prompt for RGB(255,255,255) background; Lite is 1K-only, 4 s p50 | $0.034 / $0.045 |
| Flat-lay / outfit collage from wardrobe items | `gemini-3.1-flash-image` 1K–2K, 4:5 or 1:1, up to 10 object refs | best price/quality for multi-object composition; consider deterministic on-device collage for free | $0.067–0.101 |
| "Upgrade my look" edit of user photo | `gemini-3.1-flash-image` (thinking_level high) with person as Image 1; escalate to `gemini-3-pro-image` for premium | keeps face/background via prompt; Pro when identity matters | $0.067 / $0.134 |
| Put a garment on the user's photo (prompt try-on) | Default `gemini-3.1-flash-image` 1K (3:4) + verifier + 1 retry; **`gemini-3-pro-image` for dresses/≥3 garments or paid tier**; alternative: Vertex `virtual-try-on-001` if GCP is acceptable | closior/Tria evidence: Pro markedly more reliable; Flash ~half the price | $0.07 / $0.14 |
| Consistent avatar / "digital twin" | `gemini-3-pro-image` once per user (3–5 user photos as character refs → neutral-studio full-body twin at 2K), then reuse as Image 1 | 5 character refs, best identity; one-time cost | $0.134 |
| Outfit visualization on the twin (many outfits) | `gemini-3.1-flash-image` 512 for browse previews (batch, 50% off), 1K/2K on tap; Pro for share/export | 512 previews ≈ $0.022 in batch | $0.045→$0.022 batch |
| Copy/labels on generated images (lookbook cards) | `gemini-3-pro-image` | strongest text rendering | $0.134 |

Guardrails: bill-enabled project required; handle `IMAGE_SAFETY`/`NO_IMAGE` with a non-generative fallback; skip try-on for swimwear/lingerie categories or show flat-lay; 18+ only; keep SynthID; add AI-generated badge and report button; plan the `gemini-2.5-flash-image` removal before 2026-10-02 (don't build on it).

---

## 11. Open questions / unverified
- Official `ai.google.dev` pages could not be fetched: per-input-image token math, exact Pro image-input rate ($1.10/M vs litellm's per-image figure), current rate-limit tiers, and the prohibited-use policy wording are from third parties/knowledge.
- Whether `gemini-3.1-flash-lite-image` is accepted by the Interactions API (sources conflict).
- Whether NB Pro exposes style references (banana-claude: yes up to 3; devgraphics: Flash has 3, Pro 0).
- No newer image model than `gemini-3.1-flash-image` is visible in the 2026-09-04 SDK/cookbook, but a web check for a September 2026 launch was not possible.
- Apple/Google Play disclosure rules for AI-generated imagery were not re-verified this session.

## 12. Source list
- SDK: `google_genai-2.22.0` wheel (types.py, models.py, `_gaos/types/interactions/{model,imageconfig,imageresponseformat,createmodelinteraction}.py`)
- https://github.com/googleapis/python-genai (README, CHANGELOG, 2026-09-04)
- https://github.com/google-gemini/cookbook — `quickstarts/Get_Started_Nano_Banana.ipynb`, `quickstarts/Batch_mode.ipynb`, `examples/Virtual_Try_On.ipynb` (2026-09-04)
- https://github.com/firebase/firebase-ios-sdk — `FirebaseAI/Sources/Types/Public/ImageConfig.swift`, `GenerationConfig.swift`, `FirebaseAI/CHANGELOG.md` (2026-09-04)
- https://github.com/google/skills/blob/main/skills/cloud/gemini-api/SKILL.md (official Google skills repo)
- https://github.com/AgriciDaniel/banana-claude — `skills/banana/references/gemini-models.md`, `CLAUDE.md`, `SECURITY.md` (verified vs Google docs 2026-08-29)
- https://github.com/AgriciDaniel/claude-blog — `skills/blog-image/references/gemini-models.md` (2026-07-08)
- https://github.com/promptfoo/promptfoo — `src/providers/google/gemini-image.ts`, `site/docs/providers/google.md`, `examples/google-imagen/README.md`
- https://github.com/mobius29er/devGraphics — `devgraphics/backends/gemini.py` (2026-08-20)
- https://github.com/sickn33/agentic-awesome-skills — `skills/generate-nanobanana/references/*.md`
- https://github.com/lobehub/lobehub — `packages/model-bank/src/aiModels/google.ts`
- https://github.com/BerriAI/litellm price catalogue (local snapshot `research/gh/litellm_prices.json`)
- https://github.com/fbgallet/roam-extension-live-ai-assistant — `docs/api-keys-and-pricing.md`
- https://github.com/mcheemaa/rendi — `lib/obs/pricing.ts` (fetched pricing 2026-07-21)
- https://github.com/development156/aircover — `docs/43_Image_Models.md` (latency, 2026-08-29)
- https://github.com/Ne4nf/Logo-design — `specs/001-logo-design-agent/plan.md` (latency)
- https://github.com/rux-eth/pp-editor — `prs/PR-022-ai-image-generation-editing.md`
- https://github.com/huntrbrooks/ChangeRoom — `backend/services/vton.py`, `docs/virtual-try-on-pipeline.md`
- https://github.com/madanojas-tech/closior — `api/try-on-garment.ts`
- https://github.com/akshatt123/WS-APP — `backend/src/lib/tryon.js`
- https://github.com/tryonlabs/opentryon — `api_server.py`, `docs/docs/community/integrate-next.md` (2026-08-29)
- https://github.com/DridhaTeamHQ/Tria-pilot — `docs/FACE_CONSISTENCY_PLAN.md`, `src/lib/tryon/nano-banana-pro-renderer.ts`
- https://github.com/giulioco/skills — `skills/nano-banana-prompt/SKILL.md`
- https://github.com/Negai-ai/AgentClaw — `…/references/nano_banana.md`
- https://github.com/receptron/mulmocast-cli — `plans/fix-remove-deprecated-imagen-models.md` (2026-05-08)
- https://github.com/Lore-Hex/quill-cloud-proxy — `enclave-go/internal/llm/vertex_gemini.go`
- https://github.com/NousResearch/hermes-agent — `plugins/image_gen/openrouter/__init__.py`
- https://github.com/K-Dense-AI/scientific-agent-skills — `skills/generate-image/references/models.md`
- https://github.com/adrianchang/vintage-searcher — `product_design.md`
- https://github.com/mohh187/RBT — `SPEND_SOCIAL_RESEARCH.md` (rate-limit page wording)
