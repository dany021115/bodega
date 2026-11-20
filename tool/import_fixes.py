#!/usr/bin/env python3
"""Regenerates packages/engine/lib/fixes_data.dart from highball-db (CC0-1.0).

    tool/import_fixes.py [--src DIR] [--commit SHA] [--out FILE]

Without --src it downloads the pinned commit. One entry per game of db/games,
with its recipe of recipes/games (same id) and a summary of db/reports.
Only what the engine can apply is kept; everything else is counted and
reported, never dropped silently:

  - environment steps whose variable is in ENV_ALLOWED,
  - registry steps under HKCU or HKLM\\Software,
  - dlloverride steps,
  - the renderer, as the Mac's backend (wined3d is Bodega's wine),
  - the runtimes Bodega has (RUNTIMES), from the recipe's requires,
  - the notes and the known issues, as text (in English, as upstream wrote them).

Every kept step and backend is for the Mac, the only place upstream verified
them: a host applies only what is tagged for it (see fixes.dart).
"""
import argparse
import collections
import glob
import io
import json
import os
import statistics
import sys
import tarfile
import urllib.request

COMMIT = "bc72f85d3670ba793451ac5b95759acfadb84f4d"
REPO = "gauthierpiarrette/highball-db"
# Variables our Wine and Bodega know. HB_* belong to Highball's own engine patches,
# FEX_* and MVK_* to the arm64 line, and CX_* to CrossOver's build.
ENV_ALLOWED = {
    "ROSETTA_ADVERTISE_AVX",
    "D3DM_VENDOR_ID",
    "D3DM_DEVICE_ID",
    "D3DM_DEVICE_DESCRIPTION",
    "VKD3D_FEATURE_LEVEL",
    "VKD3D_SHADER_MODEL",
    "VKD3D_CONFIG",
    "DXVK_CONFIG",
}
REGISTRY_ROOTS = ("HKCU\\", "HKLM\\Software\\")
# Highball's renderers that Bodega's Mac has, by Bodega's name.
BACKENDS = {"dxmt": "dxmt", "d3dmetal": "d3dmetal", "dxvk": "dxvk", "wined3d": "wine"}
# The ids of packages/engine/lib/dependencies.dart (fixes_test checks every one).
RUNTIMES = {
    "vcrun2005", "vcrun2008", "vcrun2010", "vcrun2012", "vcrun2013", "vcrun2022",
    "dotnet48", "d3dx9", "d3dx10", "d3dx11_43", "d3dcompiler_47", "xact", "physx", "corefonts",
}
BLOCKED = {"blocked-anticheat", "blocked-publisher"}
OUT = os.path.join(os.path.dirname(__file__), "..", "packages", "engine", "lib", "fixes_data.dart")


def fetch(commit):
    url = f"https://codeload.github.com/{REPO}/tar.gz/{commit}"
    with urllib.request.urlopen(url, timeout=120) as response:
        data = response.read()
    tar = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")
    root = tar.getnames()[0].split("/")[0]
    target = os.path.join(os.environ.get("TMPDIR", "/tmp"), f"highball-db-{commit[:7]}")
    tar.extractall(target, filter="data")
    return os.path.join(target, root)


def issues(items):
    return [
        {"symptom": i["symptom"], "cause": i.get("cause") or "", "fix": i.get("fix") or ""}
        for i in items or []
    ]


def summary(path, skipped):
    """Count, median and last day of a game's reports; its file names the game."""
    if not os.path.exists(path):
        return None
    ratings, dates = [], []
    for line in open(path):
        if not line.strip():
            continue
        report = json.loads(line)
        rating = str(report.get("rating"))
        if rating not in {"1", "2", "3", "4", "5"}:
            skipped["report without a rating"] += 1
            continue
        ratings.append(int(rating))
        dates.append((report.get("date") or "")[:10])
    if not ratings:
        return None
    return {"count": len(ratings), "median": statistics.median_low(ratings), "last": max(dates)}


