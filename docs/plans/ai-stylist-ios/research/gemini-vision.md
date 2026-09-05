# Gemini API research for a wardrobe app's UNDERSTANDING features (as of 2026-09-05)

Scope: Gemini Developer API (API key; ai.google.dev / Google AI Studio) plus Firebase AI Logic for iOS.

## 0. Method, sources, and caveats

WebSearch budget was exhausted for this session and ai.google.dev / firebase.google.com / cloud.google.com are blocked by the egress proxy, so every fact below comes from one of these primary, dated sources that ARE reachable:

| Source | Date | What it gives |
|---|---|---|
| `google-genai` 2.22.0 wheel, `google/genai/types.py` (local: `research/sdk/genai_src/`) | released 2026-09-02 | exact parameter names/enums (GenerateContentConfig, ThinkingConfig, ImageConfig, GoogleSearch, UrlContext, SafetySetting, EmbedContentConfig, CreateCachedContentConfig, ServiceTier, PartMediaResolution) |
| googleapis/python-genai `CHANGELOG.md` (github) | v2.22.0 = 2026-09-02 | "Add Gemini 3.8 Flash model to SDKs" (2026-09-02); "Add gemini-3.7-flash" (2026-08-13) |
| google-gemini/cookbook `main` (github, `research/gh/cookbook`, notebook dumps in `research/gh/nbtxt/`) | last commit 2026-09-04 | model IDs, `client.models.list()` output, spatial-understanding prompts, media-resolution token table, thinking levels, caching, batch, inference tiers, Files API limits, embeddings limits, grounding, safety |
| google-gemini/cookbook branch `archive/generate-content-api` (`research/gh/nbtxt_arch/`) | 2026-06-17 | segmentation-mask recipe, thinking_budget ranges, safety settings examples |
| BerriAI/litellm `model_prices_and_context_window.json` (raw.githubusercontent.com; `research/gh/litellm_prices.json`) | fetched 2026-09-05; entries cite `https://ai.google.dev/gemini-api/docs/pricing` | per-token prices (standard/batch/flex/priority/cache), context limits, some deprecation dates, grounding per-query prices |
| firebase/firebase-ios-sdk `FirebaseAI/` (Sources, CHANGELOG, TestApp) | last commit 2026-09-04 | Swift API names, backend selection, App Check, supported models used in tests |
| firebase/firebase-js-sdk `packages/ai` CHANGELOG | 2026-09-04 | corroborating Firebase AI Logic changes (Imagen removal, AgentPlatformBackend, locations) |
| firebase/quickstart-ios `firebaseai/` | 2026-08-12 | App Check setup guidance, sample model names |

Confidence legend: **[high]** = read directly in a primary source above; **[medium]** = third-party mirror (litellm) or inferred from two sources; **[low]** = from memory of ai.google.dev docs, could not be re-verified today — treat as "unconfirmed".

Anything not confirmable is explicitly marked *unconfirmed*.

---

## 1. Model lineup and exact IDs (Gemini Developer API)

`client.models.list()` output captured in cookbook `quickstarts/Models.ipynb` (run shortly before 3.8 Flash launched) plus the model dropdowns used across all quickstarts as of 2026-09-04 **[high]**:

### General multimodal (text+image+audio+video in, text out)
| Model ID | Status (best evidence) | Notes |
|---|---|---|
| `gemini-3.8-flash` | **Newest GA Flash**; added to SDKs 2026-09-02 (python-genai CHANGELOG) | Cookbook README: "Our most intelligent Flash model, engineered for long-horizon software engineering, autonomous agents, and complex enterprise workflows." Default `MODEL_ID` in every quickstart. **[high]** |
| `gemini-3.7-flash` | GA (no `-preview`); added to SDK 2026-08-13 | Cookbook spatial guide: "Spatial understanding works best [with] Gemini 3.7 Flash"; `models.get` → 1,048,576 in / 65,536 out. Recommended for built-in segmentation ("Gemini 3.7 Flash with thinking turned off"). **[high]** |
| `gemini-3.6-flash` | GA | in list + dropdowns; same price as 3.7/3.8 (litellm). **[high]** id, **[medium]** price |
| `gemini-3.5-flash` | GA | in list; litellm prices it at $1.50/$9.00 (higher than 3.6–3.8 — see pricing caveat). **[high]** id |
| `gemini-3.5-flash-lite` | GA | README: "fastest, lowest-cost model in the 3.5 family". **[high]** |
| `gemini-3.1-flash-lite` | GA (a `-preview` variant also still listed) | litellm deprecation_date 2027-05-07 **[medium]** |
| `gemini-3-flash-preview` | preview (older) | still listed; $0.50/$3.00 **[medium]** |
| `gemini-3.1-pro-preview` (+ `gemini-3.1-pro-preview-customtools`) | **Preview** — there is still no GA Gemini 3.x Pro | 1,048,576 in / 65,536 out (litellm). Cookbook: "You can't disable thinking for pro models"; Gemini 3 Pro supports only `low`/`high` thinking levels. **[high]** |
| `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.5-pro` | GA, still listed | No shutdown date found in any source consulted; litellm has none. **[high]** listed / deprecation *unconfirmed* |
| `gemini-flash-latest`, `gemini-flash-lite-latest`, `gemini-pro-latest` | rolling aliases | **[high]** |

### Image generation (for completeness — not the focus)
`gemini-3.1-flash-image` (Nano Banana 2, GA), `gemini-3-pro-image` (Nano Banana Pro, GA), `gemini-3.1-flash-lite-image`, `gemini-2.5-flash-image` (litellm deprecation 2026-10-02 **[medium]**). Preview IDs `gemini-3-pro-image-preview`, `gemini-3.1-flash-image-preview` listed with litellm deprecation 2026-06-25. **Imagen models were shut down Aug 2026** (Firebase iOS 12.18.0 / JS 2.15.0 CHANGELOG: "Removed deprecated Imagen methods and types due to Imagen models being shut down in August 2026") **[high]**.

