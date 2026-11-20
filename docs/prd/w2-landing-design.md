# W2 Landing page: design note

For the frontend agent. Implements `docs/prd/w2-landing.md` in `site/index.html` (inline CSS and JS, no framework, no external assets). Catalog fields used: `id`, `kind` (`fun`/`learn`), `title`, `gameId`, `art`, `from`, `link`, and for Learn `subject`, `year` (0 = Foundation), `topic`, `items`, `game`.

Must not miss:
1. Never write age, kid(s), parent(s), teacher(s), "age band" anywhere in the file (also in comments, aria text, meta description).
2. Art SVGs are already rounded squares with their own gradient. Do not put them in another coloured box; tint the TILE behind/around them (see Art).
3. No emoji. Every icon is inline SVG from the list below, `aria-hidden="true"`, `currentColor`.
4. Text via `textContent` only. Storage only `amc.theme`, `amc.recent`, always in try/catch.
5. A state is never colour alone: selected chips get a check icon plus filled style, not just a hue.

## 1. Colour tokens

Define on `:root` (light default), override in `@media (prefers-color-scheme: dark)` for `:root:not([data-theme="light"])`, and `:root[data-theme="dark"]`. Dark is the designed-first look. Ratios are against the stated background (computed, WCAG relative luminance).

| Token | Dark | Light | Use |
|---|---|---|---|
| `--bg` | #0B1020 | #F4F6FC | page |
| `--surface` | #151C33 | #FFFFFF | tiles, inputs |
| `--surface-2` | #1E2745 | #E9EDF8 | chips idle, hover, skeleton |
| `--line` | #35416A | #C3CBE0 | borders (3:1 vs bg for input edges) |
| `--ink` | #EEF2FF | #151B2E | text (dark 15:1 on bg, 13:1 on surface; light 16:1) |
| `--muted` | #A9B4D0 | #4A5470 | secondary text (dark 8.1:1 on surface; light 7.5:1 on white, 6.9:1 on bg) |
| `--accent` | #7AB2FF | #1D5FD1 | primary buttons, selected chip fill |
| `--accent-ink` | #0B1020 | #FFFFFF | text on accent (8.8:1 dark; 5.8:1 light) |
| `--focus` | #FFC24D | #12388F | focus ring, 3px (more than 3:1 on every surface above) |
| `--maths` | #FFB020 | #B45309 | maths tile band, icon stroke |
| `--english` | #B79CFF | #6D3FD0 | english tile band, icon stroke |
| `--shadow` | 0 6px 18px rgba(0,0,0,.35) | 0 4px 14px rgba(21,27,46,.12) | tiles |

Fun tile tints (fixed palette of 6, picked by a stable hash of `gameId` mod 6): `#FF6B5E, #2CD3B0, #4DB6FF, #FF7AC3, #9BD93C, #6C7CFF`. Apply as a 100% tile-top wash: `background: linear-gradient(180deg, color-mix(in srgb, TINT 22%, var(--surface)) 0, var(--surface) 70%)`. If `color-mix` is a worry, use the same tints as `rgba(r,g,b,.22)` overlays over `--surface`. Text on a wash stays `--ink`, so contrast is unchanged (at least 12:1). In light theme use alpha .16.

Maths tiles use `--maths`, English tiles `--english`, as a 6 px top bar plus the subject icon coloured with the token (icon sits next to a visible text label, so colour is never alone). Light-theme `--maths` and `--english` on white are 5.0:1 and 6.2:1 (icon, large). Text never uses them.

Hero gradient (decoration only, no text contrast depends on it): dark `radial-gradient(900px 400px at 20% -10%, #25346B 0, transparent 70%)` over `--bg`; light `radial-gradient(900px 400px at 20% -10%, #D6E4FF 0, transparent 70%)`.

## 2. Type scale (system font stack as today, no web fonts)

`font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`. Use `rem` throughout so 200% zoom reflows.

