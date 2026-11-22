#!/usr/bin/env python3
"""Build catalog.json for the landing page from the app checkouts and games.yaml.

    python3 scripts/make_catalog.py --apps <dir with the app checkouts> --out <catalog.json>

Games-first format (W6):
- `games`: one entry per playable game. Only games with `live: true` in games.yaml are listed.
  * Mind games (family mind): one entry per game in the app's lib/ui/game_registry.dart (kind "mind").
    Link: <slug>/#/game/<id>. Each game is listed once (Wingy and the Block games live inside the Mind games).
  * Craft games (family craft): one entry per free minigame (not coin-locked, Game mode) in
    <dist>/<slug>/minigames.json, written by build_game.sh from the app's real registry (kind "craft"). Every Craft game
    plays every year and topic, so `minYear`/`maxYear` are only the years the app was made for (a sort hint).
    Link: <slug>/#/play/<gameId> (year and topic come from the saved state).
    `playable` (B-13): the topic keys the game has enough questions for, by year (from minigames.json, written by the
    same minPool rule the game uses); the landing page and the in-game menu hide the card for a year with none.
- `craft`: the Craft apps with their year band (slug, title, minYear, maxYear); Learn opens in the band of the year.
- `years`: for every year with free content, the topics in teaching order (Maths, then English), merged over
  all Craft apps: {"<year>": [{"key": "maths/3/money", "subject", "topic", "title"}]}.
- Nothing here needs a network; the app checkouts are only read.
"""
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def read_games(path):
    games, cur = [], None
    for line in Path(path).read_text().splitlines():
        m = re.match(r"\s*-\s+slug:\s*(\S+)", line)
        if m:
            cur = {"slug": m.group(1)}
            games.append(cur)
            continue
        m = re.match(r"\s+(live|title|app|family):\s*(.+?)\s*$", line)
        if m and cur is not None:
            v = m.group(2).strip().strip('"')
            cur[m.group(1)] = (v == "true") if m.group(1) == "live" else v
    return games


def read_topics(topics_yaml):
    """{(subject, year): [(topic id, display name)]} from assets/content/topics.yaml (indent based, no yaml lib)."""
    order, subject, year = {}, None, None
    if not topics_yaml.exists():
        return order
    for raw in topics_yaml.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        key, _, name = line.strip().partition(":")
        key = key.strip()
        if indent == 0:
            subject, year = key, None
        elif indent == 2 and key.isdigit():
            year = int(key)
            order.setdefault((subject, year), [])
        elif indent == 4 and subject is not None and year is not None:
            order[(subject, year)].append((key, name.strip().strip('"\'')))
    return order


def free_packs(app_dir):
    index = json.loads((app_dir / "assets/content/index.json").read_text())
    return [p for p in index.get("packs", []) if not p.get("product_id") and p.get("status", "live") == "live"]


def year_topics(app_dirs):
    """{year: [topic entries]} for every (subject, year, topic) with a free pack in any Craft app."""
    have, names, order = set(), {}, {}
    for d in app_dirs:
        for p in free_packs(d):
            have.add((p["subject"], p["year"], p["topic"]))
        for (subj, yr), lst in read_topics(d / "assets/content/topics.yaml").items():
            order.setdefault((subj, yr), [])
            for tid, name in lst:
                if tid not in [t for t, _ in order[(subj, yr)]]:
                    order[(subj, yr)].append((tid, name))
                names[(subj, yr, tid)] = name
    # B-13: a pack topic that topics.yaml does not name is still played (the game lists it after the named ones, by id,
    # like the web shell does); list it here too so "Topic N of M" and the topic list agree with the game.
    for (sj, yr, tid) in sorted(have):
        order.setdefault((sj, yr), [])
        if tid not in [t for t, _ in order[(sj, yr)]]:
            order[(sj, yr)].append((tid, ""))
    out = {}
    for subj in ("maths", "english"):
        for (sj, yr), lst in sorted(order.items(), key=lambda kv: kv[0][1]):
            if sj != subj:
                continue
            for tid, name in lst:
                if (sj, yr, tid) in have:
                    out.setdefault(yr, []).append({
                        "key": f"{sj}/{yr}/{tid}", "subject": sj, "topic": tid,
                        "title": name or tid.replace("_", " ").capitalize(),
                    })
    # subjects other than maths and english (none today)
    for (sj, yr, tid) in sorted(have):
        if sj in ("maths", "english"):
            continue
        out.setdefault(yr, []).append({"key": f"{sj}/{yr}/{tid}", "subject": sj, "topic": tid,
                                       "title": names.get((sj, yr, tid)) or tid.replace("_", " ").capitalize()})
    return {str(y): out[y] for y in sorted(out)}


