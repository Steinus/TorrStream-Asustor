#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTDIR="$(mktemp -d)"
export APKG_PKG_DIR="$TESTDIR/app"
export VIDAA_DATA_DIR="$TESTDIR/data"
mkdir -p "$APKG_PKG_DIR/bin" "$VIDAA_DATA_DIR/program" "$VIDAA_DATA_DIR/logs"
CTL="$ROOT/app/CONTROL/start-stop.sh"
stranger=""
cleanup() {
  sh "$CTL" stop >/dev/null 2>&1 || true
  if [ -n "$stranger" ]; then kill "$stranger" 2>/dev/null || true; fi
  rm -rf "$TESTDIR"
}
trap cleanup EXIT
cat > "$APKG_PKG_DIR/bin/run.sh" <<'SH'
#!/bin/sh
exec "$VIDAA_DATA_DIR/program/myapp-linux-x64"
SH
cat > "$VIDAA_DATA_DIR/program/myapp-linux-x64" <<'SH'
#!/bin/sh
trap 'exit 0' TERM INT
while :; do sleep 1; done
SH
cat > "$APKG_PKG_DIR/bin/update-watch.sh" <<'SH'
#!/bin/sh
trap 'exit 0' TERM INT
while :; do sleep 1; done
SH
chmod +x "$APKG_PKG_DIR/bin/"*.sh "$VIDAA_DATA_DIR/program/myapp-linux-x64"
echo 'Test 1: start/status/idempotent start/stop.'
sh "$CTL" start
sh "$CTL" status
sh "$CTL" start
sh "$CTL" stop
if sh "$CTL" status >/dev/null 2>&1; then echo 'FAIL: still running' >&2; exit 1; fi
echo 'Test 2: orphan server without valid pidfile is detected and stopped.'
"$VIDAA_DATA_DIR/program/myapp-linux-x64" >/dev/null 2>&1 &
orphan=$!
sleep 1
printf '99999999\n' > "$VIDAA_DATA_DIR/vidaa.pid"
sh "$CTL" status
sh "$CTL" stop
if sh "$CTL" status >/dev/null 2>&1; then echo 'FAIL: orphan is running' >&2; exit 1; fi
wait "$orphan" || true
echo 'Test 3: unrelated process is never killed even when pidfile points to it.'
sleep 120 &
stranger=$!
printf '%s\n' "$stranger" > "$VIDAA_DATA_DIR/vidaa.pid"
sh "$CTL" start
kill -0 "$stranger"
sh "$CTL" stop
kill -0 "$stranger"
kill "$stranger" || true
wait "$stranger" || true
stranger=""
echo 'Test 4: duplicate managed processes all stop.'
"$VIDAA_DATA_DIR/program/myapp-linux-x64" >/dev/null 2>&1 &
orphan1=$!
"$VIDAA_DATA_DIR/program/myapp-linux-x64" >/dev/null 2>&1 &
orphan2=$!
sleep 1
rm -f "$VIDAA_DATA_DIR/vidaa.pid"
sh "$CTL" stop
if sh "$CTL" status >/dev/null 2>&1; then echo 'FAIL: duplicates remained' >&2; exit 1; fi
wait "$orphan1" || true
wait "$orphan2" || true
echo 'Test 5: update marker restarts adopted orphan.'
"$VIDAA_DATA_DIR/program/myapp-linux-x64" >/dev/null 2>&1 &
orphan3=$!
sleep 1
touch "$VIDAA_DATA_DIR/.update-on-start"
sed -i '2i rm -f "$VIDAA_DATA_DIR/.update-on-start"' "$APKG_PKG_DIR/bin/run.sh"
sh "$CTL" start
sh "$CTL" status
sh "$CTL" stop
wait "$orphan3" || true
echo 'PASS: all managed TorrStream lifecycle tests passed.'
