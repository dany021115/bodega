# Exploration: engine-prototype

SDD **explore** phase · 2026-10-30 · no code changes · status: awaiting approval to move on to `propose`. When something says "unverified" or "read", it means it was not checked by running it.

**Legend.** The `#Lx-Ly` anchors point to lines in the pinned commit.

| Alias | Path | Note |
|---|---|---|
| `CX` | `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad/research/src/cx-26.3/sources/wine` | CrossOver 26.3's Wine. It is volatile; it is rebuilt with `BE/inputs.json:4-6` |
| `SP` | `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad` | Dart experiments in `SP/dartplat/exp/`, upstream log in `SP/hblog-1793389283/`, copies of Highball, Whisky and Mythic in `SP/ops5/` |
| `BE` | `/Users/quasar/Documents/GitHub/Bodega/bodega-engine` | |
| `INV` | `/Users/quasar/Documents/investigacion-launcher` | |
| `HB` | `https://github.com/gauthierpiarrette/highball/blob/aac8cdc4630ca35ad1f79acf9db5bbc1b5e760fc` | `HBK` = `HB/Sources/HighballKit` |
| `WH` | `https://github.com/Whisky-App/Whisky/blob/fd5480a76b3ebfe3419a1ab86ca3695f5cc328f8/WhiskyKit/Sources/WhiskyKit` | |
| `MY` | `https://github.com/MythicApp/Mythic/blob/754223978e61fb6efcff1e3152ae426bad0020b7/Mythic/Utilities` | |
| `DSDK` | `/opt/homebrew/share/flutter/bin/cache/dart-sdk` | Dart 3.13.0 |
| `DVM` | `https://github.com/dart-lang/sdk/blob/3.13.0/runtime/bin` | |
| `RT` | `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine-wine-11.0-20261030T202616Z-primer-build.tar.gz` | First runtime. It was only listed with `tar -tvzf`; it was not extracted |

## 1. Problem and scope

It is the first deliverable of phase F0 (`INV/INFORME-FINAL.md:720`): a pure Dart package, `engine`, plus a CLI compiled with `dart compile exe`. It has to do five things:

1. Install and locate the `bodega-engine` runtime.
2. Create a win64 bottle.
3. Launch an `.exe` with the right environment.
4. Write one log per run.
5. Wait for the bottle's wineserver, or kill it.

Out of scope:
- the Flutter UI;
- the gamedb (`INV/INFORME-FINAL.md:423-535`);
- per-game DXMT (`:270-279`);
- the stores (`:352-421`);
- arm64 (`:723`).

**Starting point**
- The `bodega` repo is empty: branch `master`, no commits. What needs to be understood is three existing pieces: the contract that `BE/.github/workflows/build.yml` produces, the `CX` tree and `dart:io`.
- Run 41110607147 finished successfully on 2026-10-30, and `RT` is already downloaded: 334 861 341 B, the same size as the published asset. `shasum -a 256 -c` gives OK.

## 2. The runtime contract

### 2.1 Tarball and binaries

- **Packaging.** `engine-<version>-<UTC>-<note>.tar.gz` plus its `.sha256`, published in a private release whose tag is that name (`BE/.github/workflows/build.yml:117-119,134-136`; `/Users/quasar/Documents/GitHub/Bodega/crear-repo.sh:9`). It takes 1065 MB uncompressed (`SP/hblog-1793389283/log.tail:2505`).
- **Contents of `RT`.** 5243 entries, all with the `./` prefix: `engine/{bin,lib,share}` and three empty folders (`renderers/`, `frameworks/`, `tools/`). There is no `manifest.json`, no `.dylib` and no `i386-unix` (`build.yml:78-79,118`). It keeps the execute permissions; the mtime of `wine.inf` is the build time.
- **Binaries.** `bin/` only has `wine` and `wineserver` (`build.yml:74`). `bin/wine` does an `execv` to the real loader, `lib/wine/x86_64-unix/wine`, without changing PID (`CX/dlls/ntdll/unix/loader.c:2523-2547`). There is no `wine64`, `wine-preloader` or `bin/wineboot` (`CX/configure.ac:948-959,2105`), so helpers are launched as `bin/wine wineboot`.
- **DLLs.**
  - It ships Wine's `d3d11/dxgi/d3d10core`. From DXMT v0.80 it only brings the placeholder `winemetal.dll`, without `winemetal.so` (`build.yml:96-106`), so without an overlay DX10/11 goes through wined3d.
  - Mono 10.4.1 and Gecko 2.47.4 are in `share/wine` (`build.yml:85-95`).