### Embeddings
`gemini-embedding-2` (GA, multimodal), `gemini-embedding-2-preview` (litellm deprecation 2026-08-10 → treat as gone), `gemini-embedding-001` (text-only, still available; litellm deprecation 2028-05-14 **[medium]**). **[high]** ids.

### Other listed (not needed): `gemini-omni-1.1-flash`, `gemini-omni-flash-preview`, `gemini-3.5-transcribe(-live)`, `gemini-3.1-flash-live-preview`, `gemini-2.5-flash-native-audio-*`, `gemini-3.1-flash-tts-preview`, `gemini-robotics-er-2-preview`, `gemini-2.5-computer-use-preview-10-2025`, `deep-research-*`, `antigravity-preview-05-2026`, `gemma-4-26b-a4b-it`, `gemma-4-31b-it`, Veo 3.1, Lyria 3.

### Deprecation dates found
| Model | Date | Source/conf |
|---|---|---|
| Imagen (all) | shut down Aug 2026 | Firebase changelogs **[high]** |
| `gemini-embedding-2-preview` | 2026-08-10 | litellm **[medium]** |
| `gemini-2.5-flash-image` | 2026-10-02 | litellm **[medium]** |
| `gemini-3-pro-preview` | 2026-03-09 (already past; replaced by 3.1-pro-preview) | litellm **[medium]** |
| `gemini-3.1-flash-lite-preview` | 2026-05-25 | litellm **[medium]** |
| `gemini-3.1-flash-lite` | 2027-05-07 | litellm **[medium]** |
| `gemini-3.5-flash` (Vertex entry) | 2027-05-19 | litellm **[medium]** |
| `gemini-2.5-*` | none found | *unconfirmed* — check ai.google.dev/gemini-api/docs/deprecations |

### API surface change to be aware of
The cookbook has migrated almost every quickstart to the **Interactions API** (`client.interactions.create(model=, input=, system_instruction=, generation_config=, tools=[{"type":"google_search"}], response_format=, service_tier=)`, SDK ≥ 2.0; "the latest way to interact with Gemini models"). But the notebooks explicitly say the following are **not yet available in Interactions**: per-request `safety_settings`, `thinking_config` (in the spatial notebook), `media_resolution`, grounding metadata / URL-context metadata, Maps widget token. `generateContent` remains fully supported (and is what Firebase AI Logic uses). **Recommendation: use `generateContent` for the vision/cataloging paths** (need media_resolution + safety settings) **[high]**.

---

## 2. Image understanding

### 2.1 Object detection (bounding boxes) — verified format **[high]**
Source: cookbook `Spatial_understanding.ipynb` (main, 2026-09-04) and archive branch.

- Output: JSON array of `{"box_2d": [ymin, xmin, ymax, xmax], "label": "..."}`, coordinates **normalized to 0–1000**, **y before x**. "Gemini is trained to always use this format with a label and the coordinates of the bounding box in a `box_2d` array." Convert: `abs_y1 = box[0]/1000*height`, `abs_x1 = box[1]/1000*width`, etc. Swap if x1>x2 / y1>y2 (models occasionally invert).
- Recommended system instruction (verbatim from cookbook):
  `Return bounding boxes as a JSON array with labels. Never return masks or code fencing. Limit to 25 objects. If an object is present multiple times, name them according to their unique characteristic (colors, size, position, unique characteristics, etc..).`
