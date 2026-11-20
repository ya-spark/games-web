#!/usr/bin/env bash
# Shared settings for setup/build/serve/run/stop/restart. Sourced, not run.
# Everything can be overridden with environment variables:
#   APPS_DIR     folder with the app checkouts, named like the repos (default: ../apps, which is right
#                when games-web sits inside the game-studio checkout)
#   PORT / HOST  local server (default 8080 on 127.0.0.1)
#   FLUTTER_HOME Flutter SDK (default ~/flutter), used when flutter is not already on PATH

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="${APPS_DIR:-$ROOT_DIR/../apps}"
[ -d "$APPS_DIR" ] && APPS_DIR="$(cd "$APPS_DIR" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"
PID_FILE="$ROOT_DIR/.dev-server.pid"

FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
if ! command -v flutter >/dev/null 2>&1 && [ -x "$FLUTTER_HOME/bin/flutter" ]; then
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

# Slugs in games.yaml, one per line.
all_slugs() { awk '$1=="-" && $2=="slug:" {print $3}' "$ROOT_DIR/games.yaml"; }

# Field of one game in games.yaml: game_field <slug> <app|family|title>
game_field() {
  awk -v s="$1" -v k="$2:" '$1=="-" && $2=="slug:" {cur=($3==s)} cur && $1==k {sub(/^[^:]*:[ \t]*/, ""); print; exit}' "$ROOT_DIR/games.yaml"
}

# Where a game's app checkout is expected.
app_dir() { local repo; repo="$(game_field "$1" app)"; printf '%s/%s' "$APPS_DIR" "${repo#*/}"; }

port_in_use() { ss -H -tln "sport = :${1}" 2>/dev/null | grep -q .; }

need_flutter() {
  command -v flutter >/dev/null 2>&1 || { echo "flutter not found: run scripts/setup.sh" >&2; exit 1; }
}
