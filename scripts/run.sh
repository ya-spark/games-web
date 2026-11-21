#!/usr/bin/env bash
# Build and serve: the one command for local work.
# Usage: scripts/run.sh [slug ...]        e.g. scripts/run.sh ember scout   (default: every game)
# Env:   NO_BUILD=1  serve what is already in dist/      SITE_ONLY=1  rebuild only the landing page, then serve
#        WATCH=0    plain build and serve, no reload (default is watch mode: build, serve, then rebuild and reload
#        the page whenever site/, overlay/ or the app checkouts change; see watch.sh: rebuild-and-reload,
#        not Flutter hot reload; a game rebuild takes a few minutes; on start only games missing from dist/ are built, FULL=1 builds all). NO_BUILD=1 and SITE_ONLY=1 also skip watch.
#        PORT=8080 HOST=127.0.0.1 NO_OPEN=1 APPS_DIR=...
# With WATCH=0, NO_BUILD=1 or SITE_ONLY=1 there is no reload: after a change, run it again.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ "${WATCH:-1}" != "0" ] && [ -z "${NO_BUILD:-}" ] && [ -z "${SITE_ONLY:-}" ] && exec "$DIR/watch.sh" "$@"
if [ -n "${SITE_ONLY:-}" ]; then "$DIR/build.sh" --site
elif [ -z "${NO_BUILD:-}" ]; then "$DIR/build.sh" "$@"; fi
exec "$DIR/serve.sh"
