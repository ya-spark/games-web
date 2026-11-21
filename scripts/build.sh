#!/usr/bin/env bash
# Build games and the landing page into dist/ for local use (served from the root: /<slug>/).
# Usage: scripts/build.sh [slug ...]      default: every game in games.yaml
#        scripts/build.sh --site          only redo the landing page and catalog.json (fast, no Flutter build)
# The app checkouts are only read. Games that are not built are listed on the landing page
# (when live: true) but their cards will not open.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

site_only=0; slugs=()
for arg in "$@"; do
  if [ "$arg" = "--site" ]; then site_only=1
  elif all_slugs | grep -qx -- "$arg"; then slugs+=("$arg")
  else echo "Unknown slug: $arg (available: $(all_slugs | tr '\n' ' '))" >&2; exit 1; fi
done
[ "$site_only" = 1 ] || [ "${#slugs[@]}" -gt 0 ] || while read -r s; do slugs+=("$s"); done < <(all_slugs)

if [ "$site_only" = 0 ]; then
  need_flutter
  flutter config --enable-web >/dev/null
  for slug in "${slugs[@]}"; do
    echo "==> Building $slug"
    BASE_HREF="/$slug/" APPS_DIR="$APPS_DIR" bash "$ROOT_DIR/scripts/build_game.sh" "$slug" "$(app_dir "$slug")" "$DIST_DIR/$slug"
  done
fi

echo "==> Landing page"
mkdir -p "$DIST_DIR/_site"
python3 "$ROOT_DIR/scripts/make_catalog.py" --apps "$APPS_DIR" --games "$ROOT_DIR/games.yaml" --dist "$DIST_DIR" --out "$DIST_DIR/catalog.json"
cp "$ROOT_DIR/site/index.html" "$DIST_DIR/index.html"
cp "$ROOT_DIR/site/progress.js" "$DIST_DIR/_site/progress.js"
rm -rf "$DIST_DIR/_site/art"; cp -R "$ROOT_DIR/site/art" "$DIST_DIR/_site/art"
echo "Done: $DIST_DIR"
