import { describe, expect, it } from "vitest";
import { ACCESSORY_COUNTS, AVAILABILITY_STATES, CATEGORIES, FORMALITY, ITEM_STATUS, LAYER_ROLES, OCCASIONS, SEASONS, SLOTS, WARMTH, defaultLayerRole, formalityAllowed, taxonomy } from "./taxonomy.js";

describe("taxonomy literal unions match shared/schemas/taxonomy.json", () => {
  it("lists are identical", () => {
    expect([...CATEGORIES]).toEqual(taxonomy.categories);
    expect([...SLOTS]).toEqual(taxonomy.slots);
    expect([...LAYER_ROLES]).toEqual(taxonomy.layer_roles);
    expect([...WARMTH]).toEqual(taxonomy.warmth);
    expect([...FORMALITY]).toEqual(taxonomy.formality);
    expect([...SEASONS]).toEqual(taxonomy.seasons);
    expect([...OCCASIONS]).toEqual(taxonomy.occasions);
    expect([...ACCESSORY_COUNTS]).toEqual(Object.keys(taxonomy.accessory_count));
    expect([...ITEM_STATUS]).toEqual(taxonomy.item_status);
    expect([...AVAILABILITY_STATES]).toEqual(taxonomy.availability_state);
  });
  it("every subcategory key is a category and every slot maps to categories", () => {
    for (const c of Object.keys(taxonomy.subcategories)) expect(taxonomy.categories).toContain(c);
    for (const s of taxonomy.slots) expect(Object.keys(taxonomy.slot_categories)).toContain(s);
  });
});

describe("formalityAllowed", () => {
  it("work allows business, smart_casual and formal (±1 of business) but not casual or athletic", () => {
    expect(formalityAllowed("work", "business")).toBe(true);
    expect(formalityAllowed("work", "smart_casual")).toBe(true);
    expect(formalityAllowed("work", "formal")).toBe(true);
    expect(formalityAllowed("work", "casual")).toBe(false);
    expect(formalityAllowed("work", "athletic")).toBe(false);
  });
  it("sport allows only athletic", () => {
    expect(formalityAllowed("sport", "athletic")).toBe(true);
    expect(formalityAllowed("sport", "casual")).toBe(false);
  });
});

describe("defaultLayerRole", () => {
  it("tank/tee are base, shirt is single, cardigan is mid, non-tops are null", () => {
    expect(defaultLayerRole("top", "tank")).toBe("base");
    expect(defaultLayerRole("top", "shirt")).toBe("single");
    expect(defaultLayerRole("mid_layer", "cardigan")).toBe("mid");
    expect(defaultLayerRole("bottom", "jeans")).toBeNull();
  });
});