| Role | Size | Weight | Notes |
|---|---|---|---|
| Hero headline | clamp(1.9rem, 6vw, 3rem) / 1.1 | 800 | letter-spacing -0.02em |
| Section heading (h2) | 1.4rem / 1.2 | 800 | icon 24px left |
| Big button | 1.2rem | 700 | |
| Tile title | 1.05rem / 1.25 | 700 | max 2 lines, `overflow-wrap:anywhere` |
| Body, chip, input | 1rem | 600 for chips | |
| Meta ("from Mind Ember", "12 items") | 0.875rem | 500 | `--muted` |

Never go below 0.875rem. No uppercase tracking labels (the old legend style) except none.

## 3. Spacing, shape, targets

- Spacing scale: 4, 8, 12, 16, 24, 32, 48 px. Page gutter 16 px (320 and 768), 24 px at 1280. Content max-width 1120 px, centred.
- Section gap 32 px (48 px at 1280). Heading to content 12 px.
- Radius: tiles 20 px, chips and buttons 999px or 16px as noted, inputs 14 px.
- Touch targets: all controls at least 44x44; hero buttons 56 px high minimum, 64 px on 1280; year chips 48 px high, min-width 48; spacing between adjacent targets at least 8 px.
- Tile sizes (reserve with `aspect-ratio`/fixed `min-height` so no layout shift):
  - Play tile: art 120 px (below 768) and 144 px (768 and up, 160 px at 1280 wide). Tile width on phone scroll row 160 px, min-height 224 px; in grid `repeat(auto-fill, minmax(184px, 1fr))`, min-height 248 px. Contents stacked centred: art, title, "from X".
  - Recent tile: horizontal, 72 px art 56, min-height 80 px. Phone: scroll-snap row, tile width 232 px. 768+: grid `auto-fill minmax(260px, 1fr)`, 3 per row at 1280.
  - Topic tile (Learn): horizontal, min-height 96 px, art 56 px, grid `auto-fill minmax(260px, 1fr)`; phone one column.
  - Skeleton tiles use the same sizes.

## 4. Layout per section

Order: header, hero, Recent, Play, Learn, More filters, footer. Search results replace Recent/Play/Learn/More filters while the box has text (hero stays).

### Header (sticky at 768+, static on phone, 64 px high)
- 320: row 1 wordmark (left) and theme toggle (right, 48x48). Row 2 full-width search (48 px high). Sticky is off on phones to save height.
- 768 and 1280: single row: wordmark, search (flex 1, max 480 px, centred), theme toggle. Solid `--bg` at 92% plus a 1 px `--line` bottom border (no blur needed).
- Wordmark: a single JS/HTML constant `WORDMARK = "Active Mind Craft"`, 1.15rem weight 800, small inline spark icon before it, links to `./`.
- Search: `<input type="search">` with leading magnifier icon, visible label "Search games and topics" (visually hidden label is fine, placeholder is the same text), clear button (x icon, 44x44) shown only when text exists.
- Theme toggle: one button, icon shows what you will switch to (sun in dark, moon in light), `aria-label` "Switch to light theme" / "Switch to dark theme". Cycle: explicit choice only (system default until first press), saved to `amc.theme` as `light` or `dark`.

### Hero
- Headline: "What shall we play today?" with sub line "Pick a game, or practise maths and English." (one line each).
- Four buttons: **Play**, **Maths**, **English**, **Surprise me**; icon left, label right. Same visual weight; Play is filled `--accent`, the rest are `--surface` with a 2 px `--line` border, Surprise me has a dashed-free solid border and the shuffle icon.
- 320: 2x2 grid, each 56 px high, full column width. 768: one row of four, 64 px high. 1280: row, buttons min 200 px wide, 64 px high, hero padding 48 px 0.
- Behaviour: Play scrolls to `#play` heading and moves focus to it (`tabindex="-1"`). Maths/English set `subject`, scroll to `#learn`, focus its heading; if no year is chosen the Pick a year state shows. Surprise me opens a random Fun game or a random Quick quiz topic (50/50) via `location.href = link` and records it in Recent.

