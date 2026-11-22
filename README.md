# games-web

The public web versions of the games, served at `https://activemindcraft.com/games/<slug>/`
(the `/appgames/<name>/` pages are only test copies of the store apps and are built elsewhere).

Rules of the web product: no coins, no shop, no purchases, no profiles, no backend. The app repos are never changed for it.
What the browser remembers (owner, 2026-11-21): one small JSON blob on this device only (`amc.state`: year, which topics are
known or being practised, last game), plus the theme and one rules-seen flag per game. Nothing is sent anywhere.

## How it works
- `games.yaml` lists the games: slug, the app repo the code comes from, and the overlay family.
- `overlay/<family>/lib/...` holds the web entry for a family of apps (`mind`, later `craft`).
- `scripts/build_game.sh <slug> <app checkout>` copies the app to a temporary folder, copies the
  overlay on top, and builds the web bundle into `dist/<slug>/` (not committed). The app checkout
  is not modified.

## Running it on your laptop

Needs Flutter (the version in game-factory's `.flutter-version`), Python 3, and the app checkouts. Inside the
`game-studio` checkout they are in `../apps`; elsewhere set `APPS_DIR` to a folder holding the app repos.

| Script | What it does |
|---|---|
| `scripts/setup.sh` | Checks tools and app checkouts (`CLONE=1` clones missing app repos; they are private). |
| `scripts/run.sh [slug ...]` | Builds the games (default: all) and the landing page into `dist/`, then serves at `http://localhost:8080/`. |
| `scripts/build.sh [slug ...]` | Build only (`--site` redoes just the landing page and `catalog.json`, no Flutter build). |
| `scripts/serve.sh` | Serve what is in `dist/` (`PORT`, `HOST`, `NO_OPEN=1`). |
| `scripts/stop.sh`, `scripts/restart.sh` | Stop the server; stop and run again. |

A web release build takes a few minutes per game and there is no Flutter hot reload. `scripts/run.sh [slug ...]` therefore
runs in watch mode by default (`scripts/watch.sh`): it serves, rebuilds what changed (`site/` alone takes seconds; `overlay/` or an app
checkout rebuilds those games) and reloads the open page when the build is ready. Use `WATCH=0 scripts/run.sh` for a plain build and
serve, `SITE_ONLY=1` or `NO_BUILD=1` to skip the watcher. On start it builds only games missing from `dist/` (plus the landing page); `FULL=1` rebuilds them all. Locally the games are served from `/<slug>/`, not
`/games/<slug>/`; the deploy builds with the real path.

## The landing page (`site/`) and the games-first flow (W6)

`site/index.html` is plain HTML and JavaScript (no Flutter) and shows the games only: Craft games sorted by the saved
year (Scout for Years 0 to 6 first, then Ranger 7 to 10, Champion 11 to 12; nothing hidden), then a "Puzzles" section with
the Mind games. A Year chip in the header sets the active year (asked once, on the first game opened, then saved).
`site/progress.js` reads and writes the saved state (`amc.state`); the Flutter builds read the same key, so keep
`overlay/common/lib/web_product/web_state_model.dart` and `progress.js` in step. Tests: `node site/progress.test.js`
and, in a Craft build, `overlay/craft/test/web_state_test.dart` and `web_shell_test.dart` (copied in by `build_game.sh`).

`scripts/make_catalog.py` writes `catalog.json` (format 2) at deploy time from the app checkouts: `games` (one entry per
Mind game in a Mind app's `lib/ui/game_registry.dart`, one per free minigame in a Craft app's `minigames.json`),
`craft` (the Craft apps with their year band) and `years` (the topics of each year in teaching order, Maths then
English, merged over all Craft apps). Links: `<slug>/#/play/<gameId>[/<subject>/<year>/<topic>]` (Craft game),
`<slug>/#/learn[/<subject>/<year>/<topic>]` (Learn, the Quick quiz for now; `#/quiz/...` still works as the old name),
`<slug>/#/game/<id>` (Mind game). `topic` may be `all` for a mixed round; a link without a year or topic uses the saved
year and the first topic not marked known.

Every Craft game plays every year and topic: `build_game.sh` runs `scripts/merge_craft_content.py`, which copies the free
packs and topics of the other Craft apps into the temporary copy of the app (nothing is committed here; the checkouts are
never changed). A game with too few questions for a topic says so and proposes the games that can run it (never the Quick quiz). Below the games it adds "This game plays these topics": the same year's topics this game can run (its own `canPlay` check per topic over the pool; Maths then English, teaching order), each a keyboard-focusable link that opens this game on that topic; none = only the games (U2 item 3).

Inside a game the thin bar (`overlay/common/.../web_rules.dart`, `web_bar.dart`) has Year, Game, Topic, "I know this", Learn
and Rules. A topic is new, practising or known; known applies in every game, is reached by a 5-question check (4 right to
pass) and can be undone. When every topic of the year is known the game offers the next year. The card art in
`site/art/` is the studio's own icon set (from game-factory `design/game_art`, original work, see its README). Every game
opens with a how-to-play dialog the first time in a browser (`overlay/common`), and a Rules button brings it back.

## How-to-play text

The text of every game's how-to-play dialog is the apps' own: `scripts/sync_rules.py --apps <folder with the app checkouts>` reads each app's catalogue (`lib/core/rules/game_rules.dart` in the Mind hubs, `game_core/lib/engine/minigames/how_to_play_catalogue.dart` in game-factory for the Craft apps, found through `--factory`, default `../game-factory`) and writes `overlay/common/lib/web_product/web_rules_data.dart`. Run it after an app's text changes and commit the generated file; never edit that file by hand.

## How a commit reaches the site

This repo has no workflows and no secrets (it is public). `ya-spark/game-studio` holds the deploy: when the `games-web`
pin, or the pin of a web game's app repo, moves on its `main`, the `deploy-games-web` workflow there rebuilds every live
game that is behind (it compares each game's `build-info.json` on the site with `main`) and swaps it into the
`games-web` container on the VPS. Each game's `build-info.json` and the index at `/games/` show the commits that are running.

## Status (2026-11-15)
- `ember` (Mind family): builds; the game list shows the new icons; Sudoku plays.
- `scout` (Craft family): builds; year, subject and topic pickers in the teaching order of `topics.yaml`; a topic or a mixed
  round runs the Quick quiz on an empty anonymous progress with all built-in starter packs open.
- Superseded by W6 (2026-11-21): the browser now keeps the small state described above.
- Not done yet: `presto`, `ranger`, `champion` (same overlays, not built or looked at yet), the minigames of the Craft apps beyond
  the Quick quiz, the public landing page, the ad slot, the build-and-publish workflow and the hosting container.

## factory.ref
`factory.ref` holds the game-factory commit that every web build uses for `game_core` and the shared games. `scripts/build_game.sh` rewrites the game-factory refs in its temporary copy of the app's `pubspec.yaml` (the app checkout and its pin stay as they are), and `build-info.json` reports it as `gamesCommit`. Move it with each game-factory change the web should have; it must be a commit on game-factory `main`.
