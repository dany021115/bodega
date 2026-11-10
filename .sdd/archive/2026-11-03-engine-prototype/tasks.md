# Tasks: engine-prototype

**Conventions**
- **(USER)**: you do it, in your Terminal. The agent does not commit, push or dispatch: it prepares the commands and afterwards only checks the result. The agent does the rest in `apply`, in this order.
- Each task names the check that closes it.
- Paths: `B` = `/Users/quasar/Documents/GitHub/Bodega/bodega`, `BE` = `/Users/quasar/Documents/GitHub/Bodega/bodega-engine`, `P` = `B/packages/engine`, `RT` = the engine tarball (`exploration.md`).
- The tests without Wine are run with `cd P && dart test -N '<name>'`.

## Host libraries
The workflow goes first so that the CI runs while the package is being written.

- [x] **T1** Write `BE/.github/workflows/build-hostlibs.yml` according to R17–R20 and design §1, with the steps guard and `install`, `bundle`, `probe`, `tarball`, artifact and `publish`.
  **Check:** `/usr/bin/ruby -ryaml -e 'YAML.load_file(ARGV[0])' BE/.github/workflows/build-hostlibs.yml` finishes without error, and `git -C BE status --short` shows only that file.
- [x] **T2** Local dry run on arm64, without spending CI.
  1. Extract with `ruby` the `run:` blocks of `bundle` and `probe` into a script in the scratchpad.
  2. Run it with `bash -e` in a temporary directory in the scratchpad, against `/opt/homebrew`, with `ROOTS='libfreetype.6.dylib libgnutls.30.dylib'` (there is no MoltenVK here) and `RUNNER_TEMP` pointing to another folder in the scratchpad.

  **Check:** it exits with 0; the probe loads `libfreetype.6.dylib` and `libgnutls.30.dylib` from the temporary `out/`, and `otool -L` on the result does not show `/opt/homebrew`.
- [x] **T3 (USER)** Commit, push and dispatch in your Terminal. The agent prepares the message, without AI attribution:
  ```sh
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine add .github/workflows/build-hostlibs.yml
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine commit -m 'build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball'
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega-engine push origin main
  gh workflow run build-hostlibs.yml -R dany021115/bodega-engine -f publish_release=true -f ref_note=primer-hostlibs
  ```
  **Check (agent, read-only):** `gh run list -R dany021115/bodega-engine -w build-hostlibs.yml -L 1` and `gh run view <id> -R dany021115/bodega-engine --log`: the job comes out green in under 10 min, the `probe` step shows the 3 roots and the tarball weighs under 30 MiB.
  It does not block T5–T15.
- [x] **T4 (USER)** `gh release download <tag> -R dany021115/bodega-engine -D /Users/quasar/Documents/GitHub/Bodega/runtimes/<tag>`.
  **Check:** `shasum -a 256 -c` gives OK in that folder.

## Dart package
- [x] **T5** Create the skeleton: `B/.gitignore` (`.dart_tool/`, `build/`), `P/pubspec.yaml`, `P/lib/engine.dart`, `P/bin/bodega.dart` and `P/test/engine_test.dart`. Then, `dart pub get --offline`.
  **Check:** `dart analyze` with no warnings, and `P/pubspec.lock` exists.
- [x] **T6** `wineEnv` (R12) and the test `wineEnv is hermetic`.
  **Check:** `dart test -N 'wineEnv'`.
- [x] **T7** `bottleDir` (name validation), `winPathProblem` and `bodegaHome` (R1, R8), with the test `names and windows paths`.
  **Check:** `dart test -N 'names'`.
- [x] **T8** The test helper that generates the fake runtime's tarballs (design §6), with the id as a parameter, plus `requiredFiles`, `installRuntime` and `currentRuntime` (R4–R7). Test `installRuntime` with five cases:
  - it installs correctly;
  - reinstalling gives `ya instalado` ("already installed") even with the `.sha256` missing (R6 comes before R4);
  - a tampered or missing `.sha256` gives an error;
  - without `libgnutls` it gives an error without leaving `.tmp-*`;
  - installing A and then B leaves `currentRuntime` on B.

  **Check:** `dart test -N 'installRuntime'`.
- [x] **T9** The launch:
  - `_start`, with the `S` script from design §2 in attached or detached mode;
  - `_newLog`, which sets the name, label and header (R15);
  - `exitOf` (R14).

  **Check:** it has no test of its own; T10 and T11 cover it.
- [x] **T10** `createBottle` (R9, R10), with the `create` part of the test `fake runtime cycle`:
  - `t` ends up ready and its log contains `# exit=0`;
  - `broken` gives an error and keeps the folder and the log.

  **Check:** `dart test -N 'fake runtime'`.