- Prompt pattern: `Detect the 2d bounding boxes of the <things> (with "label" as <what to label>)`; search prompts like "Show me the positions of the socks with the face" work.
- Guidance: `temperature=0.5` (">0 to prevent the model from repeating itself"); limit object count to prevent looping; resize image to ~640–1024 px with `thumbnail` before sending; **disable thinking** ("it adds latency without improving the results") — Gemini 3: `thinking_level=MINIMAL`; 2.5: `thinking_budget=0`; strip ```json fences before parsing (or use JSON mode).
- Model choice: dropdown = `gemini-3.1-pro-preview, gemini-3.8-flash (default), gemini-3.7-flash, gemini-3.6-flash, gemini-3.5-flash-lite, gemini-2.5-pro`. Text: "works best [with] Gemini 3.7 Flash … even better with 2.5 models like gemini-2.5-pro but slightly slower".
- Pointing and 3D boxes: "experimental" (`examples/Spatial_understanding_3d.ipynb`).

### 2.2 Segmentation masks — verified format **[high]** (archive branch, 2026-06-17) with model caveat
- Prompt (verbatim): `Give the segmentation masks for the <items>. Output a JSON list of segmentation masks where each entry contains the 2D bounding box in the key "box_2d", the segmentation mask in key "mask", and the text label in the key "label". Use descriptive labels.`
- Output: JSON list of `{"box_2d":[y0,x0,y1,x1] (0–1000), "mask": "<base64 PNG>", "label": "..."}`. The PNG is a **probability map 0–255 covering only the bounding box**: base64-decode → open PNG → resize to bbox size → threshold at 127 → paste into full-size zero array. Uses `thinking_budget=0`, `temperature=0.5`, `safety_settings=[DANGEROUS_CONTENT: BLOCK_ONLY_HIGH]`.
- Which models: archive says "Some features, like segmentation, only works with 2.5 models" (written pre-3.x). Current `Get_started.ipynb` Gemini-3 migration notes: "**Image segmentation capabilities (returning pixel-level masks for objects) are not supported in Gemini 3 Pro.** For workloads requiring built-in image segmentation, consider continuing to utilize **Gemini 3.7 Flash with thinking turned off** … or Gemini Robotics-ER". ⇒ Segmentation: use `gemini-3.7-flash` (thinking minimal) or `gemini-2.5-flash`; **not** `gemini-3.1-pro-preview`. Whether 3.8 Flash segments as well is *unconfirmed* (docs still name 3.7). Cookbook's `examples/Virtual_Try_On.ipynb` uses masks for try-on style editing.

### 2.3 Token cost per image
- **Gemini 3 family (per-part `media_resolution`)** — cookbook `Get_started.ipynb` table **[high]**:

| `media_resolution` | Images | PDFs | Video |
|---|---|---|---|
| `MEDIA_RESOLUTION_HIGH` | 1120 tokens | 1120 | 280 tokens/frame |
| `MEDIA_RESOLUTION_MEDIUM` | 560 | 560 (default for PDFs) | 70/frame |
| `MEDIA_RESOLUTION_LOW` | 280 | 280 | 70/frame |
| unspecified (default) | = HIGH for images | = MEDIUM for PDFs | = MEDIUM for video |

  "These are maximums; actual usage usually ~10% lower." Set per part: `types.Part.from_bytes(data=..., mime_type=..., media_resolution=types.PartMediaResolution(level='MEDIA_RESOLUTION_HIGH'))` (SDK: `Part.media_resolution: PartMediaResolution{level: PartMediaResolutionLevel}`; enum also has `MEDIA_RESOLUTION_ULTRA_HIGH` — behaviour/tokens *unconfirmed*), or globally `GenerateContentConfig(media_resolution=...)`. `media_resolution` is **not** in the Interactions API yet. **[high]**
- **Gemini 2.x/2.5 rule** (from memory of ai.google.dev image-understanding docs, not re-verified today) **[low]**: images with both dimensions ≤ 384 px = 258 tokens; larger images are tiled into 768×768 crops, 258 tokens per tile. The legacy `MediaResolution` enum docstrings in the SDK ("LOW 64 tokens, MEDIUM 256, HIGH zoomed reframing with 256 tokens") match the older per-image scheme. Cookbook only says "Images are considered to be a fixed size, so they consume a fixed number of tokens, regardless of their display or file size."
- Cost math example (3.8 Flash, HIGH): 1120 in-tokens × $0.75/1M = **$0.00084/image**; MEDIUM 560 = $0.00042; plus output (~150–300 tokens × $3.75/1M ≈ $0.0006–0.0011). ⇒ **≈ $0.001–0.002 per garment analysis** at standard price, half with Batch/Flex.

### 2.4 Formats, limits, inline vs Files API
- Files API (cookbook `File_API.ipynb`, **[high]**): "up to **20 GB** of files per project, each file **≤ 2 GB**, files stored for **48 hours**, cannot be downloaded, available at no cost in all regions where the Gemini API is available." Upload: `client.files.upload(file=path, config={'display_name':..., 'mime_type':...})`; reference as `types.Part.from_uri(file_uri=file.uri, mime_type=...)`. Direct public HTTPS URLs and signed URLs (S3/Azure) can be passed as `file_data.file_uri` directly (API fetches each time).
- Inline: `types.Part.from_bytes(data=bytes, mime_type='image/jpeg')` (SDK `Blob{data, mime_type}`). Total request payload limit for inline data **20 MB** **[low, from memory]**; use Files API above that.
- Supported image MIME types: `image/png`, `image/jpeg`, `image/webp`, `image/heic`, `image/heif` **[low, from memory]** — cookbook examples use PNG/JPEG only.
- Max images per request: **3,600** **[low, from memory of docs]** — *unconfirmed*; wardrobe use (1–10 images) is far below any limit.
- Firebase Swift: `UIImage` → JPEG inline automatically (`jpegData(compressionQuality:)`, see `PartsRepresentable+Image.swift`), or `InlineDataPart(data:mimeType:)`, `FileDataPart(uri:mimeType:)` **[high]**.

---

## 3. Structured output (JSON mode / schemas / enums) **[high]** (SDK types.py + cookbook JSON_mode/Enum)

- `GenerateContentConfig(response_mime_type='application/json', response_schema=<pydantic class | types.Schema | list[...]>)` — OpenAPI-3 subset; SDK converts Pydantic/TypedDict/`Literal`/`Enum`.
- `response_json_schema=<JSON Schema dict>` — alternative accepting real JSON Schema; supported keywords listed in the SDK docstring: `$id $defs $ref $anchor type format title description enum(items strings/numbers) items prefixItems minItems maxItems minimum maximum anyOf oneOf(=anyOf) properties additionalProperties required` plus non-standard **`propertyOrdering`**. Cyclic refs only in non-required properties. Mutually exclusive with `response_schema`; `response_mime_type` required.
- Enum classification: `response_mime_type='text/x.enum'` with an enum `response_schema` (Firebase `GenerationConfig` docs: "`text/x.enum`: For classification tasks, output an enum value as defined in the responseSchema"); Interactions API: `response_format={"type":"text","mime_type":"application/json","schema": Recipe.model_json_schema()}`.
- Property ordering: keys emitted in `propertyOrdering` order; python-genai 2.17 auto-populates `propertyOrdering` for `response_schema`/`response_json_schema` (CHANGELOG). Put `category` → attributes → free text in that order for stable parsing.
- "Structured outputs with tools (Google Search, Code Execution…) — available with Gemini 3 models" (JSON_mode notebook).
- Firebase Swift: `GenerationConfig(responseMIMEType: "application/json", responseSchema: Schema.object(properties: [...], optionalProperties: [...], propertyOrdering: [...]))`, `Schema.enumeration(values:)`, `.array(items:)`, `.string/.integer/.float/.double/.boolean/.anyOf`; or `responseJSONSchema: JSONObject`. Public-preview `GenerativeModelSession` lets you use Foundation Models' `@Generable`/`@Guide` macros for typed output (Firebase 12.11+).

Wardrobe cataloging schema suggestion: `{category: enum[top, bottom, dress, outerwear, shoes, bag, accessory, ...], subcategory: str, primary_color: str, secondary_colors: [str], pattern: enum, material: enum, fit/silhouette, season: [enum], formality: enum, brand_guess: str|null, box_2d: [int]x4}` with `propertyOrdering`.

---

## 4. Multi-turn chat + system instructions (AI stylist)

- Python: `chat = client.chats.create(model=MODEL_ID, config={'system_instruction': ..., 'cached_content': cache.name, 'tools': [...]})`; `chat.send_message(message=..., config=...)`; streaming `send_message_stream`. `GenerateContentConfig.system_instruction: ContentUnion`. **[high]**
- Gemini 3 guidance (cookbook migration notes) **[high]**: keep default **temperature 1.0** ("consider removing this parameter … to avoid potential looping issues or performance degradation"); use `thinking_level` instead of chain-of-thought prompting; Gemini 3 uses **thought signatures** to keep reasoning context across turns/function calls — the SDK chat/AFC handles them; if you construct history manually, pass parts back unmodified.
- Firebase Swift: `model.startChat(history: [ModelContent])` → `Chat`; `chat.sendMessage(_ parts...)` / `sendMessageStream`; `chat.history`; `systemInstruction: ModelContent(parts: ...)` (text only; role ignored). **[high]**
- For an AI stylist: put persona + wardrobe JSON in a **context cache** (see §6) referenced by `cached_content`, keep per-user history client-side (Firebase `Chat` keeps it in memory), and enable `google_search` for weather/shopping.

---

## 5. Thinking configuration and cost impact

SDK `ThinkingConfig{include_thoughts: bool, thinking_budget: int, thinking_level: ThinkingLevel}`; `ThinkingLevel = MINIMAL | LOW | MEDIUM | HIGH` **[high]**.

- Gemini 3.x: "thinking is always on"; control with `thinking_level` — HIGH (default, dynamic), MEDIUM, LOW, MINIMAL ("roughly equivalent to off"). Pro models: cannot disable; 3 Pro supports only LOW/HIGH. **[high]**
- Gemini 2.5: `thinking_budget` — Flash/Flash-Lite **0 (off) … 24,576**; Pro **128 … 32,768**; `-1` = dynamic (default). Migration map: budget 0→MINIMAL, ~1024→LOW, 4096–8192→MEDIUM, max/dynamic→HIGH. **[high]**
- `include_thoughts=True` returns thought **summaries** as parts with `part.thought == True` (also in Firebase 12.2+ and `GenerativeModelSession.streamResponse`). **[high]**
- Cost: thinking tokens are billed as **output tokens** (litellm `output_cost_per_reasoning_token == output_cost_per_token` for every Gemini model) and show up in `usage_metadata.thoughts_token_count`. Example from cookbook: a 96-token prompt used 1,116 thought tokens at HIGH vs 0 at minimal → HIGH can multiply output cost 2–5×. **[high]** For detection/cataloging use MINIMAL (accuracy not improved per cookbook); for stylist chat use LOW/MEDIUM.
- Firebase Swift: `ThinkingConfig(thinkingLevel: .minimal/.low/.medium/.high, includeThoughts:)` (12.8+, Gemini 3) or `ThinkingConfig(thinkingBudget: 0…, includeThoughts:)` (2.5). **[high]**

---

## 6. Cost levers: context caching, Batch API, Flex/Priority tiers

Comparison table from cookbook `Inference_tiers.ipynb` **[high]**:

| | Standard | Flex | Priority | Batch | Caching |
|---|---|---|---|---|---|
| Price | full | **−50%** | +75–100% | **−50%** | **−90% on cached tokens** + prorated storage |
| Latency | seconds | 1–15 min target (sync, sheddable → 503) | seconds, non-sheddable, downgrades to standard on spikes | ≤ 24 h | faster TTFT |
| Availability | all | paid tiers only | Tier 2 & 3 only (rate limit 0.3× standard) | most models | — |

- `service_tier`: `GenerateContentConfig(service_tier=ServiceTier.FLEX|STANDARD|PRIORITY)` (enum values `'flex'`,`'standard'`,`'priority'`); Interactions: `service_tier='flex'`. Set client timeout ≥ 600 s for Flex; retry 503 with backoff then fall back to standard. **[high]**
- **Batch API** (`client.batches.create(model=, src=<uploaded JSONL file name> | inlined_requests=[...], config={'display_name':...})`): 50% discount, "process millions of requests", ≤ 24 h, poll `client.batches.get` or **webhooks** (`batch.succeeded`/`batch.failed`), results as JSONL file; **batch embeddings supported**; queue size varies by model. (Cookbook README also says "up to 90% discount" — that combines batch with caching; the notebook itself says 50%.) litellm batch prices: 3.8/3.7/3.6 Flash $0.375/$1.875; 3.5 Flash-Lite $0.15/$1.25; 3.1 Pro $1/$6. **[high]** mechanics, **[medium]** prices
- **Context caching**: explicit `client.caches.create(model=, config={'contents': [...], 'system_instruction': ..., 'ttl': '3600s' | 'expire_time': ...})`; default TTL 1 h; `client.caches.update(name, config=UpdateCachedContentConfig(ttl='7200s'))`; use via `GenerateContentConfig(cached_content=cache.name)` (also in `chats.create`). Caches are **model-specific**. `usage_metadata.cached_content_token_count` shows savings. litellm: cache read = 10% of input price for all 3.x models (e.g. $0.075/M on 3.8 Flash), `prompt_cache_min_tokens: 4096` for Gemini 3 Flash/Pro (i.e. minimum cacheable prefix 4,096 tokens) **[medium]**. Implicit caching is automatic (Firebase 12.9 changelog exposes `cachedContentTokenCount` "to see savings from cached content"). Storage price per token-hour not captured (*unconfirmed*; historically ~$1/M tokens/hour for Flash).
- Practical: a 30–100 item wardrobe JSON (≈ 5–20k tokens) + stylist system prompt is an ideal explicit cache for a chat session; bulk-import cataloging of a closet → Batch (50%) or Flex (50%, synchronous).

---

## 7. Rate limits per tier

Verified statements **[high]**: Priority tier default rate limits are **0.3× the standard limit for each model and tier** (cookbook, links to `https://aistudio.google.com/rate-limit`); Flex available to all paid tiers, Priority to Tier 2 & 3; free tier cannot use inference tiers; `count_tokens` and 429 handling — retry on 408/429/500/502/503/504 (cookbook Error_handling). Limits are per project and per model; the Firebase project is the same GCP project, so Firebase traffic shares them.

