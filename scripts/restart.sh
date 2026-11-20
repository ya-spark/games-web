#!/usr/bin/env bash
# Stop the server, then run.sh again. Arguments and env vars pass through (e.g. NO_BUILD=1 scripts/restart.sh).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$DIR/stop.sh"
exec "$DIR/run.sh" "$@"