### Pick up where you left off (Recent)
- Heading with clock icon, "Clear" text button on the right (min 44 px high, underline on focus/hover, `aria-label` "Clear recent games").
- Phone: scroll-snap row (`scroll-snap-type: x mandatory`, tiles `scroll-snap-align: start`, `scroll-padding-inline: 16px`), bleed to the screen edges. 768+: wrapping grid, 6 max.
- Tile: art 56, title, meta ("from Mind Ember" for Fun; "Maths, Year 3" for Learn).
- Hidden entirely (no heading, no space) when empty.

### Play shelf
- `<section id="play">`, heading with gamepad icon "Play".
- Phone: scroll-snap row, tile 160 px wide, a partly visible next tile as a scroll hint. Row has `tabindex="0"`, `role="region"`, `aria-label="Play games, scroll sideways"` only if it overflows. Hide scrollbar visually is NOT allowed (keep thin default scrollbar).
- 768: wrapping grid, 4 to 5 per row. 1280: 6 per row, 12 tiles = 2 rows.
- Tile: tinted wash, art centred (120/144/160), title (bold), "from Mind Ember" (muted). Whole tile is one `<a>`; accessible name "Snake, from Mind Presto".

### Learn
- `<section id="learn">`, heading with book icon "Learn".
- Row 1, label "Year": chips in a wrapping flex (gap 8). Chip text: "Foundation", then "Year 1" to "Year 12" (only years in the catalog, sorted ascending, 0 first). Chips are `<button aria-pressed>`; selected = filled `--accent` plus leading check icon. 320: wraps to 3 per row; 1280: all on one or two lines. No horizontal scrolling for chips.
- Row 2, label "Subject": segmented control of three buttons, each at least 48 px high: Maths (calculator icon), English (book-letter icon), Both (two-dot icon). Default Both. Selected state: filled `--accent` plus check icon, `aria-pressed`. Full width on 320 (three equal columns, icons above labels allowed at under 360 px).
- Results area (`aria-live="polite"` region announcing "12 topics for Year 3, Maths"):
  - No year: Pick a year state (below).
  - Year chosen: topic tiles grouped under "Maths" and "English" sub-headings when Both; sorted by title. Tile: subject icon (coloured, 28 px) plus a 6 px top bar in subject colour, title, meta line "Year 3 . 24 items" (use a real middle dot `·`, with `items` from the catalog; "1 item" singular; hide the count if 0 or missing).
  - If the "Game" select (More filters) is set to a minigame: tiles become minigame cards (art 56 from `art`, title, meta "Maths, Year 3 · Fraction pairs"), same grid.
- Cap displayed topic tiles at 60 with "Show more" like search; normally a year has fewer.

### More filters
- `<details>` with summary "More filters" (sliders icon, chevron rotated by state, summary min-height 48). Inside: Topic select, Game select, Clear filters button, in a wrapping row (selects full width at 320, 220 px at 768+). Labels visible above each select. Same logic as the current page. Closed by default, but open automatically when `topic` or `game` come from the URL.

### Footer
- One line, centred, muted, with a small lock-free shield-less icon (use the "device" icon): "This device remembers your recent games and settings. Nothing is sent anywhere, and there is no account."
- 48 px top padding, 40 px bottom.

## 5. States

