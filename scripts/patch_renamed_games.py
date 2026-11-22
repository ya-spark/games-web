#!/usr/bin/env python3
"""Rename the games that were renamed in game-factory, inside ONE TEMPORARY copy of an app (never a checkout).

    python3 scripts/patch_renamed_games.py <app copy>

Owner rule (2026-11-22): a game's folder, package and id are its name. equation_builder became bridge_builder and
series_builder became domino_chain in game-factory. The apps are paused and keep pinning an older game-factory commit
that still has the old packages; the web builds use the current game-factory (factory.ref), where only the new
packages exist. So build_game.sh runs this on the copy, right after copying the app and BEFORE the overlay (the overlay
itself mentions the old ids on purpose, to migrate saved data): for each renamed game it rewrites the pubspec dependency
(name and path) and the Dart references in lib/ and test/. Idempotent: an app that already uses the new name is left
alone. Fails loudly if the old name is only partly there.
"""
import re
import sys
from pathlib import Path

# One entry per renamed game. `renames` are (old, new) in the order they are applied: package, id, class and
# identifier prefixes. `registry` is the import every app that lists the game must have after the rewrite.
GAMES = [
    {
        "label": "equation_builder -> bridge_builder",
        "old_pkg": "game_equation_builder",
        "old_path": "games/equation_builder",
        "new_pkg": "game_bridge_builder",
        "new_path": "games/bridge_builder",
        "renames": [
            ("game_equation_builder", "game_bridge_builder"),
            ("equation_builder", "bridge_builder"),
            ("EquationBuilder", "BridgeBuilder"),
            ("equationBuilder", "bridgeBuilder"),
        ],
        "registry": "package:game_bridge_builder/bridge_builder.dart",
    },
    {
        "label": "series_builder -> domino_chain",
        "old_pkg": "game_series_builder",
        "old_path": "games/series_builder",
        "new_pkg": "game_domino_chain",
        "new_path": "games/domino_chain",
        "renames": [
            ("game_series_builder", "game_domino_chain"),
            ("series_builder", "domino_chain"),
            ("SeriesBuilder", "DominoChain"),
            ("seriesBuilder", "dominoChain"),
        ],
        "registry": "package:game_domino_chain/domino_chain.dart",
    },
]


def rewrite(text, renames):
    for old, new in renames:
        text = text.replace(old, new)
    return text


def patch(app, g):
    renames = g["renames"]
    old = re.compile("|".join(re.escape(o) for o, _ in renames))
    pub = app / "pubspec.yaml"
    s = pub.read_text()
    if g["old_pkg"] not in s:
        # a Craft app that lists the game uses the new name already; any other app does not list it at all
        assert not old.search(s), "pubspec.yaml mentions the old game name but not its package: %s" % pub
        print("patch_renamed_games: pubspec has no %s dependency, nothing to rename" % g["old_pkg"])
        return
    block = re.search(re.escape(g["old_pkg"]) + r":\s*\n\s*git:\s*\n(?:\s+\w+:[^\n]*\n)+", s)
    assert block, "%s dependency block not found in %s" % (g["old_pkg"], pub)
    assert "path: " + g["old_path"] in block.group(0), "unexpected path in the dependency block: " + block.group(0)
    pub.write_text(rewrite(s, renames))
    s2 = pub.read_text()
    assert g["new_pkg"] + ":" in s2 and "path: " + g["new_path"] in s2 and g["old_pkg"] not in s2 and \
        "path: " + g["old_path"] not in s2, "pubspec rewrite failed"
    changed = 0
    for sub in ("lib", "test"):
        for f in sorted((app / sub).rglob("*.dart")) if (app / sub).is_dir() else []:
            t = f.read_text()
            if old.search(t):
                f.write_text(rewrite(t, renames))
                changed += 1
    assert changed, "pubspec listed the game but no Dart file in lib/ or test/ referenced it"
    left = [str(f) for sub in ("lib", "test") if (app / sub).is_dir() for f in (app / sub).rglob("*.dart")
            if old.search(f.read_text())]
    assert not left, "old names left in: %s" % left
    reg = [f for f in (app / "lib").rglob("*.dart") if g["registry"] in f.read_text()]
    assert reg, "no registry imports %s after the rewrite" % g["registry"]
    print("patch_renamed_games: %s in pubspec and %d Dart files" % (g["label"], changed))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    app = Path(sys.argv[1])
    for g in GAMES:
        patch(app, g)


if __name__ == "__main__":
    main()
