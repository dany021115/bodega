#!/bin/bash
# B2: fails if a layer imports what it must not. Generated files are skipped:
# they are `part of` a file that gets checked, or the DI wiring.
set -u
cd "$(dirname "$0")/.." || exit 2
status=0

# check <what it enforces> <regex of the forbidden import> <paths...>
check() {
  local rule=$1 forbidden=$2
  shift 2
  local found
  found=$(grep -rnE "^import ['\"]($forbidden)" "$@" --include='*.dart' \
    --exclude='*.freezed.dart' --exclude='*.g.dart' --exclude='*.config.dart')
  if [ -n "$found" ]; then
    echo "NO: $rule"
    echo "$found"
    status=1
  fi
}

check 'domain/ is pure Dart: no flutter, dart:io, engine or other layers' \
  'package:flutter/|dart:io|package:engine/|package:bodega/(data|device|app)/' \
  lib/domain
check 'only data/ imports package:engine' 'package:engine/' \
  lib/app lib/device lib/domain lib/main.dart lib/di.dart
check 'device/ does not import data/ or domain/' 'package:bodega/(data|domain)/' \
  lib/device
check 'absolute imports: package:bodega/...' '\.\.?/' lib

[ "$status" -eq 0 ] && echo 'Layers OK'
exit "$status"
