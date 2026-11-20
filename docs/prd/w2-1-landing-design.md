# W2.1 Landing page revision: design note

For the frontend agent. Implements `docs/prd/w2-1-landing-revision.md` in `site/index.html` (inline CSS and JS, no framework, no network beyond `catalog.json`) and `site/art/`. Reuses the W2 page and `docs/prd/w2-landing-design.md` where this note says "as W2". Where they differ, this note wins. Catalog fields are unchanged (`id`, `kind`, `title`, `gameId`, `art`, `from`, `link`, and for Learn `subject`, `year` (0 = Foundation), `topic`, `items`, `game`).

## 0. Must not miss

1. The words age, kid(s), parent(s), teacher(s), curriculum and Australia never appear anywhere in `index.html` (copy, comments, aria text, meta, title). Australian spelling (practise as a verb, colour, maths).
2. No emoji. Icons are inline SVG in the hidden `<symbol>` sprite, `aria-hidden="true"`, `currentColor`.
3. Text from the catalog via `textContent` only. Storage only `amc.recent` and `amc.theme`, in try/catch.
4. The top bar is navy in BOTH themes. The accent fills (section 1.2) are fixed in both themes and always carry navy text `#101A44`, never white.
5. Focus ring colour differs by place (section 1.3): amber on the bar, navy on the Jump in cards, `--focus` elsewhere. Using `--focus` on the bar or on the cards fails contrast.
6. Sticky bar height changes with breakpoint, so every anchor target needs `scroll-margin-top` and `html` needs `scroll-padding-top` from `--bar-h` (section 3.6). Focus must never land under the bar.
7. Do not draw any lettering or numerals in art. Maths and English words are HTML pills (section 7.3). Keep Maths/English art motifs inside the upper 180 units so the pill never covers them.
8. Scroller arrows use `aria-disabled`, not `disabled`, so keyboard focus is not dropped at the ends.
9. Tile art is `_site/art/tile-<gameId>.svg` (same `_site/art/` prefix W2 uses for small icons). If it fails to load, fall back as in section 6.5. Never show a broken image.

## 1. Colour tokens

### 1.1 Page tokens (light is the default)

`:root` is light; override in `@media (prefers-color-scheme: dark)` for `:root:not([data-theme="light"])` and in `:root[data-theme="dark"]`, exactly as the W2 page does. Keep the W2 values for these (ratios already computed there):

| Token | Light | Dark | Notes |
|---|---|---|---|
| `--bg` | #F4F6FC | #0B1020 | page |
| `--surface` | #FFFFFF | #151C33 | tiles, inputs |
| `--surface-2` | #E9EDF8 | #1E2745 | chips, hover, skeleton |
| `--line` | #C3CBE0 | #35416A | borders |
| `--ink` | #151B2E | #EEF2FF | text: light 16:1 on bg, dark 15:1 on bg |
| `--muted` | #4A5470 | #A9B4D0 | light 6.9:1 on bg and 7.5:1 on surface; dark 9.1:1 on bg and 8.1:1 on surface |
| `--accent` | #1D5FD1 | #7AB2FF | chips selected, links; `--accent-ink` #FFFFFF (5.8:1) / #0B1020 (8.8:1) |
| `--focus` | #12388F | #FFC24D | ring on page body: 9.8:1 on light bg, 11.8:1 on dark bg |
| `--shadow` | 0 4px 14px rgba(21,27,46,.12) | 0 6px 18px rgba(0,0,0,.35) | tiles |
| `--shadow-up` | 0 8px 22px rgba(21,27,46,.18) | 0 10px 26px rgba(0,0,0,.5) | hover |

Remove the W2 `--maths`, `--english`, `--wash` tokens and the six-hue `TINTS` wash on Play tiles (the art now fills the tile). Keep `TINTS` only for the fallback tile (section 6.5).

New tokens:

| Token | Light | Dark | Use |
|---|---|---|---|
| `--bar` | #101A44 | #101A44 | top bar (same in both) |
| `--bar-ink` | #FFFFFF | #FFFFFF | wordmark and bar icons: 16.7:1 on bar |
| `--bar-focus` | #FFC24D | #FFC24D | ring on bar: 10.4:1 on bar |
| `--bar-field` | #FFFFFF | #1E2745 | search field fill |
| `--bar-field-line` | #7C8FD6 | #7C8FD6 | search field and theme button border: 5.4:1 on bar |
| `--tip-bg` | #151B2E | #EEF2FF | tooltip fill |
| `--tip-ink` | #F4F6FC | #0B1020 | tooltip text: 16:1 light, 15:1 dark |
| `--on-fill` | #101A44 | #101A44 | text and icons on any accent fill |
| `--pill-bg` | rgba(16,26,68,.92) | rgba(16,26,68,.92) | subject word pill |

Bar separation: light adds `box-shadow: 0 2px 10px rgba(16,26,68,.28)`, dark adds `border-bottom: 1px solid #35416A`.

