#!/bin/sh
# Starts the gateway on this Mac and a Cloudflare quick tunnel (no account). Prints the public URL to paste into the app's Settings.
# Requires: node 22+, `brew install cloudflared`, backend/.env with GEMINI_API_KEY and GATEWAY_TOKEN.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"
[ -f .env ] || { echo "backend/.env missing; copy .env.example and fill GEMINI_API_KEY and GATEWAY_TOKEN"; exit 1; }
[ -d node_modules ] || npm install --no-audit --no-fund
npm run build >/dev/null
PORT="$(grep -E '^PORT=' .env | cut -d= -f2)"; PORT="${PORT:-8787}"

node dist/backend/src/index.js &
NODE_PID=$!
trap 'kill $NODE_PID 2>/dev/null; kill ${CF_PID:-0} 2>/dev/null' EXIT INT TERM
sleep 1

if command -v cloudflared >/dev/null 2>&1; then
  echo "Starting Cloudflare quick tunnel to http://127.0.0.1:$PORT ..."
  cloudflared tunnel --url "http://127.0.0.1:$PORT" --no-autoupdate 2>&1 | while IFS= read -r line; do
    echo "$line"
    case "$line" in *trycloudflare.com*) echo; echo ">>> Gateway URL: $(echo "$line" | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com')"; echo ">>> Token: see GATEWAY_TOKEN in backend/.env"; echo;; esac
  done &
  CF_PID=$!
else
  echo "cloudflared not installed (brew install cloudflared); gateway is reachable on this Mac only at http://127.0.0.1:$PORT"
fi
wait $NODE_PID
