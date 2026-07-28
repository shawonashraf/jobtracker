#!/usr/bin/env bash
# Install Job Tracker from a GitHub release. Downloads the latest release
# zip, copies the .app to /Applications, and strips the quarantine flag so
# the dev-signed app clears Gatekeeper for local distribution.
#
# Usage:
#   ./install.sh                       # download + install the latest release
#   ./install.sh Job-Tracker-1.0.zip   # install a local zip (e.g. a fresh build)
set -euo pipefail

APP_NAME="Job Tracker"
REPO="shawonashraf/jobtracker"
DEST="/Applications/$APP_NAME.app"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Source: explicit local zip, otherwise the latest GitHub release asset.
if [ -n "${1:-}" ] && [ -e "${1:-}" ]; then
  ZIP="$1"
  echo "==> Using local zip: $ZIP"
else
  echo "==> Resolving latest release from $REPO"
  URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -m1 '"browser_download_url"' \
    | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/')"
  [ -n "$URL" ] || { echo "No release asset found for $REPO"; exit 1; }
  ZIP="$WORK/$(basename "$URL")"
  echo "==> Downloading $URL"
  curl -fSL -o "$ZIP" "$URL"
fi

# Replace any existing copy.
if [ -d "$DEST" ]; then
  echo "==> Replacing existing $DEST"
  rm -rf "$DEST"
fi

# ditto preserves the .app bundle structure and metadata.
echo "==> Installing to $DEST"
ditto -xk "$ZIP" "/Applications/"

# Gatekeeper: strip the quarantine flag so the dev-signed app launches cleanly.
xattr -cr "$DEST"
echo "==> Installed to $DEST"

# Prompt when run interactively; auto-launch when piped (curl | bash).
if [ -t 0 ]; then
  read -r -p "==> Launch $APP_NAME now? [Y/n] " ans
  case "${ans:-y}" in
    [yY]|'') open "$DEST" ;;
    *) echo "    Skipped launch. Run: open \"$DEST\"" ;;
  esac
else
  open "$DEST"
  echo "==> Launched $APP_NAME"
fi
