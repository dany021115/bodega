#!/usr/bin/env bash
# Usage: check_isa.sh <elf file>...
# Fails if a file declares x86-64-v3 or x86-64-v4 as its needed ISA level: the dynamic loader
# refuses it with "CPU ISA level is lower than required" on older CPUs. A distro toolchain
# tuned for new CPUs (CachyOS) marks every binary it links, so build releases on ubuntu-24.04.
# BODEGA_ALLOW_NATIVE=1 skips the check, for a package that only runs on the machine that built it.
set -euo pipefail

if [ -n "${BODEGA_ALLOW_NATIVE:-}" ]; then
  exit 0
fi

bad=0
for file in "$@"; do
  needed="$(readelf -n "$file" 2>/dev/null | grep 'x86 ISA needed' || true)"
  if grep -qE 'x86-64-v[34]' <<<"$needed"; then
    echo "error: $file requires an x86-64-v3 or v4 CPU:${needed#*needed:}" >&2
    bad=1
  fi
done

if [ "$bad" != 0 ]; then
  cat >&2 <<'EOF'
That package would not start on older machines ("CPU ISA level is lower than required").
Use the release package, which is built on ubuntu-24.04 (workflow release-linux).
For one that only runs on this machine: BODEGA_ALLOW_NATIVE=1 tool/package_linux.sh
EOF
  exit 1
fi
