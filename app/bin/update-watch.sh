#!/bin/sh
APP_DIR=${APKG_PKG_DIR:-/usr/local/AppCentral/vidaa-torrstream}
while :; do
  "$APP_DIR/bin/check-update.sh" || true
  sleep 21600
done
