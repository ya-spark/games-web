#!/usr/bin/env python3
"""Rename the games that were renamed in game-factory, inside ONE TEMPORARY copy of an app (never a checkout).

    python3 scripts/patch_renamed_games.py <app copy>

Owner rule (2026-11-22): a game's folder, package and id are its name. equation_builder became bridge_builder and
series_builder became domino_chain and snake became parcel_train and runner became wind_up_dash and true_false became judge_bot in game-factory. The apps are paused and keep pinning an older game-factory commit
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
        "label": "snake -> parcel_train",
        "old_pkg": "game_snake",
        "old_path": "games/snake",
        "new_pkg": "game_parcel_train",
        "new_path": "games/parcel_train",
        "regex": True,
        # word boundaries keep game_snake_series, 'snake_series' and its classes (another game) untouched
        "renames": [
            (r"game_snake\b", "game_parcel_train"),
            (r"games/snake\b", "games/parcel_train"),
            (r"\bsnake\.dart\b", "parcel_train.dart"),
            (r"(['\"])snake\1", r"\1parcel_train\1"),
            (r"'Snake'", "'Parcel train'"),
            (r"\bSnakeScreen\b", "ParcelTrainScreen"),
            (r"\bsnakeStarScores\b", "trainStarScores"),
        ],
        "registry": "package:game_parcel_train/parcel_train.dart",
        "art": "site/art/parcel_train.svg",
        "art_id": "parcel_train",
    },
    {
        "label": "runner -> wind_up_dash",
        "old_pkg": "game_runner",
        "old_path": "games/runner",
        "new_pkg": "game_wind_up_dash",
        "new_path": "games/wind_up_dash",
        "regex": True,
        # word boundaries keep game_door_runner and its classes (another game) untouched
        "renames": [
            (r"game_runner\b", "game_wind_up_dash"),
            (r"games/runner\b", "games/wind_up_dash"),
            (r"\brunner\.dart\b", "wind_up_dash.dart"),
            (r"(['\"])runner\1", r"\1wind_up_dash\1"),
            (r"'Runner'", "'Wind-up dash'"),
            (r"\bRunnerScreen\b", "WindUpDashScreen"),
            (r"\brunnerStarScores\b", "dashStarScores"),
        ],
        "registry": "package:game_wind_up_dash/wind_up_dash.dart",
        "art": "site/art/wind_up_dash.svg",
        "art_id": "wind_up_dash",
    },
    {
        "label": "true_false -> judge_bot",
        "old_pkg": "game_true_false",
        "old_path": "games/true_false",
        "new_pkg": "game_judge_bot",
        "new_path": "games/judge_bot",
        "regex": True,
        "renames": [
            (r"game_true_false\b", "game_judge_bot"),
            (r"games/true_false\b", "games/judge_bot"),
            (r"\btrue_false\.dart\b", "judge_bot.dart"),
            (r"\btrueFalseGame\b", "judgeBotGame"),
            (r"\btrueFalseGameFor\b", "judgeBotGameFor"),
            (r"(['\"])true_false\1", r"\1judge_bot\1"),
            (r"'True or false'", "'Judge bot'"),
        ],
        "registry": "package:game_judge_bot/judge_bot.dart",
        "art": "site/art/judge_bot.svg",
        "art_id": "judge_bot",
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


def rewrite(text, renames, regex=False):
    for old, new in renames:
        text = re.sub(old, new, text) if regex else text.replace(old, new)
    return text


def patch(app, g):
    renames = g["renames"]
    regex = g.get("regex", False)
    old = re.compile("|".join(o if regex else re.escape(o) for o, _ in renames))
    # `\b`: game_snake is not game_snake_series (a different game that keeps its name)
    old_pkg = re.compile(re.escape(g["old_pkg"]) + r"\b")
    old_path = re.compile("path: " + re.escape(g["old_path"]) + r"\b")
    pub = app / "pubspec.yaml"
    s = pub.read_text()
    if not old_pkg.search(s):
        # a Craft app that lists the game uses the new name already; any other app does not list it at all
        assert not old.search(s), "pubspec.yaml mentions the old game name but not its package: %s" % pub
        print("patch_renamed_games: pubspec has no %s dependency, nothing to rename" % g["old_pkg"])
        return
    block = re.search(re.escape(g["old_pkg"]) + r":\s*\n\s*git:\s*\n(?:\s+\w+:[^\n]*\n)+", s)
    assert block, "%s dependency block not found in %s" % (g["old_pkg"], pub)
    assert old_path.search(block.group(0)), "unexpected path in the dependency block: " + block.group(0)
    pub.write_text(rewrite(s, renames, regex))
    s2 = pub.read_text()
    assert g["new_pkg"] + ":" in s2 and "path: " + g["new_path"] in s2 and not old_pkg.search(s2) and \
        not old_path.search(s2), "pubspec rewrite failed"
    changed = 0
    for sub in ("lib", "test"):
        for f in sorted((app / sub).rglob("*.dart")) if (app / sub).is_dir() else []:
            t = f.read_text()
            if old.search(t):
                f.write_text(rewrite(t, renames, regex))
                changed += 1
    assert changed, "pubspec listed the game but no Dart file in lib/ or test/ referenced it"
    left = [str(f) for sub in ("lib", "test") if (app / sub).is_dir() for f in (app / sub).rglob("*.dart")
            if old.search(f.read_text())]
    assert not left, "old names left in: %s" % left
    reg = [f for f in (app / "lib").rglob("*.dart") if g["registry"] in f.read_text()]
    assert reg, "no registry imports %s after the rewrite" % g["registry"]
    if g.get("art"):
        # the app's own tile art still draws the old picture (a snake): swap in the new game's tile art
        src = (Path(__file__).resolve().parent.parent / g["art"]).read_text()
        art = app / "lib" / "ui" / "kit" / "game_art_data.dart"
        if art.is_file():
            t = art.read_text()
            key = re.escape("'" + g["art_id"] + "'")
            t2, n = re.subn(key + r": r\'\'\'.*?\'\'\'", lambda m: "'" + g["art_id"] + "': r\'\'\'" + " ".join(src.split()) + "\'\'\'", t, count=1, flags=re.S)
            assert n == 1, "tile art entry %s not found in %s" % (g["art_id"], art)
            art.write_text(t2)
    print("patch_renamed_games: %s in pubspec and %d Dart files" % (g["label"], changed))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    app = Path(sys.argv[1])
    for g in GAMES:
        patch(app, g)


if __name__ == "__main__":
    main()