- **The host libraries are missing.**
  - FreeType, GnuTLS, SDL2 and MoltenVK are loaded by short name (`SP/hblog-1793389283/log.part:966-988`; `CX/aclocal.m4:61-72`), and `winedmo.so` links against Intel Homebrew's FFmpeg (`CX/dlls/winedmo/Makefile.in:6`).
  - On this Mac `/usr/local/lib` only has `libmetalirconverter.dylib`, so fonts (`CX/dlls/win32u/freetype.c:1483-1486`), TLS, SDL and Vulkan are missing.
  - MoltenVK is not essential: neither DXMT nor wined3d needs it, because with patch 0002 wined3d tries OpenGL first. Without MoltenVK only an `err:` shows up (`CX/dlls/win32u/vulkan.c:3005-3016`; `BE/patches/0002-wined3d-auto-renderer-opengl-first.patch:1-30`).
- **Health.**
  - `bin/wine --version` prints `wine-11.0` without a prefix (`CX/dlls/ntdll/unix/loader.c:2555-2604`).
  - The 6 minimum files are in `RT` (`HBK/EngineStore.swift#L637-L646`): `bin/{wine,wineserver}`, `x86_64-windows/{kernel32,ntdll}.dll`, `i386-windows/kernel32.dll` and `x86_64-unix/ntdll.so`.
  - errno 86 means Rosetta is missing (`HBK/WineRunner.swift#L236-L246`). To check for it beforehand: `/usr/bin/arch -x86_64 /usr/bin/true`, which returns 0 here.
  - It is relocatable: the paths come from `realpath(ntdll.so)` (`CX/dlls/ntdll/unix/loader.c:475-499`).

### 2.2 Minimal environment

| Variable | Rule | Ref |
|---|---|---|
| `WINEPREFIX` | The only required one. It has to be an absolute path; otherwise it is a fatal error | `CX/dlls/ntdll/unix/loader.c:462-463` |
| `WINEMSYNC` (`0` or `1`) | Always explicit and with the same value across the whole bottle. Unset means off | `CX/dlls/ntdll/unix/msync.c:417-424` |
| `WINEDEBUG=fixme-all` | `err:` lines still come out | `HBK/Bottle.swift#L756` |
| `WINEDLLOVERRIDES=winemenubuilder.exe=d` | Keeps shortcuts from showing up on the Desktop | `HBK/Bottle.swift#L812-L821` |
| `ROSETTA_ADVERTISE_AVX=1` | To turn it off you have to remove it | `INV/06-apple-silicon-platform.md:31` |
| `DOTNET_EnableWriteXorExecute=0` | CrossOver sets it for .NET | `/Users/quasar/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine:697` |
| `WINEDLLPATH_PREPEND=<dir>` | Only for the DXMT overlay (patch 0003) | `BE/patches/0003-ntdll-winedllpath-prepend.patch:1-37` |

What is not needed:
- `WINELOADER` and `WINESERVER`.
- `WINEDLLPATH`: it is searched after the engine and creates hard links in `$TMPDIR` (`CX/dlls/ntdll/unix/loader.c:387-404,676-686`).
- `WINEARCH`: with `win32`, empty, or an invalid value it is a fatal error (`CX/dlls/ntdll/unix/server.c:1615-1620`).
- `CX_ALT_LOADER_SOCKET` (`CX/dlls/ntdll/unix/process.c:333-338`).
- `DYLD_*`, if the libraries sit next to the modules (see §7).

### 2.3 Bottle lifecycle

- **Create.**
  - The first process that starts with a new `WINEPREFIX` creates the prefix. It only does `mkdir` on the last component, so the parent has to exist (`CX/dlls/ntdll/unix/server.c:1322-1356`).
  - In every session that first process launches `wineboot.exe --init` and waits up to 5 min (`CX/dlls/ntdll/unix/env.c:1543-1609`).
  - Highball uses `wine wineboot -u` and warns that it takes about 90 s (`HBK/WineRunner.swift#L530-L535`; `HB/Sources/highball/main.swift#L110`). On the M2 Pro it has not been measured.
