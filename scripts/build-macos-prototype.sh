#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${1:-debug}"
binary_directory="$repository_root/.build/$configuration"
app_directory="$repository_root/.build/BetterNB.app"

cd "$repository_root"
if [[ -z "${DEVELOPER_DIR:-}" ]] \
    && [[ "$(xcode-select -p)" == "/Library/Developer/CommandLineTools" ]] \
    && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
swift build --configuration "$configuration"

mkdir -p "$app_directory/Contents/MacOS"
mkdir -p "$app_directory/Contents/Resources"

cp "$binary_directory/BetterNB" "$app_directory/Contents/MacOS/BetterNB"
cp "$repository_root/macos/BetterNB/Resources/Info.plist" "$app_directory/Contents/Info.plist"
cp "$repository_root/macos/BetterNB/Resources/Lemma.icns" "$app_directory/Contents/Resources/Lemma.icns"

# Swift Package Manager places dependency resources beside the executable.
# Bundle.module expects those bundles inside the app's Resources directory.
for resource_bundle in "$binary_directory"/*.bundle; do
    [[ -d "$resource_bundle" ]] || continue
    ditto "$resource_bundle" "$app_directory/Contents/Resources/$(basename "$resource_bundle")"
done

echo "$app_directory"
