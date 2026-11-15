#!/usr/bin/env bash
# Build the web version of one game.
#   scripts/build_game.sh <slug> [<app-dir> [out-dir]]
# <app-dir> is a checkout of the app repo (see games.yaml); when it is left out, APPS_DIR/<repo name> is used
# (default ../apps next to this repo). BASE_HREF overrides the served path (default /games/<slug>/; the
# preview on the test site uses /appgames/web-<slug>/). The app is copied to a
# temporary folder, the overlay for its family is copied on top, and the web bundle is built from the
# copy: the app checkout itself is never changed. Output: dist/<slug>/ (served at /games/<slug>/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${1:?slug, for example ember}"
REPO="$(awk -v s="$SLUG" '$1=="-" && $2=="slug:" {cur=($3==s)} cur && $1=="app:" {print $2; exit}' "$ROOT/games.yaml")"
[ -n "$REPO" ] || { echo "Unknown slug: $SLUG (see games.yaml)"; exit 1; }
APP="${2:-${APPS_DIR:-$ROOT/../apps}/${REPO#*/}}"
OUT="${3:-$ROOT/dist/$SLUG}"
BASE_HREF="${BASE_HREF:-/games/$SLUG/}"
[ -f "$APP/pubspec.yaml" ] || { echo "No app checkout at $APP"; exit 1; }
FAMILY="$(awk -v s="$SLUG" '$1=="-" && $2=="slug:" {cur=($3==s)} cur && $1=="family:" {print $2; exit}' "$ROOT/games.yaml")"
[ -n "$FAMILY" ] || { echo "Unknown slug: $SLUG (see games.yaml)"; exit 1; }
[ -d "$ROOT/overlay/$FAMILY" ] || { echo "No overlay for family $FAMILY yet"; exit 1; }
APP_SHA="$(git -C "$APP" rev-parse HEAD 2>/dev/null || echo unknown)"
WEB_SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/app"
tar -C "$APP" --exclude=.git --exclude=build --exclude=.dart_tool -cf - . | tar -C "$TMP/app" -xf -
cp -R "$ROOT/overlay/$FAMILY/lib/." "$TMP/app/lib/"
cd "$TMP/app"
flutter pub get >/dev/null
flutter build web --release --no-web-resources-cdn --base-href "$BASE_HREF" -t lib/web_product/main_web.dart
# build-info.json: which commits this build came from (served at <base>/build-info.json and shown on the /games/ index).
printf '{"slug":"%s","app":"%s","appCommit":"%s","gamesWebCommit":"%s","builtAt":"%s"}\n' \
  "$SLUG" "$REPO" "$APP_SHA" "$WEB_SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build/web/build-info.json
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"; cp -R build/web "$OUT"
echo "Built $SLUG into $OUT"
