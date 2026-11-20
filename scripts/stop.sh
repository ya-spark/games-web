#!/usr/bin/env bash
# Stop the local server started by serve.sh / run.sh. Safe to run when nothing is running.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

if [ -f "$PID_FILE" ]; then
  pid="$(cat "$PID_FILE")"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null && echo "Stopped server (PID $pid)"; fi
  rm -f "$PID_FILE"
fi
# The server is exec'd python http.server on dist/: stop a leftover one by its command line.
pkill -f "http.server $PORT --bind .* --directory $DIST_DIR" 2>/dev/null && echo "Stopped server on port $PORT"
port_in_use "$PORT" && echo "Port $PORT is still in use by another program (not stopped)."
exit 0
