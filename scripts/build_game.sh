#!/usr/bin/env bash
# Build the web version of one game.
#   scripts/build_game.sh <slug> <app-dir> [out-dir]
# <app-dir> is a checkout of the app repo at the pinned commit (see games.yaml). The app is copied to a
# temporary folder, the overlay for its family is copied on top, and the web bundle is built from the
# copy: the app checkout itself is never changed. Output: dist/<slug>/ (served at /games/<slug>/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${1:?slug, for example ember}"
APP="${2:?path of the app checkout}"
OUT="${3:-$ROOT/dist/$SLUG}"
FAMILY="$(awk -v s="$SLUG" '$1=="-" && $2=="slug:" {cur=($3==s)} cur && $1=="family:" {print $2; exit}' "$ROOT/games.yaml")"
[ -n "$FAMILY" ] || { echo "Unknown slug: $SLUG (see games.yaml)"; exit 1; }
[ -d "$ROOT/overlay/$FAMILY" ] || { echo "No overlay for family $FAMILY yet"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/app"
tar -C "$APP" --exclude=.git --exclude=build --exclude=.dart_tool -cf - . | tar -C "$TMP/app" -xf -
cp -R "$ROOT/overlay/$FAMILY/lib/." "$TMP/app/lib/"
cd "$TMP/app"
flutter pub get >/dev/null
flutter build web --release --no-web-resources-cdn --base-href "/games/$SLUG/" -t lib/web_product/main_web.dart
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"; cp -R build/web "$OUT"
echo "Built $SLUG into $OUT"