Numbers **[low — from memory of ai.google.dev/gemini-api/docs/rate-limits, not re-verifiable today; *unconfirmed*]**. Tiers: Free (no billing), Tier 1 (billing enabled), Tier 2 (≥ $250 cumulative spend + 30 days since payment), Tier 3 (≥ $1,000). Approximate order of magnitude for Flash-class models: Free ≈ 5–15 RPM / 250K TPM / a few hundred RPD (Flash-Lite ~1,000 RPD); Tier 1 ≈ 1,000–4,000 RPM / 1–4M TPM / 10K+ RPD; Tier 2 ≈ 2,000–10,000 RPM / 3–10M TPM; Tier 3 ≈ 10,000–30,000 RPM / 8–30M TPM. Pro-class: Free very limited or none; Tier 1 ≈ 150–300 RPM / 2M TPM; Tier 3 ≈ 2,000 RPM / 8M TPM. Embeddings ≈ 3,000 RPM Tier 1. litellm's per-model `rpm`/`tpm` fields (e.g. 2,000 RPM / 800K TPM for 3.x Flash; 15 RPM / 250K TPM for Flash-Lite; 10,000 RPM / 10M TPM for embedding-2) are internally inconsistent and should not be relied on. **Action: read the live table at aistudio.google.com/rate-limit before sizing.**

