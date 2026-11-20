#!/usr/bin/env bash
# One-time local check: tools, Flutter web support and the app checkouts games-web builds from.
# Usage: scripts/setup.sh            report what is missing
#        CLONE=1 scripts/setup.sh    also `git clone` missing app repos into APPS_DIR (needs access to the private repos)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

ok=1
for tool in git python3 curl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "MISSING tool: $tool"; ok=0; }
done
if command -v flutter >/dev/null 2>&1; then
  flutter --version | head -1
  flutter config --enable-web >/dev/null
else
  echo "MISSING flutter (install it, or set FLUTTER_HOME; the studio pins the version in game-factory/.flutter-version)"
  ok=0
fi

echo "App checkouts in $APPS_DIR:"
for slug in $(all_slugs); do
  dir="$(app_dir "$slug")"
  if [ -f "$dir/pubspec.yaml" ]; then
    echo "  ok       $slug  ($dir)"
  elif [ -n "${CLONE:-}" ]; then
    repo="$(game_field "$slug" app)"
    echo "  cloning  $slug  (https://github.com/$repo.git)"
    mkdir -p "$APPS_DIR"
    git clone "https://github.com/$repo.git" "$dir" || { echo "  FAILED   $slug"; ok=0; }
  else
    echo "  MISSING  $slug  (expected at $dir; run with CLONE=1 or set APPS_DIR)"
    ok=0
  fi
done

[ "$ok" = 1 ] && echo "Ready. Next: scripts/run.sh ember" || { echo "Not ready: see above."; exit 1; }
