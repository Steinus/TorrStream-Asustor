#!/bin/sh
# Read-only update check; no automatic installation.
set -eu
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
LATEST_URL='https://raw.githubusercontent.com/Steinus/TorrStream-Asustoor/main/latest.json'
mkdir -p "$DATA_DIR/logs"
TMP=$(mktemp "$DATA_DIR/.latest.XXXXXX") || exit 1
trap 'rm -f "$TMP"' EXIT
trap 'exit 1' INT TERM
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --max-time 25 -H 'Cache-Control: no-cache' -o "$TMP" "$LATEST_URL" || exit 0
elif command -v wget >/dev/null 2>&1; then
  wget -q -T 25 -O "$TMP" "$LATEST_URL" || exit 0
else exit 0; fi
new=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TMP" | head -n 1)
current=$(cat "$DATA_DIR/.apkg-installed-version" 2>/dev/null || true)
case "$new" in ''|*[!a-zA-Z0-9._-]*) exit 0 ;; esac
[ -n "$current" ] || exit 0
if [ "$new" = "$current" ]; then
  rm -f "$DATA_DIR/update_available.txt" "$DATA_DIR/.last-notified-version"
  exit 0
fi
printf 'Available: %s\nInstalled: %s\nDownload: %s\n' "$new" "$current" 'https://github.com/Steinus/TorrStream-Asustoor/releases/latest' > "$DATA_DIR/update_available.txt"
old=$(cat "$DATA_DIR/.last-notified-version" 2>/dev/null || true)
if [ "$old" != "$new" ]; then
  message="TorrStream $new available (installed $current). Update from https://github.com/Steinus/TorrStream-Asustoor/releases/latest"
  echo "$message"
  if command -v logger >/dev/null 2>&1; then logger -t TorrStream "$message" || true; fi
  printf '%s\n' "$new" > "$DATA_DIR/.last-notified-version"
fi
