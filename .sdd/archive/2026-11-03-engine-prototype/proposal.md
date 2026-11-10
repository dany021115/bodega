# Proposal: engine-prototype

SDD **propose** phase · 2026-11-02 · builds on `exploration.md` (approved) and uses its path aliases (`CX`, `BE`, `HBK`, `SP`, `DSDK`, `INV`, `RT`).

**Origin.** The *minimal-first* design (it tied at 14.5 with *app fit*; your minimalism policy breaks the tie) with the judges' grafts: a fake runtime in the tests, `wineboot` without `-u`, a `run` that waits for an `.exit`, windowless probes, a load probe in the CI, `MVK_CONFIG_LOG_LEVEL=2` and a Rosetta check.

## Why

The `engine-wine-11.0-…-primer-build` runtime is already downloaded and verified, but nothing uses it: the `bodega` repo is empty (exploration §1). It also lacks FreeType and GnuTLS (§2.1), and without them there are no fonts and no TLS. This change validates, without a UI, the full engine contract that the Flutter app will later import.

## What

**Scope**
1. A pure Dart package, `packages/engine`, with a library, a CLI and a test file. Five verbs: `install`, `create`, `run`, `wait` and `stop`.
2. One log per run with a header and a `# exit=N` footer, plus an `.exit` file with the code.
3. A new `build-hostlibs.yml` workflow in `bodega-engine`. It packs FreeType, GnuTLS and MoltenVK from Intel Homebrew, with their closure, into a separate tarball of about 6–10 MB. It does not build Wine, and if the runner image stops shipping freetype and gnutls, it fails right away instead of building them.
4. Tests without Wine, with a fake runtime made of `sh` scripts, and an optional group that uses the real runtime.

**Out of scope:** the Flutter UI, the gamedb, the stores, DXMT, arm64, SDL2, video (FFmpeg and GStreamer), a process reaper, downloads from the CLI, `bottle.json`, and log limits or rotation.

## Impact

| Repo | File (all new) | Contents |
|---|---|---|
| `bodega` | `.gitignore` | `.dart_tool/`, `build/` |
| | `packages/engine/pubspec.yaml` and `pubspec.lock` | `name: engine`, sdk `^3.13.0`; the only dependency is `test` (dev), resolved with `dart pub get --offline` |
| | `packages/engine/lib/engine.dart` | the whole engine as top-level functions (~200 lines) |
| | `packages/engine/bin/bodega.dart` | the CLI (~40 lines) |
| | `packages/engine/test/engine_test.dart` | 5 tests without Wine and the `real runtime` group |
| `bodega-engine` | `.github/workflows/build-hostlibs.yml` | a manual workflow; it does not touch `build.yml`, the patches or Wine |

**Outside the repos**
- Disk: `~/Library/Application Support/Bodega`. The runtime takes ~1.1 GB and each bottle ~300 MB.
- CI: 3–5 min per run, which a private repo bills ×10. 15 min limit.
- Downloads: only the hostlibs tarball. The 335 MB engine is not downloaded again.

## Decisions on the open questions (§7)

