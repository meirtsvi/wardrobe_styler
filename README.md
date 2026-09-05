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
| `shared/config/price_table.v1.json` | Cost estimates for the spend log (unverified figures from the plan). |
| `docs/decisions/` | ADRs. 0001 = on-device first; 0002 = personal server on the Mac mini, no third-party accounts. |
| `backend/` | The personal gateway (Node, one bearer token, Gemini behind a daily budget): outfit planning fallback, garment naming, virtual try-on, cutout clean-up. See `backend/README.md`. |
| `scripts/run-mac.sh` | Starts the gateway and a Cloudflare quick tunnel; prints the URL for the app. |
| `ios/Packages/Domain` | Swift. Taxonomy, temperature rules, Stage A, validator, combiner, colour maths, credits, `BatchRunner`. |
| `ios/Packages/OnDeviceAI` | Swift. Foundation Models Stage B planner, plan orchestrator (local → gateway → combiner), gateway client. |
| `ios/Packages/Digitize` | Swift. Vision pipeline: instance masks → cutouts on white → pixel palette → classifier guess → feature print. |
| `ios/App` + `ios/project.yml` | The SwiftUI app (XcodeGen). `cd ios && xcodegen generate`. |

## Working on it

```sh
# gateway on the Mac mini
cp backend/.env.example backend/.env   # fill GEMINI_API_KEY and GATEWAY_TOKEN
brew install cloudflared
scripts/run-mac.sh                     # prints https://….trycloudflare.com; enter it and the token in the app's Me tab
cd backend && npm run probe-models     # confirms the model ids the key can use

# backend tests
cd backend && npm install && npm test && npm run typecheck

# Swift packages (macOS 26 host, Xcode 26)
for p in Domain OnDeviceAI Digitize; do (cd ios/Packages/$p && swift test); done

# App
cd ios && xcodegen generate && xcodebuild -project WardrobeStyler.xcodeproj -scheme WardrobeStyler -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The app runs fully offline (Vision digitisation, Foundation Models planner when Apple Intelligence is on, rule-based combiner otherwise). The gateway adds Gemini naming for garments the device cannot classify, Gemini planning as a fallback, and try-on. `--seed-demo` as a launch argument fills a demo closet in the simulator.

## Status

Works end to end on device: digitise → wardrobe → Today card. Gateway endpoints are implemented and unit-tested against a fake Gemini; they have not yet been run against the real API (needs the key in `backend/.env`). Not built: week strip, widget, wear log, export.