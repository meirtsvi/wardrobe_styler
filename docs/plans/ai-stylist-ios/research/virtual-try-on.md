# Virtual Try-On (VTO) for an iOS app — implementation options as of 2026-09-05

Context: app owner has a **Gemini API key** and can create a **Google Cloud project**. Goal: "put clothes on the user / on a model".

Research constraints for this pass: WebSearch budget was exhausted and Google/Apple/vendor doc hosts are egress-blocked, so evidence comes from (a) the google-genai 2.22.0 SDK source (2026-09-02), (b) official Google sample repos and notebooks on GitHub, (c) a GitHub mirror of Google Cloud docs/release notes (gvillarroel/gcp-radar, scraped 2026-04), (d) vendor SDKs pulled from PyPI/npm, (e) third-party integration repos (tryonlabs/opentryon, AlexKapadia/TryIt provider survey dated 2026-06-16, a Chinese cost study dated 2026-08-19), (f) litellm's price table. Confidence is marked per fact. Anything not confirmed is labelled **unconfirmed**.

Local evidence files: `<session-scratch>/research/` (`sdk/unz/google/genai/{models.py,types.py,client.py}`, `repos/`, `gh/`, `thirdparty/fashn/`, `oss/`, `litellm_prices.json`).

---

## 0. TL;DR

