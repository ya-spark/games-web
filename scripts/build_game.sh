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
[ -d "$ROOT/overlay/common/lib" ] && cp -R "$ROOT/overlay/common/lib/." "$TMP/app/lib/"
cp -R "$ROOT/overlay/$FAMILY/lib/." "$TMP/app/lib/"
[ -d "$ROOT/overlay/$FAMILY/test" ] && mkdir -p "$TMP/app/test" && cp -R "$ROOT/overlay/$FAMILY/test/." "$TMP/app/test/"
# Overlay tests import the app by package name; the apps differ, so the files carry APP_PKG until here.
PKG_NAME="$(awk '/^name:/ {print $2; exit}' "$TMP/app/pubspec.yaml")"
[ -d "$ROOT/overlay/$FAMILY/test" ] && grep -rl APP_PKG "$TMP/app/test" 2>/dev/null | xargs -r sed -i "s/APP_PKG/$PKG_NAME/g"
# Craft: every Craft game plays every year and topic (W6), so merge the free packs and topics of the other Craft apps
# into this temporary copy (the checkouts and this public repo are not changed).
if [ "$FAMILY" = craft ]; then
  OTHERS=()
  while read -r other_slug other_repo; do
    [ "$other_slug" = "$SLUG" ] && continue
    d="${APPS_DIR:-$ROOT/../apps}/${other_repo#*/}"
    if [ -d "$d/assets/content" ]; then OTHERS+=("$d"); else echo "WARNING: no checkout of $other_slug at $d; its years are missing from $SLUG"; fi
  done < <(awk '$1=="-" && $2=="slug:" {s=$3} $1=="app:" {a=$2} $1=="family:" {if ($2=="craft") print s, a}' "$ROOT/games.yaml")
  [ "${#OTHERS[@]}" -gt 0 ] && python3 "$ROOT/scripts/merge_craft_content.py" "$TMP/app" "${OTHERS[@]}"
fi
cd "$TMP/app"
flutter pub get >/dev/null
flutter build web --release --no-web-resources-cdn --base-href "$BASE_HREF" -t lib/web_product/main_web.dart
# Craft: list the app's real minigames (free or coin-locked, item types, years) for the catalog page.
if [ "$FAMILY" = craft ] && [ -f "$TMP/app/test/web_minigames_test.dart" ]; then
  MINIGAMES_OUT="$TMP/app/build/web/minigames.json" flutter test test/web_minigames_test.dart >/dev/null 2>&1 \
    || echo "WARNING: could not list the minigames for $SLUG; the catalog will show Quick quiz only"
fi
# Craft games read their ~90 content packs one after another at start-up; over a real network that is one round trip
# each. Start all the downloads in parallel from the page itself (the server lets the browser reuse them for a few
# minutes), so the app's one-by-one reads come from the browser cache.
if [ "$FAMILY" = craft ] && [ -d "$TMP/app/assets/content" ]; then
  LIST="$(cd "$TMP/app/assets/content" && { echo index.json; echo topics.yaml; ls packs/*.json 2>/dev/null; } | sed 's/.*/"&"/' | paste -sd, -)"
  python3 - "$TMP/app/build/web/index.html" "$LIST" <<'PY'
import sys
p, lst = sys.argv[1], sys.argv[2]
s = open(p).read()
tag = ('<script>(function(){try{[' + lst + '].forEach(function(f){fetch("assets/assets/content/"+f)})}catch(e){}})();</script>')
assert '</head>' in s
open(p, 'w').write(s.replace('</head>', tag + '</head>', 1))
PY
fi
# build-info.json: which commits this build came from (served at <base>/build-info.json and shown on the /games/ index).
printf '{"slug":"%s","app":"%s","appCommit":"%s","gamesWebCommit":"%s","builtAt":"%s"}\n' \
  "$SLUG" "$REPO" "$APP_SHA" "$WEB_SHA" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build/web/build-info.json
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"; cp -R build/web "$OUT"
echo "Built $SLUG into $OUT"
