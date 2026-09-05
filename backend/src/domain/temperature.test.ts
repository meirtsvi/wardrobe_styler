import { describe, expect, it } from "vitest";
import { band, midLayerAllowed, openShoesAllowed, outerwearAllowed, outerwearForbidden, outerwearRequired, renderTemperatureRulesText, spansTwoBands } from "./temperature.js";

describe("bands", () => {
  it("maps feels-like to the §5.6 bands", () => {
    expect(band(-3)).toBe("cold");
    expect(band(7.9)).toBe("cold");
    expect(band(8)).toBe("cool");
    expect(band(15)).toBe("mild");
    expect(band(22)).toBe("warm");
    expect(band(28)).toBe("hot");
    expect(band(40)).toBe("hot");
  });
  it("detects a window that spans two bands", () => {
    expect(spansTwoBands({ min_feels_like_c: 9, max_feels_like_c: 21, precip_prob_max: 0 })).toBe(true);
    expect(spansTwoBands({ min_feels_like_c: 16, max_feels_like_c: 21, precip_prob_max: 0 })).toBe(false);
  });
});

describe("outerwear", () => {
  it("is required below 8 °C or with rain below 15 °C", () => {
    expect(outerwearRequired({ min_feels_like_c: 7, max_feels_like_c: 12, precip_prob_max: 0 })).toBe(true);
    expect(outerwearRequired({ min_feels_like_c: 12, max_feels_like_c: 18, precip_prob_max: 60 })).toBe(true);
    expect(outerwearRequired({ min_feels_like_c: 12, max_feels_like_c: 18, precip_prob_max: 59 })).toBe(false);
    expect(outerwearRequired({ min_feels_like_c: 16, max_feels_like_c: 18, precip_prob_max: 90 })).toBe(false);
  });
  it("is allowed below 18 °C or for formal/evening", () => {
    expect(outerwearAllowed({ min_feels_like_c: 17, max_feels_like_c: 25, precip_prob_max: 0 }, "casual")).toBe(true);
    expect(outerwearAllowed({ min_feels_like_c: 20, max_feels_like_c: 25, precip_prob_max: 0 }, "casual")).toBe(false);
    expect(outerwearAllowed({ min_feels_like_c: 20, max_feels_like_c: 25, precip_prob_max: 0 }, "formal")).toBe(true);
  });
  it("is forbidden at 24 °C+ unless light", () => {
    const w = { min_feels_like_c: 18, max_feels_like_c: 24, precip_prob_max: 0 };
    expect(outerwearForbidden(w, "mid")).toBe(true);
    expect(outerwearForbidden(w, "light")).toBe(false);
  });
});

describe("other slots", () => {
  it("mid layer only below 22 °C minimum", () => {
    expect(midLayerAllowed({ min_feels_like_c: 21, max_feels_like_c: 30, precip_prob_max: 0 })).toBe(true);
    expect(midLayerAllowed({ min_feels_like_c: 22, max_feels_like_c: 30, precip_prob_max: 0 })).toBe(false);
  });
  it("open shoes need 15 °C+ and < 40 % rain", () => {
    expect(openShoesAllowed({ min_feels_like_c: 15, max_feels_like_c: 25, precip_prob_max: 39 })).toBe(true);
    expect(openShoesAllowed({ min_feels_like_c: 15, max_feels_like_c: 25, precip_prob_max: 40 })).toBe(false);
    expect(openShoesAllowed({ min_feels_like_c: 14, max_feels_like_c: 25, precip_prob_max: 0 })).toBe(false);
  });
});

describe("prompt rendering", () => {
  it("renders every rule id and every band from the shared file", () => {
    const text = renderTemperatureRulesText();
    for (const id of ["outerwear_required", "outerwear_forbidden", "heavy_warmth_forbidden", "light_only_forbidden", "open_shoes_allowed"]) {
      expect(text).toContain(`[${id}]`);
    }
    expect(text).toContain("cold below 8 °C");
    expect(text).toContain("hot above 28 °C");
  });
});