| Fact | Confidence |
|---|---|
| Google's dedicated VTO model is **`virtual-try-on-001`** (GA 2026-01-23). The preview `virtual-try-on-preview-08-04` was **shut down 2026-03-19**. `virtual-try-on-001` carries a listed discontinuation date of **2027-01-20**. | high / high / medium |
| It is **Vertex AI only** ("Gemini Enterprise Agent Platform" is Google's new name for Vertex in the SDK). The SDK hard-fails in Gemini-Developer-API (API-key) mode: `ValueError('This method is only supported in Gemini Enterprise Agent Platform mode, not in Gemini Developer API mode.')` (`models.py:5272-5276`). | high |
| Therefore an **API key alone cannot call VTO**. You need a GCP project with billing + Vertex AI API enabled, and OAuth2 (ADC / service account). From iOS that means a **backend proxy** (Cloud Run / Cloud Functions / Firebase Functions), never a service-account key in the app. | high |
| **Imagen Product Recontext** (`imagen-product-recontext-preview-06-30`) was **discontinued 2026-03-19**; Google's migration target is **`gemini-2.5-flash-image`**. No GA successor found. | high |
| **Nano Banana** (`gemini-2.5-flash-image`, `gemini-3.1-flash-image`, `gemini-3-pro-image`, `gemini-3.1-flash-lite-image`) works with the plain Gemini API key and can do prompt-based "put this garment on this person" composition. It is the only Google route that needs no GCP project. Quality is good but not a fitted try-on (fit/size/drape not physically grounded). ~$0.034–$0.134 per image. | high (availability) / medium (quality) |
| Firebase AI Logic (firebase-ios-sdk `FirebaseAI`) supports image output (`ResponseModality.image`) and tests `gemini-2.5-flash-image` / `gemini-3.1-flash-image`, so Nano Banana can be called **directly from iOS without a backend and without shipping the API key** (Firebase App Check). It has **no** VTO/recontext API. | high |
| Best third-party fallbacks: **FASHN** (direct API, `tryon-v1.6` ≈ $0.075/img, 5–17 s; `tryon-max` for accessories/4K) and **fal.ai** hosted endpoints (`fal-ai/fashn/tryon/v1.6` $0.075, `fal-ai/kling/v1-5/kolors-virtual-try-on` $0.07, `fal-ai/image-apps-v2/virtual-try-on` $0.04, `fal-ai/leffa/virtual-tryon` $0.10). | medium (prices dated 2026-06/08) |
| Open-source VTO (IDM-VTON, OOTDiffusion, CatVTON) are **CC BY-NC-SA / non-commercial**; Leffa is reported MIT. Self-hosting needs a 16–80 GB GPU and costs more than hosted APIs below ~10k images/month. | medium |
| Apple ships **no on-device VTO**. Use Vision (body pose, person segmentation, foreground instance masks) only for capture guidance and pre-processing. | high |

---

## 1. Google Virtual Try-On (`virtual-try-on-001`)

### 1.1 Model IDs, lifecycle, availability

- **GA model ID: `virtual-try-on-001`.** Release note (mirrored Google Cloud release notes, entry "January 23, 2026"): "Virtual Try-On is now generally available (GA). The new endpoint, `virtual-try-on-001`, replaces the previous endpoint, `virtual-try-on-preview-08-04`. We recommend changing to the new endpoint as soon as possible." Source: https://github.com/gvillarroel/gcp-radar (mirror of https://docs.cloud.google.com/vertex-ai/generative-ai/docs/release-notes). **High.**
- **Preview shutdown:** Feb 17, 2026 deprecation table lists `virtual-try-on-preview-08-04` → migrate to `virtual-try-on-001` "before March 19, 2026, to avoid service disruption". Same source. **High.** The Ashot72 repo (Dec 2025) still hard-codes the preview ID and will now fail.
- **Discontinuation date for `virtual-try-on-001`: 2027-01-20** — stated by three independent secondary sources: truefoundry/models `providers/google-vertex/google/virtual-try-on-001.yaml` (`retirementDate: "2027-01-20"`, sources it to https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/virtual-try-on-001), tryonlabs/opentryon docs ("GA 20 January 2026. Google lists a discontinuation date of 20 January 2027"), and AlexKapadia/TryIt provider survey. **Medium-high.** Plan for a `-002` successor; check the model page before shipping.
- **Quality history:** preview updated 2025-09-30 (body-shape and garment-identity preservation) and Dec 2025 ("Latency is significantly reduced and quality is improved for shoes, body shape preservation, and product fidelity"). Release notes mirror. **High.**
- **Vertex-only. Confirmed in SDK source** (`google/genai/models.py` 2.22.0, lines 5272–5276):
  ```python
  if not self._api_client.vertexai:
      raise ValueError('This method is only supported in Gemini Enterprise Agent Platform'
                       ' mode, not in Gemini Developer API mode.')
  ```
  js-genai sample `sdk-samples/recontext_image_virtual_try_on.ts`: "Only Vertex AI is currently supported" / "Product recontext is not supported in Gemini Developer API." **High.**
- **Naming change:** google-genai ≥2.x renamed Vertex mode to "Gemini Enterprise Agent Platform": `genai.Client(enterprise=True, project=..., location=...)`; `vertexai=True` is a legacy alias; env var `GOOGLE_GENAI_USE_ENTERPRISE` (legacy `GOOGLE_GENAI_USE_VERTEXAI`). `client.py:278-283, 371-377`; python-genai CHANGELOG entries "Introduce `enterprise` to Client constructor", "Replace Vertex AI with Gemini Enterprise Agent Platform". **High.** Docs URLs are moving to `docs.cloud.google.com/gemini-enterprise-agent-platform/models/capabilities/generate-virtual-try-on-images` (opentryon). 
- CHANGELOG also has "Allow api key + proj/location for enterprise mode" — this is Vertex **Express mode** style API-key auth; whether Express-mode keys are allowed to call `virtual-try-on-001` is **unconfirmed** (Express mode historically covers a subset of models). Treat as an experiment, not a plan.

### 1.2 Endpoint and request/response shape (REST)

Mirrored official doc page "Generate Virtual Try-On Images" (last updated 2026-04-10):

```
POST https://REGION-aiplatform.googleapis.com/v1/projects/PROJECT_ID/locations/REGION/publishers/google/models/virtual-try-on-001:predict
Authorization: Bearer $(gcloud auth print-access-token)
{
  "instances": [{
    "personImage":   { "image": { "bytesBase64Encoded": "<BASE64_PERSON_IMAGE>" } },
    "productImages": [ { "image": { "bytesBase64Encoded": "<BASE64_PRODUCT_IMAGE>" } } ]
  }],
  "parameters": { "sampleCount": IMAGE_COUNT, "storageUri": "GCS_OUTPUT_PATH" }
}
→ { "predictions": [ { "mimeType": "image/png", "bytesBase64Encoded": "..." }, ... ] }
```
- `IMAGE_COUNT` accepted range **1–4**. `gcsUri` may be used instead of base64 for both images (js-genai sample). The sample sets `GOOGLE_CLOUD_LOCATION=global`; opentryon defaults to `global` and falls back to `us-central1` if `global` 404s. Region list: **unconfirmed** (doc says "see Generative AI on Vertex AI locations"). **High** for shape.
- Full parameter set, from the SDK's Vertex converter (`models.py:3524-3600`, `_RecontextImageConfig_to_vertex`) — this is the authoritative list of what the API accepts:

| SDK field (`RecontextImageConfig`) | REST `parameters.*` | Notes |
|---|---|---|
| `number_of_images` | `sampleCount` | 1–4 |
| `base_steps` | `baseSteps` | "higher = better quality, lower = better latency"; fmind's app exposes 1–150, default 32 |
| `output_gcs_uri` | `storageUri` | write outputs to GCS instead of inline |
| `seed` | `seed` | reproducibility |
| `safety_filter_level` | `safetySetting` | `BLOCK_LOW_AND_ABOVE` / `BLOCK_MEDIUM_AND_ABOVE` / `BLOCK_ONLY_HIGH` / `BLOCK_NONE` (`types.py:1108`) |
| `person_generation` | `personGeneration` | `DONT_ALLOW` / `ALLOW_ADULT` / `ALLOW_ALL` (`types.py:379`); opentryon defaults `allow_adult` ("shopper photos need allow_adult") |
| `add_watermark` | `addWatermark` | SynthID; **default true** (getting-started notebook) |
| `output_mime_type` | `outputOptions.mimeType` | `image/png` or `image/jpeg` |
| `output_compression_quality` | `outputOptions.compressionQuality` | JPEG only |
| `enhance_prompt` | `enhancePrompt` | irrelevant for VTO (no prompt) |
| `labels` | `labels` | billing labels |

- `RecontextImageSource`: `person_image` (required), `product_images: [ProductImage(product_image=Image)]` (required), `prompt` — "**Not supported for Virtual Try-On**" (`types.py:10292-10296`), and "prompt is behind an allowlist" (`models.py:5241-5243`). opentryon: "No text prompt — the API rejects styling instructions." **High.**
- `Image` accepts `image_bytes` + `mime_type`, `gcs_uri`, or `Image.from_file(location=...)`.
- Python (official sample, `python-docs-samples/genai/image_generation/imggen_virtual_try_on_with_txt_img.py`):
  ```python
  from google import genai
  from google.genai.types import RecontextImageSource, ProductImage, Image
  client = genai.Client()  # GOOGLE_GENAI_USE_VERTEXAI=True, GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION=global
  image = client.models.recontext_image(
      model="virtual-try-on-001",
      source=RecontextImageSource(
          person_image=Image.from_file(location="test_resources/man.png"),
          product_images=[ProductImage(product_image=Image.from_file(location="test_resources/sweater.jpg"))],
      ),
  )
  image.generated_images[0].image.save(output_file)
  ```
- Node: `ai.models.recontextImage({model:'virtual-try-on-001', source:{personImage:{gcsUri|imageBytes}, productImages:[{productImage:{...}}]}, config:{numberOfImages, outputMimeType}})` with `new GoogleGenAI({vertexai:true, project, location})`. No Swift SDK; from iOS call your own backend.
- Ashot72/Virtual-Try-On-Vertex-AI (`src/index.ts`) shows the raw REST call with `google-auth-library` + a service-account JSON, scope `https://www.googleapis.com/auth/cloud-platform`, clamps `sampleCount` to 1–4, 10 MB upload limit. fmind/virtual-try-on (`app.py`) uses the SDK with `base_steps` and `number_of_images`.

### 1.3 Garment support, multi-garment, image requirements

- Supported products (official batch notebook `vision/use-cases/batch_virtual_try_on.ipynb` and fmind app description): **Tops** (shirts, hoodies, sweaters, tank tops, blouses), **Bottoms** (pants, leggings, shorts, skirts), **Footwear** (sneakers, boots, sandals, flats, heels, formal shoes). Getting-started notebook phrasing: "Tops…; Bottoms…; Other: shoes, full body items". **High** for tops/bottoms/shoes; dresses/"full body items" **medium**; accessories (bags, hats, glasses, jewelry) **not documented → assume unsupported**.
- **One product per call.** SDK: "Only one product image is supported currently." Notebook: "One clothing item per API call (sequential calls for multiple items on same person)"; workaround: "Multiple items can be combined into a single product image for one-request try-on" (i.e., a flat-lay collage of top+bottom). **High.** Chaining top → bottom → shoes = 3 calls, 3× cost, cumulative drift.
- Image inputs: PNG/JPEG, ≤10 MB each (opentryon adapter enforces "at most 10MB as PNG or JPEG"; TryIt survey; Ashot72 clamps uploads at 10 MB). Output "aspect and resolution match the person image" (opentryon). Exact min/max pixel dimensions: **unconfirmed**. Best practice from all samples: full-body or 3/4 frontal person photo, single person, plain background; product as flat-lay/ghost-mannequin or on-model crop.
- Watermark: SynthID on by default (`addWatermark`); opentryon also mentions C2PA. **Medium-high.**
- Latency: not published. Dec 2025 note says "significantly reduced". Expect single-digit to ~20 s per image (`baseSteps` trades quality/latency). **Low/unconfirmed.**
- Quota: TryIt survey cites "documented default quota ~50 requests/min per base model"; Google's own batch notebook inserts `time.sleep(2)` "to help with API quota limits". **Medium-low.** Provisioned Throughput / quota increase for scale.
- **Pricing: UNCONFIRMED.** truefoundry's model card explicitly notes "costs: not found in official docs (Imagen virtual-try-on pricing not listed on the public Vertex AI pricing page)"; TryIt survey says the price is in the Imagen section of the pricing page but JS-rendered and unverified. litellm has no `virtual-try-on` entry. Best candidate bracket: Imagen editing/capability tier ($0.04/image for `imagen-3.0-capability-001` per litellm) — **do not quote**; read https://cloud.google.com/vertex-ai/generative-ai/pricing#imagen-models live.
- Terms: GA → standard Google Cloud terms; Vertex does not train on customer data; the Generative AI Prohibited Use Policy applies (no sexual content, no minors → keep `personGeneration=ALLOW_ADULT`).

### 1.4 iOS integration pattern for Vertex VTO

1. iOS captures/selects person photo + garment image (see §7 for pre-processing).
2. iOS → your backend (Cloud Run / Firebase Callable Function) with Firebase Auth token + App Check.
3. Backend uses ADC (service account attached to Cloud Run; no key files) → `POST …/virtual-try-on-001:predict` (or google-genai `recontext_image`).
4. Return PNG/JPEG bytes (or a signed GCS URL if using `storageUri`). Do not persist inputs unless the user opted in (§7).
5. Budget: 1 image/call by default; expose "regenerate" rather than `sampleCount=4`.

---

## 2. Imagen Product Recontext (garment/product on generated scenes or models)

- Model `imagen-product-recontext-preview-06-30` existed as a second use of the same `:predict` recontext API (`productImages` + optional `prompt`, `enhancePrompt`). The python-genai changelog shows "Add add_watermark field for recontext_image (Virtual Try-On, Product Recontext)" and later "**Remove deprecated product recontext model samples from docstrings**". The 2.22.0 docstring now says "There is one type of recontextualization currently supported: Virtual Try-On." **High.**
- Release notes (Feb 17, 2026 deprecation table): `imagen-product-recontext-preview-06-30` discontinued **2026-03-19**, recommended migration **`gemini-2.5-flash-image`**. **High.** GitHub search for `imagen-product-recontext-001` finds no real usage → **no GA successor** as of the mirrored docs (2026-04). Vertex Creative Studio's `dotenv.template` still references the preview ID (stale).
- Practical replacement for "put the garment on a generated model in a scene": Nano Banana composition (§3), or FASHN `product-to-model` / `model-create` / `model-swap` (§4.1), or Photoroom "Virtual Model" (`POST /v2/edit`, opentryon), or Pruna P-Image-Try-On (multi-garment, up to 11 references). 

---

## 3. Nano Banana (Gemini image models) — the API-key-only route

### 3.1 Models and IDs (all callable with a Gemini API key via `generateContent` / Interactions)

From the cookbook `quickstarts/Get_Started_Nano_Banana.ipynb` (current main) and the mirrored Vertex release notes:

| Model ID | Nickname | Notes | Source/conf. |
|---|---|---|---|
| `gemini-2.5-flash-image` | Nano Banana | GA 2025-10-02 (aspect-ratio control, image-only modality, multi-reference, batch). 1024px class. Up to **3** reference images. | high |
| `gemini-3-pro-image` (also `-preview`) | Nano Banana Pro | Thinking + Google Search grounding; **1K/2K/4K** output; up to **14** reference images (6 high-fidelity). | high |
| `gemini-3.1-flash-image` (also `-preview`) | Nano Banana 2 | Public preview 2026-02-26; **512px / 1K / 2K / 4K**; thinking levels; search + image-search grounding (not people); Google "recommend[s] using Gemini 3.1 Flash Image when generating images". | high |
| `gemini-3.1-flash-lite-image` | Nano Banana 2 Lite | Cheapest; 1K only; "not optimized for multiple reference inputs or multi-turn sequential editing" (opentryon quoting Google) — weaker for try-on. | medium |
| `gemini-3.8-flash`, `gemini-3.7-flash`, `gemini-3.6-flash`, `gemini-3.5-flash-lite` | — | The Sept-2026 cookbook lists these general Flash models in the image-output model picker (default `gemini-3.8-flash`; google-genai 2.22.0 of 2026-09-02 "Add Gemini 3.8 Flash model"). Suggests newer Flash models have built-in image output. **Medium; verify pricing before use.** |

- Request essentials: `contents=[prompt, person_image, garment_image]`, `config=GenerateContentConfig(response_modalities=['IMAGE'], image_config=ImageConfig(aspect_ratio='3:4', image_size='1K'|'2K'|'4K'|'512px'))`. "The model's primary behavior is to match the size of your input images" (cookbook). Aspect ratios 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9, 21:9 (+1:4, 1:8, 4:1, 8:1 on NB2). 1K outputs ≈ 1290 output tokens (opentryon table).
- Multi-turn chat editing is supported (fix garment, then "tuck in the shirt", etc.).

### 3.2 Pricing (litellm `model_prices_and_context_window.json`, fetched 2026-09-05; **medium** — cross-check https://ai.google.dev/gemini-api/docs/pricing)

| Model | Output $/image | Input image | Notes |
|---|---|---|---|
| `gemini-2.5-flash-image` | **$0.039** | text $0.30/M tok | |
| `gemini-3.1-flash-image` | **$0.045** (Gemini API); Vertex row shows $0.0672 | $0.00056/input image | resolution-tiered; 512px cheaper, 4K dearer (exact tiers unconfirmed) |
| `gemini-3.1-flash-lite-image` | **$0.0336** | $0.00028/input image | |
| `gemini-3-pro-image(-preview)` | **$0.134** (1K/2K) | $0.0011/input image | 4K higher (unconfirmed, ~$0.24) ; thinking tokens billed |
| Imagen 4 (`imagen-4.0-generate-001` / fast / ultra) | $0.04 / $0.02 / $0.06 | — | text-to-image only; not for try-on |

Batch API roughly halves token prices (input `_batches` rows). Free tier does not include image output ("Enable billing to use Image Generation" — cookbook).

### 3.3 Quality and limits for try-on (medium; from vendor/integrator statements and general experience)

- Strengths: identity/face consistency, works for any garment class including accessories, hats, bags, dresses, multiple garments in one call, can change pose/background, no GCP project needed, 2K/4K output.
- Weaknesses vs dedicated VTO: no physical fit — length, tightness, drape and size are guessed; logos/prints/patterns may be altered; occasional body-shape or skin-tone drift; may "improve" the person (slimming) which is a UX/ethics problem; may refuse or alter swimwear/underwear; non-deterministic (use `seed`? — not exposed for Nano Banana; regenerate instead). opentryon explicitly labels its Nano Banana path "a fast/cheap option, not the highest-fidelity one — prefer a dedicated VTON model when garment-fit accuracy matters".
- Safety: person images of minors should be blocked client-side; Gemini will refuse sexualised edits.

### 3.4 Prompt recipe (composition try-on)

Order: `[prompt, person_image, garment_image]` and refer to them explicitly.

```
Image 1 is a photo of a person. Image 2 is a product photo of a garment.
Generate a photorealistic image of the SAME person from Image 1 wearing the garment from Image 2.
Keep everything about the person unchanged: face, identity, skin tone, hair, body shape and proportions,
pose, hands, the rest of their outfit, the background, camera angle, framing and lighting.
Replace ONLY the {top / bottoms / dress / shoes / jacket} they are wearing with the garment from Image 2.
Reproduce the garment exactly: color, pattern, print/logo placement, neckline, sleeve length, hem length,
fabric texture and fit as shown in Image 2, draped naturally on the person's body with realistic folds
and shadows. Do not add or remove any other items. Do not change the person's body. Output one image,
same aspect ratio as Image 1.
```
Variants: for a full outfit pass 2–3 garment images and say "Image 2 = top, Image 3 = bottoms, Image 4 = shoes"; for "on a model" replace Image 1 with a text description ("a studio photo of an adult female model, neutral pose, plain grey background, full body, 3:4") or a licensed/generated model image (FASHN `model-create` / Imagen 4). Add "keep the garment's proportions true to a size {S/M/L} on this body" (weak but helps). Ask for `image_size='2K'` on `gemini-3.1-flash-image` for detail; use `512px` for a fast preview then upscale the chosen one.
- opentryon's `NanoBanana2LiteAdapter.generate_virtual_tryon(person, garment, garment_description=...)` implements exactly this pattern via `generate_multi_image` with a default styling prompt.

### 3.5 Calling Nano Banana from iOS without a backend

- **Firebase AI Logic** (`FirebaseAI` in firebase-ios-sdk): `GenerationConfig(responseModalities: [.text, .image])` exists (`FirebaseAI/Sources/GenerationConfig.swift:56,181`), `ResponseModality` has `case image = "IMAGE"`, and the test app pins `gemini-2.5-flash-image` and `gemini-3.1-flash-image` (`FirebaseAI/Tests/TestApp/Sources/Constants.swift:24,31`). It can target the Gemini Developer API (API key held by Firebase, protected by App Check) or the Vertex AI Gemini API. **No `recontextImage`/VTO API in the iOS SDK** (grep found none). **High.**
- Alternative: a thin backend proxy (also needed anyway for Vertex VTO). Never embed the raw Gemini API key in the IPA.

---

## 4. Third-party VTO APIs (fallbacks)

### 4.1 FASHN.ai (direct API) — **strongest dedicated fallback**
- API: `POST https://api.fashn.ai/v1/run` → `{id}`; `GET /v1/status/{id}`; optional `webhook_url`. Python SDK `fashn` 0.9.0 on PyPI (`thirdparty/fashn/fashn/types/prediction_run_params.py`). **High.**
- `model_name: "tryon-v1.6"` inputs: `model_image`, `garment_image` (URL or `data:image/...;base64,`), `category: auto|tops|bottoms|one-pieces`, `garment_photo_type: auto|flat-lay|model`, `mode: performance (≈5 s) | balanced (≈8 s) | quality (12–17 s)`, `moderation_level: conservative|permissive|none`, `num_samples 1–4`, `output_format png|jpeg`, `return_base64` ("outputs are not stored on our servers when enabled"), `seed`, `segmentation_free`. Full-body on-model garment photo → "full outfit swap". Saved models via `saved:<name>`. **High.**
- `model_name: "tryon-max"`: `model_image` + `product_image` ("garment, accessory, etc." — shoes, hats, jewelry, bags per the 2026-08 cost study), `prompt` ("tuck in shirt", "open jacket"), `resolution 1k|2k|4k`, `generation_mode balanced|quality` (SDK) / `fast|balanced|quality` (docs), `num_images 1–4`, `aspect_ratio`, `seed`. **High** for schema.
- Other endpoints: `product-to-model` (garment → generated person; also try-on mode), `model-create`, `model-swap`, `face-to-model`, `background-change/remove`, `edit`, `reframe`, `packshot`, `image-to-video`.
- Pricing (cost study dated 2026-08-19 citing https://help.fashn.ai/plans-and-pricing/api-pricing; **medium**): 1 credit = **$0.075**; `tryon-v1.6` 1 credit/image; `tryon-max` fast+1k 1 credit (~10 s), balanced 2 credits ($0.15; balanced+2k ≈25 s); failed predictions not charged; minimum purchase 100 credits / $7.50, no subscription required. Via fal: `fal-ai/fashn/tryon/v1.6` **$0.075**/image (TryIt, 2026-06-16).
- Data: "does not use Customer Content to train unless opt-in"; status endpoint keeps outputs ≤60 min; base64 inputs not written to history. Commercial use allowed. **Medium.**

### 4.2 fal.ai (hosted endpoints; per-image pricing; one key for many models) — TryIt survey 2026-06-16, **medium**
| Endpoint | $/image | Notes |
|---|---|---|
| `fal-ai/fashn/tryon/v1.6` (and `/v1.5`) | 0.075 | ~15 s; auto-category; commercial OK |
| `fal-ai/kling/v1-5/kolors-virtual-try-on` | 0.07 | person + flat-lay garment; no mask |
| `fal-ai/leffa/virtual-tryon` | 0.10 | person + garment + garment type |
| `fal-ai/image-apps-v2/virtual-try-on` | 0.04 | cheapest; "no prompt support"; optional preserve-pose |
| `fal-ai/flux-2-lora-gallery/virtual-tryon` | n/a | FLUX-2 LoRA composition (seen in integrator code) |
| `fal-ai/idm-vton`, `fal-ai/cat-vton` | unverified | CatVTON "research only"; IDM-VTON terms not stated — avoid commercially |
Queue API: `POST https://queue.fal.run/<endpoint>` then poll; fal stores request payloads 30 days by default (cost study says set `X-Fal-Store-IO: 0` to disable — **unconfirmed header name**). `easel-ai/fashion-tryon` is deprecated.

### 4.3 Kling AI (Kuaishou) Kolors Virtual Try-On (direct)
- `POST https://api.klingai.com/v1/images/kolors-virtual-try-on` (also `https://api-singapore.klingai.com`), body `{model_name: "kolors-virtual-try-on-v1-5" | "kolors-virtual-try-on-v1", human_image, cloth_image (URL or base64), callback_url?}`; `GET /v1/images/kolors-virtual-try-on/{task_id}` → `task_status: submitted|processing|succeed|fail`, `task_result.images[].url` (short-lived URLs). Auth: JWT HS256 signed with Access Key/Secret Key (`iss`=AK, `exp`≈30 min). Prepaid resource packs; failed tasks not charged. Sources: api-evangelist/kling-ai README (2026-07-11), tryonlabs/opentryon kling docs, multiple wrappers. **High** for shape; direct pricing **unconfirmed** (fal resale $0.07).

### 4.4 Alibaba / Qwen
- **OutfitAnyone Plus (`aitryon-plus`)** on DashScope Model Studio: person (full-body, frontal, 150–4096 px, 5 KB–5 MB, JPG/PNG/BMP/HEIC) + flat-lay top and/or bottom (or dress on `top_garment_url`); `restore_face`, `resolution -1|1024|1280`. **Beijing-region key only** (international DashScope keys do not unlock it). Price **¥0.50/successful image (~$0.071)**, ~**90 s**/image (cost study 2026-08-19). Companion `aitryon-parsing-v1` for keep-original-bottoms. **Medium.** Not practical for a Western iOS app.
- **Qwen-Image / Qwen-Image-Edit** (international DashScope) = prompt composition like Nano Banana, not a fitted VTO. **Medium.**

### 4.5 Replicate (per-GPU-second, mostly non-commercial models) — TryIt 2026-06-16, **medium**
- `cuuupid/idm-vton`: A100-80GB, **~$0.025/run, ~19 s**, license **CC BY-NC-SA 4.0 (non-commercial)**.
- `viktorfa/oot_diffusion`: L40S, ~$0.15, **~3 min**. `mmezhov/catvton-flux`: ~$0.15, ~104 s, non-commercial stack.
- Good for evaluation only.

### 4.6 Others
- **Photoroom** Image Editing API `POST /v2/edit` with shopper Virtual Try-On and catalog "Virtual Model" (preset models) — opentryon adapter. Pricing unconfirmed.
- **Amazon Nova Canvas** VTO via Bedrock (`mask_type: GARMENT`, `garment_class: UPPER_BODY…`) — opentryon adapter; needs AWS. Pricing unconfirmed (Nova Canvas images are ~$0.04–0.08 class).
- **Pruna P-Image-Try-On**: multi-garment, up to 11 reference images per call — opentryon. Pricing unconfirmed.
- **Segmind Try-On Diffusion**: `category: Upper body|Lower body|Dress` — opentryon. Pricing unconfirmed.
- **Pixelcut, Vmake, Botika, Zeg**: sites blocked in this environment and no public API usage found on GitHub. Pixelcut has a developer API for background removal/upscaling; a public try-on endpoint is **unconfirmed**. Vmake and Botika are SaaS "AI model/photoshoot" products (Botika sells enterprise on-model photo generation; API availability by contract, **unconfirmed**). Zeg is a 3D/AR product-content platform, not a photo VTO API. Do not plan around these without a sales conversation.

---

## 5. Open-source models and self-hosting

| Model | Inputs / categories | Resources | License | Speed | Source |
|---|---|---|---|---|---|
| **IDM-VTON** (yisol) | person + garment; needs DensePose, human parsing, OpenPose; categories `upper_body`, `lower_body`, `dresses`; 768×1024, 30 steps | ~16–24 GB VRAM class (SDXL-based) | **CC BY-NC-SA 4.0** | ~12 s diffusion, ~19 s e2e on A100-80GB | README; arXiv 2503.20418 via TryIt |
| **OOTDiffusion** (levihsu) | half-body (VITON-HD) and full-body (DressCode) checkpoints; `--category 0 upper / 1 lower / 2 dress` | 4090/A100 | non-commercial (reported) | ~3 min on Replicate L40S | README; TryIt |
| **CatVTON** (Zheng-Chong) | person + garment, mask-free-ish; 899 M params | **<8 GB VRAM at 1024×768 bf16** | **CC BY-NC-SA 4.0** | fast | README |
| **Leffa** (franciszzj) | try-on (VITON-HD, DressCode ckpts) + pose transfer | A100 | **MIT** (reported by opentryon/TryIt; verify) | **~6 s/image fp16 on A100** | README |
| 2025–2026 research | MOFA-VTON (CVPR 2026), Eevee video VTO (CVPR 2026), MV-Fashion, Garments2Look; FitDiT/Any2AnyTryon/OmniTry style multi-garment models | — | mixed | — | awesome-vton list |

Hosting cost (estimate, **medium-low**): an A100-80GB is ~$1.5–2.5/hr on RunPod/Lambda-class clouds, ~$5/hr on Replicate ($0.0014/s); L4/RTX 4090 ~$0.4–0.8/hr suit CatVTON/Leffa. At 6–20 s per image a saturated A100 yields ~180–600 images/hr → **$0.005–0.03 GPU cost/image**, but you pay idle time; serverless (RunPod/Modal/fal custom) adds 30–90 s cold starts. Break-even vs FASHN $0.075 is roughly >3–10k images/month with steady traffic, and only if a commercial license exists (Leffa) — IDM-VTON/CatVTON/OOTD are non-commercial. Also expect preprocessing pipelines (parsing, DensePose) to be the main engineering cost. Recommendation: do not self-host at MVP.

---

## 6. Apple on-device options (no on-device VTO exists)

From Apple platform knowledge (developer.apple.com blocked; **medium** confidence on API names, which are stable):
- **Vision**: `VNDetectHumanBodyPoseRequest` (iOS 14+, 2D joints) and `VNDetectHumanBodyPose3DRequest` (iOS 17+) → verify the subject is upright, frontal, full-body in frame, arms slightly away from torso; `VNGeneratePersonSegmentationRequest` (iOS 15+) and `VNGeneratePersonInstanceMaskRequest` (iOS 17+) → confirm exactly one person, optionally flatten the background; `VNGenerateForegroundInstanceMaskRequest` (iOS 17+, "lift subject") → cut a garment out of a product photo or a photo of clothes on a hanger; `VNDetectFaceRectanglesRequest` → face present/size check; `VNClassifyImageRequest` / `VNDetectHumanRectanglesRequest` for quick gating. All run on-device, free, private.
- **ARKit** `ARBodyTrackingConfiguration` for live pose overlay during capture (A12+). **AVFoundation** capture with a silhouette guide.
- **PhotoKit / PHPickerViewController** avoids the photo-library permission prompt for user-selected images.
- Core ML: running an SD/SDXL-class VTO diffusion model on iPhone is not realistic today (multi-GB weights, minutes of compute, thermal); Apple's Image Playground has no try-on capability. Use on-device only for gating, cropping, masking, downscaling (e.g., long edge 1024–1536 px, JPEG q≈90, <10 MB) and hashing for caching.

---

## 7. UX, consent, retention, App Store

Capture guidance (borrowed from Google/FASHN/Alibaba input specs): full-body or at least knee-up, frontal, neutral pose, arms slightly apart, fitted/plain clothing, even lighting, plain background, one person, no mirror selfies, phone at chest height; garments as flat-lay/ghost-mannequin or on-model crops with the item fully visible. Validate on-device (§6) before upload; show a silhouette overlay; reject minors (ask age; VTO `personGeneration=ALLOW_ADULT` rejects children anyway).

Avatar vs real photo: offer (a) real photo (best fidelity, most sensitive), (b) a generated look-alike model (FASHN `model-create` / Imagen 4 / Nano Banana from a text description; no body photo stored), (c) stock models. Default to real photo processed ephemerally; store a re-usable "base photo" only with explicit opt-in.

Consent/retention checklist:
- Just-in-time consent sheet before the first upload naming the processor (Google Cloud / FASHN / fal), purpose, retention, and that AI results are approximate. Log consent.
- Keep body photos on-device by default; send to the provider only for the request; do not persist inputs server-side; if caching results, key by content hash and let the user delete. Provide "Delete my photos" and honour App Store account-deletion (Guideline 5.1.1(v)) by purging server copies.
- Provider retention: Vertex/Google Cloud does not train on customer data (enterprise terms); Gemini Developer API paid tier does not train on prompts but keeps abuse-monitoring logs for a limited period (**verify current duration**); FASHN `return_base64=true` keeps no outputs, inputs not logged; fal stores payloads 30 days unless disabled; Kling/Alibaba result URLs expire in 24 h–ish. Prefer providers with base64-in/base64-out and no storage.
- Body photos are personal data (GDPR/UK GDPR; CCPA); they are not biometric unless used for identification — do not run face recognition; avoid Illinois BIPA-style face-geometry processing.
- App Store Review Guidelines to satisfy (**medium**; numbers stable): 5.1.1 Data Collection and Storage (privacy policy, purpose strings `NSCameraUsageDescription`/`NSPhotoLibraryAddUsageDescription`, consent), 5.1.2 Data Use and Sharing (no repurposing, disclose sharing with AI vendors), 5.1.1(v) account deletion, 1.2 User-Generated Content (report/block if results are shareable), 1.1.4 no overtly sexual content (enforce moderation; FASHN `moderation_level: conservative`, Gemini safety filters), 2.5.13/5.1.2(iii)-style rules on face/TrueDepth data (do not use ARKit face data for anything but the feature). Privacy nutrition label: "Photos or Videos", "User Content", linked/not linked, with "App Functionality" purpose. Disclose that images are generated by AI (SynthID watermark stays on for Google models; keep `addWatermark=true`).

---

## 8. Comparison table

| Approach | Auth needed | Garment support | Quality (try-on fidelity) | Latency | Cost / image | Risks |
|---|---|---|---|---|---|---|
| **Google `virtual-try-on-001` (Vertex)** | GCP project + billing + OAuth (ADC/SA) via backend; API key **not** enough | Tops, bottoms, footwear, "full body items"; **1 product/call** (collage workaround); no prompt | High (dedicated, body-shape & garment identity preserved; SynthID) | Unpublished; est. ~5–20 s | **Unconfirmed** (not on public pricing page; likely Imagen-edit tier ~$0.04) | Discontinuation listed 2027-01-20; ~50 RPM default quota; backend required; no accessories |
| **Nano Banana `gemini-3.1-flash-image` / `gemini-2.5-flash-image` (Gemini API key)** | API key (or Firebase AI Logic from iOS) | Anything you can describe: tops/bottoms/dresses/shoes/accessories, multi-garment in one call, on-model generation | Medium (photorealistic composition; fit/size not physical; occasional garment/body drift) | ~5–15 s (512px faster) | $0.039 (2.5) / $0.045 (3.1; $0.0336 lite) / $0.134 (3-pro) | Non-deterministic; may alter body/logos; safety refusals; key must not ship in app |
| **Imagen Product Recontext** | Vertex | — | — | — | — | **Discontinued 2026-03-19** → use Nano Banana |
| **FASHN direct (`tryon-v1.6`, `tryon-max`)** | FASHN API key (backend) | v1.6: tops/bottoms/one-pieces; max: garments + shoes/hats/jewelry/bags, prompt styling, up to 4K | High (dedicated; widely benchmarked as SOTA hosted) | 5 / 8 / 12–17 s (v1.6 modes); ~10–25 s (max) | $0.075 (1 credit); max balanced $0.15 | Startup vendor; credits prepaid; moderation policy |
| **fal.ai hosted (FASHN, Kling, Leffa, image-apps-v2)** | fal key (backend) | tops/bottoms/one-piece; Kling flat-lay; image-apps-v2 generic | High (FASHN/Kling) → medium (image-apps-v2) | ~10–20 s | $0.04–0.10 | Payload retention 30 d default; model deprecations |
| **Kling direct** | AK/SK → JWT (backend) | person + garment (tops/bottoms/dress) | High-medium | async, tens of s | unconfirmed (fal $0.07) | Prepaid packs; CN vendor; short-lived URLs |
| **Alibaba `aitryon-plus`** | Beijing DashScope key | top/bottom/combo/dress, flat-lay only | High | ~90 s | ¥0.50 (~$0.071) | China-only endpoint; latency |
| **Replicate IDM-VTON etc.** | Replicate token | upper/lower/dress | Medium-high | 19 s–3 min | $0.025–0.15/run | **Non-commercial licenses**; per-second billing |
| **Self-host Leffa/CatVTON/IDM-VTON** | own GPU infra | upper/lower/dress | Medium-high | 6–20 s warm; cold starts | $0.005–0.03 GPU + idle | Licenses (only Leffa MIT), ops burden, preprocessing pipelines |
| **Apple on-device** | none | n/a (no VTO) | n/a | real-time | free | Only for pose/segmentation gating and masks |

---

## 9. Recommended strategy

**Primary (ship first, API key only): Nano Banana composition via Firebase AI Logic or a thin proxy.**
- Model: `gemini-3.1-flash-image` (preview; Google's recommended image model, 512px preview → 1K/2K final), fallback `gemini-2.5-flash-image` (GA). Use the §3.4 prompt, pass person then garment(s), `response_modalities=['IMAGE']`, match the person's aspect ratio. Offer "regenerate" and a multi-turn "fix" chat. Cost ≈ $0.04–0.05/image.
- Why: zero GCP setup, supports every garment class and multi-garment outfits, works "on the user" and "on a model", and iOS can call it without a server via Firebase AI Logic + App Check.
- Guardrails: on-device Vision gating (single adult, full-body, frontal), downscale to ≤1536 px, client-side age gate, safety filters, SynthID stays on, ephemeral processing.

**Upgrade path for fidelity (needs a backend anyway): Google `virtual-try-on-001` on Vertex.**
- Create a GCP project, enable Vertex AI, deploy a Cloud Run/Firebase Function with an attached service account, call `:predict` at `global` (fallback `us-central1`), `sampleCount=1`, `personGeneration=ALLOW_ADULT`, `addWatermark=true`, `outputOptions.mimeType=image/jpeg`. Route **tops/bottoms/shoes** here; route dresses (verify), accessories and multi-garment looks to Nano Banana. Chain calls for outfits or collage the garments into one product image. Verify price and the 2027-01-20 retirement on the model page; abstract the model ID in config.

**Fallback / A-B vendor: FASHN (`tryon-v1.6` for speed, `tryon-max` for accessories and 4K)** through the same backend abstraction (OpenTryOn-style adapter: `person`, `garment`, `category`, `num_images`, `seed`). Use `return_base64=true`, `moderation_level=conservative`. If you want one key for several engines, fal.ai gives FASHN + Kling + Leffa at $0.04–0.10.

**Do not**: embed the Gemini key in the app; rely on the `-preview-08-04` model or Imagen Product Recontext (both gone); self-host IDM-VTON/CatVTON/OOTD commercially (non-commercial licenses); plan on Pixelcut/Vmake/Botika/Zeg without confirming an API exists.

**Open items to verify live before build** (all blocked in this environment): official Vertex VTO price and regions; exact input dimension limits; whether Vertex Express-mode API keys can call `virtual-try-on-001`; current Gemini API abuse-log retention; whether `gemini-3.8-flash` image output is priced like `gemini-3.1-flash-image`; FASHN current credit price; Leffa license text.

---

## Sources (URLs)
- SDK: google-genai 2.22.0 wheel (PyPI) — `google/genai/models.py` (recontext_image, converters), `types.py` (RecontextImageSource/Config, PersonGeneration, SafetyFilterLevel), `client.py` (enterprise/vertexai), `CHANGELOG.md`.
- https://github.com/GoogleCloudPlatform/python-docs-samples/blob/main/genai/image_generation/imggen_virtual_try_on_with_txt_img.py
- https://github.com/googleapis/js-genai/blob/main/sdk-samples/recontext_image_virtual_try_on.ts
- https://github.com/GoogleCloudPlatform/generative-ai/blob/main/vision/getting-started/virtual_try_on.ipynb ; .../vision/use-cases/batch_virtual_try_on.ipynb
- https://github.com/gvillarroel/gcp-radar (mirrors of https://docs.cloud.google.com/vertex-ai/generative-ai/docs/release-notes and .../docs/image/generate-virtual-try-on-images, scraped 2026-04)
- https://github.com/truefoundry/models/blob/main/providers/google-vertex/google/virtual-try-on-001.yaml
- https://github.com/tryonlabs/opentryon (docs/api-reference: google-vton.md, fashn.md, kling-ai.md, nano-banana.md, outfitanyone-plus.md, overview.md; tryon/api/vton/google_vton.py)
- https://github.com/fmind/virtual-try-on ; https://github.com/Ashot72/Virtual-Try-On-Vertex-AI
- https://github.com/google-gemini/cookbook/blob/main/quickstarts/Get_Started_Nano_Banana.ipynb
- https://github.com/BerriAI/litellm/blob/main/model_prices_and_context_window.json
- https://github.com/firebase/firebase-ios-sdk (FirebaseAI/Sources/GenerationConfig.swift, Types/Public/ResponseModality.swift, Tests/TestApp/Sources/Constants.swift)
- PyPI `fashn` 0.9.0 (`fashn/types/prediction_run_params.py`)
- https://github.com/AlexKapadia/TryIt/blob/main/docs/research/provider-survey.md (2026-06-16)
- https://github.com/api-evangelist/kling-ai ; https://github.com/npc-live/clawfirm (kling skill) ; https://github.com/vercel/ai (packages/fal/src/fal-image-settings.ts) ; https://github.com/gokayfem/ComfyUI-fal-API/blob/main/MODELS.md
- https://github.com/yisol/IDM-VTON ; https://github.com/levihsu/OOTDiffusion ; https://github.com/Zheng-Chong/CatVTON ; https://github.com/franciszzj/Leffa ; awesome-vton list (local copy)
- Local prior research: `gh/steam-vto-cost.md` (2026-08-19 cost/retention study citing docs.fashn.ai, help.fashn.ai, fal.ai docs, help.aliyun.com)
