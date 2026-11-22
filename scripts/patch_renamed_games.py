#!/usr/bin/env python3
"""Rename the games that were renamed in game-factory, inside ONE TEMPORARY copy of an app (never a checkout).

    python3 scripts/patch_renamed_games.py <app copy>

Owner rule (2026-11-22): a game's folder, package and id are its name. equation_builder became bridge_builder in
game-factory. The apps are paused and keep pinning an older game-factory commit that still has the old package; the web
builds use the current game-factory (factory.ref), where only the new package exists. So build_game.sh runs this on the
copy, right after copying the app and BEFORE the overlay (the overlay itself mentions the old id on purpose, to migrate
saved data): it rewrites the pubspec dependency (name and path) and the Dart references in lib/ and test/.
Idempotent: an app that already uses the new name is left alone. Fails loudly if the old name is only partly there.
"""
import re
import sys
from pathlib import Path

# (old, new) in the order they are applied: package, id, class and identifier prefixes.
RENAMES = [
    ("game_equation_builder", "game_bridge_builder"),
    ("equation_builder", "bridge_builder"),
    ("EquationBuilder", "BridgeBuilder"),
    ("equationBuilder", "bridgeBuilder"),
]
OLD = re.compile("|".join(re.escape(o) for o, _ in RENAMES))


def rewrite(text):
    for old, new in RENAMES:
        text = text.replace(old, new)
    return text


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    app = Path(sys.argv[1])
    pub = app / "pubspec.yaml"
    s = pub.read_text()
    if "game_equation_builder" not in s:
        # a Craft app that lists the game uses the new name already; any other app does not list it at all
        assert not OLD.search(s), "pubspec.yaml mentions the old game name but not its package: %s" % pub
        print("patch_renamed_games: pubspec has no equation_builder dependency, nothing to rename")
        return
    block = re.search(r"game_equation_builder:\s*\n\s*git:\s*\n(?:\s+\w+:[^\n]*\n)+", s)
    assert block, "game_equation_builder dependency block not found in %s" % pub
    assert "path: games/equation_builder" in block.group(0), "unexpected path in the dependency block: " + block.group(0)
    pub.write_text(rewrite(s))
    s2 = pub.read_text()
    assert "game_bridge_builder:" in s2 and "path: games/bridge_builder" in s2 and "equation" not in s2.lower().replace(
        "equations", ""), "pubspec rewrite failed"
    changed = 0
    for sub in ("lib", "test"):
        for f in sorted((app / sub).rglob("*.dart")) if (app / sub).is_dir() else []:
            t = f.read_text()
            if OLD.search(t):
                f.write_text(rewrite(t))
                changed += 1
    assert changed, "pubspec listed the game but no Dart file in lib/ or test/ referenced it"
    left = [str(f) for sub in ("lib", "test") if (app / sub).is_dir() for f in (app / sub).rglob("*.dart")
            if OLD.search(f.read_text())]
    assert not left, "old names left in: %s" % left
    reg = [f for f in (app / "lib").rglob("*.dart") if "package:game_bridge_builder/bridge_builder.dart" in f.read_text()]
    assert reg, "no registry imports package:game_bridge_builder/bridge_builder.dart after the rewrite"
    print("patch_renamed_games: equation_builder -> bridge_builder in pubspec and %d Dart files" % changed)


if __name__ == "__main__":
    main()
