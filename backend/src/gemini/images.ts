// Gemini image generation (ADR 0002): virtual try-on composition and optional cutout clean-up (PLAN §5.14, §5.16 prompt patterns).
import type { GenerateContentParameters, GenerateContentResponse } from "@google/genai";
import { isSafetyBlock, statusOf, usageOf, withRetries, type GenerateFn, type RetryOptions, type Usage } from "./client.js";

export type InlineImage = { mimeType: "image/jpeg" | "image/png" | "image/webp"; data: string }; // base64

export type TryOnRequest = {
  person: InlineImage;
  garments: { image: InlineImage; label: string }[]; // ≤ 4 cutouts on white, wear order
  /** "1K" default; "512px" for a cheap preview. */
  imageSize?: "512px" | "1K" | "2K";
  notes?: string;
};

export type ImageResult = { image: InlineImage; usage: Usage; model: string; finishReason: string | undefined; text: string | null };

export class ImageGenError extends Error {
  constructor(public readonly code: "safety_block" | "no_image", message: string) { super(message); }
}

/** Prompt-composition try-on (PLAN §5.14): keep the person, replace only the clothing with the exact garments given. */
export function tryOnPrompt(garments: { label: string }[], notes?: string): string {
  const list = garments.map((g, i) => `${i + 1}. ${g.label}`).join("\n");
  return [
    "Edit the first image (a photo of a person). Dress the person in exactly these garments, shown in the following images as product cutouts on white:",
    list,
    "Rules: keep the person's face, hair, skin, body shape, pose, hands, background and lighting identical to the first image. Replace only the clothing.",
    "Reproduce each garment faithfully: same colour, pattern, fabric, cut and length. Do not add garments that are not listed; keep existing shoes or accessories only if no replacement is listed.",
    "Fit the garments naturally to the pose with realistic drape, wrinkles and shadows. Photorealistic, same camera framing as the first image.",
    "Output one photograph only, no collage, no text, no watermark.",
    notes ? `Notes: ${notes}` : "",
  ].filter(Boolean).join("\n");
}

export function cleanupPrompt(): string {
  return "Keep this garment exactly as it is (colour, pattern, shape, texture) and place it on a clean, evenly lit pure white studio background, centred, product-photo style. Do not alter the garment. Output one image only.";
}

function firstImage(res: GenerateContentResponse): InlineImage | null {
  for (const part of res.candidates?.[0]?.content?.parts ?? []) {
    const d = part.inlineData;
    if (d?.data && d.mimeType?.startsWith("image/")) return { mimeType: d.mimeType as InlineImage["mimeType"], data: d.data };
  }
  return null;
}

function textOf(res: GenerateContentResponse): string | null {
  const t = (res.candidates?.[0]?.content?.parts ?? []).map((p) => p.text).filter(Boolean).join("\n");
  return t || null;
}

export class ImageGenerator {
  constructor(private readonly generate: GenerateFn, private readonly retry: RetryOptions = {}) {}

  private async run(model: string, parts: unknown[], imageSize: string | undefined): Promise<ImageResult> {
    const params = {
      model,
      contents: [{ role: "user", parts }],
      config: {
        responseModalities: ["IMAGE"],
        ...(imageSize ? { imageConfig: { imageSize } } : {}),
      },
    } as unknown as GenerateContentParameters;
    let res: GenerateContentResponse;
    try {
      res = await withRetries(() => this.generate(params), this.retry);
    } catch (err) {
      if (statusOf(err) === 400) throw Object.assign(new Error("image model rejected the request (check GEMINI_IMAGE_MODEL and imageSize)"), { code: "bad_request", cause: err });
      throw err;
    }
    if (isSafetyBlock(res)) throw new ImageGenError("safety_block", "The image model declined this photo.");
    const image = firstImage(res);
    if (!image) throw new ImageGenError("no_image", `no image in response (${res.candidates?.[0]?.finishReason ?? "unknown"})`);
    return { image, usage: usageOf(res), model, finishReason: res.candidates?.[0]?.finishReason, text: textOf(res) };
  }

  async tryOn(model: string, req: TryOnRequest): Promise<ImageResult> {
    if (req.garments.length === 0 || req.garments.length > 4) throw new Error("1–4 garments required");
    const parts = [
      { inlineData: { mimeType: req.person.mimeType, data: req.person.data } },
      ...req.garments.map((g) => ({ inlineData: { mimeType: g.image.mimeType, data: g.image.data } })),
      { text: tryOnPrompt(req.garments, req.notes) },
    ];
    return this.run(model, parts, req.imageSize ?? "1K");
  }

  async cleanup(model: string, garment: InlineImage): Promise<ImageResult> {
    return this.run(model, [{ inlineData: { mimeType: garment.mimeType, data: garment.data } }, { text: cleanupPrompt() }], undefined);
  }
}
