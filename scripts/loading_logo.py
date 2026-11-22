#!/usr/bin/env python3
"""Put the Active Mind Craft logo on a built game's loading screen.

  loading_logo.py <built index.html> <brand logo svg>

The app's web/index.html shows a #loading block (app icon, <h1> with the family name, a sliding bar,
"Getting ready...") until Flutter's `flutter-first-frame` event removes it. This replaces the content of that
block with the centred logo (inline SVG, no extra request), the sliding bar and "Getting ready...". When the page
has no #loading block, the block, its style and the removal script are added (warning, build not failed). The
page <title> and the rest of the page are not changed.
"""
import re, sys

LOGO_CSS = '#loading svg { width: min(220px, 56vw); height: auto; display: block; }\n'
FALLBACK_CSS = """
  <style>
    html, body { margin: 0; height: 100%; background: #101820; }
    #loading {
      position: fixed; inset: 0; display: flex; flex-direction: column; align-items: center;
      justify-content: center; gap: 16px; background: #101820; color: #fff;
      font-family: system-ui, sans-serif; text-align: center; transition: opacity .4s;
    }
    #loading p { margin: 0; opacity: .7; font-size: 14px; }
    #loading .bar { width: 120px; height: 4px; border-radius: 2px; background: #ffffff22; overflow: hidden; }
    #loading .bar::after { content: ""; display: block; width: 40%; height: 100%; background: #18B5A0;
      animation: slide 1.4s ease-in-out infinite; }
    @keyframes slide { from { margin-left: -40%; } to { margin-left: 100%; } }
  </style>
"""
REMOVE_JS = """  <script>
    window.addEventListener('flutter-first-frame', function () {
      var el = document.getElementById('loading');
      if (!el) return;
      el.style.opacity = '0';
      setTimeout(function () { el.remove(); }, 450);
    });
  </script>
"""


def find_block(s):
    """Return (start, inner_start, inner_end, end) of the <div id="loading"> element, matching nested divs."""
    m = re.search(r'<div\b[^>]*\bid="loading"[^>]*>', s)
    if not m:
        return None
    depth, pos = 1, m.end()
    for t in re.finditer(r'<(/?)div\b[^>]*>', s[pos:]):
        depth += -1 if t.group(1) else 1
        if depth == 0:
            return m.start(), m.end(), pos + t.start(), pos + t.end()
    raise AssertionError('unclosed #loading block')


def main(page, logo):
    s = open(page).read()
    svg = open(logo).read().strip()
    assert svg.startswith('<svg') and svg.endswith('</svg>'), 'logo is not a single svg'
    svg = re.sub(r'\s(width|height)="\d+"', '', svg, count=2)  # sized by CSS
    inner = '\n    ' + svg + '\n    <div class="bar"></div>\n    <p>Getting ready...</p>\n  '
    blk = find_block(s)
    if blk:
        _, a, b, _ = blk
        s = s[:a] + inner + s[b:]
        if '#loading svg' not in s:
            assert '</style>' in s, 'no <style> to add the logo size to'
            s = s.replace('</style>', '  ' + LOGO_CSS + '  </style>', 1)
        assert 'flutter-first-frame' in s, 'removal script missing'
    else:
        print('WARNING: %s has no #loading block; adding one' % page)
        assert '</head>' in s and '<body' in s
        s = s.replace('</head>', FALLBACK_CSS + '  <style>\n    ' + LOGO_CSS + '  </style>\n</head>', 1)
        s = re.sub(r'(<body[^>]*>)', lambda m: m.group(1) + '\n  <div id="loading">' + inner + '</div>\n' + REMOVE_JS, s, count=1)
    assert 'id="loading"' in s and '<svg' in s and 'Getting ready...' in s and 'flutter-first-frame' in s
    assert '<h1>' not in s[s.index('id="loading"'):s.index('Getting ready...')], 'old heading left in #loading'
    open(page, 'w').write(s)
    print('loading screen: logo set in', page)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
