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
| `shared/config/` | Remote Config defaults and the (unverified) price table. |
| `docs/decisions/` | ADRs. 0001 = on-device first, Gemini for the rest, and the §12.2 decisions taken. |
| `backend/` | TypeScript Cloud Run gateway: Stage A, validator, combiner, Gemini planner and attribute fallback, two-bucket ledger, idempotent jobs, rules. See `backend/README.md`. |
| `ios/Packages/Domain` | Swift. Taxonomy, temperature rules, Stage A, validator, combiner, colour maths, credits, `BatchRunner`. |
| `ios/Packages/OnDeviceAI` | Swift. Foundation Models Stage B planner, plan orchestrator (local → gateway → combiner), gateway client. |
| `ios/Packages/Digitize` | Swift. Vision pipeline: instance masks → cutouts on white → pixel palette → classifier guess → feature print. |
| `ios/App` + `ios/project.yml` | The SwiftUI app (XcodeGen). `cd ios && xcodegen generate`. |

## Working on it

```sh
# backend
cd backend && npm install && npm test && npm run typecheck

# Swift packages (macOS 26 host, Xcode 26)
for p in Domain OnDeviceAI Digitize; do (cd ios/Packages/$p && swift test); done

# App
cd ios && xcodegen generate && xcodebuild -project WardrobeStyler.xcodeproj -scheme WardrobeStyler -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Set `GATEWAY_URL` in the run scheme's environment to enable the Gemini fallback; without it the app runs fully offline (local Foundation Models planner when Apple Intelligence is on, rule-based combiner otherwise).

## Status

Phase 0/1 (PLAN §11.1) under ADR 0001: digitisation, wardrobe and the Today card run on device end to end; the gateway plans with Gemini when a key is configured and meters Looks. Not yet built: Cloud Tasks dispatch, rate limits, Looks (try-on) rendering, Firebase Auth/App Check in the app, RevenueCat, widget, week strip, overnight plan. See the git log and `backend/README.md`.
