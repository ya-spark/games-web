#!/usr/bin/env python3
"""Build catalog.json for the landing page from the app checkouts and games.yaml.

    python3 scripts/make_catalog.py --apps <dir with the app checkouts> --out <catalog.json>

- Only games with `live: true` in games.yaml are listed.
- Mind games (family mind): one Fun card per game in the app's lib/ui/game_registry.dart.
  Link: <slug>/#/game/<id>. Each Fun game is listed once (Wingy and the Block games live inside the Mind games).
- Craft games (family craft): one Learn card per free pack in the app's assets/content/index.json
  (the built-in starter packs; a pack with a product_id is for sale and is not on the web).
  Link: <slug>/#/quiz/<subject>/<year>/<topic>. Order inside a year follows assets/content/topics.yaml.
- Craft minigames: when `--dist <dir>` is given and `<dir>/<slug>/minigames.json` exists (written by build_game.sh from the
  app's real registry), one extra Learn card per free minigame (not coin-locked, Game mode) and per topic that has
  enough items of the types the game plays and falls inside the game's years. Link:
  <slug>/#/play/<gameId>/<subject>/<year>/<topic>. The page shows these only when that game is picked in the Game filter.
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


def topic_order(topics_yaml):
    """{(subject, year): [topic ids in teaching order]} from assets/content/topics.yaml (indent based, no yaml lib)."""
    order, subject, year = {}, None, None
    if not topics_yaml.exists():
        return order
    for raw in topics_yaml.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        key = line.strip().split(":", 1)[0].strip()
        if indent == 0:
            subject, year = key, None
        elif indent == 2 and key.isdigit():
            year = int(key)
            order.setdefault((subject, year), [])
        elif indent == 4 and subject is not None and year is not None:
            order[(subject, year)].append(key)
    return order


def mind_cards(game, app_dir):
    text = (app_dir / "lib/ui/game_registry.dart").read_text()
    cards = []
    for m in re.finditer(r"MiniGame\(\s*id:\s*'([^']+)',\s*title:\s*'([^']+)'", text):
        gid, title = m.group(1), m.group(2)
        cards.append({
            "kind": "fun", "id": f"{game['slug']}:{gid}", "gameId": gid, "title": title,
            "slug": game["slug"], "from": game.get("title", game["slug"]),
            "art": gid, "link": f"{game['slug']}/#/game/{gid}",
        })
    return cards


def minigame_cards(game, app_dir, packs, mini):
    cards = []
    free = [g for g in mini.get("games", [])
            if g["id"] != "quick_quiz" and g.get("access") != "coins" and "game" in g.get("modes", [])]
    for p in packs:
        try:
            items = json.loads((app_dir / "assets/content" / p["file"]["path"]).read_text())["items"]
        except (OSError, KeyError, ValueError):
            continue
        counts = {}
        for it in items:
            counts[it.get("type")] = counts.get(it.get("type"), 0) + 1
        for g in free:
            if not g["minYear"] <= p["year"] <= g["maxYear"]:
                continue
            if sum(counts.get(t, 0) for t in g["itemTypes"]) < g["minPool"]:
                continue
            cards.append({
                "kind": "learn", "id": f"{game['slug']}:{g['id']}:{p['subject']}:{p['year']}:{p['topic']}",
                "title": p["title"], "subject": p["subject"], "year": p["year"], "topic": p["topic"],
                "items": p.get("items", 0), "game": g["title"], "gameId": g["id"],
                "slug": game["slug"], "from": game.get("title", game["slug"]), "art": g["id"],
                "link": f"{game['slug']}/#/play/{g['id']}/{p['subject']}/{p['year']}/{p['topic']}",
            })
    return cards


def craft_cards(game, app_dir, dist=None):
    index = json.loads((app_dir / "assets/content/index.json").read_text())
    order = topic_order(app_dir / "assets/content/topics.yaml")
    packs = [p for p in index.get("packs", []) if not p.get("product_id") and p.get("status", "live") == "live"]

    def sort_key(p):
        ids = order.get((p["subject"], p["year"]), [])
        pos = ids.index(p["topic"]) if p["topic"] in ids else len(ids)
        return (p["subject"], p["year"], pos, p["topic"])

    cards = []
    for p in sorted(packs, key=sort_key):
        cards.append({
            "kind": "learn", "id": f"{game['slug']}:{p['subject']}:{p['year']}:{p['topic']}",
            "title": p["title"], "subject": p["subject"], "year": p["year"], "topic": p["topic"],
            "items": p.get("items", 0), "game": "Quick quiz", "gameId": "quick_quiz",
            "slug": game["slug"], "from": game.get("title", game["slug"]), "art": "quick_quiz",
            "link": f"{game['slug']}/#/quiz/{p['subject']}/{p['year']}/{p['topic']}",
        })
    mini_file = Path(dist) / game["slug"] / "minigames.json" if dist else None
    if mini_file and mini_file.exists():
        cards += minigame_cards(game, app_dir, sorted(packs, key=sort_key), json.loads(mini_file.read_text()))
    return cards


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apps", required=True, help="folder with the app checkouts, named like the repos")
    ap.add_argument("--games", default=str(Path(__file__).resolve().parent.parent / "games.yaml"))
    ap.add_argument("--dist", help="folder with the built games (<slug>/minigames.json), for the Craft minigame cards")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    cards = []
    for g in read_games(a.games):
        if not g.get("live"):
            continue
        app_dir = Path(a.apps) / g["app"].split("/", 1)[1]
        if not app_dir.is_dir():
            sys.exit(f"no checkout for {g['slug']} at {app_dir}")
        fam = g.get("family")
        cards += mind_cards(g, app_dir) if fam == "mind" else craft_cards(g, app_dir, a.dist)
    out = {"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "cards": cards}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1) + "\n")
    fun = sum(1 for c in cards if c["kind"] == "fun")
    print(f"catalog: {fun} fun, {len(cards) - fun} learn -> {a.out}")


if __name__ == "__main__":
    main()
