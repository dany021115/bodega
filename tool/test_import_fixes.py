#!/usr/bin/env python3
"""E1: tool/import_fixes.py on a small source tree. Standard library only.

    python3 -I tool/test_import_fixes.py
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def write(root, path, data):
    path = os.path.join(root, path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        if isinstance(data, list):
            f.write("".join(json.dumps(line) + "\n" for line in data))
        else:
            json.dump(data, f)


def game(gid, **fields):
    return {"id": gid, "title": gid.title(), "status": "community", "notes": f"{gid} notes",
            "provenance": "long text", "knownIssues": [], **fields}


def main():
    with tempfile.TemporaryDirectory() as src:
        write(src, "db/games/beta.json", game("beta", steam_appid=20, renderer="dxmt"))
        write(src, "db/games/alpha.json", game("alpha", steam_appid=10, renderer="dxvk"))
        write(src, "db/games/old.json", game("old", renderer="wined3d"))
        write(src, "db/games/vk.json", game("vk", renderer="vkd3d"))
        write(src, "db/games/locked.json", game(
            "locked", status="blocked-anticheat",
            anticheat={"names": ["Easy Anti-Cheat"], "macVerdict": "blocked", "note": "n"}))
        write(src, "recipes/games/alpha.json", {
            "id": "alpha", "kind": "game", "title": "Alpha", "requires": ["steam", "dotnet48"],
            "steps": [
                {"type": "renderer", "renderer": "d3dmetal"},
                {"type": "sync", "sync": "msync"},
                {"type": "environment", "name": "DXVK_CONFIG", "value": "a=b"},
                {"type": "note", "text": "recipe note"},
            ],
            "knownIssues": [{"symptom": "s", "cause": "c", "fix": "f"}],
        })
        write(src, "db/reports/alpha.jsonl", [
            {"game_id": "alpha", "rating": "5", "date": "2026-10-01T00:00:00Z"},
            {"game_id": "alpha", "rating": "x", "date": "2026-10-02T00:00:00Z"},
            {"rating": "3", "date": "2026-11-11T09:00:00Z"},
            {"game_id": "alpha", "rating": "2", "date": "2026-10-03T00:00:00Z"},
        ])
        out = os.path.join(src, "fixes_data.dart")
        run = subprocess.run([sys.executable, "-I", os.path.join(HERE, "import_fixes.py"),
                              "--src", src, "--out", out], capture_output=True, text=True, check=True)
        text = open(out).read()
        entries = json.loads(text.split("r'''", 1)[1].rsplit("'''", 1)[0])

    by = {e["id"]: e for e in entries}
    assert [e["id"] for e in entries] == ["alpha", "beta", "locked", "old", "vk"], list(by)
    alpha = by["alpha"]
    assert alpha["backends"] == {"mac": "d3dmetal"}, alpha["backends"]
    assert alpha["requires"] == ["dotnet48"], alpha["requires"]
    assert alpha["reports"] == {"count": 3, "median": 3, "last": "2026-11-11"}, alpha["reports"]
    assert alpha["steps"] == [{"type": "env", "name": "DXVK_CONFIG", "value": "a=b", "platforms": ["mac"]}]
    assert alpha["notes"] == ["alpha notes", "recipe note"], alpha["notes"]
    assert alpha["knownIssues"] == [{"symptom": "s", "cause": "c", "fix": "f"}]
    assert alpha["steam"] == 10 and alpha["status"] == "community"
    assert by["beta"]["backends"] == {"mac": "dxmt"} and by["beta"]["reports"] is None
    assert by["old"]["backends"] == {"mac": "wine"} and by["old"]["steam"] is None
    assert by["vk"]["backends"] == {}
    assert by["locked"]["status"] == "blocked"
    assert by["locked"]["antiCheat"] == {"names": ["Easy Anti-Cheat"], "verdict": "blocked"}
    assert all("provenance" not in e for e in entries)
    assert "const fixesCommit = 'bc72f85" in text
    for line in ("skipped renderer vkd3d: 1", "skipped requires steam: 1", "skipped step sync: 1",
                 "skipped report without a rating: 1"):
        assert line in run.stdout, run.stdout
    print("import_fixes: ok")


if __name__ == "__main__":
    main()
