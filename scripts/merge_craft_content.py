#!/usr/bin/env python3
"""Merge the free content of the other Craft apps into one Craft app copy (W6: every Craft game plays every year).

    python3 scripts/merge_craft_content.py <app copy> <other app checkout> [<other app checkout> ...]

Run by build_game.sh on the TEMPORARY copy of the app, never on a checkout. For each other app it copies the free
packs (no product_id, status live) into <app copy>/assets/content/packs/, appends them to index.json and adds the
topics the copy does not have to topics.yaml. Pack files are copied byte for byte (their sha256 stays valid).
Nothing is written into the games-web repo, which is public.
"""
import json
import shutil
import sys
from pathlib import Path


def parse_topics(path):
    """{subject: {year: [(topic id, name)]}} in file order (indent based, no yaml lib)."""
    out, subject, year = {}, None, None
    if not path.exists():
        return out
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        key, _, name = line.strip().partition(":")
        key = key.strip()
        if indent == 0:
            subject, year = key, None
            out.setdefault(subject, {})
        elif indent == 2 and key.isdigit():
            year = int(key)
            out[subject].setdefault(year, [])
        elif indent == 4 and year is not None:
            out[subject][year].append((key, name.strip()))
    return out


def write_topics(path, topics):
    lines = ["# Merged by games-web (W6): the topics of every Craft app, in teaching order.", ""]
    for subject, years in topics.items():
        lines.append(f"{subject}:")
        for year in sorted(years):
            lines.append(f"  {year}:")
            for tid, name in years[year]:
                lines.append(f"    {tid}: {name}")
    path.write_text("\n".join(lines) + "\n")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    app = Path(sys.argv[1])
    content = app / "assets/content"
    index_path = content / "index.json"
    index = json.loads(index_path.read_text())
    have = {p["id"] for p in index["packs"]}
    topics = parse_topics(content / "topics.yaml")
    added = 0
    for other in map(Path, sys.argv[2:]):
        oc = other / "assets/content"
        if not (oc / "index.json").exists():
            print(f"merge: no content in {other}, skipped")
            continue
        for p in json.loads((oc / "index.json").read_text())["packs"]:
            if p.get("product_id") or p.get("status", "live") != "live" or p["id"] in have:
                continue
            src = oc / p["file"]["path"]
            dst = content / p["file"]["path"]
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                print(f"merge: {dst.name} exists, skipped")
                continue
            shutil.copyfile(src, dst)
            index["packs"].append(p)
            have.add(p["id"])
            added += 1
        for subject, years in parse_topics(oc / "topics.yaml").items():
            for year, lst in years.items():
                mine = topics.setdefault(subject, {}).setdefault(year, [])
                ids = {t for t, _ in mine}
                mine.extend((t, n) for t, n in lst if t not in ids)
    index_path.write_text(json.dumps(index, indent=1) + "\n")
    write_topics(content / "topics.yaml", topics)
    print(f"merge: {added} packs added, {len(index['packs'])} in total")


if __name__ == "__main__":
    main()