def convert(game, recipe, reports, skipped):
    gid = game["id"]
    steps, notes = [], []
    if game.get("notes"):
        notes.append(game["notes"])
    renderer = game.get("renderer")
    requires = []
    if recipe:
        renderer = recipe.get("renderer") or renderer
        for step in recipe["steps"]:
            kind = step["type"]
            if kind == "note":
                notes.append(step["text"])
            elif kind == "environment" and step["name"] in ENV_ALLOWED:
                steps.append({"type": "env", "name": step["name"], "value": step["value"], "platforms": ["mac"]})
            elif kind == "registry" and step["key"].startswith(REGISTRY_ROOTS):
                steps.append({
                    "type": "registry", "key": step["key"], "name": step["name"],
                    "valueType": step["valueType"], "data": step["data"], "platforms": ["mac"],
                })
            elif kind == "dlloverride":
                steps.append({"type": "dlloverride", "value": step["value"], "platforms": ["mac"]})
            elif kind == "renderer":
                renderer = step["renderer"]
            else:
                label = step.get("name", "") if kind == "environment" else ""
                skipped[f"step {kind} {label}".rstrip()] += 1
        for need in recipe.get("requires", []):
            if need in RUNTIMES:
                requires.append(need)
            else:
                skipped[f"requires {need}"] += 1
    backends = {}
    if renderer in BACKENDS:
        backends["mac"] = BACKENDS[renderer]
    elif renderer:
        skipped[f"renderer {renderer}"] += 1
    cheat = game.get("anticheat")
    verified = (recipe or {}).get("lastVerified")
    if verified:
        verified = {k: verified.get(k) for k in ("date", "engine", "chip")}
    elif game.get("verified"):
        verified = {"date": game.get("lastVerified"), "engine": game["verified"].get("engine"),
                    "chip": game["verified"].get("chip")}
    else:
        verified = None
    return {
        "id": gid,
        "title": game["title"],
        "steam": game.get("steam_appid"),
        "status": "blocked" if game["status"] in BLOCKED else "community",
        "backends": backends,
        "antiCheat": {"names": cheat["names"], "verdict": cheat["macVerdict"]} if cheat else None,
        "reports": reports,
        "nativeMac": bool(game.get("nativeMac")),
        "optIn": bool((recipe or {}).get("optIn")),
        "requires": requires,
        "steps": steps,
        "notes": notes,
        "knownIssues": issues(game.get("knownIssues")) + issues((recipe or {}).get("knownIssues")),
        "verified": verified,
        "source": f"db/games/{gid}.json",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", help="a highball-db checkout; default: download the pinned commit")
    parser.add_argument("--commit", default=COMMIT)
    parser.add_argument("--out", default=OUT)
    args = parser.parse_args()
    src = args.src or fetch(args.commit)

    recipes = {}
    for path in glob.glob(os.path.join(src, "recipes", "games", "*.json")):
        recipe = json.load(open(path))
        recipes[recipe["id"]] = recipe
    skipped = collections.Counter()
    entries = []
    for path in sorted(glob.glob(os.path.join(src, "db", "games", "*.json"))):
        game = json.load(open(path))
        reports = summary(os.path.join(src, "db", "reports", game["id"] + ".jsonl"), skipped)
        entries.append(convert(game, recipes.pop(game["id"], None), reports, skipped))
    for gid in recipes:
        skipped[f"recipe without a game: {gid}"] += 1
    entries.sort(key=lambda e: e["id"])

    # One game per line: a diff shows which games changed.
    text = "[\n" + ",\n".join(json.dumps(e, ensure_ascii=False) for e in entries) + "\n]"
    if "'''" in text:
        sys.exit("a string holds ''', which the Dart raw string cannot carry")
    header = (
        f"/// Per-game configurations (F1), from {REPO} at {args.commit[:7]} (CC0-1.0):\n"
        "/// db/games, recipes/games and a summary of db/reports.\n"
        "/// Generated by tool/import_fixes.py: do not edit by hand. Text in the app, not a file,\n"
        "/// because `dart compile exe` carries no assets. Notes and known issues are in English, as upstream wrote them.\n"
        "/// Nothing here comes from CrossOver's data.\n"
        "const fixesCommit = '" + args.commit + "';\n"
        "const fixesJson = r'''\n"
    )
    with open(args.out, "w") as out:
        out.write(header + text + "\n''';\n")

    count = lambda test: sum(1 for e in entries if test(e))
    print(f"{len(entries)} games -> {os.path.normpath(args.out)}")
    print(f"  with steps {count(lambda e: e['steps'])}, with a backend {count(lambda e: e['backends'])}, "
          f"blocked {count(lambda e: e['status'] == 'blocked')}, with reports {count(lambda e: e['reports'])}, "
          f"with runtimes {count(lambda e: e['requires'])}")
    for what, times in sorted(skipped.items()):
        print(f"  skipped {what}: {times}")


if __name__ == "__main__":
    main()
