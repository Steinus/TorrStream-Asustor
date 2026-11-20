#!/bin/sh
# ASUSTOR ADM service control. /proc scanning recovers orphaned TorrStream processes.
# Never match/stop a different TorrServer installation.
APP_DIR=${APKG_PKG_DIR:-/usr/local/AppCentral/vidaa-torrstream}
DATA_DIR=${VIDAA_DATA_DIR:-/volume1/Docker/Vidaa}
SERVER="$DATA_DIR/program/myapp-linux-x64"
RUN_SCRIPT="$APP_DIR/bin/run.sh"
WATCH_SCRIPT="$APP_DIR/bin/update-watch.sh"
PID_FILE="$DATA_DIR/vidaa.pid"
WATCH_PID="$DATA_DIR/.update-watch.pid"
LOG_FILE="$DATA_DIR/logs/vidaa.log"

has_argument() {
  arg_pid=$1
  arg_value=$2
  [ -r "/proc/$arg_pid/cmdline" ] || return 1
  tr '\000' '\n' < "/proc/$arg_pid/cmdline" 2>/dev/null | grep -Fxq "$arg_value"
}

is_server_pid() {
  server_pid=$1
  case "$server_pid" in ''|*[!0-9]*) return 1 ;; esac
  [ -d "/proc/$server_pid" ] || return 1
  [ "$server_pid" != "$$" ] || return 1
  if command -v readlink >/dev/null 2>&1; then
    server_exe=$(readlink "/proc/$server_pid/exe" 2>/dev/null || true)
    case "$server_exe" in
      "$SERVER"|"$SERVER (deleted)") return 0 ;;
    esac
  fi
  has_argument "$server_pid" "$SERVER" || has_argument "$server_pid" "$RUN_SCRIPT"
}

is_watch_pid() {
  watcher_pid=$1
  case "$watcher_pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$watcher_pid" != "$$" ] || return 1
  has_argument "$watcher_pid" "$WATCH_SCRIPT"
}

server_pids() {
  for server_proc in /proc/[0-9]*; do
    [ -d "$server_proc" ] || continue
    server_candidate=${server_proc##*/}
    if is_server_pid "$server_candidate"; then
      printf '%s\n' "$server_candidate"
    fi
  done
}

watch_pids() {
  for watch_proc in /proc/[0-9]*; do
    [ -d "$watch_proc" ] || continue
    watch_candidate=${watch_proc##*/}
    if is_watch_pid "$watch_candidate"; then
      printf '%s\n' "$watch_candidate"
    fi
  done
}

stop_watch() {
  for stopped_watch in $(watch_pids); do
    if is_watch_pid "$stopped_watch"; then
      kill "$stopped_watch" 2>/dev/null || true
    fi
  done
  rm -f "$WATCH_PID"
}

start_watch() {
  [ -x "$WATCH_SCRIPT" ] || return 0
  existing_watch=$(watch_pids)
  if [ -n "$existing_watch" ]; then
    printf '%s\n' "$existing_watch" | sed -n '1p' > "$WATCH_PID"
    return 0
  fi
  VIDAA_DATA_DIR="$DATA_DIR" APKG_PKG_DIR="$APP_DIR" nohup "$WATCH_SCRIPT" >> "$LOG_FILE" 2>&1 &
  printf '%s\n' "$!" > "$WATCH_PID"
}

stop_service() {
  stop_watch
  found=$(server_pids)
  if [ -z "$found" ]; then
    rm -f "$PID_FILE"
    echo 'TorrStream is already stopped.'
    return 0
  fi
  for stopped_pid in $found; do
    if is_server_pid "$stopped_pid"; then
      kill "$stopped_pid" 2>/dev/null || true
    fi
  done
  attempts=0
  while [ "$attempts" -lt 10 ]; do
    found=$(server_pids)
    [ -n "$found" ] || break
    sleep 1
    attempts=$((attempts + 1))
  done
  # Force only the APK's own processes, never a generic torrserver process.
  found=$(server_pids)
  if [ -n "$found" ]; then
    for stopped_pid in $found; do
      if is_server_pid "$stopped_pid"; then
        kill -9 "$stopped_pid" 2>/dev/null || true
      fi
    done
    sleep 1
  fi
  if [ -n "$(server_pids)" ]; then
    echo 'ERROR: TorrStream processes are still running.' >&2
    return 1
  fi
  rm -f "$PID_FILE"
  echo 'TorrStream stopped.'
}

start_service() {
  [ -x "$RUN_SCRIPT" ] || { echo 'ERROR: missing TorrStream launcher.' >&2; return 1; }
  mkdir -p "$DATA_DIR/logs" || return 1
  found=$(server_pids)
  if [ -n "$found" ]; then
    if [ -f "$DATA_DIR/.update-on-start" ]; then
      echo 'TorrStream: restarting an old instance to apply package update.'
      stop_service || return 1
    else
      first_pid=$(printf '%s\n' "$found" | sed -n '1p')
      printf '%s\n' "$first_pid" > "$PID_FILE"
      start_watch
      echo "TorrStream already running (PID $first_pid); adopted by ADM."
      return 0
    fi
  fi
  if [ -f "$LOG_FILE" ]; then
    log_bytes=$(wc -c < "$LOG_FILE" | tr -d ' ')
    if [ "$log_bytes" -gt 10485760 ]; then mv -f "$LOG_FILE" "$LOG_FILE.old" || true; fi
  fi
  umask 077
  VIDAA_DATA_DIR="$DATA_DIR" APKG_PKG_DIR="$APP_DIR" nohup "$RUN_SCRIPT" >> "$LOG_FILE" 2>&1 &
  printf '%s\n' "$!" > "$PID_FILE"
  sleep 2
  found=$(server_pids)
  if [ -z "$found" ]; then
    rm -f "$PID_FILE"
    echo "ERROR: TorrStream did not remain running; check $LOG_FILE" >&2
    return 1
  fi
  first_pid=$(printf '%s\n' "$found" | sed -n '1p')
  printf '%s\n' "$first_pid" > "$PID_FILE"
  start_watch
  echo "TorrStream started (PID $first_pid)."
}

case "${1:-}" in
  start) start_service ;;
  stop) stop_service ;;
  restart) stop_service && start_service ;;
  status)
    found=$(server_pids)
    if [ -n "$found" ]; then
      echo "TorrStream is running (PID(s): $(printf '%s' "$found" | tr '\n' ' '))."
      exit 0
    fi
    echo 'TorrStream is stopped.'
    exit 1
    ;;
  *) echo "Usage: $0 {start|stop|restart|status}" >&2; exit 2 ;;
esac