| State | Look and copy |
|---|---|
| Loading | Skeleton tiles (6 in Play, no Learn skeleton) in `--surface-2`, same sizes. Hero and header render immediately. Shimmer only when motion is allowed (see section 9). `aria-busy="true"` on the main region. |
| Load error | Card with warning icon: "The game list could not be loaded." plus button "Try again" (re-fetch). |
| Empty catalog (zero cards) | No crash. Play section shows: "No games are listed yet. Please check back soon." Learn shows the same line. Hero buttons stay but Surprise me is disabled. |
| Recent, none | Section absent. |
| Pick a year (no year chosen) | A soft panel (`--surface`, dashed 2 px `--line` border, radius 20, 32 px padding): calendar icon 48 px, heading "Pick a year", line "Choose a year above to see maths and English topics." Chips sit above it, so no extra button. |
| Year chosen, no topics for subject | "No topics here yet. Try Both, or another year." plus a button "Show both" if subject is not Both. |
| Search empty | Panel with magnifier icon: "No games match" and line "Try a shorter word, like snake or fractions." plus button "Clear search". |
| Search results | Heading "Results" with live count "14 results for snake" (`role="status"`). Cap 60 then button "Show more" (adds 60 more; focus stays on the button position by moving focus to the first new tile). Fun and Learn results mixed, Fun first, each tile shows a small text tag "Play" or "Learn" with its icon. |
| Hover (pointer only, in `@media (hover:hover)`) | Tile lifts 2 px, border becomes `--accent`, shadow stronger. Buttons: background to `--surface-2`. |
| Pressed | `transform: scale(.98)` plus darker background (`--surface-2`). Same on touch via `:active`. |
| Focus (`:focus-visible`) | 3 px solid `--focus`, 3 px offset, on every interactive element, including tiles (ring follows the 20 px radius), chips, selects, summary, scroll rows. Never `outline: none` without replacement. |
| Selected | Filled accent plus check icon. |
| Disabled | `opacity .55`, `cursor: not-allowed`, `aria-disabled`/`disabled`, still readable (muted text keeps 4.5:1 on the dimmed surface because the label stays `--ink` at that opacity: verify, otherwise use `--muted` without opacity). Used for: Surprise me with empty catalog, Topic/Game selects with no options. |

## 6. Icon list (inline SVG, 24x24 viewBox, `fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"`)

Define once in a hidden `<svg>` sprite of `<symbol>` elements and reference with `<use href="#i-name">` (same document, so no external request). Names: `i-spark` (wordmark: 4-point star), `i-search` (circle plus handle), `i-x` (clear), `i-sun`, `i-moon`, `i-play` (rounded triangle in rounded square outline) , `i-gamepad`, `i-calc` (rounded rect with plus and minus), `i-book` (open book), `i-both` (two overlapping circles), `i-shuffle` (two crossing arrows), `i-clock` (circle with hands), `i-calendar`, `i-sliders` (three lines with knobs), `i-chevron`, `i-check`, `i-warning` (triangle with bar), `i-device` (phone outline), `i-refresh`. Icons next to text are 24 px (28 px in hero buttons and Learn subject), empty-state icons 48 px. All `aria-hidden="true" focusable="false"`.

## 7. Art tile treatment

- Art served from `_site/art/<art>.svg` (unchanged path), `<img alt="" width height loading="lazy" decoding="async">` with explicit size per breakpoint to avoid shift. The SVGs are vector (96 viewBox, rounded 24 radius) and stay sharp at 160 px.
- Tile wash per section 1; art gets a soft drop shadow `0 6px 14px rgba(0,0,0,.25)` (dark) / `.15` (light) and no extra border or padding.
- Learn topic tiles show no per-game art: use the subject icon on a 56 px rounded square filled with 18% `--maths` / `--english` over `--surface`. Minigame cards use the game's art at 56.
- Check in the browser that every `art` file looks good at 120 to 160 px; fix any ugly ones in `site/art/` only (simple original shapes, no people). Known good: `quick_quiz` (white speech bubble on coral), `snake` (green snake and apple).

## 8. Copy (final strings, en-AU)

