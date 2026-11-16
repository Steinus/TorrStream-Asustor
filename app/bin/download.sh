#!/bin/sh
# Preserve settings, stage executable before replacement.
set -eu
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
PROGRAM_DIR="$DATA_DIR/program"
APP_URL='https://github.com/cash94/cash94.github.io/releases/download/%23vidaa/TorrStream-linux.zip'
FFMPEG_URL='https://github.com/jellyfin/jellyfin-ffmpeg/releases/download/v7.1.3-3/jellyfin-ffmpeg_7.1.3-3_portable_linux64-gpl.tar.xz'
mkdir -p "$PROGRAM_DIR"
TMP_DIR=$(mktemp -d "$DATA_DIR/.vidaa-download.XXXXXX") || exit 1
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
trap 'exit 1' INT TERM
fetch() {
  url=$1; target=$2
  echo "TorrStream download: $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$target" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$target" "$url"
  else
    echo 'ERROR: curl or wget is required.' >&2
    return 1
  fi
  [ -s "$target" ] || return 1
}
unzip_archive() {
  archive=$1; dest=$2
  if command -v unzip >/dev/null 2>&1; then
    unzip -qo "$archive" -d "$dest"
  elif command -v busybox >/dev/null 2>&1; then
    busybox unzip -o "$archive" -d "$dest" >/dev/null
  else
    echo 'ERROR: unzip required.' >&2
    return 1
  fi
}
extract_xz() {
  archive=$1; dest=$2
  if tar -xJf "$archive" -C "$dest" 2>/dev/null; then return 0; fi
  if command -v xz >/dev/null 2>&1; then
    xz -dc "$archive" | tar -xf - -C "$dest"
  else return 1; fi
}
install_app() {
  fetch "$APP_URL" "$TMP_DIR/torrstream.zip"
  mkdir -p "$TMP_DIR/app"
  unzip_archive "$TMP_DIR/torrstream.zip" "$TMP_DIR/app"
  binary=$(find "$TMP_DIR/app" -type f -name TorrStream-linux-amd64 | head -n 1)
  [ -n "$binary" ] && [ -s "$binary" ] || { echo 'ERROR: amd64 executable missing.' >&2; return 1; }
  stage_binary="$PROGRAM_DIR/.vidaa-server-new.$$"
  cp "$binary" "$stage_binary"
  chmod 755 "$stage_binary"
  public=$(find "$TMP_DIR/app" -type d -name public | head -n 1)
  if [ -n "$public" ]; then
    stage_public="$PROGRAM_DIR/.vidaa-public-new.$$"
    backup_public="$PROGRAM_DIR/.vidaa-public-backup.$$"
    cp -R "$public" "$stage_public"
    if [ -d "$PROGRAM_DIR/public" ]; then mv "$PROGRAM_DIR/public" "$backup_public"; fi
    if ! mv "$stage_public" "$PROGRAM_DIR/public"; then
      [ ! -d "$backup_public" ] || mv "$backup_public" "$PROGRAM_DIR/public"
      rm -f "$stage_binary"
      return 1
    fi
    rm -rf "$backup_public"
  fi
  mv -f "$stage_binary" "$PROGRAM_DIR/myapp-linux-x64"
  echo 'TorrStream binary installed.'
}
install_ffmpeg() {
  fetch "$FFMPEG_URL" "$TMP_DIR/ffmpeg.tar.xz"
  mkdir -p "$TMP_DIR/ffmpeg"
  extract_xz "$TMP_DIR/ffmpeg.tar.xz" "$TMP_DIR/ffmpeg"
  ff=$(find "$TMP_DIR/ffmpeg" -type f -name ffmpeg | head -n 1)
  fp=$(find "$TMP_DIR/ffmpeg" -type f -name ffprobe | head -n 1)
  [ -n "$ff" ] && [ -s "$ff" ] && [ -n "$fp" ] && [ -s "$fp" ] || return 1
  mkdir -p "$PROGRAM_DIR/ffmpeg"
  cp "$ff" "$PROGRAM_DIR/ffmpeg/.ffmpeg-new.$$"
  cp "$fp" "$PROGRAM_DIR/ffmpeg/.ffprobe-new.$$"
  chmod 755 "$PROGRAM_DIR/ffmpeg/.ffmpeg-new.$$" "$PROGRAM_DIR/ffmpeg/.ffprobe-new.$$"
  mv -f "$PROGRAM_DIR/ffmpeg/.ffmpeg-new.$$" "$PROGRAM_DIR/ffmpeg/ffmpeg"
  mv -f "$PROGRAM_DIR/ffmpeg/.ffprobe-new.$$" "$PROGRAM_DIR/ffmpeg/ffprobe"
  echo 'FFmpeg installed.'
}
case "${1:-}" in
  app) install_app ;;
  ffmpeg) install_ffmpeg ;;
  all) install_app; install_ffmpeg ;;
  *) echo "Usage: $0 {app|ffmpeg|all}" >&2; exit 2 ;;
esac