- [x] **T11** `runInBottle`, `waitBottle` and `stopBottle` (R11, R13, R14), with the rest of the test `fake runtime cycle`, which launches `C:\Juegos\Mi Juego.exe` with `prefix/drive_c/Juegos` already created:
  - exit 7 arrives in under 2 s even though a grandchild process holds the log;
  - the log contains `# exit=7` and the header `# cwd <prefix>/drive_c/Juegos`;
  - the label comes out as `-Mi_Juego.log`;
  - `stop` returns 0 and `wait` returns 0.

  **Check:** `dart test -N 'fake runtime'`.
- [x] **T12** `hintsIn` (R16) and the test `hints`, which uses a canned log with the 4 markers and a clean one.
  **Check:** `dart test -N 'hints'`.
- [x] **T13** The CLI in `P/bin/bodega.dart` (R1–R3): a `switch` with list patterns, the Rosetta check, the `log:` line, waiting for the `.exit`, the hints and the codes 0, 1, 64 and N. Add the `ponytail:` notes for the simplifications: no log limit, `BODEGA_WINEDEBUG`, no reaper, no syswow64 repair and a global runtime.
  **Check:**
  - `mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega`;
  - `build/bodega; echo $?` shows the usage and 64;
  - `BODEGA_HOME=$(mktemp -d) build/bodega create 'a b'; echo $?` gives 1;
  - `BODEGA_HOME=$(mktemp -d)/a./b build/bodega stop x; echo $?` gives 1 and the message names `a.`;
  - `cat lib/engine.dart bin/bodega.dart | grep -c 'ponytail:'` gives 5 or more.
- [x] **T14** The `real runtime` group (design §6): it is skipped if `BODEGA_TEST_RUNTIME` is not set, it has a 15 min timeout, it always runs the two `rundll32` probes and requires the FreeType and GnuTLS hints if there are no hostlibs, and none if there are. Its `tearDownAll` runs `stopBottle` and deletes its `BODEGA_HOME` with `deleteSync(recursive: true)`, which does not follow links.
  **Check:** `dart test` marks it as skipped and everything else passes.

## Headless checks with the real runtime
The agent runs them, with no windows (decision 6).
- **Timing.** T15 runs in the background: the group can go past the 10 min that a foreground call allows, and its `tearDownAll` cleans up even if it fails. Each step of T16 runs in the foreground with an explicit 10 min timeout: `create` has not been measured (Highball takes about 90 s with `-u`, and the first time Rosetta, Mono and Gecko add to that).
- **If a call gets cut off**, before repeating it: `BODEGA_HOME=$H build/bodega stop t` (or `wineserver -k` with that `WINEPREFIX`) and `rm -rf "$H"`. Otherwise wineboot and wineserver are left orphaned and the retry fails with `ya existe` ("already exists") (R9), which is not a bug.
- **Cleanup.** First `stop`, then `rm -rf`, which deletes the `dosdevices/z:` → `/` link without following it. Nothing walks a bottle with `find -L` or with a `followLinks: true` listing.

- [x] **T15** Without hostlibs; it does not wait for T3.
  1. Extract `RT` with `/usr/bin/tar -xzf` into a new directory in the scratchpad.
  2. Run `BODEGA_TEST_RUNTIME=<dir> dart test -N 'real runtime'` in the background.
  3. Delete the extraction with `rm -rf <dir>` (~1.1 GB).

  **Check:** `create` finishes successfully and prints its time; `cmd /c echo ok` gives 0 and `ok` in the log; `cmd /c exit 7` gives 7; the probes give the FreeType and GnuTLS hints (the test requires it); `stop` gives 0.
- [x] **T16** With hostlibs; requires T4. `H` is a new folder in the scratchpad, written out literally in every call because shell variables do not carry over from one call to the next. Each step runs as `BODEGA_HOME=$H build/bodega …`:
  1. `install <RT> <hostlibs>`.
  2. `create t`.
  3. `run t cmd /c set`: the log contains no `DYLD_`, `WINEARCH`, `CX_` or `LANG=`.
  4. `run t rundll32 dwrite.dll,BodegaProbe` and `run t rundll32 bcrypt.dll,BodegaProbe`: they give no hints.
  5. Write `$H/bottles/t/prefix/drive_c/https.js` with:
     ```js
     try{var r=new ActiveXObject("WinHttp.WinHttpRequest.5.1");r.Open("GET","https://example.com/",false);r.Send();WScript.Echo("status="+r.Status)}catch(e){WScript.Echo("error="+(e.number>>>0).toString(16)+" "+e.message)}
     ```
     and run `run t cscript //nologo 'C:\https.js'`: the log contains `status=200`. If it fails, the `error=` line goes into `verify`. Without the `catch`, cscript would swallow the error (`CX/programs/wscript/main.c:123-128`) and `fixme-all` would hide even that.
  6. `cat "$H"/bottles/t/logs/*.log | grep -cE 'mvk-info|Failed to load libMoltenVK'` gives 0.
  7. `otool -L` on the installed `.dylib` files only shows `@loader_path`, `/usr/lib` and `/System`.
  8. `stop t` gives 0.
  9. `rm -rf "$H"` (~1.4 GB).

  **Check:** the output is pasted into `verify`.
