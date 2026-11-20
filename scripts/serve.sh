#!/usr/bin/env bash
# Serve dist/ (landing page at /, games at /<slug>/) in the foreground. Ctrl+C stops it.
# Usage: scripts/serve.sh            env: PORT=8080 HOST=127.0.0.1 NO_OPEN=1
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

[ -f "$DIST_DIR/index.html" ] || { echo "Nothing in dist/: run scripts/build.sh first" >&2; exit 1; }
port_in_use "$PORT" && { echo "Port $PORT is in use: run scripts/stop.sh, or set PORT" >&2; exit 1; }

URL="http://localhost:$PORT/"
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT
echo "Serving $DIST_DIR at $URL  (Ctrl+C to stop)"
if [ -z "${NO_OPEN:-}" ]; then
  ( sleep 1
    if command -v wslview >/dev/null 2>&1; then wslview "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
    elif command -v open >/dev/null 2>&1; then open "$URL"
    fi ) >/dev/null 2>&1 &
fi
exec python3 -m http.server "$PORT" --bind "$HOST" --directory "$DIST_DIR"
