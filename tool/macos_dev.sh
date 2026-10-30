#!/usr/bin/env bash
# Build di debug per macOS + firma ad-hoc + avvio.
#
# Perché serve: se il repository vive in una cartella sincronizzata (iCloud Drive,
# OneDrive, Dropbox...) il File Provider riaggiunge com.apple.FinderInfo ai bundle
# e codesign fallisce con "resource fork, Finder information ... not allowed".
# Qui la build viene spostata fuori dalla cartella sincronizzata e, per sicurezza,
# gli attributi estesi vengono rimossi prima della firma ad-hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$HOME/tools/flutter/bin}"
export PATH="$FLUTTER_BIN:$PATH"

if ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

if [ ! -e "$ROOT/build" ]; then
  BUILD_TARGET="${CENTSO_BUILD_DIR:-$HOME/Dev/centsgo-build}"
  mkdir -p "$BUILD_TARGET"
  ln -sfn "$BUILD_TARGET" "$ROOT/build"
  echo "build/ -> $BUILD_TARGET"
fi

cd "$ROOT"
flutter pub get
flutter build macos --debug

APP="$ROOT/build/macos/Build/Products/Debug/CentsGo.app"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - \
  --entitlements macos/Runner/DebugProfile.entitlements "$APP" 2>/dev/null || true

# macOS caches app icons: re-registering the bundle makes Finder/Spotlight pick
# up a regenerated AppIcon without waiting for the cache to expire.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true

echo "Avvio $APP"
open "$APP"
