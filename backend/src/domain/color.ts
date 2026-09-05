// Colour maths for PLAN.md §5.4 (nearest named colour, ΔE00) and §5.6 (harmony term of the Stage A score).
import paletteJson from "../../../shared/rules/color_palette.json" with { type: "json" };

export const palette = paletteJson;

export type Lab = { L: number; a: number; b: number };

export function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace("#", "");
  if (h.length !== 6) throw new Error(`bad hex colour: ${hex}`);
  return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
}

function srgbToLinear(c: number): number {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

export function hexToLab(hex: string): Lab {
  const [r, g, b] = hexToRgb(hex).map(srgbToLinear) as [number, number, number];
  // sRGB D65 → XYZ
  const x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047;
  const y = (r * 0.2126729 + g * 0.7151522 + b * 0.072175) / 1.0;
  const z = (r * 0.0193339 + g * 0.119192 + b * 0.9503041) / 1.08883;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f(x), fy = f(y), fz = f(z);
  return { L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
}

export function chroma(lab: Lab): number {
  return Math.hypot(lab.a, lab.b);
}

export function hueDeg(lab: Lab): number {
  const h = (Math.atan2(lab.b, lab.a) * 180) / Math.PI;
  return h < 0 ? h + 360 : h;
}

/** CIEDE2000 colour difference. */
export function deltaE00(c1: Lab, c2: Lab): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const deg = (r: number) => (r * 180) / Math.PI;
  const avgL = (c1.L + c2.L) / 2;
  const C1 = chroma(c1), C2 = chroma(c2);
  const avgC = (C1 + C2) / 2;
  const G = 0.5 * (1 - Math.sqrt(Math.pow(avgC, 7) / (Math.pow(avgC, 7) + Math.pow(25, 7))));
  const a1p = c1.a * (1 + G), a2p = c2.a * (1 + G);
  const C1p = Math.hypot(a1p, c1.b), C2p = Math.hypot(a2p, c2.b);
  const avgCp = (C1p + C2p) / 2;
  const h = (a: number, b: number) => {
    if (a === 0 && b === 0) return 0;
    const v = deg(Math.atan2(b, a));
    return v < 0 ? v + 360 : v;
  };
  const h1p = h(a1p, c1.b), h2p = h(a2p, c2.b);
  let avgHp: number;
  if (C1p * C2p === 0) avgHp = h1p + h2p;
  else if (Math.abs(h1p - h2p) <= 180) avgHp = (h1p + h2p) / 2;
  else avgHp = h1p + h2p < 360 ? (h1p + h2p + 360) / 2 : (h1p + h2p - 360) / 2;
  const T =
    1 - 0.17 * Math.cos(rad(avgHp - 30)) + 0.24 * Math.cos(rad(2 * avgHp)) + 0.32 * Math.cos(rad(3 * avgHp + 6)) - 0.2 * Math.cos(rad(4 * avgHp - 63));
  let dhp: number;
  if (C1p * C2p === 0) dhp = 0;
  else if (Math.abs(h2p - h1p) <= 180) dhp = h2p - h1p;
  else dhp = h2p - h1p > 180 ? h2p - h1p - 360 : h2p - h1p + 360;
  const dLp = c2.L - c1.L;
  const dCp = C2p - C1p;
  const dHp = 2 * Math.sqrt(C1p * C2p) * Math.sin(rad(dhp) / 2);
  const SL = 1 + (0.015 * Math.pow(avgL - 50, 2)) / Math.sqrt(20 + Math.pow(avgL - 50, 2));
  const SC = 1 + 0.045 * avgCp;
  const SH = 1 + 0.015 * avgCp * T;
  const dTheta = 30 * Math.exp(-Math.pow((avgHp - 275) / 25, 2));
  const RC = 2 * Math.sqrt(Math.pow(avgCp, 7) / (Math.pow(avgCp, 7) + Math.pow(25, 7)));
  const RT = -RC * Math.sin(rad(2 * dTheta));
  return Math.sqrt(Math.pow(dLp / SL, 2) + Math.pow(dCp / SC, 2) + Math.pow(dHp / SH, 2) + RT * (dCp / SC) * (dHp / SH));
}

export function nearestNamedColor(hex: string): { name: string; deltaE: number } {
  const lab = hexToLab(hex);
  let best = { name: "other", deltaE: Infinity };
  for (const [name, h] of Object.entries(palette.named)) {
    const d = deltaE00(lab, hexToLab(h));
    if (d < best.deltaE) best = { name, deltaE: d };
  }
  return best;
}

export function isNeutral(hex: string): boolean {
  return chroma(hexToLab(hex)) < palette.harmony.neutral_chroma_max;
}

/** Harmony of `hex` against one reference colour, 0–1 (§5.6: monochrome, analogous, complementary, neutral + accent). */
export function harmonyScore(hex: string, referenceHex: string): number {
  const s = palette.harmony.scores;
  const a = hexToLab(hex), b = hexToLab(referenceHex);
  if (chroma(a) < palette.harmony.neutral_chroma_max || chroma(b) < palette.harmony.neutral_chroma_max) return s.neutral;
  let dh = Math.abs(hueDeg(a) - hueDeg(b));
  if (dh > 180) dh = 360 - dh;
  if (dh <= palette.harmony.monochrome_hue_deg) return s.monochrome;
  if (dh <= palette.harmony.analogous_hue_deg) return s.analogous;
  if (dh >= palette.harmony.complementary_min_deg && dh <= palette.harmony.complementary_max_deg) return s.complementary;
  return s.other;
}

/** Best harmony against a set of reference colours (anchor first if given, else the calendar-season palette). */
export function paletteScore(hex: string, references: readonly string[]): number {
  if (references.length === 0) return palette.harmony.scores.neutral;
  return Math.max(...references.map((ref) => harmonyScore(hex, ref)));
}

export function seasonalPalette(season: "spring" | "summer" | "autumn" | "winter"): readonly string[] {
  return palette.seasonal[season];
}