---

## 8. Google Search grounding, URL context, Maps (shopping + weather)

SDK **[high]**: `types.Tool(google_search=types.GoogleSearch(search_types=SearchTypes(...web/image...), time_range_filter=Interval(start, end)))` — `exclude_domains` and `blocking_confidence` are Vertex-only; `time_range_filter` is Gemini-API-only. `types.Tool(url_context=types.UrlContext())` (no params). `types.Tool(google_maps=types.GoogleMaps())` + `tool_config=ToolConfig(retrieval_config=RetrievalConfig(lat_lng=LatLng(latitude, longitude), language_code=...))`. Response: `candidates[0].grounding_metadata` (`search_entry_point.rendered_content` — must be displayed per Search terms; `web_search_queries`, `grounding_chunks/supports`), `candidates[0].url_context_metadata.url_metadata[]`.

- URL context: up to **20 URLs per prompt**; PDFs/images by URL can also be passed directly as `file_data`. Combine `url_context` + `google_search` in one request. **[high]**
- Interactions API: `tools=[{"type":"google_search"}]`, `{"type":"url_context"}`, `{"type":"google_maps"}` but grounding/URL metadata not yet returned there. **[high]**
- Pricing **[medium, litellm]**: Gemini 3 family **$0.014 per search query** ($14/1,000; billed per query executed — `web_search_billing_unit: per_query`); 2.5 family **$0.035 per grounded prompt** ($35/1,000); Google Maps grounding $0.025/query. Free monthly/daily grounding allowance *unconfirmed* (historically 1,500 RPD free on 2.5; a free query allowance for Gemini 3).
- Weather: there is no weather tool. Options: (a) `google_search` grounding ("what's the weather in Tel Aviv tomorrow") — works but costs a search query and is unstructured; (b) **function calling** to your own weather API (Open-Meteo etc.) — deterministic and free; recommended. Shopping: `google_search` (optionally `search_types` image search) for "where to buy a beige linen blazer", then `url_context` on the product page to extract price/size.
- Firebase Swift: `tools: [.googleSearch(), .urlContext(), .googleMaps(), .functionDeclarations([...])]`; `candidate.groundingMetadata`, `candidate.urlContextMetadata.urlMetadata` (URL context GA in 12.9). **[high]**

---

## 9. Embeddings for style similarity — `gemini-embedding-2` **[high]** (cookbook Embeddings.ipynb + SDK)

- First **multimodal** embedding model in the Gemini API: text, images, video, audio, PDFs into one space, 100+ languages. Default **3072 dims**; `EmbedContentConfig(output_dimensionality=N)` truncates (Matryoshka-style; 768/1536 are the usual choices **[medium]**).
- Limits per request: text ≤ 8,192 tokens; **images: max 6 per request, PNG/JPEG**; PDF ≤ 6 pages; audio ≤ 80 s; video ≤ 128 s; overall ≤ 8,192 tokens.
- Aggregation semantics: multiple parts in one `contents` list → **one** aggregated embedding (e.g. garment photo + caption); wrapping each in `types.Content(parts=[...])` → separate embeddings. Recommended for multi-media "posts": average separate embeddings.
- `task_type` is **not supported on gemini-embedding-2** — put task instructions in the text prompt; `gemini-embedding-001` supports `task_type` (SEMANTIC_SIMILARITY, RETRIEVAL_QUERY/DOCUMENT, CLASSIFICATION, CLUSTERING). SDK `EmbedContentConfig{task_type, title, output_dimensionality, ...}`; `document_ocr`/`audio_track_extraction` are Vertex-only.
- Price **[medium, litellm]**: $0.20 / 1M input tokens; **$0.00012 per image**; $0.00016/s audio; $0.00079/s video; embedding-001 $0.15/M (2,048-token max). Batch embeddings supported (50% off).
- Similarity: cosine / dot product; store in your own vector DB (Firestore vector search, pgvector, etc.). **Not exposed in Firebase AI Logic Swift SDK** (no embed API in `FirebaseAI/Sources` — see §13) → call from a backend (Cloud Function) or directly via REST from the app with a restricted key.

---

## 10. Safety settings for photos of people **[high]** (SDK + cookbook Safety)