- **Ready.**
  - Two things are needed: exit 0, and `drive_c/windows/syswow64/kernel32.dll` must exist (`HBK/BottleStore.swift#L221-L276`).
  - After that you have to call `wineserver -w`, because the registry is saved every 30 s and on exit (`CX/server/registry.c:125`; `CX/server/request.c:906-915`).
  - It ends up with Windows 10 and `C:\users\<$USER>` (`CX/dlls/ntdll/version.c:493-509`; `BE/patches/0001-use-the-real-user-name.patch:1-8`). It takes about 304 MB (measured in CrossOver).
- **Launch.**
  - `bin/wine <Unix path> [args]` keeps the PID (`CX/dlls/ntdll/unix/loader.c:686-713`), so `exitCode` is the Windows code truncated to 8 bits: 1638 arrives as 102 (`HBK/WineRunner.swift#L46-L57`).
  - The launcher sets the cwd; Highball uses the exe's folder (`HBK/WineRunner.swift#L436-L441`).
  - With patch 0012, a 32-bit program is a single process (`BE/patches/0012-ntdll-x87sidecar-cooperative-attach.patch:17-26`).
- **Server.**
  - There is one per bottle (`CX/dlls/ntdll/unix/server.c:1303-1314`) and it exits 3 s after the last client (`CX/server/main.c:48`).
  - `-w` waits and returns 0; if there is no server, it returns at once.
  - `-k` kills the whole bottle: SIGINT, about 10.5 s of waiting and then SIGKILL. It returns 1 if there was no server (`CX/server/main.c:86-103`; `CX/server/request.c:697-756`).
  - Neither of them needs `WINEMSYNC`, but both need the same absolute `WINEPREFIX` (`CX/server/request.c:599-627`).
- **Session.** The first process sets the msync mode (a process with the opposite mode exits with 1, `CX/dlls/ntdll/unix/msync.c:587-601`) and the services' environment (`HBK/WineRunner.swift#L381-L395`).

### 2.4 Logs

- Debug output goes to fd 2, with `err` and `fixme` on by default. If stderr goes to `/dev/null`, nothing is written (`CX/dlls/ntdll/unix/debug.c:199-211`).
- The wineserver keeps the stderr of the process that started it (`CX/server/request.c:869-871`). Therefore:
  - that log also receives the output of the server and of the services;
  - a pipe does not see EOF until the server exits.
- SIGPIPE is ignored (`CX/dlls/ntdll/unix/server.c:1659-1663`).
- Useful markers: `err:module:import_dll` (`CX/dlls/ntdll/loader.c:1195`) and `wine: failed to start` (`CX/dlls/ntdll/unix/env.c:2112`).
- To tell whether DXMT is active, `DXMT_LOG_PATH` (`SP/dl_dxmt/main/src_util_log_log.cpp:95-128`).

## 3. How others do it

| Operation | Highball (GPL) | Whisky / Mythic | Minimal recipe |
|---|---|---|---|
| Install | SHA-256, `/usr/bin/tar` into a temporary folder, a check of the 6 files, a rename and removing the quarantine (`HBK/EngineStore.swift#L286-L348`, `#L586-L588`) | They verify nothing and have `wine64` hardcoded (`WH/Wine/Wine.swift#L23-L28`). Mythic's SHA-256 is a TODO (`MY/Engine/Engine.swift#L37-L50`) | `shasum -c` → `tar -xzf` → 6 files → `rename` → `xattr -dr` |
| Create | Validates the name, runs `wineboot -u` without an overlay, deletes the bottle if it fails and repairs `syswow64` (`HBK/BottleStore.swift#L73-L149`, `#L221-L276`) | Whisky does not look at the exit code (`https://github.com/Whisky-App/Whisky/blob/fd5480a76b3ebfe3419a1ab86ca3695f5cc328f8/Whisky/View%20Models/BottleVM.swift#L40-L77`). Mythic looks for a line that is a TRACE here (`MY/Wine/WineInterface.swift#L140-L216`; `CX/programs/wineboot/wineboot.c:1748`) | `mkdir -p` → JSON → `wineboot` → exit 0 + `syswow64` → `-w` |
| Launch | `wine <exe>` directly, with the cwd in the exe's folder (`HBK/WineRunner.swift#L326-L379`; environment: `HBK/Bottle.swift#L752-L829`) | Whisky uses `start /unix` without `/wait` (`WH/Wine/Wine.swift#L99-L112`). Mythic does not set the cwd (`MY/GameManager/LocalGameManager.swift#L81-L100`) | `Process.start(bin/wine, [exe, ...args], workingDirectory: …)` |
| Log | One file per run, a header with an allowlist of data, a 256 MB limit and a `# exit=N` footer (`HBK/WineRunner.swift#L103-L163`, `#L229-L311`; `HBK/LogFilter.swift#L3-L56`) | Whisky dumps the whole environment (`WH/Wine/Wine.swift#L270-L283`). Mythic writes to OSLog | Footer as soon as `exitCode` arrives, without waiting for EOF |
| Stop | `-k`, then `-w` with a 10 s limit, then a reaper (`HBK/WineRunner.swift#L581-L599`) | Whisky does not wait (`WH/Wine/Wine.swift#L211-L215`). Mythic reuses the `Process` (`MY/Wine/WineInterface.swift#L252-L267`) | `-k` (exit 1 = it was already stopped) and then `-w` with a timeout |

