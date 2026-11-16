#!/bin/sh
set -eu
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
APP_DIR=${APKG_PKG_DIR:-/usr/local/AppCentral/vidaa-torrstream}
VERSION=${APKG_PKG_VER:-}
if [ -z "$VERSION" ] && [ -f "$APP_DIR/VERSION" ]; then VERSION=$(cat "$APP_DIR/VERSION"); fi
[ -n "$VERSION" ] || VERSION=1.0.0.r03
mkdir -p "$DATA_DIR/program" "$DATA_DIR/logs"
if [ ! -f "$DATA_DIR/config.env" ]; then
  (umask 077; printf '%s\n' 'PORT=8098' 'HOST=0.0.0.0' > "$DATA_DIR/config.env")
fi
previous=$(cat "$DATA_DIR/.apkg-installed-version" 2>/dev/null || true)
if [ -x "$DATA_DIR/program/myapp-linux-x64" ] && [ "$previous" != "$VERSION" ]; then
  : > "$DATA_DIR/.update-on-start"
  chmod 600 "$DATA_DIR/.update-on-start"
fi
printf '%s\n' "$VERSION" > "$DATA_DIR/.apkg-installed-version"
chmod 700 "$DATA_DIR" "$DATA_DIR/logs"
chmod 600 "$DATA_DIR/config.env" "$DATA_DIR/.apkg-installed-version"
exit 0