- Adjustable categories: `HARM_CATEGORY_HARASSMENT`, `HARM_CATEGORY_HATE_SPEECH`, `HARM_CATEGORY_SEXUALLY_EXPLICIT`, `HARM_CATEGORY_DANGEROUS_CONTENT`; `HARM_CATEGORY_CIVIC_INTEGRITY` deprecated ("Election filter is no longer supported"); new `HARM_CATEGORY_JAILBREAK` ("Prompts designed to bypass safety filters"). `HARM_CATEGORY_IMAGE_*` values exist but are Vertex-only.
- Thresholds: `BLOCK_LOW_AND_ABOVE`, `BLOCK_MEDIUM_AND_ABOVE`, `BLOCK_ONLY_HIGH`, `BLOCK_NONE`, `OFF`. `method` (SEVERITY/PROBABILITY) is Vertex-only.
- Defaults (cookbook 2026): "Due to the model's inherent safety, additional filters are **Off** by default. You should only adjust these settings if consistently needed." Core harms (e.g. child safety) are always blocked and not adjustable. Interactions API has no per-request safety settings.
- Implications for a wardrobe app: mirror selfies/outfit photos of adults are fine at defaults; swimwear/underwear cataloging could trip `SEXUALLY_EXPLICIT` if you tighten it — keep it at default/`BLOCK_ONLY_HIGH`; the spatial notebook sets `DANGEROUS_CONTENT: BLOCK_ONLY_HIGH` to avoid false positives on scissors/knives-type objects. Check `response.prompt_feedback.block_reason` and `candidate.finish_reason == SAFETY` / `IMAGE_SAFETY`; photos of minors trying on clothes are a policy-risk area (child-safety filters are non-configurable). `ImageConfig.person_generation` (`ALLOW_ALL/ALLOW_ADULT/ALLOW_NONE`) only applies to image *generation*.
- Firebase Swift: `SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockOnlyHigh)`; `SafetyRating` exposes `probability`, `probabilityScore`, `severity`, `severityScore`, `blocked`.

---

## 11. Pricing table (USD per 1M tokens, standard tier; Gemini Developer API paid tier)

Source: litellm `model_prices_and_context_window.json` fetched 2026-09-05, whose entries cite `ai.google.dev/gemini-api/docs/pricing` **[medium]** — sanity-checked against remembered launch prices where possible. Thinking tokens billed at output rate. "Cache" = cached-input read price. Batch/Flex = −50%; Priority ≈ +80%.

| Model | Input | Output (incl. thinking) | Cache read | Batch/Flex in/out | Priority in/out | Context in/out |
|---|---|---|---|---|---|---|
| `gemini-3.8-flash` | **$0.75** | **$3.75** | $0.075 | $0.375 / $1.875 | $1.35 / $6.75 | 1,048,576 / 65,536 |
| `gemini-3.7-flash` | $0.75 | $3.75 | $0.075 | $0.375 / $1.875 | $1.35 / $6.75 | 1,048,576 / 65,536 |
| `gemini-3.6-flash` | $0.75 | $3.75 | $0.075 | $0.375 / $1.875 | $1.35 / $6.75 | 1,048,576 / 65,536 |
| `gemini-3.5-flash` | $1.50 (audio $1.50) | $9.00 | $0.15 | — (no batch price listed) | $2.70 / $16.20 | 1,048,576 / 65,535 |
| `gemini-3.5-flash-lite` | **$0.30** | **$2.50** | $0.03 | $0.15 / $1.25 | $0.54 / $4.50 | 1,048,576 / 65,536 |
| `gemini-3.1-flash-lite` | $0.25 | $1.50 | $0.025 | $0.125 / $0.75 | — | 1,048,576 / 65,536 |
| `gemini-3-flash-preview` | $0.50 | $3.00 | $0.05 | — | — | 1,048,576 / 65,535 |
| `gemini-3.1-pro-preview` | $2.00 (≤200k) / $4.00 (>200k) | $12.00 / $18.00 | $0.20 / $0.40 | $1.00 / $6.00 | $3.60 / $21.60 | 1,048,576 / 65,536 |
| `gemini-2.5-flash` | $0.30 (audio $1.00) | $2.50 | $0.03 | — | — | 1,048,576 / 65,535 |
| `gemini-2.5-flash-lite` | $0.10 | $0.40 | $0.01 | — | — | 1,048,576 / 65,535 |
| `gemini-2.5-pro` | $1.25 / $2.50 (>200k) | $10.00 / $15.00 | $0.125 | — | — | 1,048,576 / 65,535 |
| `gemini-embedding-2` | $0.20 (+$0.00012/image, $0.00016/s audio, $0.00079/s video) | n/a | — | batch −50% | — | 8,192 in; 3072 dims |
| `gemini-embedding-001` | $0.15 | n/a | — | — | — | 2,048 in; 3072 dims |
| Search grounding | Gemini 3.x: $0.014/query; 2.5: $0.035/prompt; Maps $0.025/query | | | | | |

Caveats: (1) the `gemini-3.5-flash` price ($1.50/$9) is **2× the 3.6–3.8 Flash price** in litellm — plausible (3.5 Flash was a larger "Flash" tier and 3.6+ were re-priced) but **verify on ai.google.dev/pricing before budgeting**; (2) no ">200k" surcharge exists for Flash models; (3) free tier = $0 for all listed text models with lower limits; (4) **no announced 2027 price change was found in any reachable source** — only 2027 *deprecation* dates (3.1-flash-lite 2027-05-07; 3.5-flash 2027-05-19 on Vertex) — *unconfirmed either way*; (5) context-cache storage $/token-hour not captured.

---

## 12. Files API retention, data-use policy, regional availability

- Files API: 48 h retention, 2 GB/file, 20 GB/project, free, not downloadable, tied to the API key's project; direct HTTPS/signed URLs accepted in prompts **[high]**.
- Data use **[low — from memory of the Gemini API Additional Terms of Service; *unconfirmed* today]**: on the **unpaid/free tier** Google may use prompts, uploaded content and responses to improve its products (including human review) and you must not submit sensitive/confidential/personal data; on **paid services** (Cloud Billing enabled on the project) content is *not* used to improve Google products, and processing falls under the Cloud Data Processing Addendum, with limited-time abuse-monitoring logs. Historically the free tier's data-use terms did not apply / free tier was treated differently in the EEA, UK and Switzerland; the exact current wording could not be verified. For an app handling user photos: **use a billing-enabled project (paid tier) from day one** and state this in the privacy policy.
- Regional availability: Gemini API is available in EU member states (cookbook links `ai.google.dev/available_regions`; Files API "available in all regions where the Gemini API is available") **[medium]**. The Gemini Developer API has no data-residency/location selector; for EU data residency use the Agent Platform (Vertex) backend with an EU location — Firebase now defaults to `global` and the JS changelog warns "most new Gemini models do not support us-central1" **[high]** (which EU regions host 3.x models is *unconfirmed*).

