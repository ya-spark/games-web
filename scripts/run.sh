#!/usr/bin/env bash
# Build and serve: the one command for local work.
# Usage: scripts/run.sh [slug ...]        e.g. scripts/run.sh ember scout   (default: every game)
# Env:   NO_BUILD=1  serve what is already in dist/      SITE_ONLY=1  rebuild only the landing page, then serve
#        WATCH=1    build, serve, then rebuild and reload the page whenever site/, overlay/ or the app checkouts change
#        (see watch.sh: rebuild-and-reload, not Flutter hot reload; a game rebuild takes a few minutes)
#        PORT=8080 HOST=127.0.0.1 NO_OPEN=1 APPS_DIR=...
# Without WATCH=1 there is no reload: after a change, run it again (use SITE_ONLY=1 for edits under site/).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -n "${WATCH:-}" ] && exec "$DIR/watch.sh" "$@"
if [ -n "${SITE_ONLY:-}" ]; then "$DIR/build.sh" --site
elif [ -z "${NO_BUILD:-}" ]; then "$DIR/build.sh" "$@"; fi
exec "$DIR/serve.sh"