| # | Question | Decision | Reason | Reference |
|---|---|---|---|---|
| 1a | Where do the host libs go? | In `engine/lib/wine/x86_64-unix/`, with `@loader_path/<leaf>` ids. No `DYLD_*` and no changes to Wine | The 31 `.so` files already have `LC_RPATH @loader_path/`. It works in every process, also through `/bin/sh` | `otool -l` on RT; dlopen(3); `SP/dyldtest` |
| 1b | Which libs? Is it enough without fonts or TLS? | Not enough: FreeType and GnuTLS go in, plus MoltenVK. SDL2, FFmpeg and GStreamer stay out | They are the leaf names the modules open. sdl2-compat can hang winebus. winedmo and winegstreamer fail without breaking anything | `strings` on RT; `BE/.github/workflows/build-arm64.yml:217-222`; `CX/dlls/ntdll/unix/virtual.c:851-853` |
| 2 | Attached or detached `sh`? | `run`: a detached `sh` that writes the footer and the `.exit`; the CLI waits for the `.exit` and exits with its code. `create`: the same script, attached | The game outlives the Terminal and the exit code is the real one. No pipes (pitfall 1) | `SP/dartplat/exp/detached_footer.dart:4-7`; `INV/INFORME-FINAL.md:638` |
| 3 | Hermetic or inherited environment? | Hermetic: `includeParentEnvironment: false` and a fixed map. Only `HOME`, `USER`, `LOGNAME`, `TMPDIR` and `__CF_USER_TEXT_ENCODING` are copied from the parent, and `BODEGA_WINEDEBUG` is read | The same from Terminal and from Finder. `WINEARCH`, `DYLD_*` and `CX_*` never get in | `DSDK/lib/io/process.dart:318-320`; `CX/dlls/ntdll/unix/server.c:1615-1620` |
| 4 | Is DXMT in? | No. DX9–11 go through wined3d | It is not one of the five operations. The overlay is another artifact (pitfall 10) | `BE/.github/workflows/build.yml:96-106` |
| 5 | msync on? | `WINEMSYNC=1`, constant | It is the recommended setting. Since it is constant, pitfall 3 cannot happen. CEF is out of scope | `INV/INFORME-FINAL.md:320`; `CX/dlls/ntdll/unix/msync.c:587-601` |
| 6 | `-u` or `--init`? And syswow64? | `wine wineboot` with no flags and then `wineserver -w`. The bottle is ready if `syswow64/kernel32.dll` and `system.reg` exist; if not, an error, with no repair and no deletion | The automatic `--init` already installs the prefix. `-u` repeats `wine.inf` and `--init` starts a second services.exe | `CX/dlls/ntdll/unix/env.c:1908`; `CX/programs/wineboot/wineboot.c:1959-1965` |
| 7 | Name or UUID? | The name is the folder: `^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$`. No JSON | It makes pitfall 11 impossible and there is nothing to store per bottle | `HBK/Paths.swift#L95-L110` |
| 8 | Where do the logs go? | `bottles/<b>/logs/<UTC>-<label>.log` plus its `.exit`. Exclusive creation and no limit (ponytail) | `BODEGA_HOME` isolates the tests. Patch 0014 removed the known cause of the giant logs | `BE/patches/README.md:65`; `WH/Wine/Wine.swift#L279-L281` |
| 9 | Install with a download? | No: only local tarballs with their `.sha256`, with `install <engine> <hostlibs>`. You download them with `gh release download` and keep the engine's one | The repo is private and the connection is slow: no token and no resuming. Changing the hostlibs means reinstalling from the saved tarball, without downloading 335 MB | `HBK/EngineStore.swift#L286-L348` |
| 10 | Are `-k`/`-w` enough? | Yes. `stop` = `wineserver -k`, and its 1 (there was no server) is returned as 0. `wait` = `-w`. No reaper | `-k` already moves on to SIGKILL after ~10.5 s | `CX/server/main.c:86-103`; `CX/server/request.c:697-756` |
| 11 | What real test? | The agent, with no windows: `cmd /c echo ok`, `cmd /c exit 7`, `rundll32` probes with and without hostlibs, and HTTPS with `cscript`. You: notepad (with `lsof`), winecfg, Cave Story in a path with a space and an accented letter, detaching and stopping | No large downloads. They cover fonts, TLS, MoltenVK, WoW64 and the lifecycle, and the probes make the hints deterministic | `CX/programs/rundll32/rundll32.c:317-331` |

**Also**
- The current runtime is marked by the `runtimes/current` symlink, which `install` replaces with an atomic rename.
- A `C:\…` program is launched with its folder inside `drive_c` as the cwd, if it exists; a bare name, with `drive_c`.
- The data root is `BODEGA_HOME` or, if it is not set, `~/Library/Application Support/Bodega`.
- Before every verb, Rosetta is checked with `/usr/bin/arch -x86_64 /usr/bin/true` (`INV/INFORME-FINAL.md:321`).
