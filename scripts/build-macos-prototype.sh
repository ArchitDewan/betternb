#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-debug}"
binary_directory="$repository_root/.build/$configuration"
app_directory="$repository_root/.build/BetterNB.app"

cd "$repository_root"
swift build --configuration "$configuration"

mkdir -p "$app_directory/Contents/MacOS"
mkdir -p "$app_directory/Contents/Resources"

cp "$binary_directory/BetterNB" "$app_directory/Contents/MacOS/BetterNB"
cp "$repository_root/macos/BetterNB/Resources/Info.plist" "$app_directory/Contents/Info.plist"

echo "$app_directory"