Search field text: `--ink` on `--bar-field` (light 16:1, dark 13:1). Placeholder `--muted` (light 7.5:1 on white, dark 7.1:1 on #1E2745). The field edge is `--bar-field-line` 2px.

### 1.2 Accent palette (fixed, same in both themes)

Each is used as a button or badge fill with `--on-fill` (#101A44) text. Contrast is navy text on the fill (WCAG relative luminance, computed).

| Name | Hex | Where | Navy text on fill |
|---|---|---|---|
| Maths amber | #FFB020 | bar Maths, Maths badge, Maths art bg | 9.2:1 |
| English violet | #B79CFF | bar English, English badge, English art bg | 7.4:1 |
| Play teal | #2CD3B0 | bar Play, Play badge | 8.8:1 |
| Recent sky | #4DB6FF | bar Recent, Continue card | 7.5:1 |
| Surprise pink | #FF7AC3 | bar Surprise me, Surprise card | 7.0:1 |
| Quiz lime | #9BD93C | Quick quiz card | 9.9:1 |
| Today coral | #FF6B5E | Today's pick card | 6.0:1 |

Fills are never the only signal: every bar button and card has an icon and a text label.

### 1.3 Focus rings

- Default: `:focus-visible { outline: 3px solid var(--focus); outline-offset: 3px; }`.
- Inside `.top` (bar): `outline-color: var(--bar-focus)`.
- Inside `.jump-card` (button on a colour block): `outline-color: #101A44`. The ring sits on the card fill: 6.0:1 (coral), 7.0:1 (pink), 7.5:1 (sky), 9.9:1 (lime). Amber or `--focus` would fail on these fills in dark mode.
- Forced colours: `outline: 3px solid Highlight`, borders as W2.

Other contrast facts, for reference: white on the navy bar button/pill 16.7:1; white on the pill over the worst-case white art about 13.5:1; tile title `--ink` on `--surface` 16:1 light, 13:1 dark; tile meta `--muted` on `--surface` 7.5:1 light, 8.1:1 dark; Jump in card text navy on fill as in the table. The Jump in cards, coloured against the light body, have a boundary contrast below 3:1 (for example pink against #F4F6FC is 2.2:1), which is acceptable because each card's button is a navy block with a 7:1 or better edge and the card is not itself the control.

## 2. Type scale (system stack, rem units)

| Role | Size | Weight |
|---|---|---|
| H1 headline | clamp(1.9rem, 6vw, 3rem) / 1.1, letter-spacing -0.02em | 800 |
| Headline sentence | 1.1rem / 1.5, `--muted` | 500 |
| Section h2 (Learn, Play, Jump in, Pick up...) | 1.6rem / 1.2 | 800 |
| Shelf label (h3) | 1.2rem / 1.25 | 800 |
| Shelf caption | 0.95rem, `--muted` | 500 |
| Bar button label | 0.95rem (1rem at 1024+) | 800 |
| Card title | 1.25rem | 800 |
| Card sentence | 0.95rem | 500 |
| Card button | 1.05rem | 800 |
| Tile title | 1.05rem / 1.25 | 700 |
| Badge, meta | 0.875rem | 800 badge, 500 meta |
| Pill (subject word) | 1rem (1.1rem at 768+) | 800 |

Nothing under 0.875rem. No fixed heights on text containers (use `min-height`); 200 percent text must reflow.

## 3. Sticky top bar

### 3.1 Structure

```html
<header class="top" id="top">
  <div class="wrap bar">
    <a class="brand" href="./"><svg .../><span class="brand-text">Active Mind Craft</span></a>
    <div class="search" role="search"> ... </div>
    <button class="icon-btn" id="theme" ...></button>
    <nav class="actions" aria-label="Sections"> <!-- scroll row on narrow screens -->
      <button class="act maths" ...>, english, play, recent (hidden until a recent exists), surprise
    </nav>
  </div>
</header>
```

Decision: DOM order is wordmark, search, theme toggle, nav. This matches the visual order on narrow screens (row 1 wordmark, search, theme; row 2 nav). On 1024+ the single row uses CSS `order` (wordmark 0, nav 1, search 2, theme 3), so there tab order differs slightly from visual order; this is accepted. The Learn-first button order Maths, English, Play, Recent, Surprise me is the same in the DOM and visually.

`position: sticky; top: 0; z-index: 30` at all sizes. Background `--bar`, text `--bar-ink`.

### 3.2 Buttons (the `.act` elements)

Order and style, left to right: Maths, English, Play, Recent, Surprise me.

| Button | Fill | Icon | Tooltip text | Action |
|---|---|---|---|---|
| Maths | #FFB020 | `i-maths` | "Maths topics by year" | set subject maths, scroll to and focus `#learnH` |
| English | #B79CFF | `i-english` | "English topics by year" | set subject english, scroll to and focus `#learnH` |
| Play | #2CD3B0 | `i-gamepad` | "Puzzles and arcade games" | clear Learn/search filters that hide games, scroll to and focus `#playH` |
| Recent | #4DB6FF | `i-clock` | "Games you played lately" | scroll to and focus `#recentH`; hidden (`hidden` attribute, not just visually) while the recent list is empty |
| Surprise me | #FF7AC3 | `i-shuffle` | "Open a random game or quiz" | 50/50 random Fun game or random Quick quiz, as W2 |

Anatomy: `display:inline-flex; align-items:center; gap:8px; min-height:44px; padding:0 14px; border-radius:999px; border:0; background:<fill>; color:var(--on-fill); font-weight:800; white-space:nowrap`. Icon 22 px, label always visible (also on phones). Desktop 1024+: height 48, padding 0 16px, icon 24. Gap between buttons 8 px (touch targets never touch).

States:
- Hover (`@media (hover:hover)`): `filter: brightness(1.06)` and lift `translateY(-1px)`; navy text stays above 6:1 on the brighter fill.
- Pressed: `transform: scale(.97)`, `filter: brightness(.94)`.
- Current: Maths and English get `aria-pressed="true"` when `state.subject` matches; shown as a check icon after the label plus `box-shadow: 0 0 0 2px #FFFFFF` (white ring, 16.7:1 on bar). Play and Surprise me and Recent are plain buttons (no pressed state).
- Focus: ring per 1.3 (amber).
- Loading: all five render immediately but are `disabled` until the catalog loads, with the fill replaced by transparent, a 2px dashed `#7C8FD6` border and `#C9D2F5` text (11:1 on bar). Recent stays `hidden`.
- Empty catalog: Surprise me disabled in the same look.
- Reduced motion: no lift, no scale, no transition.

### 3.3 Wordmark, search, theme toggle

- Wordmark `WORDMARK = "Active Mind Craft"` (one JS constant, as W2), 1.15rem 800, spark icon 24 px in `#FFC24D` before it, link to `./`. Min target 44 px high.
- Search: as W2 but coloured for the bar. Height 48, radius 14, fill `--bar-field`, 2px `--bar-field-line` border, magnifier icon `--muted`, clear button 44x44 shown only with text. Visible label is the `sr`-only text "Search games and topics". Placeholder "Search games and topics" at 480+ and "Search" below 480 (set in JS from `matchMedia`; the label text stays the full phrase).
- Theme toggle: 48x48 (44 on phones), transparent fill, 2px `--bar-field-line` border, icon `--bar-ink`, radius 14. Icon shows what you switch to (sun in dark, moon in light), labels "Switch to light theme" / "Switch to dark theme". Hover fills `rgba(255,255,255,.12)`. Tooltip as for buttons, right-aligned.

### 3.4 Tooltips

Use a real element, not `title`: `<span class="tip" role="tooltip" id="tip-maths">Maths topics by year</span>` as the last child of each button's wrapper, with `aria-describedby` on the button.
- Shown on `:hover` (after 300 ms delay) and `:focus-visible` (no delay) of the button; hoverable (the tip is inside the hover area wrapper), and dismissible with Escape (JS adds a `dismissed` class until the next focus or hover).
- Look: `--tip-bg` fill, `--tip-ink` text, 0.875rem 600, padding 6px 10px, radius 10, max-width 220, below the button (`top: calc(100% + 8px)`), centred (`left:50%; transform:translateX(-50%)`); the theme toggle's tip is right-aligned (`right:0`).
- Hidden on `@media (hover:none)` and below 768 px: labels are visible there and touch has no hover, so skip them.
- Reduced motion: no fade (show/hide instantly). With motion: 120 ms opacity.
- The tip does not clip: the bar row on 1024+ is `overflow: visible`; the narrow scroll row has `overflow-x:auto`, which clips tips, which is another reason they are off below 768. At 768 to 1023 the nav fits without scrolling (it is about 590 px wide), so keep `overflow: visible` there and use scroll only below 768.

### 3.5 Layout by breakpoint

| Width | Layout | Height (`--bar-h`) |
|---|---|---|
| 320 and 360 (under 480) | Row 1: spark icon only (wordmark text visually hidden but kept as the link's accessible name), search `flex:1`, theme 44x44. Row 2: nav as horizontal scroll row. | 56 + 52 = 108 px |
| 480 to 767 (including 768 minus) | Row 1: wordmark with text, search `flex:1`, theme. Row 2: nav scroll row. | 108 px |
| 768 to 1023 | Same two rows; nav fits without scroll, left-aligned. | 108 px (reduce to 104 if padding trimmed) |
| 1024 and up (1280 designed) | Single row: wordmark, nav, search `flex:1 1 auto; max-width:420px; margin-left:auto`, theme. Gutters 24. | 64 px |

Nav scroll row (under 768): `display:flex; gap:8px; overflow-x:auto; scroll-snap-type:x proximity; scroll-padding-inline:16px; padding:2px 16px 6px; margin-inline:-16px; scrollbar-width:thin; scrollbar-color:#7C8FD6 transparent`. Buttons `scroll-snap-align:start; flex:none`. The cut-off third button is the hint that the row scrolls. At 360 the first two buttons and part of Play are visible.

Gutter 16 px (320 to 1023), 24 px at 1024+. The bar's inner `.wrap` max-width 1120 like the page, centred, but the navy background spans the full width.

### 3.6 Anchor offsets

Set `--bar-h` per the table, and also measure it in JS (`ResizeObserver` on `#top`, write `--bar-h` on `:root`) so text zoom changes are honoured. CSS: `html { scroll-padding-top: calc(var(--bar-h) + 12px); }` and `section, h2, h3 { scroll-margin-top: calc(var(--bar-h) + 16px); }`.

## 4. Headline

```
H1:       Build your mind, one game at a time.
Sentence: Practise maths and English by year, or jump straight into a puzzle or an arcade game.
```

Placement: directly under the bar, left-aligned in `.wrap`, padding 24 px 0 8 px (32 / 12 at 768, 40 / 16 at 1280). Background `--hero` radial gradient as W2 (decoration only). The sentence is `--muted`, max-width 60ch. No buttons here (the W2 hero buttons move into the bar and the Jump in row).

While the search box has text, the headline, Jump in and all shelves are hidden and only Results show (section 9).

## 5. Jump in row

`<section id="jump">`, h2 "Jump in" (bolt icon) with caption "Not sure where to start? Try one of these." Shelf anatomy as section 6 (header row with arrows, scroller), but with cards.

### 5.1 Cards

Size: width `min(264px, 82vw)` under 768, 280 px at 768 to 1279, 264 px at 1280 (four fit one row in 1120 px, so arrows hide when nothing overflows). Min-height 176. Radius 24. Padding 16 (20 at 768+). Fill is the accent colour (section 1.2), text `--on-fill` navy, no border, shadow `--shadow`. Layout column: icon badge (a 48 px circle in `rgba(16,26,68,.12)` with a navy icon 28 px), title (h3), one sentence, then the button pinned to the bottom (`margin-top:auto`).

Button: navy `#101A44` fill, white text 1.05rem 800, min-height 48 (52 at 1024+), radius 999, padding 0 20, a small icon left, full-width on phones, auto width at 768+. White on navy is 16.7:1. Hover: `filter: brightness(1.25)`; pressed `scale(.98)`; focus ring navy (1.3). Only the button is the control (do not nest it in a link or make the card clickable).

| Card | Fill | Icon | Title | Sentence | Button | Notes |
|---|---|---|---|---|---|---|
| Surprise me | pink #FF7AC3 | `i-shuffle` | "Surprise me" | "A random game or quiz, picked for you." | "Pick for me" | same logic as bar Surprise me |
| Continue | sky #4DB6FF | `i-play` | "Continue" | the last recent title via `textContent`, for example "Snake" or "Fractions, Maths, Year 3" | "Keep going" | `aria-label` "Continue Snake"; card absent when no recent |
| Quick quiz | lime #9BD93C | `i-bolt` | "Quick quiz" | "A short Maths or English round." | "Start a quiz" | opens a random Learn card with `gameId === "quick_quiz"`; absent if none exist |
| Today's pick | coral #FF6B5E | `i-star` | "Today's pick" | the game title | "Play it" | optional; `aria-label` "Play Snake, today's pick". Index = `floor(localDayNumber) % funList.length` over Fun cards sorted by `gameId`; same for everyone on a given date, no network |

Order: Surprise me, Continue (when present), Quick quiz, Today's pick. Clicking any button records the opened card in `amc.recent` as W2 does.

### 5.2 States

- Loading: three skeleton cards (`--surface-2`, same size, static unless motion allowed, then the W2 pulse).
- No recent: no Continue card, no gap.
- Empty catalog or load error: the whole Jump in section is hidden (the error panel carries the message).
- Fewer than two cards that make sense (for example no Fun games): still render what exists.

## 6. Shelves and tiles

### 6.1 Shelf anatomy

```html
<div class="shelf" role="group" aria-labelledby="puzzlesH">
  <div class="shelf-head">
    <div class="shelf-text"><h3 id="puzzlesH" tabindex="-1">Puzzles</h3><p class="cap">Think it through, one move at a time.</p></div>
    <div class="arrows"><button class="arrow" aria-label="Scroll Puzzles left" ...><svg i-chev-l/></button> <button ... right></div>
  </div>
  <div class="scroller" id="puzzlesRow"><ul class="row"> <li>tile</li> ... </ul></div>
</div>
```

- Header: label and caption stacked on the left (`flex:1`, `min-width:0`), arrows on the right, bottom-aligned with the caption. Gap below the header 8 px.
- Arrows: `<button type="button" class="arrow">`, 48x48 (min 44), radius 999, `--surface` fill, 2px `--line` border, chevron 24 px `--ink`, shadow `--shadow`. Hidden below 768 (swipe) and hidden at any width when that row does not overflow. Hover: border `--accent`, fill `--surface-2`. Pressed `scale(.96)`. Focus per 1.3. Gap between the two 8 px.
- Arrow end state: at scrollLeft 0 the left arrow gets `aria-disabled="true"` plus `opacity:.4` and a `--line` border with no shadow; same for the right arrow at the end. Click is ignored when disabled. Focus is not moved. (Disabled controls are exempt from the contrast rule, still keep the glyph visible.) Update on `scroll` (passive) and on `resize` / content change.
- Arrow click: `scroller.scrollBy({left: ±step, behavior: reduce ? "auto" : "smooth"})` where `step = max(1, floor(clientWidth / (tileW + gap))) * (tileW + gap)`. The next row of tiles starts exactly at the left edge thanks to snap.
- Scroller CSS: `overflow-x:auto; overscroll-behavior-x:contain; scroll-snap-type:x mandatory; scroll-padding-inline:16px (24 at 1280); padding:10px 16px 18px; margin-inline:-16px (-24 at 1280); scrollbar-width:thin`. The 10 px top and 18 px bottom padding stop the focus ring (3 + 3 offset) and the shadow being clipped. The row is a flex `ul` with `gap:12px` (16 at 768+), `width:max-content` so tiles keep their size. Tiles `scroll-snap-align:start`. Do not hide the scrollbar.
- The next tile always peeks: at 360 px two tiles (160 + 12 + 160 = 332) exceed the 328 px content width, so the second is partly cut; keep tile width 160 to preserve that cue.
- Keyboard: tiles are links in normal tab order (focus scrolls the tile into view by default, no trap). Additionally, on a tile ArrowRight/ArrowLeft move focus to the next/previous tile in the same shelf, Home/End to the first/last (preventDefault only for these keys, only when the focus is on a tile link). The scroller itself is NOT a tab stop, because it always contains focusable links (this keeps tab order short and satisfies the scrollable region rule). Shelves are `role="group"` with `aria-labelledby`, not `region`, to avoid landmark noise.
- Reduced motion: arrow scroll `behavior:"auto"`, `scroll-behavior:auto`, no hover lift. Snap stays (it is not animation).
- A shelf with zero tiles is not rendered. A shelf with five or fewer tiles at 1280 shows no arrows.

### 6.2 Tile sizes

Reserve space with `aspect-ratio` and fixed widths so nothing shifts.

| Width | Tile width | Gap | Art area (4:3) | Total height (approx) |
|---|---|---|---|---|
| 320 to 767 | 160 | 12 | 160 x 120 | 120 + 80 text = about 200 |
| 768 to 1279 | 192 | 16 | 192 x 144 | about 224 |
| 1280 and up | 208 | 16 | 208 x 156 | about 236 |
| 1600 and up | 220 (cap) | 16 | 220 x 165 | about 245 |

At 1280 the 1120 px content shows five tiles fully (5 x 208 + 4 x 16 = 1104). Body block min-height 80 px (grows with 200% text).

### 6.3 Tile anatomy

```html
<li><a class="tile" href="..." aria-label="Snake, from Mind Presto">
  <span class="media" style="--tint:#2CD3B0"><img class="tileart" src="_site/art/tile-snake.svg" width="400" height="300" alt="" loading="lazy" decoding="async"><span class="pill">Maths</span> <!-- subject tiles only --></span>
  <span class="tbody">
    <b class="ttl">Snake</b>
    <span class="tmeta"><span class="badge b-play"><svg i-gamepad 16/>Play</span><span class="meta">from Mind Presto</span></span>
  </span>
</a></li>
```

- Tile: `display:flex; flex-direction:column; width:100%; background:--surface; border:1px solid --line; border-radius:20px; overflow:hidden; box-shadow:--shadow; text-decoration:none`. Whole tile is one `<a>`; no nested controls.
- `.media`: `aspect-ratio:4/3; position:relative; background:var(--tint)` (the tint shows while the image loads, so no empty flash). `img.tileart { width:100%; height:100%; object-fit:cover; display:block }`.
- `.tbody`: padding 10px 12px 12px, gap 4; title 1.05rem 700, wraps (no clamp; `overflow-wrap:anywhere`).
- Badge (`.badge`): inline-flex, gap 4, padding 2px 10px, radius 999, 0.875rem 800, icon 16 px, text `--on-fill` on its fill: Play teal (gamepad icon), Maths amber (`i-maths`), English violet (`i-english`). Contrast 8.8, 9.2, 7.4:1. No "Free" badge.
- Meta line, after the badge, wraps below it when narrow (`flex-wrap:wrap; gap:4px 8px`):
  - Fun: "from Mind Presto".
  - Learn topic: "Year 3 · 24 items" (as W2: singular "1 item", count hidden when 0). The badge carries the subject; the year always shows.
  - Recent shelf Learn tile: same as Learn topic.
  - Search result: same as its kind.
- `aria-label`: Fun "Snake, from Mind Presto"; Learn "Fractions, Maths, Year 3, 24 items"; as W2.
- Hover (`@media (hover:hover)`): lift 2 px, border `--accent`, `--shadow-up`. Pressed: `scale(.98)`, body background `--surface-2`. Focus: 3px ring following the 20 px radius. Forced colours: 2px `ButtonText` border.

### 6.4 Subject tiles (Maths and English)

Topic tiles on the Maths and English shelves use `tile-maths.svg` / `tile-english.svg` as their art, and show the subject word as HTML in a dark pill over the lower part of the art:

- `.pill { position:absolute; left:50%; bottom:10px; transform:translateX(-50%); padding:6px 18px; border-radius:999px; background:var(--pill-bg); color:#FFFFFF; font-weight:800; font-size:1rem; line-height:1.2; white-space:nowrap; }` (1.1rem at 768+). White on pill 16.7:1 on the pure fill and about 13.5:1 over white art.
- The pill is decoration of text that is also in the badge and `aria-label`; set `aria-hidden="true"` on it so it is not read twice.
- Because the art is shared by every topic tile of a subject, the title and year below are what distinguish them. Keep the pill so the subject is clear at a glance.
- Fun tiles never get a pill.

### 6.5 Fallback tile

Used when a tile SVG fails to load, and for any card with no tile art (Craft minigame cards in "Games for your topics", unknown `gameId`).
- JS sets `img.onerror` (assigned before `src`): first retry once with the small icon `_site/art/<c.art>.svg`; if that also fails, remove the `img` and keep the tinted `.media` only.
- Appearance: `.media` shows its solid `--tint` (from `TINTS[hash(gameId) % 6]`, or amber / violet for the subject tiles), and the small icon (96 px wide, centred, `object-fit:contain`, `border-radius:22%`, `box-shadow:var(--art-shadow)`) sits in the centre. Apply a class `fallback` to `.media` when the small icon is used so the CSS switches from `cover` to a 96 px centred box (72 px under 768).
- Text contrast unaffected: titles live in the white/dark `tbody`, not on the tint. If the tint is behind a pill (subject tile), the pill still reads at 13:1 or more.
- Fallback for tile art of `quick_quiz` Learn cards at subject shelves is `tile-maths` / `tile-english`, not the small `quick_quiz` icon.

### 6.6 Skeleton tile

Same width and `.media` 4:3 block plus a body of two bars (title 70% wide, badge 40% wide) in `--surface-2`, `aria-hidden="true"`, static unless motion allowed (pulse as W2). Six skeleton tiles in the Puzzles shelf only; Jump in shows three skeleton cards.

## 7. Page structure and shelf order

Page order below the bar (Learn before Play):

1. Headline (section 4)
2. Jump in (section 5)
3. Pick up where you left off: h2 with clock icon, caption "Your latest games on this device.", a "Clear" text button (44 px, `aria-label` "Clear recent games") on the right before the arrows. Shelf of tiles (max 6). Hidden entirely when empty.
4. Learn (`<section id="learn">`, h2 "Learn" with book icon, caption "Pick a year, then a topic."):
   - "Year" chips (wrapping, 48 px, selected state filled with accent plus check icon, as W2).
   - "Subject" segmented control Maths / English / Both (as W2, kept so the bar's Maths and English buttons can be undone).
   - Status line `aria-live="polite"`.
   - No year chosen: the "Pick a year" panel (as W2). Year chosen: one shelf per subject: Maths shelf (label "Maths", caption "Topics for Year 3." or "Topics for Foundation.") and English shelf (label "English", same caption). A shelf with no topics shows no shelf; if both are empty show the W2 "No topics here yet" panel with "Show both".
   - "More filters" `<details>` (as W2) sits at the end of the Learn section.
5. Ad slot (section 8).
6. Play (`<section id="play">`, h2 "Play" with gamepad icon, caption "Open any game and start in one click."): shelves **Puzzles**, **Arcade**, **More games** (h3 labels).
   - Puzzles, caption "Think it through, one move at a time.": block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge (in that order).
   - Arcade, caption "Quick reflexes and big scores.": wingy, snake, bricks, stack, runner (in that order).
   - More games, caption "Even more to try.": every Fun card whose `gameId` is in neither list, sorted by title; shelf is absent when none. This guarantees every Fun game appears in exactly one shelf.
   - The grouping is a constant inside the script: `var GROUPS = [{id:"puzzles", label:"Puzzles", cap:"...", ids:[...]}, {id:"arcade", ...}]`, keyed by `gameId`; "More games" is derived (everything unlisted).
7. Games for your topics (h3 shelf, shown only when the Game filter in More filters is set to a Craft minigame; label "Games for your topics", caption "Games that match your topic filter."). Tiles use the fallback look (small icon on tint) with the meta "Maths, Year 3 · Fraction pairs" and badge for the subject. This shelf is placed last, after Play. The Play section hides while the Game filter selects a Learn minigame (as W2).
8. Footer line (as W2).

Filters that hide sections (type, topic, game) behave as W2 (`type=learn` hides Play, `type=fun` hides Learn, and so on). A year or subject chosen from the URL shows the Learn shelves.

Section spacing: 32 px between sections (40 at 1280), 24 px between shelves inside a section. h2 has margin 0 0 4, caption below at margin 0 0 12.

## 8. Ad slot (empty)

Between the Learn section (including More filters) and the Play section, exactly one container:

```html
<!-- AD SLOT 1: intentionally empty. A future ad unit goes inside this container. No ad code, scripts or network calls belong here yet. -->
<div class="ad-slot" id="ad-slot-1"></div>
```

CSS: `.ad-slot { max-width: 728px; margin: 32px auto 0; } .ad-slot:empty { display: none; }`. No border, no label, no placeholder box, so it adds no space today. When an ad unit is added, it fills the container and the owner decides on a small "Advertisement" label then. Hidden with the other shelves while searching. It is not a landmark and has no `aria-label` today.

## 9. Search and results

- Typing (80 ms debounce) switches to Results mode: the headline, Jump in, all shelves, ad slot and More filters hide; the bar stays. `h2` "Results" with search icon, status `role="status"` "14 results for snake" (as W2).
- Results are a wrapping grid (not a shelf) of the same tiles with badges: `display:grid; gap:12px (16 at 768); grid-template-columns: repeat(auto-fill, minmax(150px, 1fr))`. At 320 this is one column (288 px wide, tile art 216 high), at 360 two columns, at 768 four, at 1280 six. Fun first, then Learn (as W2). Tile width follows the column, so the `.media` stays 4:3.
- Cap 60 with "Show more" (as W2; focus moves to the first new tile).
- Empty: panel with the magnifier, "No games match", "Try a shorter word, like snake or fractions.", button "Clear search" (as W2).
- Escape clears the text and keeps focus in the input; the clear button is 44x44 inside the field.
- The bar buttons Maths, English, Play, Recent (and Surprise me) first clear the search, then act (the W2 `leaveSearch` behaviour).
- URL params `type`, `year`, `topic`, `game`, `q`, `subject` unchanged, updated with `history.replaceState`.

## 10. Other states

| State | Look |
|---|---|
| Loading | Bar buttons disabled (3.2); headline shows; Jump in 3 skeleton cards; Puzzles shelf 6 skeleton tiles; `aria-busy="true"` on `main`. |
| Load error | The W2 error panel replaces Jump in and shelves ("The game list could not be loaded." and "Try again"). Bar buttons stay disabled. |
| Empty catalog | Headline; Play section shows "No games are listed yet. Please check back soon."; Jump in hidden; Surprise me disabled. |
| Storage blocked | Page works; Recent and Continue absent; theme still toggles for the session. |
| No JavaScript | `<noscript>` panel "This page needs JavaScript to list the games." (as W2). |

## 11. Spacing and responsive summary

| Item | 320 / 360 | 768 | 1280 |
|---|---|---|---|
| Gutter | 16 | 16 | 24 |
| Bar | 2 rows, 108 px | 2 rows, 108 px | 1 row, 64 px |
| Wordmark text | icon only under 480 | shown | shown |
| Bar button | 44 high, scroll row | 44 high, fits | 48 high, fits |
| Arrows | hidden (swipe) | shown on overflow | shown on overflow |
| Tile | 160 wide | 192 | 208 (220 cap at 1600) |
| Jump card | min(264, 82vw) | 280 | 264 (four fit) |
| Results grid | 1 col at 320, 2 at 360 | 4 | 6 |
| Section gap | 32 | 32 | 40 |
| Headline size | 1.9rem | 2.6rem | 3rem |

Touch targets: all 44 px minimum (bar buttons 44, arrows 48, card buttons 48, chips 48, clear 44); at least 8 px between adjacent targets. No horizontal page scroll at 320 (only the intended scrollers); the page `body` keeps `overflow-x: hidden` only as a guard.

Check at 200 percent text: the bar wraps to its rows (do not set fixed heights), tiles grow downward, card text wraps.

## 12. Icons to add to the sprite

Same style as W2 (24x24, stroke currentColor, width 2, round caps and joins, `fill:none`). Keep the existing W2 symbols (`i-spark`, `i-search`, `i-x`, `i-sun`, `i-moon`, `i-play`, `i-gamepad`, `i-calc`, `i-book`, `i-both`, `i-shuffle`, `i-clock`, `i-calendar`, `i-sliders`, `i-chevron`, `i-check`, `i-warning`, `i-device`, `i-refresh`). Add:

| Symbol | Description and path |
|---|---|
| `i-maths` (bar Maths, badge) | Four operators in a 2x2 layout. Plus top left `M3.5 7h7M7 3.5v7`; minus top right `M14 7h7`; times bottom left `M4 15l6 6M10 15l-6 6`; equals bottom right `M14 16.5h7M14 20h7`. |
| `i-english` (bar English, badge) | Pencil on a diagonal. `M4 20l1.2-4.8L16.5 3.9a2 2 0 0 1 2.8 0l.8.8a2 2 0 0 1 0 2.8L8.8 18.8z` and the band `M14 6.5l3.5 3.5`. |
| `i-bolt` (Quick quiz card) | Lightning bolt. `M13 2L4 14h7l-1 8 9-12h-7z`. |
| `i-star` (Today's pick card) | Five point star. `M12 3l2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8 6.6 19.7l1.1-6.1L3.2 9.4l6.1-.8z`. |
| `i-chev-l` | `M15 5l-7 7 7 7`. |
| `i-chev-r` | `M9 5l7 7-7 7`. |

Bar button icons: Maths `i-maths`, English `i-english`, Play `i-gamepad`, Recent `i-clock`, Surprise me `i-shuffle`. Sizes: 22 px in bar buttons (24 at 1024+), 28 px in card badges, 16 px in tile badges, 24 px in arrows. No emoji.

## 13. Motion

Allowed when no reduced-motion preference: tile hover lift and press scale (120 ms ease-out), bar button hover (120 ms), arrow smooth scroll, tooltip fade (120 ms), skeleton pulse (1.6 s, opacity .6 to 1), smooth anchor scroll. Under `prefers-reduced-motion: reduce`: the W2 rule (`animation:none; transition:none; scroll-behavior:auto`), no transforms on hover or press, arrow scroll `behavior:"auto"`, tooltips without fade. No autoplay, no flashing, no parallax.

## 14. Copy (final strings, en-AU)

- Title: "Active Mind Craft games". Meta description: "Free games to play, and maths and English practice for every year. Open a game and start in one click."
- H1 "Build your mind, one game at a time." Sentence "Practise maths and English by year, or jump straight into a puzzle or an arcade game."
- Bar: Maths, English, Play, Recent, Surprise me. Tooltips: section 3.2. Search label and placeholder: "Search games and topics" ("Search" under 480). Clear: "Clear search". Theme: "Switch to light theme" / "Switch to dark theme".
- Jump in: section 5.1 (titles, sentences and buttons are final). Section heading "Jump in", caption "Not sure where to start? Try one of these."
- Recent: "Pick up where you left off", caption "Your latest games on this device.", "Clear".
- Learn: "Learn", caption "Pick a year, then a topic.", labels "Year" and "Subject", chips "Foundation", "Year 1" and so on, subject "Maths", "English", "Both"; shelves "Maths" and "English" with "Topics for Year 3." Pick a year panel: "Pick a year" / "Choose a year above to see maths and English topics."
- Play: "Play", "Puzzles", "Arcade", "More games", "Games for your topics"; captions in section 7.
- Announcements and the remaining W2 strings (More filters, errors, empty, search empty, Show more, noscript, footer) unchanged.
- Arrow labels: "Scroll {shelf label} left" and "Scroll {shelf label} right".

## 15. Art style guide

### 15.1 Rules (every file)

- Hand-drawn original SVG, written by hand in a text editor. No AI image or illustration generation, no Figma generation, no stock, no traced images. A plain minifier is fine; nothing generative. No XML comments in the files (they add bytes).
- Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300" width="400" height="300">`.
- Flat bold shapes: `rect`, `circle`, `ellipse`, `path`, `polygon`, `g`. Rounded corners (`rx` at least 12 on rectangles, stroke-linejoin and linecap round). No gradients, filters, masks, blur, patterns, clip paths, `<style>`, `<text>`, `<image>`, `<script>`, `<foreignObject>`, `href` or external reference of any kind. No raster. No people or faces of people (animals and objects only). No text, letters or numerals (use pips, dots and bars instead).
- Size: 6 KB or less per file (aim for 2 to 4 KB). Integer coordinates, hex colours only (6 digits), no unused groups.
- Background: first element is a full-bleed `<rect width="400" height="300" fill="BG"/>` with no rounded corners (the tile clips the corners). One optional lighter or darker second background shape (a large circle or band) at most.
- Palette (use only these hex values):

| Role | Hex |
|---|---|
| Navy (outlines, shadows, wells) | #101A44 |
| Indigo | #2B3A8F |
| Royal blue | #1D6FE0 |
| Sky | #4DB6FF |
| Teal | #2CD3B0 |
| Deep teal | #11967C |
| Forest | #17594A |
| Lime | #9BD93C |
| Felt green | #2E8B57 |
| Amber | #FFB020 |
| Orange | #FF8A2B |
| Coral | #FF6B5E |
| Red | #E0443A |
| Pink | #FF7AC3 |
| Magenta | #C2368F |
| Violet | #B79CFF |
| Deep violet | #7B4FD6 |
| Cream | #FFF4DC |
| White | #FFFFFF |

- Use the background colour assigned per file below. Draw the main motif in two to four bright colours plus cream, with navy as outline (8 to 10 unit strokes) or shadow. On a light background (sky, lime, amber, violet, orange) every motif shape gets a navy outline so its silhouette holds.
- Composition: one clear motif, centred, filling about 55 to 70 percent of the width. Safe zone for Fun tiles x 40 to 360, y 30 to 270. For `tile-maths` and `tile-english` the motif sits in x 50 to 350, y 20 to 180 only; the bottom 120 units hold calm background (a ground band or large soft shape) because the HTML pill covers about y 190 to 280 at 160 to 220 px wide.
- Legibility: minimum stroke 8 units, minimum shape 24 units, minimum gap 10 units. At 56 px wide (scale 0.14) the tile must still read as a silhouette: keep two or three big shapes, not many small ones.
- Same visual voice across all 14: same corner radius feel, same outline weight, a simple offset shadow shape (the same shape in navy, moved 8 units down and right, at most) instead of effects.
- Check each at 200 px and 56 px wide, in both light and dark pages, and as the 96 px fallback is not needed for these.

### 15.2 Per-file motifs

All backgrounds are unique per file for recognition at a glance. Coordinates are guidance; keep the described composition.

| File | Background | Motif |
|---|---|---|
| `tile-block_puzzle.svg` | Indigo #2B3A8F | A cream rounded board (about 190x190, centred, rx 20) with a 3x3 grid of recessed navy cells; four cells are filled with rounded squares in teal, amber and pink; an L shaped piece (four coral squares) hovers at the lower right half overlapping the board edge with a navy offset shadow. Placed board and a loose piece say "fit the piece". |
| `tile-blockfall.svg` | Red #E0443A | A tall navy well (about 150 wide, 240 high, centred, rx 16). At the bottom a stack of tetromino blocks in teal, amber, lime and sky (squares about 36 with 4 gaps); a violet T piece falls near the top with three short cream vertical bars above it to show the drop. |
| `tile-sudoku.svg` | Royal blue #1D6FE0 | A cream rounded square board (about 200, rx 20) cut into a 3x3 of big cells by thick navy lines, each cell holding pips (one to three navy or coral dots, never numerals); two cells highlighted amber. |
| `tile-solitaire.svg` | Felt green #2E8B57 | Three cream playing cards fanned from a lower left pivot (rotations about -18, 0 and 18 degrees, rx 16, navy outline) each carrying one large suit shape: a coral heart, a navy spade, an amber diamond. No corner letters or numbers. A darker green oval (forest #17594A) behind as a table. |
| `tile-ball_sort.svg` | Deep violet #7B4FD6 | Three test tubes (rounded bottom rectangles, cream outline 8, about 70x190) side by side; two hold stacked balls (circles about 46) in coral, amber, teal and lime; the third is half empty; one lime ball floats above it. |
| `tile-mahjong.svg` | Deep teal #11967C | A pyramid of three cream tiles (about 100x130, rx 14), two at the bottom and one on top, each with a thicker amber lower edge to show depth; faces carry simple symbols: a ring of dots (coral), three vertical bars (lime and navy), and a navy diamond. No characters. |
| `tile-merge.svg` | Magenta #C2368F | Two small amber rounded squares (about 70) at the left merging with a cream chevron arrow into a large coral rounded square (about 130) at the right; one pip on each small square, two pips on the large one; three cream four point sparks around the big square. |
| `tile-wingy.svg` | Sky #4DB6FF | Two lime pipes (a top pipe and a bottom pipe with a wider cap, navy outline) leaving a gap; between them a round amber bird (circle about 90, navy outline) with a cream eye (navy pupil), a coral beak and a small coral wing; two cream clouds behind. |
| `tile-snake.svg` | Forest #17594A | A lime snake body drawn as a thick (36 unit) round-capped S curve stroke with a darker segment pattern of teal dots, a rounded head with two cream eyes (navy pupils) and a coral tongue; a coral apple (circle with a lime leaf) at the right. |
| `tile-bricks.svg` | Navy #101A44, with a slightly lighter indigo #2B3A8F lower band | Top rows: three rows of five rounded bricks (about 56x26) in coral, amber, lime, with one gap; a white ball with a short cream motion trail below the gap; a cream rounded paddle (about 110x20) at the bottom. |
| `tile-stack.svg` | Orange #FF8A2B | A tower of five horizontal rounded slabs (navy outline) in teal, violet, pink, lime and sky, each shifted a little left or right; the top slab overhangs and a small chip of it falls away at the right; a navy base slab. |
| `tile-runner.svg` | Lime #9BD93C | A navy ground band along the bottom, an amber sun (circle with a navy outline) at the upper right, two darker green rounded hills (felt green #2E8B57); a coral ball (circle about 80, navy outline) leaping in the middle with three cream speed lines behind it; two navy spike triangles on the ground ahead. No creature or person. |
| `tile-maths.svg` | Amber #FFB020 | Four rounded cream squares (about 70) in a 2x2 grid in the upper area (y 20 to 180), each carrying a navy symbol drawn as strokes: plus, minus, times, equals (these are shapes, not lettering); a coral circle and a teal triangle as accents at the corners; the lower 120 units a calm lighter amber band with a navy rounded base line. |
| `tile-english.svg` | Violet #B79CFF | An open cream book (two pages with rounded corners, navy spine) in the upper area (y 20 to 180) with three horizontal navy bars on each page standing for lines of writing (plain bars, no letters); a coral pencil crossing the bottom right of the book; three cream four point sparks; the lower 120 units a calm deeper violet band. |

### 15.3 Per-file checklist (frontend)

- Opens standalone in a browser without error, `viewBox` is exactly `0 0 400 300`.
- 6 KB or less; no forbidden elements (search the file for `<text`, `<image`, `href`, `<style`, `<script`, `filter`, `gradient`, `mask`).
- Looks right at 200 px and 56 px wide, on a light and a dark page; the silhouette is recognisable at 56 px.
- Only palette hexes appear (search for `#` values).
- `site/art/LICENSES.md` lists every file as original work made for the studio (hand-drawn, no AI or generated art).
- Names are stable: `tile-<gameId>.svg` for the twelve Fun games, `tile-maths.svg`, `tile-english.svg`. The owner may replace them by name later.

## 16. Accessibility summary

- Landmarks: `header`, `main`, `footer`; skip link first ("Skip to games", targets `#main`). One `h1`. h2 for Jump in, Pick up, Learn, Play, Results. h3 for shelf labels and card titles.
- Tab order: skip link, wordmark, search, theme, bar buttons, Jump in buttons, Recent clear and tiles, Learn chips and subject buttons, Learn tiles, More filters, Play tiles, footer (see 3.1 for the one accepted desktop difference).
- Every tile is one link with a full accessible name; images have `alt=""`; pills are `aria-hidden`.
- Selected, current and disabled are never colour alone: check icon, ring, dashed border, opacity.
- Contrast: all text at least 4.5:1 (table in section 1; many are 7:1 or better). Focus ring at least 3:1 on its own background (section 1.3). Lighthouse accessibility target 95 or more.
- Forced colours: 2px `ButtonText` borders on tiles, chips, bar buttons, cards; selected `Highlight`; ring `Highlight`.