- Title: "Active Mind Craft games". Meta description: "Free games to play, and maths and English practice for every year. Open a game and start in one click."
- Wordmark: "Active Mind Craft".
- Hero: "What shall we play today?" / "Pick a game, or practise maths and English." Buttons: "Play", "Maths", "English", "Surprise me".
- Search label/placeholder: "Search games and topics"; clear button aria-label "Clear search".
- Theme toggle aria-labels: "Switch to light theme", "Switch to dark theme".
- Recent: "Pick up where you left off", link "Clear".
- Play: "Play"; tile meta "from Mind Ember" (use `from` from the catalog).
- Learn: "Learn"; labels "Year", "Subject"; chips "Foundation", "Year 1" ...; subject "Maths", "English", "Both".
- Learn meta: "Year 3 · 24 items", "Year 3 · 1 item".
- More filters: summary "More filters"; labels "Topic", "Game"; selects "Any topic", "Any game"; button "Clear filters".
- Pick a year panel: "Pick a year" / "Choose a year above to see maths and English topics."
- Announcements: "{n} topics for {Year 3 or Foundation}, {Maths|English|Maths and English}"; "{n} results for {query}".
- Search empty: "No games match" / "Try a shorter word, like snake or fractions." / button "Clear search". Show more: "Show more".
- Errors: "The game list could not be loaded." / "Try again". Empty catalog: "No games are listed yet. Please check back soon."
- Noscript: "This page needs JavaScript to list the games."
- Footer: "This device remembers your recent games and settings. Nothing is sent anywhere, and there is no account."
- Tile aria-labels: Fun "Snake, from Mind Presto"; Learn "Fractions, Maths, Year 3, 24 items"; Recent same as source tile.

## 9. Motion and reduced motion

- Allowed (when no preference): tile hover lift and press scale (120 ms ease-out), chip and button colour change (120 ms), details chevron rotate (150 ms), skeleton shimmer (1.6 s linear, a slow opacity pulse between .6 and 1, never a flash), smooth scroll for hero jumps.
- `@media (prefers-reduced-motion: reduce)`: `*,*::before,*::after { animation: none !important; transition: none !important; scroll-behavior: auto !important; }` and no `transform` on hover/press (use border and background change only). Skeleton stays static.
- No autoplay, no flashing, no sound, no parallax.

## 10. Keyboard and accessibility

- Landmarks: `<header>`, `<main>`, `<footer>`; first focusable element is a "Skip to games" link (visible on focus) targeting `#main`. One `<h1>` (hero headline), h2 per section, h3 for Maths/English sub-groups.
- Tab order follows visual order: skip link, wordmark, search, theme toggle, hero buttons, Recent (tiles then Clear), Play tiles, year chips, subject buttons, topic tiles, More filters. Roving tabindex is NOT used: chips and segmented buttons are plain buttons in tab order (13 chips is acceptable) with `aria-pressed`; Enter/Space activate.
- Search: Escape clears the text and keeps focus in the input; typing is debounced 80 ms; results region has `role="status"` count.
- Hero jump buttons move focus to the target heading (`tabindex="-1"`) so screen readers and keyboard users land there.
- Scroll rows (phone): focusable tiles scroll into view on focus (browser default); no keyboard trap.
- Every tile is a single link with a full accessible name; do not nest buttons in links. Images `alt=""`.
- Language on a changed region is not needed (all en-AU). Text spacing and 200% zoom: no fixed heights on text containers (use `min-height`), no horizontal scroll at 320 px, tiles reflow to one column.
- Colour independence: selected, current, disabled and error states always also change an icon, weight or border style, not only hue.
- Targets 44 px minimum (section 3); pointer cursor on tiles only.
- URL: update with `history.replaceState` for `type`, `year`, `topic`, `game`, `q`, `subject` (omit defaults: subject Both, empty values); search typing uses `replaceState`, not new history entries.
- Target Lighthouse accessibility 95 or more. Test the focus ring in both themes and with forced-colors (use `outline: 3px solid` so it still shows; add `@media (forced-colors: active)` borders on tiles and chips: `border: 2px solid ButtonText`, selected `Highlight`).

## 11. Feel for a 5-year-old and a 16-year-old

- Big art, big hit areas, one icon per label and very short words serve the youngest; the dark navy base, tight type scale, restrained accents and no mascot or cartoon frames keep it from looking babyish. Do not add exclamation marks, speech bubbles or characters. No confetti or celebratory animation.