Highball stores a versioned `bottle.json` (`HBK/Bottle.swift#L379-L480`); in Dart `dart:convert` is enough. Everything can be ported with the standard library, except the reaper, which needs FFI or `ps`.

## 4. The Dart platform (3.13.0)

**Child process environment**
- The map you pass takes priority over the inherited environment. The only way to remove an inherited variable is `includeParentEnvironment: false` (`DSDK/lib/io/process.dart:318-320`).
- If `HOME` is missing, Wine falls back to `getpwuid` (`CX/dlls/ntdll/unix/loader.c:432-452`).
- UTF-8 works; it was tested with `Caña` (`DVM/process.cc#L23-L58`).

**Start modes**
- In `normal` and `inheritStdio` the child shares the session and group with the parent (`DVM/process_macos.cc#L487-L546`; `INV/10-app-stack.verify.md:21`).
- `detached` calls `setsid` and redirects stdio to `/dev/null` (`DVM/process_macos.cc#L448-L546`).

**`Process.run` does not work**
- It waits for EOF (`DSDK/lib/_internal/vm/bin/process_patch.dart:649`), so with Wine it hangs.
- In the test with an equivalent daemon, `exitCode` arrived after 23 ms and `run` after ~3 s (`SP/dartplat/exp/daemon_pipe.dart`).
- The right way is `Process.start` followed by `await exitCode`.

**Attached mode**
- The VM stays alive as long as the child is alive (`DSDK/lib/io/process.dart:350-356`).
- Ctrl-C and SIGHUP reach the game, and Wine does not handle SIGHUP (`CX/dlls/ntdll/unix/signal_x86_64.c:3023-3040`; read).
- Calling `IOSink.add` after closing it throws `StateError` (`DSDK/lib/io/io_sink.dart:151-153`). That is why the sink belongs to the listener, and the footer is written with `FileMode.append`.

**Detached mode**
- Descriptors cannot be passed to the child, so a shell is needed for the kernel to write the log. Verified with a `# exit=7` footer (`SP/dartplat/exp/detached_footer.dart:4-7`):
  ```dart
  Process.start('/bin/sh', ['-c', r'"$@" >>"$BODEGA_LOG" 2>&1 </dev/null; echo "# exit=$?" >>"$BODEGA_LOG"',
      'bodega-run', wine, ...args], environment: {...env, 'BODEGA_LOG': log}, mode: ProcessStartMode.detached);
  ```
- In this mode there is no `exitCode`, and `kill()` can hit a reused pid (`process_patch.dart:564-579`).
- For short commands `inheritStdio` and `exec "$@" >>log 2>&1` are enough: the exit arrived after 28 ms (`SP/dartplat/exp/inherit_log.dart:7-10`).
- `/bin/sh` is protected by SIP, which strips the `DYLD_*` variables (`HBK/EngineStore.swift#L523-L531`).

