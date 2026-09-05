#!/bin/sh
# Copies the shared rule/schema files into the Swift Domain package resources. SwiftPM cannot reference files outside a target,
# and it copies symlinks as dangling links, so the files are duplicated and SharedFilesTests asserts they are byte-identical.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/ios/Packages/Domain/Sources/Domain/Resources"
cp "$ROOT/shared/rules/temperature.json" "$DEST/temperature.json"
cp "$ROOT/shared/schemas/taxonomy.json" "$DEST/taxonomy.json"
cp "$ROOT/shared/rules/color_palette.json" "$DEST/color_palette.json"
echo "synced shared files into $DEST"
cp "$ROOT/shared/prompts/persona/v1.md" "$ROOT/ios/Packages/OnDeviceAI/Sources/OnDeviceAI/Resources/persona_v1.md"
