#!/bin/bash
# Builds hook_harness.exe (HC2 of specs/checks.md): hook_harness.cpp with PolyHook 2, MinHook and
# the rewrite function of wine/patches/0030, statically, with zig for x86_64-windows-gnu.
# It fetches nothing: the third-party sources are checked out beforehand, outside the repo.
#
# Usage: build_hook_harness.sh <third-party-dir> [<out-dir>]
#   <third-party-dir>/PolyHook_2_0  PolyHook 2 with its submodules: zydis (and its
#                                   dependencies/zycore), asmjit, asmtk
#   <third-party-dir>/minhook       MinHook
#   <out-dir>                       default <third-party-dir>/build; gets hook_harness.exe
# ZIG is the zig command, e.g. ZIG='python3 -m ziglang' after `pip install ziglang` in a venv,
# as for packages/engine/tool/build_probe.sh.
#
# Checked 2026-11-25 (zig 0.17.1) with these commits, fetched shallow into a scratch folder:
#   stevemk14ebr/PolyHook_2_0  b0aac632f427cd730c88b9b5198c6669aa05d02f (2023-07-19, "Revert ff25
#                              size calculations"). Its parent 0d4d90e35ecc8ead9940c23cd29e7d8952b1bcb6,
#                              the last commit before 2023-07-19, adds 8 bytes to the prologue size and
#                              refuses to hook a thunk ("Function too small to hook safely!").
#     zydis  d4c37ae7a9db989495eb66636a65d8d4ff69eb35, its zycore 685c3350ef91b566af7eef7c332467e3a027ea0f
#     asmjit 3577608cab0bc509f856ebf6e41b2f9d9f71acc4, asmtk 6e25b8983fbd8bf455c01ed7c5dd40c99b789565
#   TsudaKageyu/minhook        0f25a2449b3cf878bcbdbf91b693c38149ecf029 (2023-05-15)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "${1:?usage: build_hook_harness.sh <third-party-dir> [<out-dir>]}" && pwd)
out=${2:-$src/build}
ZIG=${ZIG:-zig}
patch=$(git -C "$here" rev-parse --show-toplevel)/wine/patches/0030-ntdll-hookable-d3dmetal-thunks.patch
ph=$src/PolyHook_2_0
zydis=$ph/zydis
zycore=$zydis/dependencies/zycore
asmjit=$ph/asmjit
asmtk=$ph/asmtk
mh=$src/minhook
for dir in "$ph/sources" "$zydis/src" "$zycore/src" "$asmjit/src/asmjit" "$asmtk/src/asmtk" "$mh/src"; do
  [[ -d $dir ]] || { echo "missing $dir" >&2; exit 1; }
done
mkdir -p "$out"

# The patch's rewrite function as loader.c gets it: the lines between its markers, without the
# diff's first column; a removed line ("-") would not be in loader.c, so it is dropped.
awk '/BODEGA HOOKABLE THUNKS BEGIN/ { on = 1; next }
     /BODEGA HOOKABLE THUNKS END/ { on = 0 }
     on && /^[+ ]/ { print substr($0, 2) }
     on && /^$/ { print "" }' "$patch" > "$out/hookable_thunks.inc"
grep -q 'rewrite_hookable_thunks' "$out/hookable_thunks.inc" ||
  { echo "no rewrite_hookable_thunks between the markers of $patch" >&2; exit 1; }

target=(-target x86_64-windows-gnu)
defines=(-DZYCORE_STATIC_BUILD -DZYDIS_STATIC_BUILD -DASMJIT_STATIC -DASMJIT_NO_AARCH64 -DASMTK_STATIC)
includes=(-I"$ph" -I"$zydis/include" -I"$zydis/src" -I"$zycore/include" -I"$asmjit/src"
  -I"$asmtk/src" -I"$mh/include" -I"$out")
jobs=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
objects=()
pids=()

# compile <cc|c++> <object subdir> <source>...: third-party code, warnings off, in parallel.
compile() {
  local lang=$1 dir=$2 source object
  shift 2
  mkdir -p "$out/obj/$dir"
  for source in "$@"; do
    object=$out/obj/$dir/$(basename "${source%.*}").o
    objects+=("$object")
    if [[ $lang == c++ ]]; then
      $ZIG c++ "${target[@]}" -O2 -std=c++17 "${defines[@]}" "${includes[@]}" -w -c "$source" -o "$object" &
    else
      $ZIG cc "${target[@]}" -O2 "${defines[@]}" "${includes[@]}" -w -c "$source" -o "$object" &
    fi
    pids+=($!)
    if (( ${#pids[@]} >= jobs )); then
      wait "${pids[0]}"
      pids=(${pids[@]+"${pids[@]:1}"})
    fi
  done
}

compile cc zycore "$zycore"/src/*.c "$zycore"/src/API/*.c
compile cc zydis "$zydis"/src/*.c
compile c++ asmjit "$asmjit"/src/asmjit/core/*.cpp "$asmjit"/src/asmjit/x86/*.cpp
compile c++ asmtk "$asmtk"/src/asmtk/*.cpp
# What CMakeLists.txt builds for the core, the x64 detour and its disassembler.
compile c++ polyhook "$ph"/sources/{MemProtector,MemAccessor,FBAllocator,RangeAllocator,ErrorLog,UID,Misc,PolyHookOs,ADetour,x64Detour,ZydisDisassembler}.cpp
compile cc minhook "$mh"/src/{buffer,hook,trampoline}.c "$mh"/src/hde/hde64.c
for pid in ${pids[@]+"${pids[@]}"}; do wait "$pid"; done

# The harness's own warnings only: third-party headers count as system headers here.
$ZIG c++ "${target[@]}" -O1 -std=c++17 "${defines[@]}" -isystem "$ph" -isystem "$zydis/include" \
  -isystem "$zycore/include" -isystem "$asmjit/src" -isystem "$asmtk/src" -isystem "$mh/include" \
  -I"$out" -Wall -o "$out/hook_harness.exe" "$here/hook_harness.cpp" "${objects[@]}" -luser32 -lkernel32
echo "built $out/hook_harness.exe"
