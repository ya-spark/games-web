# W2 Landing page redesign

Authoritative spec: `/home/track/pro/game-studio/docs/FEATURE-SPECS.md` item W2, and `docs/decisions/web.md` section "Web landing page". This PRD only restates and slices it.

## Goal
Replace the W1a landing page (filter bar plus flat grid) with a modern page where a visitor reaches a game in one click. One static file `site/index.html`, no framework, same `catalog.json`, same card `link` values and URL parameters.

## User-visible behaviour
- Audience-neutral: never write age, kids, parents, teachers, "age band". Copy is short: Play, Maths, English, Pick up where you left off.
- Header: text wordmark "Active Mind Craft" (single constant, easy to swap), theme toggle (system default, manual choice remembered), search box.
- Hero: short headline, big buttons Play (scroll to Play shelf), Maths, English (jump to Learn with subject set), Surprise me (random Fun game or random Quick quiz topic, opens its link).
- Recent ("Pick up where you left off"): last 6 opened cards, newest first, no duplicates, hidden when empty, "Clear" link. Recorded on card click.
- Play shelf: one big tile per Fun game (art 120 to 160 px, title, "from <app>"). Wrapping grid on desktop, scroll-snap row on phones.
- Learn: year chips (from catalog, Foundation = 0, only years with content), Maths / English / Both toggle, topic tiles for chosen year and subject. No year chosen: friendly "Pick a year" state, no tile dump. Tiles: title, subject icon, year, item count. Quick quiz default; Game select switches to minigame cards.
- More filters (collapsed `<details>`): Topic and Game selects, Clear. Same logic as today.
- Search: instant, matches titles, subject, "year 3", "foundation", game names; replaces shelves while text present; clear button; empty state "No games match"; cap about 60 with "Show more".
- Footer: one calm line: this device remembers recent games and settings, nothing sent anywhere, no account.
- URL: keep `type`, `year`, `topic`, `game`; add `q`, `subject`. Link with params shows same view.

## Scope / non-goals
In: `site/index.html` (and new art under `site/art/` only if needed). Out: apps, game-factory, `overlay/`, deploy workflow, `make_catalog.py` (no change needed), favourites (later), accounts, network calls other than the existing same-origin `catalog.json` fetch. Do not add anything to games-web that is secret or private (repo is public).

## UI notes
Dark-first deep navy, vivid accents, rounded shapes, soft depth; light theme via `prefers-color-scheme` plus `data-theme` toggle. Touch targets 44 px min, main buttons 56 px+. Icon beside every label (inline SVG or emoji-free inline icons). Hover/press feedback gentle; `prefers-reduced-motion` removes all animation; no flashing, no sound. Contrast 4.5:1, never colour alone, visible focus ring, full keyboard, 200 percent text, 320 px to wide desktop. Design note from ui-design-agent: `docs/prd/w2-landing-design.md`.

## Frontend tasks (frontend-agent)
1. Rewrite `site/index.html` following the design note.
2. localStorage only, keys prefixed `amc.` (`amc.theme`, `amc.recent`), every access in try/catch; page works when storage is blocked.
3. Build DOM with textContent (no innerHTML with catalog data). Art path stays `_site/art/<art>.svg`.

## Backend tasks
None expected.

## Acceptance criteria
- No mention of age, kids, parents, teachers anywhere in the file.
- All 12 Fun games appear on the Play shelf; Learn tiles appear only after a year (or search/URL) selects them.
- Old deep links (`?type=learn&year=3&topic=...&game=...`) still render the same selection; new `q`, `subject` work.
- Recent: reopening moves to front, max 6, Clear works, hidden when empty, survives reload, no errors when storage is blocked.
- Theme toggle remembered; reduced-motion removes animation; keyboard-only use works; no horizontal scroll at 320 px.
- Card `link` values and `catalog.json` untouched; no external requests.

## Risks
- Minigame cards (many) flooding Learn: keep them behind the Game select.
- Catalog sizes (about 700 learn cards): render only the chosen year/subject or capped search results.
- Wordmark text, colour feel and favourites are owner questions.
