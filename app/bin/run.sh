#!/bin/sh
set -eu
APP_DIR=${APKG_PKG_DIR:-/usr/local/AppCentral/vidaa-torrstream}
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
PROGRAM_DIR="$DATA_DIR/program"
SERVER="$PROGRAM_DIR/myapp-linux-x64"
mkdir -p "$PROGRAM_DIR" "$DATA_DIR/logs"
if [ -x "$SERVER" ] && [ -f "$DATA_DIR/.update-on-start" ]; then
  echo 'TorrStream: updating upstream after APKG upgrade...'
  if "$APP_DIR/bin/download.sh" app; then
    rm -f "$DATA_DIR/.update-on-start"
  else
    echo 'TorrStream WARNING: upstream update failed, keeping old binary.' >&2
  fi
fi
if [ ! -x "$SERVER" ]; then
  "$APP_DIR/bin/download.sh" app
  rm -f "$DATA_DIR/.update-on-start"
fi
if [ ! -x "$PROGRAM_DIR/ffmpeg/ffmpeg" ] || [ ! -x "$PROGRAM_DIR/ffmpeg/ffprobe" ]; then
  "$APP_DIR/bin/download.sh" ffmpeg
fi
PORT=8098
HOST=0.0.0.0
if [ -f "$DATA_DIR/config.env" ]; then . "$DATA_DIR/config.env"; fi
case "$PORT" in ''|*[!0-9]*) echo 'Invalid PORT' >&2; exit 1 ;; esac
[ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || { echo 'Invalid PORT range' >&2; exit 1; }
[ -n "$HOST" ] || exit 1
export PORT HOST HOME="$DATA_DIR" XDG_CONFIG_HOME="$DATA_DIR" NODE_ENV=production
cd "$PROGRAM_DIR"
echo "TorrStream: starting on $HOST:$PORT"
exec "$SERVER"
