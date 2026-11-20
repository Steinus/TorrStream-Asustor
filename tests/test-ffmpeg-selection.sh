#!/usr/bin/env bash
# Verify app-specific environment selects the bundled FFmpeg for HLS.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export VIDAA_DATA_DIR="$TMP/data"
export APKG_PKG_DIR="$TMP/app"
export VIDAA_SELECTION_TEST_RESULT="$TMP/selected.txt"
mkdir -p "$APKG_PKG_DIR/bin" "$VIDAA_DATA_DIR/program/ffmpeg"
cp "$ROOT/app/bin/run.sh" "$APKG_PKG_DIR/bin/run.sh"
chmod +x "$APKG_PKG_DIR/bin/run.sh"
cat > "$VIDAA_DATA_DIR/program/myapp-linux-x64" <<'SH'
#!/bin/sh
{
  printf 'FFMPEG_PATH=%s\n' "$FFMPEG_PATH"
  printf 'FFPROBE_PATH=%s\n' "$FFPROBE_PATH"
  printf 'PATH_FFMPEG=%s\n' "$(command -v ffmpeg)"
  printf 'PATH_FFPROBE=%s\n' "$(command -v ffprobe)"
} > "$VIDAA_SELECTION_TEST_RESULT"
SH
for bin in ffmpeg ffprobe; do
  printf '#!/bin/sh\nexit 0\n' > "$VIDAA_DATA_DIR/program/ffmpeg/$bin"
  chmod +x "$VIDAA_DATA_DIR/program/ffmpeg/$bin"
done
chmod +x "$VIDAA_DATA_DIR/program/myapp-linux-x64"
VIDAA_DATA_DIR="$VIDAA_DATA_DIR" APKG_PKG_DIR="$APKG_PKG_DIR" \
  VIDAA_SELECTION_TEST_RESULT="$VIDAA_SELECTION_TEST_RESULT" sh "$APKG_PKG_DIR/bin/run.sh"
for key in FFMPEG_PATH PATH_FFMPEG; do
  grep -Fxq "$key=$VIDAA_DATA_DIR/program/ffmpeg/ffmpeg" "$VIDAA_SELECTION_TEST_RESULT" || {
    echo "Incorrect $key"; cat "$VIDAA_SELECTION_TEST_RESULT"; exit 1;
  }
done
for key in FFPROBE_PATH PATH_FFPROBE; do
  grep -Fxq "$key=$VIDAA_DATA_DIR/program/ffmpeg/ffprobe" "$VIDAA_SELECTION_TEST_RESULT" || {
    echo "Incorrect $key"; cat "$VIDAA_SELECTION_TEST_RESULT"; exit 1;
  }
done
echo "PASS: bundled FFmpeg and FFprobe selected via PATH and env vars."
