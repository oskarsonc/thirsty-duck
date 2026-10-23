#!/bin/sh
# Renders the README pictures and the app icon from the app's own drawing code, off screen.
set -eu
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for f in DuckView.swift Sprite.swift; do
    grep -v '^import DuckCore' "Sources/ThirstyDuck/$f" > "$TMP/$f"
done
cp scripts/RenderDocs.swift "$TMP/main.swift"
swiftc -O -o "$TMP/render" Sources/DuckCore/*.swift "$TMP/DuckView.swift" "$TMP/Sprite.swift" "$TMP/main.swift"

mkdir -p docs Resources "$TMP/AppIcon.iconset"
"$TMP/render" docs "$TMP/AppIcon.iconset"
iconutil -c icns -o Resources/AppIcon.icns "$TMP/AppIcon.iconset"
ls -lh docs Resources/AppIcon.icns
