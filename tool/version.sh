#!/usr/bin/env bash
# SemVer helper for apps/bodega/pubspec.yaml (line: version: X.Y.Z+N).
set -euo pipefail

cd "$(dirname "$0")/.."

PUBSPEC=apps/bodega/pubspec.yaml

usage() {
  echo "usage: tool/version.sh get | bump patch|minor|major | check" >&2
  exit 64
}

die() {
  echo "error: $*" >&2
  exit 1
}

# Sets VER (X.Y.Z) and BUILD (N) from the pubspec.
load() {
  local line
  line=$(grep -m1 '^version:' "$PUBSPEC" || true)
  if [[ ! $line =~ ^version:\ ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
    die "$PUBSPEC: the 'version:' line must have the form X.Y.Z+N"
  fi
  VER=${BASH_REMATCH[1]}
  BUILD=${BASH_REMATCH[2]}
}

# Last vX.Y.Z tag reachable from HEAD, or empty when there is none.
last_tag() {
  git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true
}

# True when version $1 is strictly lower than $2.
ver_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]
}

write_version() {
  local tmp="$PUBSPEC.tmp"
  sed "s/^version: .*/version: $1+$2/" "$PUBSPEC" > "$tmp" || { rm -f "$tmp"; exit 1; }
  mv "$tmp" "$PUBSPEC"
}

cmd_bump() {
  local level=$1 tag base maj min pat target
  case $level in
    patch|minor|major) ;;
    *) usage ;;
  esac
  load
  tag=$(last_tag)
  if [ -z "$tag" ]; then
    echo "No version released yet (no tags): $VER stays the same."
    exit 0
  fi
  base=${tag#v}
  IFS=. read -r maj min pat <<< "$base"
  case $level in
    patch) pat=$((pat + 1)) ;;
    minor) min=$((min + 1)); pat=0 ;;
    major) maj=$((maj + 1)); min=0; pat=0 ;;
  esac
  target="$maj.$min.$pat"
  if ! ver_lt "$VER" "$target"; then
    echo "$VER already covers this level (from $tag, $target or higher is enough): nothing changes."
    exit 0
  fi
  write_version "$target" "$((BUILD + 1))"
  echo "Version: $VER+$BUILD -> $target+$((BUILD + 1))"
}

cmd_check() {
  local tag base changes
  load
  tag=$(last_tag)
  if [ -z "$tag" ]; then
    echo "No version released yet (no tags): $VER. Check OK."
    exit 0
  fi
  base=${tag#v}
  if ver_lt "$VER" "$base"; then
    die "$VER is lower than the tag $tag. Raise the version with tool/version.sh bump <level>."
  fi
  if [ "$VER" = "$base" ]; then
    # Tracked changes (committed or not) plus untracked files, minus docs and specs.
    changes=$({ git diff --name-only "$tag"; git ls-files --others --exclude-standard; } \
      | grep -Ev '^(\.sdd/|\.claude/|AGENTS\.md$)|\.md$' || true)
    if [ -n "$changes" ]; then
      echo "There are product changes since $tag and the version was not raised ($VER):" >&2
      echo "$changes" >&2
      die "run tool/version.sh bump patch|minor|major to match the work, then run check again."
    fi
  fi
  echo "OK: version $VER (tag $tag)."
}

case "${1:-}" in
  get)
    [ $# -eq 1 ] || usage
    load
    echo "$VER"
    ;;
  bump)
    [ $# -eq 2 ] || usage
    cmd_bump "$2"
    ;;
  check)
    [ $# -eq 1 ] || usage
    cmd_check
    ;;
  *)
    usage
    ;;
esac

# Examples:
#   tool/version.sh get            # prints 1.0.0
#   tool/version.sh bump minor     # with tag v1.0.0: 1.0.0+1 -> 1.1.0+2; repeating it changes nothing
#   tool/version.sh check          # fails if product files changed since the last tag and the version was not raised
