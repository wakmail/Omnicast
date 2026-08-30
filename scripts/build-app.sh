#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_root="$project_root/.build-app/Omnicast.app"
contents_root="$app_root/Contents"

cd "$project_root"
swift build -c release

rm -rf "$app_root"
mkdir -p "$contents_root/MacOS" "$contents_root/Resources"
cp "$project_root/Resources/Info.plist" "$contents_root/Info.plist"
cp "$project_root/.build/release/Omnicast" "$contents_root/MacOS/Omnicast"

codesign \
    --force \
    --sign - \
    --entitlements "$project_root/Resources/Omnicast.entitlements" \
    "$app_root"
