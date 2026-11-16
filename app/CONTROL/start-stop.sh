#!/bin/sh
APP_DIR=${APKG_PKG_DIR:-/usr/local/AppCentral/vidaa-torrstream}
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
PID_FILE="$DATA_DIR/vidaa.pid"
WATCH_PID="$DATA_DIR/.update-watch.pid"
LOG_FILE="$DATA_DIR/logs/vidaa.log"
valid_pid() {
  [ -f "$PID_FILE" ] || return 1
  pid=$(cat "$PID_FILE" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  kill -0 "$pid" 2>/dev/null || return 1
  [ -r "/proc/$pid/cmdline" ] || return 1
  tr '\000' ' ' < "/proc/$pid/cmdline" | grep -q -e 'vidaa-torrstream/bin/run.sh' -e 'TorrStream' -e 'myapp-linux-x64'
}
stop_watch() {
  [ -f "$WATCH_PID" ] || return 0
  wid=$(cat "$WATCH_PID" 2>/dev/null || true)
  case "$wid" in ''|*[!0-9]*) ;; *)
    if [ -r "/proc/$wid/cmdline" ] && tr '\000' ' ' < "/proc/$wid/cmdline" | grep -q 'vidaa-torrstream/bin/update-watch.sh'; then
      kill "$wid" 2>/dev/null || true
    fi
  ;; esac
  rm -f "$WATCH_PID"
}
start() {
  if valid_pid; then echo "TorrStream already running (PID $(cat "$PID_FILE"))."; return 0; fi
  [ -x "$APP_DIR/bin/run.sh" ] || { echo "Missing launcher" >&2; return 1; }
  mkdir -p "$DATA_DIR/logs"
  if [ -e "$LOG_FILE" ]; then
    bytes=$(wc -c < "$LOG_FILE" | tr -d ' ')
    if [ "$bytes" -gt 10485760 ]; then mv -f "$LOG_FILE" "$LOG_FILE.old"; fi
  fi
  umask 077
  VIDAA_DATA_DIR="$DATA_DIR" APKG_PKG_DIR="$APP_DIR" nohup "$APP_DIR/bin/run.sh" >> "$LOG_FILE" 2>&1 &
  echo "$!" > "$PID_FILE"
  if [ -x "$APP_DIR/bin/update-watch.sh" ]; then
    VIDAA_DATA_DIR="$DATA_DIR" APKG_PKG_DIR="$APP_DIR" nohup "$APP_DIR/bin/update-watch.sh" >> "$LOG_FILE" 2>&1 &
    echo "$!" > "$WATCH_PID"
  fi
  echo "TorrStream started."
}
stop() {
  stop_watch
  if ! valid_pid; then rm -f "$PID_FILE"; echo "TorrStream is not running."; return 0; fi
  pid=$(cat "$PID_FILE")
  kill "$pid" 2>/dev/null || true
  i=0
  while [ "$i" -lt 10 ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
    i=$((i+1))
  done
  if valid_pid; then kill -9 "$pid" 2>/dev/null || true; fi
  rm -f "$PID_FILE"
  echo "TorrStream stopped."
}
case "${1:-}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) if valid_pid; then echo "TorrStream is running."; exit 0; else echo "TorrStream is stopped."; exit 1; fi ;;
  *) echo "Usage: $0 {start|stop|restart|status}" >&2; exit 2 ;;
esac