---

## 13. Firebase AI Logic (FirebaseAI / FirebaseAILogic Swift SDK) **[high]** unless noted

Source: firebase-ios-sdk `FirebaseAI/` @ 2026-09-04, quickstart-ios `firebaseai/` @ 2026-08-12, firebase-js-sdk `packages/ai` changelog.

- **Module/product**: `import FirebaseAILogic` (renamed from `FirebaseAI` in 12.5.0; `FirebaseAI` library "will be removed" in Firebase 13.0). Current release line 12.19.0. Min iOS 15. Firebase App Check became a hard dependency in 12.15.0.
- **Backends**: `FirebaseAI.firebaseAI(app:, backend: .googleAI(), useLimitedUseAppCheckTokens: false)` — `.googleAI()` = **Gemini Developer API** (default; GA since 12.4.0 "Using Firebase AI Logic with the Gemini Developer API is now Generally Available", includes "its free tier offering"); `.agentPlatform(location: "global")` = Vertex AI, renamed "Agent Platform Gemini API" in 12.17.0 (`.vertexAI()` deprecated; default location now `global`). All calls go through the **Firebase proxy** (`firebaseProxyProd`, API version `v1beta`); the Gemini API key never ships in the app; model resource name is `projects/{projectID}/models/{modelName}` for the Developer API.
- **Core API**: `generativeModel(modelName:generationConfig:safetySettings:tools:toolConfig:systemInstruction:requestOptions:) -> GenerativeModel`; `generateContent(_ parts: any PartsRepresentable...) async throws -> GenerateContentResponse`; `generateContent(_ content: [ModelContent])`; `generateContentStream(...)`; `startChat(history:) -> Chat`; `Chat.sendMessage / sendMessageStream`; `countTokens`. Parts: `TextPart`, `InlineDataPart(data:mimeType:)`, `FileDataPart(uri:mimeType:)` (doc: "File data stored in Cloud Storage for Firebase, referenced by URI" — i.e. `gs://` URIs for the Agent Platform backend; Gemini Files API URIs are not surfaced by the Swift SDK), `FunctionCallPart`, `FunctionResponsePart`, `ExecutableCodePart`, `CodeExecutionResultPart`; `UIImage` is `PartsRepresentable` (encoded to JPEG). `RequestOptions` default timeout 180 s.
- **GenerationConfig** init params: `temperature, topP, topK, candidateCount, maxOutputTokens, presencePenalty, frequencyPenalty, stopSequences, responseMIMEType ("text/plain" | "application/json" | "text/x.enum"), responseSchema: Schema, responseJSONSchema: JSONObject, responseModalities: [ResponseModality] (.text/.image/.audio), thinkingConfig: ThinkingConfig, imageConfig: ImageConfig (aspectRatio/imageSize, 12.13), speechConfig`. `Schema.object(properties:optionalProperties:propertyOrdering:...)`, `.enumeration(values:)`, `.array(items:minItems:maxItems:)`, `.anyOf(schemas:)`, `title/minimum/maximum/nullable`.
- **Thinking**: `ThinkingConfig(thinkingLevel: .minimal/.low/.medium/.high, includeThoughts:)` (12.8.0, Gemini 3+) or `ThinkingConfig(thinkingBudget:includeThoughts:)` (11.15.0, Gemini 2.5). Thought summaries returned when `includeThoughts == true` (12.2.0).
- **Tools**: `Tool.googleSearch()` (12.0.0), `.urlContext()` (12.4.0 preview → GA 12.9.0), `.googleMaps()` (12.13.0), `.codeExecution()` (12.3.0), `.functionDeclarations([FunctionDeclaration])`; `ToolConfig(functionCallingConfig: .auto()/.any(allowedFunctionNames:)/.none())`; automatic function calling via Foundation Models `Tool` conformances in `GenerativeModelSession` (12.12.0). Responses expose `groundingMetadata`, `urlContextMetadata`.
- **Safety**: `SafetySetting(harmCategory:threshold:method:)`; `HarmCategory` `.harassment/.hateSpeech/.sexuallyExplicit/.dangerousContent/.civicIntegrity`; thresholds `.blockLowAndAbove/.blockMediumAndAbove/.blockOnlyHigh/.blockNone/.off`.
- **Caching**: implicit-cache savings surfaced via `UsageMetadata.cachedContentTokenCount` / `cacheTokensDetails` (12.9.0). No explicit `caches.create` API in the Swift SDK (none in Sources) — explicit caches must be created server-side and cannot be referenced from Firebase AI Logic requests (*no `cachedContent` field in GenerateContentRequest* — **[medium]**, inferred from source listing).
- **Not in Firebase AI Logic Swift**: embeddings (`embedContent`), Files API upload, Batch API (none present in `FirebaseAI/Sources`) **[high]** → do these from a backend (Cloud Functions / Cloud Run) with the same project.
- **Other features**: Live API (public preview), Server Prompt Templates (12.6.0, `templateGenerativeModel()` — prompts stored server-side, keeps prompt IP out of the binary), hybrid on-device/cloud inference with Apple Foundation Models (12.13.0 public preview: `GeminiModel`, `HybridModel`, `GenerativeModelSession`), Nano Banana image generation via `responseModalities: [.text, .image]`; Imagen removed (12.18.0) — "migrate to Gemini Image models (Nano Banana)".
- **Supported models**: any `gemini-*` or `gemma-*` name is accepted (warning logged otherwise). Integration tests exercise `gemini-2.5-flash`, `gemini-2.5-flash-lite`, `gemini-2.5-pro`, `gemini-3.1-flash-lite`, `gemini-3.1-flash-image`, `gemini-3.1-flash-tts-preview`, `gemma-4-31b-it`, `gemini-flash-latest`; the JS SDK docs use `gemini-3.6-flash` as the example resource. `gemini-3.8-flash` availability via Firebase is not evidenced in the repos but the Developer API backend is a proxy to the same models — expected to work **[medium]**.
- **App Check**: sample app: "Firebase App Check protects your Vertex AI / Gemini API resources from abuse"; debug provider for dev, **App Attest / DeviceCheck** for App Store builds; enforcement is toggled per API in the Firebase console (App Check → Apps) **[medium]**; `useLimitedUseAppCheckTokens: true` sends limited-use tokens (12.2.0) "required for an upcoming optional feature called replay protection". API keys restricted by iOS bundle ID are supported (`x-ios-bundle-identifier` header, 12.7.0). Firebase Auth token is also forwarded (`FirebaseAuthInterop`) so you can gate by signed-in user.
- **Pricing / limits pass-through** **[medium]**: with the Developer API backend, usage is billed at Gemini API rates through the Firebase project's Cloud Billing (Blaze); the no-cost Spark plan gets the Gemini API free tier (changelog 11.13.0 "including its free tier offering"). Rate limits are the underlying Gemini API project limits (Firebase project == GCP project). The Agent Platform backend is billed at Vertex prices (litellm shows a 1.1× regional-endpoint uplift for non-global regions).

