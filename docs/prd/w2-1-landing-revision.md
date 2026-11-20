# W2.1 Landing page revision (Kahoot-style structure)

Authoritative spec: `/home/track/pro/game-studio/docs/FEATURE-SPECS.md` item W2.1 (builds on W2, see `docs/prd/w2-landing.md` and `docs/prd/w2-landing-design.md`), plus `docs/decisions/web.md` "Web landing page". Owner decisions of 2026-11-21 override the older W2 text where they differ.

## Goal
Restructure the W2 page in the working tree (`site/index.html`, uncommitted) into a colourful game-portal pattern: sticky top bar, Jump in row, themed sideways shelves with large illustrated tiles. Our own colours, wording and hand-drawn art; copy nothing from the reference.

## User-visible behaviour
- Sticky top bar, always visible. Order (LEARN FIRST): wordmark, Maths, English, Play, Recent (hidden or disabled until a recent game exists), Surprise me, wide search box, theme toggle. Each button has its own accent colour AND an inline SVG icon, a short tooltip on hover and focus. Buttons scroll to or open their section (Maths/English set subject and scroll to Learn). Phones: buttons become a horizontally scrolling row under wordmark and search, 44 px min targets.
- Headline: one large bold line plus one calm sentence, audience-neutral.
- Jump in row: colour-block cards with one clear button each: Surprise me, Continue (last recent, only when one exists), Quick quiz (random Maths or English Quick quiz), optional Today's pick (game chosen by date, no server). Sideways row, arrows on desktop, swipe on phones.
- Page order below the bar (Learn before Play): Jump in, Pick up where you left off (hidden when empty, Clear link), Learn (year chips, then Maths and English shelves; "Pick a year" state until chosen), Puzzles (block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge), Arcade (wingy, snake, bricks, stack, runner), More games (any Fun gameId not listed, so none is lost), Games for your topics (Craft minigames, only when the Game filter is used).
- Every Fun game appears in exactly one shelf. Grouping is a constant map keyed by `gameId` inside `index.html`.
- Shelf: label and one-line caption on the left, sideways scroll-snap row of large tiles (160 to 220 px wide) with prev/next arrow buttons, keyboard reachable.
- Tiles: art fills the tile, title, small type badge (Play, Maths, English) plus year on Learn tiles. No "Free" badge. Maths and English subject tiles show the word as real HTML text in a dark rounded pill over the lower part of the art.
- Kept from W2: year chips, search (replaces shelves while text present), collapsed More filters, URL params (`type`, `year`, `topic`, `game`, `q`, `subject`), footer line, recents logic.
- Colour: bold coloured top bar (deep navy or violet, not the reference's purple), light body default, dark via system setting and toggle. Fixed small accent palette per top-bar button and subject. Contrast 4.5:1.
- Ad slot: leave one clean, empty, unobtrusive container between shelves (for example after the Learn block) with a comment marking it. Add no ad code, no network.

## Art (hand-drawn original SVG; NO AI generation, NO Figma generation)
- `site/art/tile-<gameId>.svg` for the 12 Fun games: block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge, wingy, snake, bricks, stack, runner. Plus `tile-maths.svg` and `tile-english.svg`.
- 400x300 viewBox, bold flat shapes, rounded corners, few vivid palette colours, no people, no text or lettering, no raster, no external refs, no script, about 6 KB or less each.
- `site/art/LICENSES.md`: every file original work made for the studio.
- Names stable (owner's Figma art replaces them later by name). Existing small icons `site/art/<art>.svg` stay. If a tile fails to load, fall back to the small icon on a coloured tile (`onerror` handler set via JS, never a broken image).
- Check each at 200 px and 56 px wide.

## Scope and non-goals
In: `site/index.html`, `site/art/`. Out: apps, game-factory, overlay/, deploy workflow, make_catalog.py, favourites, accounts, analytics, ads, any backend. Do not commit or push. games-web is PUBLIC: no secrets.

## Constraints (unchanged from W2)
Never name an age, kids, parents, teachers, curriculum or Australia anywhere in the file (copy, comments, aria, meta). Australian spelling. No people in art. Single static file, inline CSS/JS, no framework, no network beyond same-origin `catalog.json`. localStorage only `amc.recent`, `amc.theme`, in try/catch. textContent for catalog data. Visible focus, keyboard, reduced motion removes animation, 200 percent text, 320 px to wide desktop.

## Tasks
- ui-design-agent: design note `docs/prd/w2-1-landing-design.md` (top bar, Jump in cards, shelves and arrows, tile anatomy, palette, light/dark tokens, mobile behaviour, art style guide and per-tile motif list).
- frontend-agent: art files, LICENSES.md, and `site/index.html` rewrite following the note.
- backend-agent: none.

## Acceptance criteria
- Top bar stays visible on scroll at 360, 768, 1280 px, Learn-first order.
- Every shelf scrolls by arrow, swipe and keyboard.
- Every Fun game in exactly one shelf; Surprise me, Continue, Quick quiz open working games.
- All 14 tile files load with no broken image; look right at 200 and 56 px; fallback works.
- Any Fun game one click away; Learn topic at most three clicks.
- No age or audience wording; deep links still work; recents and theme persist; works with storage blocked.
- Lighthouse accessibility 95 or more.

## Risks
- Hand-drawn art quality: keep motifs simple and recognisable; the owner may replace in Figma.
- Light default vs W2 dark-first tokens: both themes need re-checking for contrast.
- Sticky bar plus anchor scrolling needs scroll-margin-top.
