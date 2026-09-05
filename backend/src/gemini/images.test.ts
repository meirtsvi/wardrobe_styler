import { describe, expect, it } from "vitest";
import type { GenerateContentParameters, GenerateContentResponse } from "@google/genai";
import { ImageGenError, ImageGenerator, tryOnPrompt } from "./images.js";

const png = { mimeType: "image/png" as const, data: "iVBORw0KGgo=" };

function fake(parts: unknown[], finishReason = "STOP") {
  const seen: GenerateContentParameters[] = [];
  const gen = async (p: GenerateContentParameters): Promise<GenerateContentResponse> => {
    seen.push(p);
    return { candidates: [{ finishReason, content: { parts } }], usageMetadata: { promptTokenCount: 2000, candidatesTokenCount: 1290 } } as unknown as GenerateContentResponse;
  };
  return { seen, gen };
}

describe("ImageGenerator.tryOn", () => {
  it("sends person first, then cutouts, then the prompt, with IMAGE modality and size", async () => {
    const { seen, gen } = fake([{ inlineData: { mimeType: "image/png", data: "OUT" } }]);
    const r = await new ImageGenerator(gen).tryOn("img-model", { person: png, garments: [{ image: png, label: "navy wool blazer" }, { image: png, label: "white tee" }], imageSize: "1K" });
    expect(r.image.data).toBe("OUT");
    const p = seen[0]!;
    const parts = (p.contents as { parts: Record<string, unknown>[] }[])[0]!.parts;
    expect(parts).toHaveLength(4);
    expect(parts[3]!.text as string).toContain("1. navy wool blazer");
    expect((p.config as Record<string, unknown>).responseModalities).toEqual(["IMAGE"]);
    expect((p.config as { imageConfig: { imageSize: string } }).imageConfig.imageSize).toBe("1K");
  });
  it("rejects 0 or > 4 garments", async () => {
    const { gen } = fake([]);
    await expect(new ImageGenerator(gen).tryOn("m", { person: png, garments: [] })).rejects.toThrow(/1–4/);
  });
  it("surfaces safety blocks and missing images with codes", async () => {
    await expect(new ImageGenerator(fake([], "IMAGE_SAFETY").gen).tryOn("m", { person: png, garments: [{ image: png, label: "x" }] })).rejects.toBeInstanceOf(ImageGenError);
    await expect(new ImageGenerator(fake([{ text: "sorry" }]).gen).tryOn("m", { person: png, garments: [{ image: png, label: "x" }] })).rejects.toMatchObject({ code: "no_image" });
  });
  it("prompt keeps the person and forbids extra garments", () => {
    const p = tryOnPrompt([{ label: "red dress" }]);
    expect(p).toContain("keep the person's face");
    expect(p).toContain("Do not add garments that are not listed");
  });
});