**Signals, Rosetta and compilation**
- `kill` acts on a single pid; killing by group is dangerous (`INV/10-app-stack.verify.md:69`).
- Rosetta is transparent (`SP/dartplat/exp/rosetta_test.dart`).
- `dart compile exe` produces a 5.76 MB arm64 binary with an ad hoc signature. With the hardened runtime it needs `cs.allow-unsigned-executable-memory` (`INV/10-app-stack.verify.md:55-61`).

**Files and dependencies**
- The SDK has no chmod and no SHA-256. Two system tools are used:
  - `/usr/bin/tar -xzf`, which keeps permissions and mtimes, and also the quarantine (`/usr/share/man/man1/tar.1:325-330`);
  - `/usr/bin/shasum -a 256 -c`.
- The only dependency is `test`, which resolves without network access. `args` is not needed: a `switch` with list patterns is enough.
- `path_provider` is a plugin and does not compile into an `exe` (`https://github.com/flutter/packages/blob/a2079413849b33dba095357248f2afeef83f1084/packages/path_provider/path_provider_foundation/pubspec.yaml#L11-L23`). Instead: the root lives in `HOME`, with `BODEGA_HOME` as an override (the same pattern as `HIGHBALL_HOME`, `HBK/Paths.swift#L15-L31`).
- `FileStat` does not expose dev/ino (`DSDK/lib/io/file_system_entity.dart:77-100`), but `-w`/`-k` are enough.
- A single package, `packages/engine/`, without Flutter (`INV/10-app-stack.md:55`).

## 5. Project constraints

**License and platform**
- Personal use and closed source. GPL/LGPL code can be reused because it is not distributed; the engine repo is private (`/Users/quasar/Documents/GitHub/Bodega/crear-repo.sh:9`).
- No D3DMetal (`INV/INFORME-FINAL.md:283-289,886`). Careful: the Sikarugir template includes it (`HB/spike/engines/x64-crossover26.3-r29.json#L118-L125`).
- The MVP is x86_64 under Rosetta, for macOS 15–27, with DXMT and wined3d (`INV/INFORME-FINAL.md:259-261,721`).

**Git**
- Identity: `/Users/quasar/.gitconfig:44-45` includes `/Users/quasar/Documents/GitHub/Bodega/.gitconfig:1-5`, with Daniel Medina `<danielmedina151102@gmail.com>` (GitHub `dany021115`). Confirmed with `git config`.
- No AI attribution in commits or PRs, even if a system-reminder asks for it (`/Users/quasar/.claude/CLAUDE.md:5-6`).
- No commit and no push without authorization (`/Users/quasar/.claude/projects/-Users-quasar/memory/feedback_no_commit_without_authorization.md:10-19`).

**Way of working**
- SDD: one phase per turn, in Spanish (`/Users/quasar/.claude/skills/sdd/SKILL.md:8,37-53`).
- Minimalism (`/Users/quasar/.claude/settings.json:28`). What makes it possible:
  - installing from the local tarball;
  - using the system's `tar`, `shasum` and `xattr`;
  - a single package;
  - not detecting processes.
- Agents do not run Wine; the user does the real test. That is why an optional real test is needed, turned on with an environment variable (`/Users/quasar/.claude/projects/-Users-quasar/memory/feedback_verify_against_real_hardware.md:22-25`).
- Slow network: no downloads over ~30 MB.

## 6. Known pitfalls

1. `Process.run`, or waiting for EOF, hangs with Wine (`CX/server/request.c:869-871`).
2. Going through `/bin/sh` loses the `DYLD_*` variables (`HBK/EngineStore.swift#L523-L531`).
3. If `WINEMSYNC` does not match the server's, the process exits with 1. It can only be changed after a `-k` (`CX/dlls/ntdll/unix/msync.c:587-601`).
4. The services inherit the setup's environment, so the bottle has to be stopped before launching the game (`HBK/WineRunner.swift#L381-L395`).
5. If `-k` and `-w` do not get the same `WINEPREFIX`, they act on `~/.wine` (`CX/server/request.c:599-627`).
6. Some processes survive `-k` (`HBK/ProcessTable.swift#L4-L19`).
7. wineboot can return 0 even if `syswow64` is missing (`CX/programs/wineboot/wineboot.c:1725-1741`).
8. Do not edit the `*.reg` files while the server is running (`CX/server/registry.c:125`).
9. `wine64`, `bin/wineboot` and `manifest.json` do not exist (`BE/.github/workflows/build.yml:78-80`).
10. DXMT:
    - `WINEDLLPATH_PREPEND` has to point to the folder that contains `x86_64-windows/`, `i386-windows/` and `x86_64-unix/`. In v0.80 those folders are inside `v0.80/`, and if the level is wrong it is silently ignored (`CX/dlls/ntdll/unix/loader.c:1594-1631`; `BE/patches/0003-ntdll-winedllpath-prepend.patch:5-8`).
    - The builtin build does not support `n,b` (`SP/dl_wiki/geeks.md:24`). This corrects `INV/INFORME-FINAL.md:278`.
