#!/usr/bin/env bash
# Watch mode for local work: serve dist/, and when files change rebuild what they affect and reload the open page.
# Usage: scripts/watch.sh [slug ...]      (started by scripts/run.sh unless WATCH=0 [slug ...])
# Watches: site/ (landing page only, seconds), overlay/ (the games of that family), the app checkouts (that game).
# This is rebuild-and-reload, not Flutter hot reload: a game rebuild is a full release build (a few minutes).
# For instant hot reload of a game on its own, run `flutter run -d chrome` inside its app folder.
# Env: NO_BUILD=1 (skip the first build), FULL=1 (first build rebuilds every game, not just the missing ones), POLL=2 (seconds between checks), plus PORT HOST NO_OPEN APPS_DIR as for run.sh.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

slugs=("$@")
[ "${#slugs[@]}" -gt 0 ] || while read -r s; do slugs+=("$s"); done < <(all_slugs)
POLL="${POLL:-2}"
STAMP="$ROOT_DIR/.watch-stamp"

# The page polls /__reload and reloads itself when the stamp changes. Local dist/ only, never deployed.
SNIPPET='<script>/*dev-reload*/(function(){var l;setInterval(function(){fetch("/__reload",{cache:"no-store"}).then(function(r){return r.text()}).then(function(t){if(l&&t!==l)location.reload();l=t}).catch(function(){})},1000)})();</script>'
inject() {
  local f
  for f in "$DIST_DIR/index.html" "${slugs[@]/#/$DIST_DIR/}"; do
    [ -d "$f" ] && f="$f/index.html"
    [ -f "$f" ] && ! grep -q 'dev-reload' "$f" && python3 -c 'import sys; p, t = sys.argv[1:]; s = open(p).read(); open(p, "w").write(s.replace("</head>", t + "</head>", 1))' "$f" "$SNIPPET"
  done
  date +%s%N > "$DIST_DIR/__reload"
}

# changed <path...>: true when any file under the paths is newer than the last build started.
changed() { find "$@" \( -name .git -o -name build -o -name .dart_tool \) -prune -o -type f -newer "$STAMP" -print -quit 2>/dev/null | grep -q .; }

rebuild() {  # rebuild <build.sh args...>
  touch "$STAMP"                       # before the build, so edits made during it trigger another round
  bash "$ROOT_DIR/scripts/build.sh" "$@" || echo "!! Build failed (see above); fix and save again, still watching."
  inject
  echo "==> $(date +%H:%M:%S) ready, page reloads"
}

touch "$STAMP"
# First build: only games with no output in dist/ yet (plus the landing page, always). FULL=1 rebuilds every game.
if [ -n "${NO_BUILD:-}" ]; then inject   # NO_BUILD=1: serve dist/ as is, only watch
else
  first=()
  for s in "${slugs[@]}"; do { [ -n "${FULL:-}" ] || [ ! -f "$DIST_DIR/$s/index.html" ]; } && first+=("$s"); done
  if [ "${#first[@]}" -gt 0 ]; then echo "==> First build: ${first[*]}"; rebuild "${first[@]}"
  else echo "==> All games already in dist/ (FULL=1 to rebuild them); landing page only"; rebuild --site; fi
fi
NO_OPEN_SET="${NO_OPEN:-}"
NO_OPEN="$NO_OPEN_SET" bash "$ROOT_DIR/scripts/serve.sh" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -f "$STAMP" "$PID_FILE"; exit 0' INT TERM EXIT
echo "Watching site/, overlay/ and the app checkouts for: ${slugs[*]}  (Ctrl+C to stop)"

while kill -0 "$SERVER" 2>/dev/null; do
  sleep "$POLL"
  todo=()
  for s in "${slugs[@]}"; do
    fam="$(game_field "$s" family)"
    if changed "$(app_dir "$s")" "$ROOT_DIR/overlay/$fam" "$ROOT_DIR/overlay/common"; then todo+=("$s"); fi
  done
  if [ "${#todo[@]}" -gt 0 ]; then echo "==> Change in: ${todo[*]}"; rebuild "${todo[@]}"
  elif changed "$ROOT_DIR/site" "$ROOT_DIR/games.yaml"; then echo "==> Change in site/"; rebuild --site; fi
done
