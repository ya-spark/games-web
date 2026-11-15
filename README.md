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

## The landing page (`site/`)

`site/index.html` is plain HTML and JavaScript (no Flutter): filters Learn / Fun, Year, Topic and Game over `catalog.json`.
`scripts/make_catalog.py` writes `catalog.json` at deploy time from the app checkouts: one Fun card per game in a Mind
app's `lib/ui/game_registry.dart` and one Learn card per free pack in a Craft app's `assets/content/index.json`, only for
games with `live: true` in `games.yaml`. A card links into the game's own build: `<slug>/#/game/<id>` or
`<slug>/#/quiz/<subject>/<year>/<topic>`. The card art in `site/art/` is the studio's own icon set (from game-factory
`design/game_art`, original work, see its README). Every game opens with a how-to-play dialog the first time in a browser
(`overlay/common`), and a Rules button brings it back; the only thing stored is one flag per game in the browser.

## How a commit reaches the site

This repo has no workflows and no secrets (it is public). `ya-spark/game-studio` holds the deploy: when the `games-web`
pin, or the pin of a web game's app repo, moves on its `main`, the `deploy-games-web` workflow there rebuilds every live
game that is behind (it compares each game's `build-info.json` on the site with `main`) and swaps it into the
`games-web` container on the VPS. Each game's `build-info.json` and the index at `/games/` show the commits that are running.

## Status (2026-11-15)
- `ember` (Mind family): builds; the game list shows the new icons; Sudoku plays.
- `scout` (Craft family): builds; year, subject and topic pickers in the teaching order of `topics.yaml`; a topic or a mixed
  round runs the Quick quiz on an empty anonymous progress with all built-in starter packs open.
- For both, browser `localStorage` stays empty (nothing is saved) and the console shows no errors (Chromium, 2026-11-15).
- Not done yet: `presto`, `ranger`, `champion` (same overlays, not built or looked at yet), the minigames of the Craft apps beyond
  the Quick quiz, the public landing page, the ad slot, the build-and-publish workflow and the hosting container.
