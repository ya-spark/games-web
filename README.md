# games-web

The public web versions of the games, served at `https://activemindcraft.com/games/<slug>/`
(the `/appgames/<name>/` pages are only test copies of the store apps and are built elsewhere).

Rules of the web product (owner, 2026-11-15): no coins, no shop, no purchases, no profiles, and
**nothing is saved** (every visit starts fresh). The app repos are never changed for it.

## How it works
- `games.yaml` lists the games: slug, the app repo the code comes from, and the overlay family.
- `overlay/<family>/lib/...` holds the web entry for a family of apps (`mind`, later `craft`).
- `scripts/build_game.sh <slug> <app checkout>` copies the app to a temporary folder, copies the
  overlay on top, and builds the web bundle into `dist/<slug>/` (not committed). The app checkout
  is not modified.

## Status
- `ember`: builds, shows the game list with the new icons, Sudoku plays, nothing is written to
  browser storage (checked in Chromium on 2026-11-15).
- Not done yet: `presto`, the three Craft games, the public landing page, the ad slot, the
  build-and-publish workflow and the hosting container.
