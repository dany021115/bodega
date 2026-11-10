# Design: engine-prototype

This document records only the decisions that are not obvious. It uses the aliases from `exploration.md` plus two more:
- `SP/dyldtest`: an experiment with x86_64 dyld under Rosetta on macOS 27.0.1.
- `SP/brewapi`: the Homebrew API, queried on 2026-11-02.

## §1 Host libraries: next to the modules, without `DYLD_*`

**Facts**
- **Module rpaths.** According to `otool -l` on `RT`, the 31 `.so` files in `lib/wine/x86_64-unix/` carry `LC_RPATH @loader_path/`; `winegstreamer.so` also adds a Cellar path. The `wine` loader has no rpath at all.
- **What each module opens**, according to `strings`:

  | Module | Libraries it opens | Call site in the code |
  |---|---|---|
  | `win32u.so` | `libfreetype.6.dylib`, `libMoltenVK.dylib` | `CX/dlls/win32u/freetype.c:1483`, `CX/dlls/win32u/vulkan.c:3005-3015` |
  | `dwrite.so` | `libfreetype.6.dylib` | `CX/dlls/dwrite/freetype.c:119` |
  | `bcrypt.so` | `libgnutls.30.dylib` | `CX/dlls/bcrypt/gnutls.c:388-396` |
  | `crypt32.so` | `libgnutls.30.dylib` | `CX/dlls/crypt32/unixlib.c:100-108` |
  | `secur32.so` | `libgnutls.30.dylib` | `CX/dlls/secur32/schannel_gnutls.c:1481-1489` |
  | `winebus.so` | `libSDL2-2.0.0.dylib` | — |
  | `odbc32.so` | `libodbc.2.dylib` | — |

  According to `otool -L`, only `winedmo.so` and `winegstreamer.so` link against `/usr/local/opt`.
- **dlopen(3) search** (SEARCHING section): a leaf name is looked up in the `LC_RPATH` entries of the Mach-O that makes the call. `SP/dyldtest` confirms it:
  - it works with `env -i`, with cwd `/` and through `/bin/sh`;
  - without `LC_RPATH` it fails, and dyld does not try `/usr/local/lib`.
- **The cwd comes first.** With a decoy library of the same name in the cwd, the decoy is loaded (`SP/dyldtest/decoy`): in practice dyld looks at the cwd before the `LC_RPATH`. That is why the engine always sets the cwd (§4).

**Decision.** The hostlibs tarball puts the `.dylib` files in `engine/lib/wine/x86_64-unix/`, with the id and the dependencies rewritten to `@loader_path/<leaf>` and an ad hoc signature. No Wine binary is touched and no variable is exported. It works for any process in the bottle, including the children that a Windows program launches with its own environment.

Rejected alternatives:
- `DYLD_FALLBACK_LIBRARY_PATH` inside the script. `/bin/sh` is protected by SIP (`HBK/EngineStore.swift#L523-L531`) and children lose the variable (`BE/patches-arm64/0030-unixlib-host-libraries-next-to-wine.patch:7-16`).
- Rewriting the engine's rpaths: it would mean re-signing 31 modules on every build.

**The `build-hostlibs.yml` workflow**
- **Frozen Homebrew.** Today's API no longer has Intel bottles for freetype 2.15.0, gettext, gmp, libpng, libunistring or p11-kit (`SP/brewapi/*.json`). On the other hand:
  - the runner image already ships freetype and gnutls, which do not appear under "Would install" (`SP/hblog-1793389283/log.part:204-219`);
  - molten-vk 1.4.2 has a `sonoma` bottle (`:663`).

  `HOMEBREW_NO_AUTO_UPDATE` and `HOMEBREW_NO_INSTALL_UPGRADE` avoid building from source. `timeout-minutes: 15` caps what the ×10 billing costs. If a weekly image update stops shipping freetype or gnutls, the `brew list --versions freetype gnutls` guard (R17) stops the job within seconds instead of compiling until the time limit. `hostlibs.txt` records `$ImageOS` and `$ImageVersion`.
