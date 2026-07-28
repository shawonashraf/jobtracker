#!/usr/bin/env bash
# Build + zip the Job Tracker macOS app. Optionally cut a GitHub release.
# Usage:
#   ./build.sh            # build Release .app + zip into ./build
#   ./build.sh release    # same, then create/upload a GitHub release tag v<VERSION>
set -euo pipefail

PROJECT="Job Tracker.xcodeproj"
SCHEME="Job Tracker"
CONFIGURATION="Release"
APP_NAME="Job Tracker"

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Version stays in sync with MARKETING_VERSION in the Xcode project.
VERSION="$(grep -m1 'MARKETING_VERSION' "$PROJECT/project.pbxproj" \
  | sed -E 's/.*= *([0-9.]+).*/\1/')"
ZIP_NAME="Job-Tracker-${VERSION}.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"

echo "==> Building $APP_NAME v$VERSION ($CONFIGURATION)"
rm -rf "$APP_PATH"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build \
  | grep -E '(BUILD SUCCEEDED|BUILD FAILED|error:)' || true

# CONFIGURATION_BUILD_DIR lives under DerivedData; copy the product out.
SRC_APP="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
[ -d "$SRC_APP" ] || { echo "Build failed: $SRC_APP not found"; exit 1; }
ditto "$SRC_APP" "$APP_PATH"

echo "==> Verifying code signature"
codesign --verify --strict --verbose=2 "$APP_PATH" 2>&1 | sed 's/^/    /'

echo "==> Zipping -> $ZIP_NAME"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "==> Built: $ZIP_PATH"

if [ "${1:-}" = "release" ]; then
  REPO="$(git -C "$ROOT" remote get-url origin \
    | sed -E 's#.*[:/]([^/]+/[^/]+)(\.git)?$#\1#')"
  TAG="v$VERSION"
  echo "==> Creating GitHub release $TAG in $REPO"
  if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP_PATH" -R "$REPO" --clobber
  else
    gh release create "$TAG" "$ZIP_PATH" -R "$REPO" \
      --title "Job Tracker $VERSION" \
      --generate-notes
  fi
  echo "==> Released: $TAG"
fi