---

## 14. Recommended model per task (with rationale)

| Task | Model | Config | Why | Est. cost |
|---|---|---|---|---|
| **Garment detection / bounding boxes** (segment a full-body or flat-lay photo into items) | `gemini-3.8-flash` (fallback `gemini-3.7-flash`) | `generateContent`; system instruction from §2.1; `thinking_level=MINIMAL`; `temperature≈0.5`; `media_resolution` HIGH (1120 tok) for dense flat-lays, MEDIUM (560) for single-garment shots; `response_mime_type='application/json'` + schema `[ {box_2d:[int×4], label:str} ]` | Cookbook: spatial understanding "works best" with 3.7 Flash, 3.8 is its successor at the same price; thinking off explicitly recommended; Flash ≈ 2.7× cheaper than Pro-preview and Pro can't disable thinking | ≈ $0.001–0.002 / image |
| **Segmentation masks** (try-on cut-outs, swatch extraction) | `gemini-3.7-flash` (thinking minimal) or `gemini-2.5-flash` | prompt from §2.2, `thinking_budget=0`/`MINIMAL`, temp 0.5 | Docs: not supported on Gemini 3 Pro; 3.7 Flash named explicitly | ≈ $0.002–0.004 / image (masks are long outputs) |
| **Cataloging** (attributes: category, colors, pattern, material, season, formality) | `gemini-3.5-flash-lite` for bulk; `gemini-3.8-flash` when accuracy matters (brand/material) | `response_json_schema` with enums + `propertyOrdering`; `media_resolution=MEDIUM`; `thinking_level=MINIMAL/LOW`; bulk import via **Batch API** (−50%) or **Flex** | Flash-Lite is $0.30/$2.50 — same as 2.5 Flash but a 3.5-gen model; JSON mode removes parsing failures; Batch halves it | ≈ $0.0003–0.0006 / image (Lite, batch) |
| **AI stylist chat** (outfit suggestions, "what goes with this", weather-aware) | `gemini-3.8-flash` | `chats`/`startChat`; system instruction persona; wardrobe catalog in an **explicit context cache** (≥ 4,096 tokens) or implicit caching; `thinking_level=LOW` (MEDIUM for planning a week of outfits); tools: `google_search` (weather/shopping), `url_context` (product pages), or function-calling to a weather API | Best Flash reasoning, 1M context, tool + structured output support; cache read $0.075/M makes re-sending a 20k-token closet ≈ $0.0015/turn | ≈ $0.003–0.01 / turn |
| **Shopping recommendations** | `gemini-3.8-flash` + `google_search` (+ `url_context`) | `Tool(google_search=GoogleSearch())`, display `search_entry_point.rendered_content` | Only grounded route in the API; $0.014/query on Gemini 3 vs $0.035 on 2.5 | + $0.014 / search query |
| **Style similarity / "find similar items" / dedupe** | `gemini-embedding-2` | image (+ short caption) → one aggregated 3072-d vector, truncate to 768–1536; cosine similarity in your vector store; batch-embed the closet | Only multimodal Gemini embedding; text queries ("navy pinstripe blazer") search the same space; $0.00012/image | ≈ $0.00012 / image |
| **On-device path (iOS)** | Firebase AI Logic `FirebaseAILogic` with `.googleAI()` backend, App Check (App Attest) enforced; `gemini-3.8-flash` for vision/chat; embeddings + batch + explicit caches from a Cloud Function | Keeps API key off the device, free tier for dev, same models/prices | — |

Overall: a full closet import of 100 photos ≈ 100 × ($0.0015 detect + $0.0005 catalog + $0.00012 embed) ≈ **$0.20–0.25 at standard prices, ≈ $0.12 with Batch/Flex**; a chatty user (30 stylist turns/day) ≈ $0.10–0.30/day mostly from output/thinking tokens — cap `max_output_tokens` and thinking level.

---

## 15. Open questions / things to verify against the live docs

1. Exact current rate-limit table per tier (free / T1 / T2 / T3) for `gemini-3.8-flash`, `gemini-3.5-flash-lite`, `gemini-embedding-2` — only order-of-magnitude memory available.
2. Confirm `gemini-3.5-flash` really lists at $1.50/$9.00 vs 3.6–3.8 Flash at $0.75/$3.75 (litellm value); and whether any 2027 pricing change has been announced.
3. Whether `gemini-3.8-flash` supports segmentation masks (docs still name 3.7 Flash) and whether `MEDIA_RESOLUTION_ULTRA_HIGH` is accepted for images on the Developer API and at what token cost.
4. Current Gemini API Additional Terms wording on free-tier data use and EEA/UK/CH treatment; context-cache storage price per token-hour; Gemini 3 search-grounding free allowance.
5. Shutdown dates for `gemini-2.5-flash`/`-pro`/`-flash-lite` (none found).
6. Whether Firebase AI Logic (Developer API backend) accepts `gemini-3.8-flash` today and exposes `cachedContent` for explicit caches (source suggests no).
7. Max images per request (3,600 remembered) and inline request cap (20 MB remembered) for Gemini 3.x.
