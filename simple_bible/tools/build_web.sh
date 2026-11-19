#!/usr/bin/env bash
# Builds the web app stamped with a version, and writes build/web/app-version.json
# for the running app to compare against.
set -e
cd "$(dirname "$0")/.."
VERSION=$(date +%Y%m%d-%H%M)
FLUTTER=${FLUTTER:-/c/src/flutter/bin/flutter}
"$FLUTTER" build web --release --dart-define=APP_VERSION="$VERSION"
printf '{"v":"%s"}\n' "$VERSION" > build/web/app-version.json
echo "$VERSION"
