#!/bin/sh
set -eu
case "$(uname -m)" in
  x86_64|amd64) exit 0 ;;
  *) echo 'TorrStream supports x86-64 only.' >&2; exit 1 ;;
esac