def mind_games(game, app_dir):
    text = (app_dir / "lib/ui/game_registry.dart").read_text()
    games = []
    for m in re.finditer(r"MiniGame\(\s*id:\s*'([^']+)',\s*title:\s*'([^']+)'", text):
        gid, title = m.group(1), m.group(2)
        games.append({
            "kind": "mind", "slug": game["slug"], "gameId": gid, "title": title,
            "from": game.get("title", game["slug"]), "art": gid,
            "link": f"{game['slug']}/#/game/{gid}",
        })
    return games


def craft_years(app_dir):
    ys = [p["year"] for p in free_packs(app_dir)]
    return (min(ys), max(ys)) if ys else (0, 12)


def craft_games(game, app_dir, dist=None):
    mini_file = Path(dist) / game["slug"] / "minigames.json" if dist else None
    if not (mini_file and mini_file.exists()):
        return []
    lo, hi = craft_years(app_dir)
    games = []
    for g in json.loads(mini_file.read_text()).get("games", []):
        if g["id"] == "quick_quiz" or g.get("access") == "coins" or "game" not in g.get("modes", []):
            continue
        entry = {
            "kind": "craft", "slug": game["slug"], "gameId": g["id"], "title": g["title"],
            "from": game.get("title", game["slug"]), "art": g["id"], "minYear": lo, "maxYear": hi,
            "link": f"{game['slug']}/#/play/{g['id']}",
        }
        # B-13: {"<year>": ["maths/3/money", ...]} = the topics this game has enough questions for. The page shows the
        # game on a card only when the chosen year has at least one; a direct link still opens it (no-questions screen).
        if isinstance(g.get("playable"), dict):
            entry["playable"] = {y: t for y, t in g["playable"].items() if t}
        games.append(entry)
    return games


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apps", required=True, help="folder with the app checkouts, named like the repos")
    ap.add_argument("--games", default=str(Path(__file__).resolve().parent.parent / "games.yaml"))
    ap.add_argument("--dist", help="folder with the built games (<slug>/minigames.json), for the Craft minigame cards")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    games, craft, craft_dirs = [], [], []
    for g in read_games(a.games):
        if not g.get("live"):
            continue
        app_dir = Path(a.apps) / g["app"].split("/", 1)[1]
        if not app_dir.is_dir():
            sys.exit(f"no checkout for {g['slug']} at {app_dir}")
        if g.get("family") == "mind":
            games += mind_games(g, app_dir)
        else:
            lo, hi = craft_years(app_dir)
            craft.append({"slug": g["slug"], "title": g.get("title", g["slug"]), "minYear": lo, "maxYear": hi})
            craft_dirs.append(app_dir)
            games += craft_games(g, app_dir, a.dist)
    out = {"format": 2, "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
           "craft": craft, "years": year_topics(craft_dirs), "games": games}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1) + "\n")
    topics = sum(len(v) for v in out["years"].values())
    print(f"catalog: {len(games)} games, {len(out['years'])} years, {topics} topics -> {a.out}")


if __name__ == "__main__":
    main()