- [x] **T17 (USER)** Commit in `bodega`, in your Terminal. The agent prepares the message, without AI attribution:
  ```sh
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega add .gitignore packages/engine .sdd
  git -C /Users/quasar/Documents/GitHub/Bodega/bodega commit -m 'engine: prototype Dart engine package and bodega CLI (SDD prototipo-motor)'
  ```
  No push: the repo has no remote yet. If you want one, ask for it.
  **Check (agent):** `git -C B log --oneline -1` shows the commit and `git -C B status --short` comes out empty.

## User acceptance
On the M2 Pro, with windows. Requires T4 and `build/bodega` on the PATH or called with its full path.

- [x] **U1** `bodega install <engine…tar.gz> <hostlibs…tar.gz>`.
  **Expected:** in under 2 min it prints `…/Application Support/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build`, and `ls "$HOME/Library/Application Support/Bodega/runtimes/current/engine/lib/wine/x86_64-unix/"*.dylib` shows `libfreetype.6`, `libgnutls.30`, `libMoltenVK` and their closure. Afterwards, **do not delete** `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (tarball and `.sha256`): changing the hostlibs means reinstalling from there (R6), and without it that would be a 335 MB download.
- [x] **U2** `time bodega create prueba`.
  **Expected:** it exits with 0 and with no `pista:` ("hint:") lines. Write down the time (Highball takes about 90 s with `-u`). `du -sh` on the bottle gives about 300 MB. If macOS warns about an Intel app or about Rosetta, that is not a failure.
- [x] **U3** `bodega run prueba notepad` and type "Caña, acción, pingüino". With notepad open, in another Terminal: `lsof -p $(pgrep -n -f notepad) | grep -E 'libfreetype|libgnutls|libMoltenVK'`.
  **Expected:** the menus and glyphs look right, which proves FreeType. `lsof` shows at least `libfreetype.6.dylib`, and all its lines are under `…/Bodega/runtimes/<id>/engine/lib/wine/x86_64-unix/`: that is the direct proof of the `LC_RPATH` under Rosetta on your macOS. When notepad closes, `echo $?` gives 0 and the printed log contains `# exit=0` and the 3-line header (`# cwd …/prefix/drive_c`), with no variables from your environment.
- [x] **U4** `bodega run prueba winecfg`.
  **Expected:** it opens, shows Windows 10 and closes without errors.
- [ ] **U5** Cave Story freeware (`Doukutsu.exe`, about 2 MB, 32-bit, DirectDraw), in a folder with a space and an accented letter on purpose: `bodega run prueba "$HOME/Juegos/Cave Story ñ/Doukutsu.exe"`.
  **Expected:** the window opens with picture and sound and responds to the keyboard; the `# cwd` header ends in `Cave Story ñ`. On exit, `bodega run` ends with its code.
- [x] **U6** Detaching, with notepad or Cave Story:
  1. Press Ctrl-C in the Terminal where `bodega run` is running. **Expected:** the program stays open.
  2. Close the program, launch it again with `bodega run` and close that Terminal window (⌘W and "Terminate"). **Expected:** the program stays open.
  3. In another Terminal run `bodega wait prueba` and close the program. **Expected:** `wait` returns about 3 s later.
- [x] **U7** Stopping: `bodega run prueba notepad` in one Terminal and `bodega stop prueba` in another.
  **Expected:** `stop` exits with 0, notepad closes within about 11 s at most and the first `run` ends. The `run` exits with 0 (design §2). Afterwards, `lsof 2>/dev/null | grep "Application Support/Bodega" | awk '{print $2}' | sort -u` prints nothing; if any PID is left, write it down, because there is no reaper. `pgrep -fl wine` does not work: it does not see the bottle's processes, which have Windows names, and it lists CrossOver's.
- [ ] **U8** Optional: a DX9 or DX11 game of yours, as a standalone `.exe` with no launcher.
  **Expected:** it starts with wined3d. Write down the FPS and the errors for the DXMT change.