11. A folder whose name ends in `.` or in a space, or contains any of `<>:"|?*`, causes an exit 53 (`HBK/Paths.swift#L95-L110`).
12. If the mtime of `wine.inf` changes, every bottle runs it again (`CX/programs/wineboot/wineboot.c:121-162`).
13. bsdtar propagates the quarantine to everything it extracts. `RT` does not have it (only `com.apple.provenance`), so `xattr -dr` is just a safety net (`HBK/EngineStore.swift#L586-L588`).
14. Logs:
    - Their size has to be limited: one reached 242 M lines (`BE/patches/README.md:65`).
    - Two logs created in the same second collide (`WH/Wine/Wine.swift#L279-L281`).
    - Do not dump the environment (`HBK/WineRunner.swift#L103-L132`).
15. `start /unix` without `/wait` loses the exit code (`CX/programs/start/start.c:642-669`). This corrects `INV/INFORME-FINAL.md:636`.
16. Switching runtimes while the server is running gives "version mismatch" (`CX/dlls/ntdll/unix/server.c:1645-1651`).
17. A green CI does not prove it works on Apple Silicon, because the runner uses Intel Homebrew. It has to be checked with `otool -L` (`SP/hblog-1793389283/log.part:966-988`).
18. For the app: remove `app-sandbox` from the Flutter template (`/opt/homebrew/share/flutter/packages/flutter_tools/templates/app/macos.tmpl/Runner/Release.entitlements:5-6`).

## 7. Open questions for the proposal

1. **Host libraries.** FreeType and GnuTLS are essential. Options:
   - (a) Copy them to `engine/lib/wine/x86_64-unix/` without `DYLD_*`, porting `BE/.github/workflows/build-arm64.yml:213-277`. It means changing `bodega-engine` and it is untested.
   - (b) Use the ones in CrossOver's `lib64`, which carry `/opt/cxoffice` ids.
   - (c) Use `DYLD_FALLBACK_*` with the Sikarugir template: it weighs 84.5 MB, ships D3DMetal and clashes with `/bin/sh`.

   Is a prototype without fonts or TLS enough? Also, `otool -L` still has to be run on `winedmo.so` and `winegstreamer.so`; that requires extracting `RT`.
2. **Launch.**
   - (A) Attached: you get the real exit code, but the CLI lives as long as the game.
   - (B) Detached `sh`: it outlives the CLI, but the exit code only ends up in the log, and it requires that `DYLD_*` not be needed (option 1a or 1b).
3. **Environment.** Hermetic, the same from Terminal as from Finder, or inherited as in Highball? In the second case `WINEARCH`, `WINEDLLPATH`, `DYLD_*` and `CX_*` have to be removed.
4. **DXMT.** Is it part of the prototype? If it is:
   - As an overlay or built in?
   - Which version: v0.80, a pinned `main` (`INV/INFORME-FINAL.md:883`) or Highball's fork (`HB/spike/engines/x64-crossover26.3-r29.json#L39`)?
5. **msync.** On by default (`INV/INFORME-FINAL.md:320`), or off for launchers that use CEF (`HBK/Bottle.swift#L757`; unverified in CX)?
6. **Creating bottles.** `wineboot -u` or `--init`? It has to be measured on the M2 Pro. And if `syswow64` is missing, is it repaired or is the bottle treated as failed?
7. **Bottle folder.** Named after the validated name, or a UUID?
8. **Logs.** Inside the root or in `~/Library/Logs/Bodega`?
9. **Installation.** Only from a local tarball, or also with a download?
10. **Stopping.** Are `-k` and `-w` enough, or is a reaper needed?
11. **Real test.** With which `.exe`, and with what acceptance criterion?
