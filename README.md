# Wardrobe Styler

Native iOS AI wardrobe stylist built on Gemini. The full plan lives in [`docs/plans/ai-stylist-ios/PLAN.md`](docs/plans/ai-stylist-ios/PLAN.md); the research it rests on is in `docs/plans/ai-stylist-ios/research/`.

## Layout

| Path | What |
|---|---|
| `shared/rules/temperature.json` | The one temperature/layering rule table (PLAN §5.6). Rendered into the Stage B prompt, executed by both validators. |
| `shared/rules/color_palette.json` | 40 named colours, calendar-season palettes, harmony thresholds (PLAN §5.4, §5.6). |
| `shared/schemas/taxonomy.json` | Categories, subcategories, slots, formality per occasion, Stage A top-N (PLAN §5.3, §5.6). |
| `shared/schemas/outfit_plan.schema.json` | Stage B structured-output schema (PLAN §5.6). |
| `shared/prompts/persona/v1.md` | The Remy persona block (PLAN §5.19). |
| `backend/` | TypeScript. `src/domain/` = Stage A retrieval, validator, deterministic combiner, colour maths. Gateway and worker follow (PLAN §7). |
| `ios/Packages/Domain` | Swift. Value types, taxonomy enums, the validator mirror, credit arithmetic, `BatchRunner` protocol (PLAN §6). |

## Working on it

```sh
# backend
cd backend && npm install && npm test && npm run typecheck

# iOS Domain package (macOS host, Swift 6)
cd ios/Packages/Domain && swift test
```

## Status

Phase 0 (PLAN §11.1) in progress: foundations that need no Google Cloud or Apple accounts are being built first. See the git log.
