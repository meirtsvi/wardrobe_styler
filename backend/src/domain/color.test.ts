import { describe, expect, it } from "vitest";
import { deltaE00, harmonyScore, hexToLab, isNeutral, nearestNamedColor } from "./color.js";

describe("colour maths", () => {
  it("converts sRGB white and black to Lab", () => {
    expect(hexToLab("#FFFFFF").L).toBeCloseTo(100, 0);
    expect(hexToLab("#000000").L).toBeCloseTo(0, 0);
  });
  it("ΔE00 is zero for identical colours and matches a reference pair", () => {
    expect(deltaE00(hexToLab("#2F5DA8"), hexToLab("#2F5DA8"))).toBeCloseTo(0);
    // Sharma et al. (2005) test pair 1: Lab(50, 2.6772, -79.7751) vs Lab(50, 0, -82.7485) → 2.0425
    expect(deltaE00({ L: 50, a: 2.6772, b: -79.7751 }, { L: 50, a: 0, b: -82.7485 })).toBeCloseTo(2.0425, 3);
  });
  it("finds the nearest named colour", () => {
    expect(nearestNamedColor("#1F2A44").name).toBe("navy");
    expect(nearestNamedColor("#C42B2B").name).toBe("red");
    expect(nearestNamedColor("#FFFFFF").name).toMatch(/white|ivory/);
  });
  it("classifies neutrals and harmony", () => {
    expect(isNeutral("#8C8C8C")).toBe(true);
    expect(isNeutral("#C42B2B")).toBe(false);
    expect(harmonyScore("#2F5DA8", "#1F3F80")).toBe(1.0); // monochrome blues
    expect(harmonyScore("#2F5DA8", "#8C8C8C")).toBe(0.85); // neutral
    expect(harmonyScore("#2F5DA8", "#E07A2E")).toBe(0.8); // complementary blue/orange
    expect(harmonyScore("#2F5DA8", "#3B7A3B")).toBeLessThanOrEqual(0.9);
  });
});
