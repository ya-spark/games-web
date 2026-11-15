#!/usr/bin/env python3
"""Build catalog.json for the landing page from the app checkouts and games.yaml.

    python3 scripts/make_catalog.py --apps <dir with the app checkouts> --out <catalog.json>

- Only games with `live: true` in games.yaml are listed.
- Mind games (family mind): one Fun card per game in the app's lib/ui/game_registry.dart.
  Link: <slug>/#/game/<id>. Each Fun game is listed once (Wingy and the Block games live inside the Mind games).
- Craft games (family craft): one Learn card per free pack in the app's assets/content/index.json
  (the built-in starter packs; a pack with a product_id is for sale and is not on the web).
  Link: <slug>/#/quiz/<subject>/<year>/<topic>. Order inside a year follows assets/content/topics.yaml.
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


def craft_cards(game, app_dir):
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
    return cards


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apps", required=True, help="folder with the app checkouts, named like the repos")
    ap.add_argument("--games", default=str(Path(__file__).resolve().parent.parent / "games.yaml"))
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
        cards += mind_cards(g, app_dir) if fam == "mind" else craft_cards(g, app_dir)
    out = {"generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "cards": cards}
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1) + "\n")
    fun = sum(1 for c in cards if c["kind"] == "fun")
    print(f"catalog: {fun} fun, {len(cards) - fun} learn -> {a.out}")


if __name__ == "__main__":
    main()