- **`bundle`.** It is a port of `BE/.github/workflows/build-arm64.yml:223-268` with two changes:
  - the roots arrive as arguments (`$ROOTS`, the job's only list), which allows the local dry run with just freetype and gnutls;
  - it leaves out the SDL3 part.

  The ctypes load check (`:266-268`) is replaced by the probe: loading the three roots loads the whole closure.
- **`probe`.** A single `probe.c` serves for both pieces:
  - With `-DMOD` it builds `x86_64-unix/probe.so` with `-dynamiclib -Wl,-rpath,@loader_path/`, just like a Wine module. It exports a function that calls `dlopen` on the name it receives.
  - Without that macro it produces an executable with no `LC_RPATH`, just like the loader. It opens `probe.so` by absolute path, calls that function with each argument and, if any call fails, prints `dlerror()` and exits with 1.

  The step, with the runner's default shell (`bash -e`):
  ```sh
  probe="$PWD/probe"; dir=$(cd out/engine/lib/wine/x86_64-unix && pwd -P); log="$RUNNER_TEMP/probe.log"
  (cd / && env -i DYLD_PRINT_LIBRARIES=1 "$probe" "$dir/probe.so" $ROOTS) 2>"$log" || { cat "$log"; exit 1; }
  cat "$log"
  for r in $ROOTS; do grep -F "$dir/$r" "$log"; done
  if grep -q "$(brew --prefix)/" "$log"; then exit 1; fi
  ```
  - The paths are set before the `cd /`, and the `2>` goes outside the subshell: inside it, `probe.log` would land in `/`, which belongs to root, and the step would die with "Permission denied".
  - `pwd -P` gives the real path, which is the one dyld prints.
  - The `grep -F` in the loop stops the step through `set -e`; the last line uses `if` because `set -e` does not catch a failing `! grep`.
  - In T2, `RUNNER_TEMP` points to the scratchpad and `ROOTS` leaves out MoltenVK.

  `probe.so` does not end up in the tarball, because the pattern is `*.dylib`.
- **`tarball`.** `(cd out && tar -czf ../$name.tar.gz hostlibs.txt engine/lib/wine/x86_64-unix/*.dylib)`.
  - It only contains files, so extracting it over the engine does not change folder modes or the mtime of `wine.inf` (pitfall 12). It does update the mtime of `engine/lib/wine/x86_64-unix/`, which does not matter.
  - `shasum -a 256 … | tee ….sha256`, as in `BE/.github/workflows/build.yml:119`.
  - Limit: `stat -f %z` under 30 MiB.
- **`publish`.** Same as `build.yml:128-136`, but with `GH_REPO: ${{ github.repository }}`, because there is no checkout. The name is recovered with `ls hostlibs-*.tar.gz`, without passing variables between steps.

**Coupling.** The sonames `libfreetype.6` and `libgnutls.30` appear both in the workflow's roots and in `requiredFiles`. If a future engine changes either one, `install` fails visibly.

## §2 Launching through `/bin/sh`, and the exit code

There is a single script, `S`:

```sh
l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s
```

It is launched with `Process.start('/bin/sh', ['-c', S, 'bodega', log, wine, program, ...args], mode: …, workingDirectory: cwd, environment: wineEnv(…), includeParentEnvironment: false)`.

- **`run`** uses `ProcessStartMode.detached`, which calls `setsid` and sends stdio to `/dev/null` (`DVM/process_macos.cc#L448-L546`). That way neither Ctrl-C nor Terminal's SIGHUP reaches the game; Wine does not handle SIGHUP (`CX/dlls/ntdll/unix/signal_x86_64.c:3022-3040`). This is variant E7 (`SP/dartplat/exp/detached_footer.dart:4-7`).
- **`create`** uses the same `S` with `ProcessStartMode.inheritStdio` and `await exitCode`, as in E8 (`SP/dartplat/exp/inherit_log.dart:7-10`). The `sh` exits with wine's code, and here Ctrl-C does abort.
- **No `exec`.** The `sh` has to stay alive to write the footer.
- **Log path in `$1`.** It goes as an argument and not as a variable, so that Wine's environment is exactly `wineEnv`.
- **Atomic `.exit`.** It is written to a temporary file and moved within the same folder; the rename is atomic. `exitOf(log)` polls it every 250 ms and never reads a half-written file.
- **What the code means.**
  - `bin/wine` does an `execv` to the loader without changing PID (`CX/dlls/ntdll/unix/loader.c:2523-2547`). That is why `$?` is the Windows code truncated to 8 bits: 1638 arrives as 102 (`HBK/WineRunner.swift#L46-L57`).
  - If the process dies from a signal, `$?` is 128 + the signal.
  - After `bodega stop`, the `run` that was waiting ends with 0: when the wineserver shuts down, Wine clients exit cleanly with `_exit(0)` (`CX/dlls/ntdll/unix/server.c:266-267`, `CX/dlls/ntdll/unix/thread.c:1499-1512`). User's decision: this is accepted; a stopped `run` cannot be told apart from a normal exit by its code.
  - `wine: failed to open` ends with `STATUS_DLL_NOT_FOUND`, which truncates to 53 (`CX/dlls/ntdll/unix/env.c:1920-1926`): that is the exit 53 of pitfall 11.
- **No pipes from Dart to Wine.** Because of pitfall 1 (`CX/server/request.c:869-871`) and because `Process.run` waits for EOF (`DSDK/lib/_internal/vm/bin/process_patch.dart:649`). `Process.run` is only used with tools that terminate: `tar`, `shasum`, `xattr`, `arch` and `wine --version`, which does not start the server (`CX/dlls/ntdll/unix/loader.c:2555-2604`).

## §3 Logs, and the stderr the wineserver inherits

The wineserver calls `setsid` and only redirects stdin and stdout (`CX/server/request.c:864-871`). It therefore keeps fd 2 of the session's first process, and the same happens to the services. Consequences:
1. That log keeps receiving lines after the footer; E8 showed a daemon writing after the parent had already exited. That is why every check requires the log to **contain** `# exit=N`.
2. Nothing waits for the log's EOF: the code is read from the `.exit`.
3. A size limit would require a pipe, or periodic truncation from a live process. It is left with no limit and no rotation (`ponytail:`):
   - the 242 M-line log was fixed by patch 0014 (`BE/patches/README.md:65`);
   - with `fixme-all` only the `err:` lines come out.

Other log decisions:
- **Name:** with microseconds and `File.createSync(exclusive: true)` (`DSDK/lib/io/file.dart:256`). That way two logs cannot collide, which is Whisky's bug (`WH/Wine/Wine.swift#L279-L281`).
- **Header:** an allowlist of three lines. It never dumps the environment (`HBK/WineRunner.swift#L103-L132`).

**Hints.** `hintsIn(log)` reads the log as a stream (`openRead`, `latin1` and `LineSplitter`, without loading it whole) and checks it against a fixed table:

| Marker | Source | Hint |
|---|---|---|
| `cannot find the FreeType` | `CX/dlls/win32u/freetype.c:1486`, `CX/dlls/dwrite/freetype.c:122` | the hostlibs are missing: reinstall with their tarball |
| `ailed to load libgnutls` | `CX/dlls/bcrypt/gnutls.c:401`, `CX/dlls/crypt32/unixlib.c:113`, `CX/dlls/secur32/schannel_gnutls.c:1494` | same as above |
| `version mismatch` | `CX/dlls/ntdll/unix/server.c:1648` | a server from another runtime is running: `bodega stop <b>` |
| `wine: failed to open` | `CX/dlls/ntdll/unix/env.c:1925` | check the program's path (pitfall 11) |

There are no markers for msync (`CX/dlls/ntdll/unix/msync.c:600,636`) or for `Bad CPU type`: with a constant `WINEMSYNC=1` (§4) and Rosetta checked before every verb (R3) they cannot appear, and if `bootstrap_look_up` failed for another reason, `bodega stop` would not fix it.

## §4 Hermetic environment and working directory

`includeParentEnvironment: false` is the only way to remove an inherited variable (`DSDK/lib/io/process.dart:318-320`). The full map is in R12. What is not obvious:

- **Variables left out by construction:**

  | Variable | Problem | Reference |
  |---|---|---|
  | `WINEARCH` | it is fatal with `win32` | `CX/dlls/ntdll/unix/server.c:1615-1620` |
  | `WINEDLLPATH` | it creates hard links in `$TMPDIR` | `CX/dlls/ntdll/unix/loader.c:387-404` |
  | `CX_LIBVULKAN` and `CX_ACTIVE_GRAPHICS_BACKEND` | they change the Vulkan library | `CX/dlls/win32u/vulkan.c:3005-3011` |
  | `CX_APPLEGPTK_LIBD3DSHARED_PATH` | it loads libd3dshared, from D3DMetal | `CX/dlls/ntdll/unix/loader.c:1323-1331` |
  | `DYLD_*` | not needed | §1 |

  If `HOME` or `USER` is missing, Wine uses `getpwuid` (`CX/dlls/ntdll/unix/loader.c:432-452`).
- **No `LANG` or `LC_*`.** `setlocale` returns `C` and Wine takes the language and region from `CFLocale` (`CX/dlls/ntdll/unix/env.c:734-760`). The result is the same from Terminal and from Finder.
- **`WINEDEBUG`** comes from `BODEGA_WINEDEBUG` (default `fixme-all`), never from the parent's `WINEDEBUG`: a `+all` left over in the shell does not fill the disk with GB of log. `ponytail:` it is the only knob that is read from the caller.
- **`MVK_CONFIG_LOG_LEVEL=2`.**
  - MoltenVK logs at INFO level by default (`SP/research/src/moltenvk-upstream/MoltenVK-1.2.10/MoltenVK/MoltenVK/Utility/MVKEnvironment.h:221`).
  - win32u creates a Vulkan instance every time it refreshes the display cache, at least once per session (`CX/dlls/win32u/sysparams.c:2839`, `CX/dlls/win32u/vulkan.c:3128`).
  - Highball uses 2 (`SP/hb/Bottle.swift:778`).
- **Constant `WINEMSYNC=1`.** That way modes cannot be mixed (pitfall 3, `CX/dlls/ntdll/unix/msync.c:587-601`). `wineserver -k` and `-w` receive the same map and therefore the same `WINEPREFIX` (pitfall 5).
- **cwd:**
  - in `create`, `bottles/<b>`;
  - for a Unix path, its folder, already validated;
  - for `C:\…`, its folder inside `prefix/drive_c` if it exists (R13), as Highball does with the exe's folder (`HBK/WineRunner.swift#L436-L441`);
  - otherwise, `prefix/drive_c`.

  There are two reasons: dyld looks at the cwd before the `LC_RPATH` (§1), and Wine turns the cwd into a DOS path (pitfall 11).

## §5 Creating the bottle

- **The automatic `--init`.** Every process without a parent goes through `build_initial_params`, which calls `run_wineboot`. That launches `wineboot.exe --init` once per session and waits for it for up to 5 min (`CX/dlls/ntdll/unix/env.c:1543-1609,1908`). That `--init` installs the new prefix because `.update-timestamp` does not exist yet (`CX/programs/wineboot/wineboot.c:121-162,1713`).
- **Why no flags.** Because of the above, `wine wineboot` with no flags is enough: that way wineboot calls neither `update_wineprefix` nor `start_services_process`, and only does the light steps (dynamic keys, RunOnce, Run and StartUp; `wineboot.c:1949-1977`).
  - `-u` forces a second full pass over `wine.inf`, including Wow64Install (`wineboot.c:1713,1740,1965`).
  - An explicit `--init` calls `start_services_process` again (`wineboot.c:1959-1963`).
  - Plan B, if verify finds an incomplete prefix: `-u`, which is what Highball uses (`HBK/WineRunner.swift#L530-L535`).
- **Then, `wineserver -w`.** It waits for the `--init` if that went past 5 min, and also for services and explorer. On exit, the server saves the registry (`CX/server/request.c:909`; the periodic save is every 30 s, `CX/server/registry.c:125`). The limit is 10 min with `exitCode.timeout`; if it runs out, `-k` is run and an error is reported.
- **When it is ready.** Exit 0, `syswow64/kernel32.dll` and `system.reg`.
  - syswow64 is not repaired; Highball copies `i386-windows` (`HBK/BottleStore.swift#L221-L276`). In a prototype we want to see that failure.
  - The engine deletes nothing, so it does not need to guard against the `dosdevices/z:` → `/` link (`CX/dlls/ntdll/unix/server.c:1350-1354`). The tests do delete (§6).

## §6 Installation, and tests without Wine

- **Installation.** If `runtimes/<id>` already exists, it fails before verifying or extracting anything (R6). Engine and hostlibs are extracted into a single staging folder, with an atomic rename at the end: a visible runtime is always complete. The `.tmp-<id>` left by a failed attempt is deleted at the start. `current` also changes with an atomic rename (R7).
- **`wine --version` before the rename.** It catches three problems:
  - a quarantine;
  - an unsigned binary that macOS kills (`strip` removed the engine's signature);
  - missing Rosetta. errno 86 arrives as a `ProcessException` because there is no `sh` in between here.
- **The test's fake runtime.** It is packed with `/usr/bin/tar` and `shasum`, just like the real one:
  - `engine/bin/wine` (an `sh` script):
    - with `--version` it prints `wine-11.0`;
    - with `wineboot` it creates `drive_c/windows/syswow64/kernel32.dll` and `system.reg`, unless `WINEPREFIX` contains `/broken/`;
    - with any other argument it prints its arguments, leaves a `sleep 5 &` running with the log open (it plays the wineserver) and exits with 7.
  - `engine/bin/wineserver` (an `sh` script): `-k` returns 1 and `-w` returns 0.
  - The rest of `requiredFiles` are empty files. The fake hostlibs are the two empty `.dylib` files plus `hostlibs.txt`.
- **The `real runtime` group.** It turns on if `BODEGA_TEST_RUNTIME` points to an installed or freshly extracted runtime. In a temporary `BODEGA_HOME` it creates `runtimes/current` pointing there, without extracting 1 GB again, and runs:
  - `--version`, `create`, `cmd /c echo ok` and `cmd /c exit 7`;
  - always, the two `rundll32` probes, which open no dialogs (`CX/programs/rundll32/rundll32.c:317-331`); dwrite and bcrypt open their library in `DllMain` (`CX/dlls/dwrite/main.c:46-50`, `CX/dlls/bcrypt/bcrypt_main.c:2837-2841`);
  - `stop`.

  If the runtime has `x86_64-unix/libgnutls.30.dylib`, no log may give the FreeType and GnuTLS hints; if it does not, they have to appear. That way T15 and R21 do not depend on side effects: without the probes, GnuTLS only gets loaded indirectly when Mono and Gecko are installed (msi imports crypt32 and appwiz.cpl imports bcrypt: `CX/dlls/msi/Makefile.in:3`, `CX/dlls/appwiz.cpl/Makefile.in:2`), and `cmd` imports neither of them (`CX/programs/cmd/Makefile.in:2`).
- **Cleanup.** `tearDownAll` runs `stopBottle` (`wineserver -k`) and then `Directory(home).deleteSync(recursive: true)`, which deletes links without following them (`DSDK/lib/io/directory.dart:290,313`): neither `dosdevices/z:` → `/` nor `runtimes/current` takes its target with it. `rm -rf` behaves the same. A recursive listing of a bottle always passes `followLinks: false`, because the default is `true` (`directory.dart:350-353,376-379`) and it would walk the whole disk through `z:`.

## §7 Accepted risks and fallback plans

- **`LC_RPATH` lookup.** Under Rosetta it has only been measured on macOS 27; the CI probe covers macOS 15 on native Intel. On your Mac it is checked by T16 (no hints and no `Failed to load libMoltenVK`) and, directly, by the `lsof` in U3.
  - Plan B: `DYLD_FALLBACK_LIBRARY_PATH` inside `S`.
  - Plan C: port `patches-arm64/0030`, which means rebuilding.
- **Engine signature.** If macOS killed the engine's binaries for being unsigned, `install` would sign them ad hoc (`codesign -f -s -`, allowed by decision 3).
- **Intel Homebrew expires.** The image lasts until ~August 2027 and Homebrew drops Intel on 2027-09-01 (`INV/INFORME-FINAL.md:710-711`). The tarball stays saved in the release.
- **No video.** winedmo and winegstreamer link against `/usr/local/opt` and fail without breaking anything (`CX/dlls/ntdll/unix/virtual.c:851-853`).
- **Controllers only through IOHID**, because there is no SDL2.
- **No reaper.** Some process may survive `-k` (pitfall 6); acceptance checks for it with `pgrep`.
- **No log limit.** An `err:` in a loop can make it grow.
- **`runtimes/current` is global.** Installing another runtime while bottles are running gives `version mismatch` (pitfall 16), and every bottle goes through `wine.inf` again (pitfall 12). Before installing, `bodega stop`.
- **No `.exit`.** If the `sh` dies from SIGKILL the `.exit` is not written, and `bodega run` waits until you press Ctrl-C.
- **Ctrl-C during `create`.** It leaves the folder half-made: you have to run `bodega stop <b>` and `rm -rf`.
- **`wait` right after launching from another Terminal** may return before the server exists.
- **Shadowing through the cwd.** A `.dylib` with the same name in a game's folder would shadow the hostlibs, because dyld looks at the cwd first. It is unlikely.
- **Configuration paths.** GnuTLS and p11-kit carry `/usr/local/etc` paths that do not exist. TLS validates with crypt32 and the keychain's roots (`CX/dlls/winhttp/net.c:97,158`, `CX/dlls/crypt32/unixlib.c:648-651`); the `cscript` in T16 checks it.
- **Commit, push and dispatch** are run by you from your Terminal (T3, T17); the agent prepares the commands and only checks the result, because the classifier already blocked one of its pushes.
