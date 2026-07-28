#!/usr/bin/env bash
# Install Job Tracker from a release zip. Handles macOS Gatekeeper by
# stripping the quarantine attribute after install.
#
# Usage:
#   ./install.sh                       # auto-finds Job-Tracker-*.zip in cwd
#   ./install.sh Job-Tracker-1.0.zip   # explicit zip
#   ./install.sh                       # curl one-liner, see README
set -euo pipefail

APP_NAME="Job Tracker"
DEST="/Applications/$APP_NAME.app"

# Resolve the zip: explicit arg, else any matching zip next to this script.
ZIP="${1:-}"
if [ -z "$ZIP" ]; then
  for f in "$PWD"/Job-Tracker-*.zip "$PWD"/"Job Tracker.zip"; do
    if [ -e "$f" ]; then ZIP="$f"; break; fi
  done
fi
[ -n "$ZIP" ] && [ -e "$ZIP" ] || {
  echo "No zip found. Usage: $0 [Job-Tracker-x.y.zip]"; exit 1; }

echo "==> Installing $APP_NAME from $(basename "$ZIP")"

# Replace any existing copy.
if [ -d "$DEST" ]; then
  echo "    replacing existing $DEST"
  rm -rf "$DEST"
fi

# ditto preserves the .app bundle structure and metadata.
ditto -xk "$ZIP" "/Applications/"

# Gatekeeper: strip the quarantine flag so the dev-signed app launches cleanly.
xattr -cr "$DEST"
echo "==> Installed to $DEST"

read -r -p "==> Launch $APP_NAME now? [Y/n] " ans
case "${ans:-y}" in
  [yY]|'') open "$DEST" ;;
  *) echo "    skipped launch. Run: open \"$DEST\"" ;;
esac
