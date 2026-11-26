#!/bin/bash
# Builds and runs rewrite_test.c against rewrite_hookable_thunks() exactly as it is in
# wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch (sdd d3dmetal-hookable: T2, HW2).
#
# The function is the text between the patch's "BODEGA HOOKABLE THUNKS BEGIN" and "END"
# markers. Each line there loses its one-character diff prefix: "+" for an added line and
# " " for a context line, as both end up in the patched loader.c. Any other line between
# the markers, or a missing or repeated marker, stops the script.
#
# It builds with AddressSanitizer and UndefinedBehaviorSanitizer, at -O0 and -O2, natively
# and, on Apple silicon with Rosetta, also for x86_64, the architecture the patch runs on.
# CC overrides the compiler (default: xcrun clang, or clang without xcrun).
#
# Usage: run_rewrite_test.sh [patch]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
patch=${1:-$repo/wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
inc=$tmp/rewrite_hookable_thunks.inc

if ! awk -v begin='/* BODEGA HOOKABLE THUNKS BEGIN */' -v end='/* BODEGA HOOKABLE THUNKS END */' '
  {
    prefix = substr($0, 1, 1); text = substr($0, 2)
    kept = (prefix == "+" || prefix == " ")
  }
  kept && text == begin { begins++; inside = 1; next }
  kept && text == end { if (!inside) bad = 1; ends++; inside = 0; next }
  !inside { next }
  $0 == "" { print ""; next }  # an empty context line, as patch(1) and git apply read one
  kept { print text; next }
  { printf "line %d between the markers is not in the patched file: %s\n", NR, $0 > "/dev/stderr"; bad = 1 }
  END {
    if (begins != 1 || ends != 1 || inside) { print "expected one BEGIN marker, then one END marker" > "/dev/stderr"; bad = 1 }
    exit bad
  }' "$patch" > "$inc"; then
  echo "cannot take rewrite_hookable_thunks out of $patch" >&2
  exit 1
fi
if command -v shasum > /dev/null; then sum=$(shasum -a 256 "$inc"); else sum=$(sha256sum "$inc"); fi
echo "rewrite_hookable_thunks: $(wc -l < "$inc" | tr -d ' ') lines from ${patch#"$repo"/}, sha256 ${sum%% *}"

if [ -n "${CC:-}" ]; then
  read -r -a cc <<< "$CC"
elif command -v xcrun > /dev/null; then
  cc=(xcrun clang)
else
  cc=(clang)
fi
archs=(native)
if [ -z "${CC:-}" ] && [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] \
   && arch -x86_64 /usr/bin/true 2> /dev/null; then
  archs=(arm64 x86_64)
fi

status=0
for arch in "${archs[@]}"; do
  arch_flags=()
  [ "$arch" = native ] || arch_flags=(-arch "$arch")
  for opt in -O0 -O2; do
    echo "== $arch $opt"
    bin=$tmp/rewrite_test-$arch$opt
    "${cc[@]}" ${arch_flags[@]+"${arch_flags[@]}"} -std=c99 -Wall -Wextra -Werror \
      -fsanitize=address,undefined -fno-sanitize-recover=all -g "$opt" \
      -I"$tmp" -o "$bin" "$here/rewrite_test.c"
    if ! "$bin"; then
      echo "FAILED: $arch $opt" >&2
      status=1
    fi
  done
done
exit "$status"
