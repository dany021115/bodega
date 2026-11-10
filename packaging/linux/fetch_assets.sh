#!/usr/bin/env bash
# Downloads to packaging/linux/cache/<name>/ whatever from assets.json is missing, and checks its sha256.
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
cache="$dir/cache"

python3 -I -c '
import json, sys
for a in json.load(open(sys.argv[1]))["assets"]:
    print(a["name"], a["url"], a["sha256"], sep="\t")
' "$dir/assets.json" | while IFS=$'\t' read -r name url sha; do
  file="$cache/$name/$(basename "$url")"
  mkdir -p "$cache/$name"
  if ! echo "$sha  $file" | sha256sum -c --status 2>/dev/null; then
    curl -fLC - --retry 5 -o "$file" "$url"
    echo "$sha  $file" | sha256sum -c
  fi
done
