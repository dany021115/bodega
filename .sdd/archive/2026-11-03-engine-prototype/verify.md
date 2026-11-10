# Verification: engine-prototype

SDD **verify** phase · 2026-11-02 · checks requirements R1–R21 in `specs/*.md` against what `apply` built (T1–T16), with `design.md` and `tasks.md` as reference.

**Conventions**
- Paths: the aliases from `tasks.md` (`B`, `BE`, `P`, `RT`), plus `SCR` = `/private/tmp/claude-501/-Users-quasar/cabea996-65df-4091-b3df-9592ba319dd4/scratchpad`, where all the evidence lives. That folder is temporary: whatever is needed to back each status is pasted here.
- In the blocks, `$SCR` literally stands for that path and `<H>` for the group's `BODEGA_HOME` root (each group says which one it is). `[…]` marks a cut. Nothing else has been changed, apart from translating into English the notes added while writing this report; the other labels are the ones from the check scripts.
- `[S4]`, `[H3]`, `[C4]`, `[P1]`, `[V1]`… point to the blocks in §3. `test:N` is a line of `P/test/engine_test.dart`.
- **Met**: every scenario of the requirement has pasted output, from this verify or from T15/T16. **Partial**: at least one scenario has not been run exactly as written; §4 says which step closes it. A U step that only repeats something already shown appears in §4 as a confirmation and does not downgrade the status.
- **Refuter**: the first run failed because of a network outage. It was rerun and reviewed the 16 requirements marked as met (R1–R10, R12, R15, R16, R18–R20): it confirmed all 16, with no downgrades. While writing this report, the evidence on disk was reread and three details in the wording of the checks were corrected (§5.10); no status changed.

## 1. Summary

| Status | No. | Requirements |
|---|---|---|
| Met | 20 | R1–R16, R18–R21 |
| Partial | 1 | R17, accepted by the user (§6) |
| Not met | 0 | — |

- **Without Wine:** `dart analyze` → `No issues found!`; `dart test` → `All tests passed!`, with the `real runtime` group skipped, giving its reason [S2, S4].
- **CLI:** `build/bodega` is arm64, with a valid ad hoc signature, and only links `/usr/lib` and `/System`. Exit codes 64, 1 and N come out as R2 says [S5, T13-1…T13-3, X2–X5, H5].
- **Real runtime with hostlibs, no windows:** `install` in 4.28 s, `create` in 12.52 s, the `real runtime` group green and a live `stop` that leaves the bottle with no processes in 0.13 s [H1–H3]. No log with hostlibs gives FreeType or GnuTLS hints or `Failed to load libMoltenVK`; without hostlibs (T15) they do show up [P1, P2].
- **CI:** run 41512345512 of `build-hostlibs` comes out green in 43 s on `macos-15-intel` and runs exactly the YAML from commit 8a00dea. Release, `.sha256` and local files match [C1–C10].
- **Main finding (§5.1):** after `bodega stop`, the waiting `run` exits with **0** and its `.exit` says `0` (2 times out of 2), not with 128 + the signal as `design.md:89` says. R11 and R14 are met as written, but a decision is needed on whether to correct the design or the spec.
- **Tasks:** T1–T17 done. U1–U4, U6 and U7 pass. U5 was replaced by a check without windows and U8 was not done (§7). The tables in §2 and §4 keep the status from before these tests for rows R11, R13, R14 and R21; §7 prevails.

## 2. Requirement → status → evidence

| Req | Status | Evidence | Missing |
|---|---|---|---|
| R1 · Data root | met | Test `names and windows paths` [S4] (test:134-151): `BODEGA_HOME=$tmp/link/b` ends up as `$tmp/real/b` (canonicalized through a link, like `/tmp` → `/private/tmp`), with `runtimes/` and `bottles/`; `$tmp/a./b` gives `FormatException` with `"a."` and `$tmp/a.` never comes into existence. CLI: `BODEGA_HOME=…/a./b` → `bodega: "a." en …` ("bodega: 'a.' in …"), exit 1, and the parent folder stays empty [T13-3]; a valid root gets `bottles` and `runtimes` [T13-2]. | The default root is only seen in code (`lib/engine.dart:12`), because every check sets `BODEGA_HOME`. U1 uses it. |
| R2 · Verbs and exit codes | met | No arguments, an unknown verb or a wrong number of arguments → the usage on stderr and 64, without creating the root [T13-1, X2]. `create 'a b'` → `bodega: nombre de botella no válido: "a b" …` ("bodega: invalid bottle name: 'a b' …"), 1 and no `bottles/a b` [T13-2]. Other errors → `bodega: …` and 1 [X3, X4, X5, H5c, H5d]. `run` exits with the N from the `.exit` (53 and 1) [H5a, H5b]; `wait` and `stop`, with their own (0) [H3, H6]. Build: `dart compile exe` → `build/bodega`, `Mach-O 64-bit executable arm64`, `Signature=adhoc`, `valid on disk`, and `otool -L` with only `/usr/lib` and `/System` [S5]. `pubspec.yaml` only has `dev_dependencies: test` [S1]. | — |
| R3 · Rosetta | met | Code review, as the spec prescribes [X7]: with a valid verb, `bin/bodega.dart:50-57` runs `/usr/bin/arch -x86_64 /usr/bin/true` before `bodegaHome()`, which creates the root, and before the verb. If it fails, it throws `falta Rosetta: softwareupdate --install-rosetta --agree-to-license` ("missing Rosetta: …"), and the `catch` writes `bodega: …` and leaves 1; no `bottles/x` can be left behind. Positive case: the probe gives 0 on this Mac [X7] and the verbs do get to run [T13-2, T13-3, H1, H3a, P5]. | The negative path is not run: it would require uninstalling Rosetta. |
| R4 · Verification before extracting | met | Test `installRuntime` [S4] (test:178-197): a `.sha256` of zeros → `engine-b.tar.gz: FAILED`; one that names another file → `no corresponde a engine-b.tar.gz` ("does not match engine-b.tar.gz"); no `.sha256` → `gh release download engine-b -R dany021115/bodega-engine`. Afterwards, `runtimes/` is still `['current', 'engine-a']`, with no `.tmp-*`. CLI without `.sha256` → `bodega: falta ….sha256: gh release download engine-zz -R dany021115/bodega-engine` ("bodega: missing ….sha256: …"), 1 and `runtimes/` empty [X5]. `grep -rn HttpClient lib bin` returns nothing [X6]. `shasum -c` runs in the tarball's folder (`lib/engine.dart:105-112`). Real pair: `OK` in both folders [C9]. | — |
| R5 · Extraction into a single staging folder | met | Scenario 1, test `installRuntime` [S4] (test:199-207): without `libgnutls` → `runtime incompleto: falta engine/lib/wine/x86_64-unix/libgnutls.30.dylib` ("incomplete runtime: missing …"), and `runtimes/` is still `['current', 'engine-a']`. Scenario 2, with the real tarballs [H1]: exit 0 in 4.28 s, it prints `<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build`, `x86_64-unix/` has the 12 `.dylib` files (`libgnutls.30.dylib` among them) and no `.tmp-*` entry is left. The T16 rerun also printed the folder [P5]. | U1 repeats it in the default root (confirmation). Not exercised: deleting a `.tmp-<id>` left by an earlier attempt (`lib/engine.dart:117-118`, code only). |
| R6 · Immutable runtimes | met | Test `installRuntime` [S4] (test:172-176): after deleting `engine-a.tar.gz.sha256`, reinstalling A → `ya instalado` ("already installed"). The check comes before R4 and R5 (`lib/engine.dart:95-99`) and its message gives the steps `bodega stop`, `rm -rf` and installing again. The engine pair is kept in `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (334861341 B and 120 B), with `shasum -c` OK and size and digest equal to the release's [C9]. | — |
| R7 · Current runtime | met | Test `installRuntime` [S4] (test:160-215): no runtime → `no hay runtime: bodega install` ("no runtime: bodega install"); after A → `runtimes/engine-a`; after B → `runtimes/engine-b`; with B deleted (dangling `current`) → `no hay runtime` again. Real: `current -> engine-wine-11.0-20261030T202616Z-primer-build` [H1], and every log carries `# runtime engine-wine-11.0-20261030T202616Z-primer-build` [H2]. CLI without a runtime: `create x` and `stop y` → `bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>` and 1, with no `bottles/x` [X4]. | `run` and `wait` without a runtime: code only (`lib/engine.dart:212,250`). |
| R8 · Name and layout | met | Test `names and windows paths` [S4] (test:121-126): accepts `prueba` and `cave-story_2` (`/h/bottles/<name>`) and throws `FormatException` with `''`, `.x`, `-x`, `a.`, `a b`, `a/b`, `a:b` and 65 `a`s. `run`, `wait` and `stop` on a bottle that does not exist → `no existe la botella nope` ("bottle nope does not exist") in the test (test:263-269) and in the CLI, with 1 and no new logs [X3, H5d]. Layout: Wine creates `bottles/t/prefix` (`wine: created the configuration directory '<H>/bottles/t/prefix'`) and the logs go in `bottles/t/logs/` [H3a, H6]. No UUID or JSON: `grep -niE 'uuid\|bottle\.json\|\.json'` → exit 1 [V1]. | — |
| R9 · Create | met | Test `fake runtime cycle` [S4] (test:224-233): the log of `createBottle('t')` contains `# exit=0`, and a second `create t` → `ya existe … rm -rf` ("already exists … rm -rf"). Real: `create t` exits with 0 in 12.52 s and prints `log: <H>/bottles/t/logs/2026-11-02T20-40-11.179908Z-wineboot.log`, which carries `# cwd <H>/bottles/t`, `# argv wineboot` and `# exit=0`; after the `-w` no process is left [H3a]. Also `create: 0:00:19.454293` [H2] and, in T15, `create: 0:00:10.369397` [P1]. Without a runtime it creates nothing [X4]. | U2 records the time in the default root. Not exercised: wineboot ≠ 0 and the 10-min cap on `-w` (`lib/engine.dart:183-193`, code only). |
| R10 · Bottle ready | met | Test `fake runtime cycle` [S4] (test:234-241): `createBottle('broken')`, whose wineboot gives 0 without syswow64, throws an error that contains `<home>/bottles/broken/logs/`, and its `-wineboot.log` is still there. Real, after `-w`: `889967 <H>/bottles/t/prefix/drive_c/windows/syswow64/kernel32.dll` and `3354095 <H>/bottles/t/prefix/system.reg` [H3a]. | That `run` requires the bottle to be ready: code only (`lib/engine.dart:215-218`). |
| R11 · Wait and stop | **met (§7)** | Scenario 1, test [S4] (test:260-261): with the fake `-k` that exits with 1, `stopBottle` → 0 and `waitBottle` → 0. Scenario 2 without a window, with `cmd /c ping -n 120 127.0.0.1` instead of notepad [H3]: `stop` → 0 in 0.25 s; the bottle's 10 processes, wineserver included, are gone at +0.13 s; the waiting `run` returns at +0.38 s, and afterwards neither `pgrep` nor `lsof` finds anything under `<H>`. The wineserver that was stopped is this prefix's: its cwd is `/private/tmp/.wine-501/server-100000d-4c4ae29`, derived from the prefix's dev/ino, even though the parent shell exports `WINEPREFIX` [H3, §3.1]. Without a server: `wait t` → 0 in 0.036 s [H4] and `stop t` → 0 in 0.04 s [H6]. | U7 (notepad, about 11 s at most and `pgrep` for survivors, because there is no reaper) and U6.3 (`wait` blocked until the program closes; here it only ran without a server). The stopped `run` exits with 0 (§5.1). |
| R12 · Hermetic environment | met | Scenarios 1 and 2: test `wineEnv is hermetic` [S4] (test:83-118), with a parent that brings `WINEARCH=win32`, `DYLD_LIBRARY_PATH`, `WINEDLLPATH`, `CX_ROOT`, `LANG`, `WINEDEBUG=+all` and `PATH=/opt/homebrew/bin`. Every launch of `/bin/sh`, `wine` and `wineserver` passes `environment: wineEnv(...)` and `includeParentEnvironment: false` (`lib/engine.dart:136-140,326-331,336-340`) [X6]. Scenario 3: `grep -cE 'DYLD_\|WINEARCH\|CX_\|LANG='` gives 0 in the log of T16's `run t cmd /c set` and in that of its rerun [P3], even though this session's shell exports `LANG` and `WINEPREFIX` [V1]. The log has `WINEDEBUG=fixme-all`, `WINE_HOST_PATH=/usr/bin:/bin:/usr/sbin:/sbin` and the bottle's `WINEPREFIX`. | — |
| R13 · Program and working directory | **met (§7)** | Scenario 1, test [S4] (test:251-259): `C:\Juegos\Mi Juego.exe`, with `drive_c/Juegos` created → `# cwd $prefix/drive_c/Juegos`. Scenario 3, test (test:243-249): `$tmp/no/Juego.exe` → `FileSystemException` with no new log; and in the CLI, `run t /nonexistent/x.exe` → `bodega: FileSystemException: Cannot resolve symbolic links, …`, 1 and no new logs [H5c]. With the real runtime, bare names (`cmd`, `rundll32`, `cscript`, `nonexistent.exe`) carry `# cwd …/prefix/drive_c` [H2, H5a, P2]. `C:\nope\x.exe` is passed as is (`# argv C:\nope\x.exe`) with cwd `drive_c`, because the folder does not exist [H5b]. The CLI's cwd is not inherited: the launched `sh` has cwd `<H>/bottles/t/prefix/drive_c` while the CLI runs in `B` [H3]. | Scenario 2 with notepad: U3. The branch for an existing Unix path (resolved, validated and with cwd in its folder) was not run: U5. |
| R14 · Detached launch and exit code | **met (§7)** | Scenario 1, test [S4] (test:252-255): the fake program exits with 7 and leaves a `sleep 5 &` with the log open; `exitOf` returns 7 in under 2 s. Scenario 2, in two halves: with the real runtime, `cmd /c exit 7` leaves `# exit=7` and a `.exit` with 7 (T15 [P1] and headless [H2]); and the CLI prints `log: <path>` and exits with the N from the `.exit` (53 and 1) [H5a, H5b]. Detachment: while the CLI waits, the launched `sh` has PPID 1 and PGID 54727, the same as `start.exe`, `cmd.exe` and `ping`, and at the end it writes the footer and the `.exit` [H3]. | Scenario 3 (closing the Terminal) and Ctrl-C: U6.2 and U6.1. `bodega run t cmd /c exit 7; echo $?` was not run literally with the CLI. After `stop`, N = 0 (§5.1). |
| R15 · One log per run | met | Test `fake runtime cycle` [S4] (test:256-258): the log of `C:\Juegos\Mi Juego.exe` ends in `-Mi_Juego.log` and contains `# exit=7`. With the real runtime the names are `<UTC with µs>-<label>.log`: `…-wineboot.log`, `…-cmd.log`, `…-rundll32.log`, `…-cscript.log`, `2026-11-02T20-46-14.412988Z-nonexistent.log` (from `nonexistent.exe`) and `2026-11-02T20-46-19.356089Z-x.log` (from `C:\nope\x.exe`). They all start with `# runtime <id>`, `# cwd …` and `# argv …`, none dumps the environment and all contain their `# exit=N` [H2, H5, H6, P1, P2]. Exclusive creation and no cap: code (`lib/engine.dart:360-363`) [T13-4]. | U3 repeats it with notepad. Not exercised: the 40-character cap on the label (`lib/engine.dart:237`). |
| R16 · Hints | met | Test `hints` [S4] (test:272-291): the log with the 4 markers gives 4 hints (FreeType, GnuTLS, `bodega stop`, path) and the clean one none. T15, without hostlibs: the `real runtime` group, which requires the FreeType and GnuTLS hints (test:337-344), passes; its logs have 15 FreeType markers and 6 GnuTLS markers in wineboot, and 2 and 1 in the bcrypt probe [P1]. CLI: `run t 'C:\nope\x.exe'` → stderr `pista: Wine no pudo abrir el programa: revisa su ruta (trampa 11)` ("hint: Wine could not open the program: check its path (pitfall 11)") and exit 53, same as its `.exit` [H5b]; a clean `create` → 0 `pista:` lines [H3a]. | Hints after a `create` that fails: code only (`bin/bodega.dart:18-31`). |
| R17 · A manual, cheap workflow | **partial** | Configuration [C7]: only `workflow_dispatch`, with `publish_release` (boolean) and `ref_note`; `contents: write`; `runs-on: macos-15-intel`, same as `build.yml:22`; `timeout-minutes: 15`; the 4 `HOMEBREW_*` and `ROOTS`; `install` with `timeout-minutes: 5`; no checkout and no Wine build. Scenario 1 [C1, C2]: run 41512345512 with `conclusion=success`, a 43 s job with `labels=["macos-15-intel"]`; the guard prints `freetype 2.14.3` and `gnutls 3.8.13_2`, and `install` only pours `molten-vk--1.4.2.sonoma.bottle.tar.gz`. What ran is the YAML from commit 8a00dea, which is `HEAD` and `origin/main` of `BE` [C6, C7]. | Scenario 2 (with an image without freetype or gnutls, the job fails within seconds with the message): not run, and no U step covers it. Only the guard's text and its positive path are on record. |
| R18 · Closure and names | met | `bundle` step green (12 s). It prints `x86_64-unix: [...]` with 12 leaves, a line that comes after `assert not left, left` (YAML:78-80), so the assertion passed [C3]. Scenario, on the published artifact [C11]: no reference outside `@loader_path/`, `/usr/lib/` and `/System/`; every `.dylib` with `id=@loader_path/<leaf>`, x86_64, `Signature=adhoc` and `verify=valid`. The copy installed in T16 gives the same [P4]. The roots come in as arguments (`python3 - $ROOTS`) and the closure has no SDL2, FFmpeg or GStreamer [C3]. | T2's output is not part of this evidence (T2 was closed in `apply`). |
| R19 · Load probe by leaf name | met | `probe` step green (3 s) on `macos-15-intel` [C4]. Its last 3 lines are the `grep -F` of each root, loaded from `/Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/`. Of 605 unique images, 424 are from `/System/`, 167 from `/usr/lib/`, 13 from `out/…/x86_64-unix/` (12 `.dylib` files and `probe.so`) and 1 is the executable; 0 lines with `/usr/local`, the Intel Homebrew prefix (see `Cellar` in [C2]), or with `/opt/homebrew`. The setup that ran (`-Wl,-rpath,@loader_path/`, executable without rpath, `env -i`, `cd /`, log in `$RUNNER_TEMP`) is the YAML's [C4, C6]. | T2's output is not part of this evidence. |
| R20 · Artifact | met | Scenario [C10]: `tar -tzf … \| grep -E '/$\|^\./'` gives nothing (exit 1). There are 13 entries, all files: `hostlibs.txt` and `engine/lib/wine/x86_64-unix/*.dylib`. `hostlibs.txt` carries the name, `runner image: macos15 20260824.0482.1`, `brew list --versions` and the 12 files. It weighs 5121991 B (< 30 MiB), with the CI assertion passed [C5]. Name `hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz`, with the note passed through `env` (`NOTE: primer-hostlibs`) [C5]. `.sha256` in the `<hex>  <name>` format, same as the engine's [C10]; `shasum -c` OK and digest equal to the asset's [C9]. Release: tag = file name, author `github-actions[bot]`, created by `publish` with `GH_TOKEN` and `GH_REPO` [C5, C8]. | Not exercised: the sanitizing of `ref_note` (`primer-hostlibs` has nothing to change). |
| R21 · Use without variables | **met (§7)** | Scenario 1: with hostlibs, 0 FreeType or GnuTLS markers and 0 `mvk-info`/`Failed to load libMoltenVK` in T16's 5 logs (wineboot, `cmd /c set`, the two `rundll32` probes and `cscript`) and in those of its rerun; T16's literal step 6 gives `0` [P2, P5]. The `real runtime` group with hostlibs, which requires that there be no hints, passes, and its 5 logs give 0 [H2]. Scenario 2: T15, without hostlibs, gives both hints and `Failed to load libMoltenVK.dylib`, with dyld searching in `…/t15-rt/engine/lib/wine/x86_64-unix/libMoltenVK.dylib` [P1]. Scenario 3: `cscript //nologo C:\https.js` → `status=200` and `.exit` 0 [P2]. Scenario 4, without a window, on the Apple M2 Pro [V1]: `lsof` shows `libfreetype.6.dylib` and `libpng16.16.dylib` loaded from `<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/` in `start.exe`, `plugplay.exe`, `winedevice.exe` and `cmd.exe`, launched by `build/bodega` with an environment without `DYLD_*` (R12) [H3]. Mechanism: `win32u.so`, `dwrite.so`, `bcrypt.so`, `crypt32.so` and `secur32.so` carry `LC_RPATH @loader_path/`, and the `wine` loader carries none [C12]. | U3: glyphs drawn with FreeType and `lsof` of notepad. |

## 3. Outputs backing each status

### 3.1 Group `static-unit-cli`

Evidence in `$SCR/verify-static-unit-cli-20261102T202728Z` (`00-environment.txt` … `15-pubspec.txt`), from 2026-11-02 between 20:29 and 20:36 UTC. Under verify's rules, T13's `BODEGA_HOME` roots are new folders inside that evidence and not `$(mktemp -d)` in `$TMPDIR`; the usage check also gets one, to prove that nothing is created. The meaning of each T13 check does not change. The `---- Xn` labels in `09-extra-cli.txt` do not match the `[Xn]` ids in this report.

**Environment**
```
## sw_vers / uname -m
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
arm64
## which dart / dart --version
/opt/homebrew/bin/dart
Dart SDK version: 3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"
## inherited BODEGA_* / WINE* / TMPDIR (values of WINE* redacted to presence only)
(no BODEGA_* variables set)
WINEPREFIX=<set>
TMPDIR=/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/
```

**[S1] Dependencies** (T5; R2, no runtime dependencies)
```
$ (cd P &&) dart pub get --offline
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 96.0.0 (107.0.0 available)
  analyzer 10.2.0 (14.3.0 available)
  package_config 2.2.0 (3.0.0 available)
Got dependencies!
3 packages have newer versions incompatible with dependency constraints.
Try `dart pub outdated` for more information.
[exit=0]
$ (cd P &&) cat pubspec.yaml
name: engine
publish_to: none

environment:
  sdk: ^3.13.0

dev_dependencies:
  test: ^1.31.1
[exit=0]
```
`pubspec.lock` does not change: `efbc8199…` before and after [POST].

**[S2] Analysis** (T5)
```
$ (cd P &&) dart analyze
Analyzing engine...
No issues found!
[exit=0]
```

**[S3] Formatting** (hygiene; backs no requirement)
```
$ (cd P &&) dart format --output=none --set-exit-if-changed lib bin test
Formatted 3 files (0 changed) in 0.01 seconds.
[exit=0]
```

**[S4] Tests without Wine** (T6–T12 and T14)
```
## $TMPDIR bodega* entries BEFORE
(eval):4: no matches found: /var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega*
(none)
## BODEGA_TEST_RUNTIME=<unset>
$ (cd P &&) dart test
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: wineEnv is hermetic
00:00 +1: test/engine_test.dart: names and windows paths
00:00 +2: test/engine_test.dart: installRuntime
00:01 +3: test/engine_test.dart: fake runtime cycle
00:02 +4: test/engine_test.dart: hints
00:02 +5: test/engine_test.dart: real runtime cycle
  Skip: BODEGA_TEST_RUNTIME no está definida
00:02 +5 ~1: All tests passed!
[exit=0]  wall=3s
## $TMPDIR bodega* entries AFTER
(eval):10: no matches found: /var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega*
(none)
```
What this output counts as passed, according to the `Check` line of each spec:
- `wineEnv is hermetic` (test:83-118) → R12, scenarios 1 and 2.
- `names and windows paths` (test:120-152) → R1 and R8.
- `installRuntime` (test:154-216) → R4, R5, R6 and R7.
- `fake runtime cycle` (test:218-270) → R8 (nonexistent bottle), R9, R10, R11, R13, R14 and R15.
- `hints` (test:272-291) → R16.
- `real runtime cycle`, skipped with its reason → T14. Its assertions with the real runtime are in [H2] and [P1].

**[S5] Compilation, type and signature** (R2; T13)
```
## pre-check: processes executing build/bodega
(none)
$ (cd P &&) mkdir -p ../../build && dart compile exe bin/bodega.dart -o ../../build/bodega
Generated: /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
[exit=0]
## build/bodega AFTER recompile
-rwxr-xr-x@ 1 quasar  staff  6010208 Nov  2 15:30 /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
(before: e39ad46d1e2ded29b3a21650409d7964c81249b0bc26c1a043be0485c4b75bb0, 6010208 bytes, 14:15)
$ (cd B &&) file build/bodega
build/bodega: Mach-O 64-bit executable arm64
[exit=0]
$ (cd B &&) codesign -dv build/bodega
Executable=/Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
Identifier=bodega-555549444c4c440155553144a107cc88f2ac6917
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=11944 flags=0x20002(adhoc,linker-signed) hashes=367+2 location=embedded
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements count=0 size=12
[exit=0]
$ (cd B &&) otool -L build/bodega
build/bodega:
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)
	/System/Library/Frameworks/Security.framework/Versions/A/Security (compatibility version 1.0.0, current version 61123.100.169)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 2420.0.0)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 2420.0.0)
	/System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices (compatibility version 1.0.0, current version 1226.0.0)
[exit=0]
$ (cd B &&) codesign --verify --strict --verbose=2 build/bodega
build/bodega: valid on disk
build/bodega: satisfies its Designated Requirement
[exit=0]
```

**[T13-1] No arguments** (R2)
```
---- T13.1 no arguments -> usage on stderr, 64
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>
[exit=64]
post: ls -ld $U
ls: $SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist: No such file or directory
```

**[T13-2] Invalid name** (R2, R8; R1, valid root; R3, positive case)
```
---- T13.2 invalid bottle name 'a b' -> 1
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-ab.wvnuTE build/bodega create a b
[stdout]
[stderr]
bodega: nombre de botella no válido: "a b" (letras, números, _ y -, hasta 64, sin empezar por _ ni -)
[exit=1]
```
The command log lost the quotes: the message shows that a single argument arrived, `"a b"` (with two, the pattern would not match and the usage would come out with 64). State of that root, listed while writing this report without following links:
```
$ ls -A h-ab.wvnuTE
bottles
runtimes
[exit=0]
$ ls -A h-ab.wvnuTE/bottles
[exit=0]
```

**[T13-3] Root with an `a.` component** (R1, R2; R3, positive case)
```
---- T13.3 root with component 'a.' -> 1, names it
$ (cd B &&) BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-dot.p6KgMF/a./b build/bodega stop x
[stdout]
[stderr]
bodega: "a." en $SCR/verify-static-unit-cli-20261102T202728Z/h-dot.p6KgMF/a./b: Windows no admite nombres que acaben en punto o espacio ni que lleven <>:"|?*
[exit=1]
post: ls -A $H0 (must be empty: rejected root not created)
(ls exit=0)
```
Repeated while writing this report: `ls -A h-dot.p6KgMF` → nothing, `[exit=0]`.

**[T13-4] `ponytail:` markers** (T13; R10, R11, R12, R15 and design §7)
```
$ (cd P &&) cat lib/engine.dart bin/bodega.dart | grep -c 'ponytail:'
6
[exit=0]
$ (cd P &&) grep -n 'ponytail:' lib/engine.dart bin/bodega.dart
lib/engine.dart:69:  // ponytail: BODEGA_WINEDEBUG is the only knob read from the caller.
lib/engine.dart:150:  // ponytail: one global runtime; installing another while bottles run gives
lib/engine.dart:194:  // ponytail: syswow64 is not repaired (Highball copies i386-windows); in a
lib/engine.dart:256:  // ponytail: no reaper; whatever survives -k (trap 6) stays, and acceptance
lib/engine.dart:266:  // ponytail: no timeout; if the shell dies by SIGKILL there is no .exit and
lib/engine.dart:360:  // ponytail: no size cap or rotation; patch 0014 fixed the known runaway log
[exit=0]
```
The five simplifications that T13 asks for are there (`:360`, `:69`, `:256`, `:194`, `:150`), plus one more (`:266`).

**[X2] Unknown verb and wrong arity** (R2)
```
---- X1 unknown verb -> usage, 64 (R2)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega frobnicate x
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>
[exit=64]
---- X2 wrong arity 'install' with 1 arg -> usage, 64 (R2)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist build/bodega install only-one.tar.gz
[stdout]
[stderr]
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[…the other 4 usage lines, identical]
[exit=64]
post: ls -ld $U
ls: $SCR/verify-static-unit-cli-20261102T202728Z/usage-root-must-not-exist: No such file or directory
```

**[X3] Nonexistent bottle** (R8; R2)
```
---- X3 stop on missing bottle (R8)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega stop x
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
---- X4 wait on missing bottle (R8)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega wait x
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
---- X5 run on missing bottle (R8; program never reached)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega run x cmd /c echo ok
[stdout]
[stderr]
bodega: no existe la botella x
[exit=1]
```

**[X4] No runtime installed** (R7; R9, step 1)
```
---- X6 create with no runtime installed (R7, R9.1)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega create x
[stdout]
[stderr]
bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[exit=1]
post: ls -A $H/bottles (must be empty)
(ls exit=0)
---- X7 stop on existing bottle dir but no runtime (R7)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega stop y
[stdout]
[stderr]
bodega: no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>
[exit=1]
```
Before `stop y` the check created `bottles/y` by hand: getting `no hay runtime` and not `no existe la botella y` confirms it, because `stopBottle` checks the bottle before the runtime (`lib/engine.dart:255-258`).

**[X5] `install` without `.sha256`** (R4)
```
---- X8 install without .sha256 (R4)
$ (cd B &&) env BODEGA_HOME=$SCR/verify-static-unit-cli-20261102T202728Z/h-x.Wg78U7 build/bodega install $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/engine-zz.tar.gz $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/hostlibs-zz.tar.gz
[stdout]
[stderr]
bodega: falta $SCR/verify-static-unit-cli-20261102T202728Z/nofiles/engine-zz.tar.gz.sha256: gh release download engine-zz -R dany021115/bodega-engine
[exit=1]
post: ls -A $H/runtimes (must be empty: nothing new, no .tmp-*)
(ls exit=0)
```
`nofiles/` does not exist (`ls -ld …/nofiles` → `No such file or directory`), so here the tarball is missing too; the case with the tarball present is covered by the test (test:190-196).

**[X6] Code searches** (R4, R12, R2; design §2)
```
$ (cd P &&) grep -rn HttpClient lib bin
[exit=1]  (1 = no match)
$ (cd P &&) grep -n '^import' lib/engine.dart bin/bodega.dart
bin/bodega.dart:1:import 'dart:io';
bin/bodega.dart:3:import 'package:engine/engine.dart';
lib/engine.dart:5:import 'dart:convert';
lib/engine.dart:6:import 'dart:io';
[exit=0]
$ (cd P &&) grep -nE 'Process\.(start|run)\(|includeParentEnvironment|^Future<String> _run' lib/engine.dart bin/bodega.dart
lib/engine.dart:124:    await Process.run('/usr/bin/xattr', [
lib/engine.dart:136:    final version = await Process.run(
lib/engine.dart:140:      includeParentEnvironment: false,
lib/engine.dart:326:}) => Process.start(
lib/engine.dart:331:  includeParentEnvironment: false,
lib/engine.dart:336:  final server = await Process.start(
lib/engine.dart:340:    includeParentEnvironment: false,
lib/engine.dart:372:Future<String> _run(String exe, List<String> args, [String? cwd]) async {
lib/engine.dart:373:  final result = await Process.run(exe, args, workingDirectory: cwd);
bin/bodega.dart:50:    final rosetta = await Process.run('/usr/bin/arch', [
[exit=0]
$ (cd P &&) grep -nE "_run\('" lib/engine.dart
107:    final out = await _run('/usr/bin/shasum', [
122:      await _run('/usr/bin/tar', ['-xzf', tarball, '-C', tmp.path]);
[exit=0]
$ (cd P &&) grep -n 'environment: wineEnv' lib/engine.dart
139:      environment: wineEnv('${tmp.path}/prefix', Platform.environment),
330:  environment: wineEnv(prefix, Platform.environment),
339:    environment: wineEnv(prefix, Platform.environment),
[exit=0]
```
`:136` is `wine --version`, `:326` the `/bin/sh` of `_start` and `:336` the `wineserver`. `Process.run` is only used with `xattr`, `wine --version`, `shasum`, `tar` and `arch`.

**[X7] Rosetta** (R3, code review and positive case)
```
$ (cd P &&) grep -nE 'verb == null|exitCode = 64|/usr/bin/arch|falta Rosetta|bodegaHome\(Platform|exitCode = 1' bin/bodega.dart
44:  if (verb == null) {
46:    exitCode = 64;
50:    final rosetta = await Process.run('/usr/bin/arch', [
55:      throw 'falta Rosetta: '
58:    exitCode = await verb(bodegaHome(Platform.environment));
61:    exitCode = 1;
[exit=0]
$ /usr/bin/arch -x86_64 /usr/bin/true
[exit=0]
$ (cd P &&) sed -n '44,62p' bin/bodega.dart
  if (verb == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final rosetta = await Process.run('/usr/bin/arch', [
      '-x86_64',
      '/usr/bin/true',
    ]);
    if (rosetta.exitCode != 0) {
      throw 'falta Rosetta: '
          'softwareupdate --install-rosetta --agree-to-license';
    }
    exitCode = await verb(bodegaHome(Platform.environment));
  } catch (e) {
    stderr.writeln('bodega: ${e is FormatException ? e.message : e}');
    exitCode = 1;
  }
```
An unknown verb exits with the usage before the probe; with a valid one, the probe comes before `bodegaHome()`, which is what creates the root, and before the verb.

**[X8] Build reproducibility** (binary identity; see §5.5)
```
$ (cd P &&) dart compile exe bin/bodega.dart -o $EV/repro/bodega
Generated: $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
[exit=0]
## sizes / hashes
-rwxr-xr-x@ 1 quasar  wheel  6010208 Nov  2 15:35 $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
-rwxr-xr-x@ 1 quasar  staff  6010208 Nov  2 15:30 /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
6d7bab0a893d5d223f9595c5a7baaa7927bf3b7083c3d2eeab9f7575b26ce701  $SCR/verify-static-unit-cli-20261102T202728Z/repro/bodega
## differing bytes: cmp -l build/bodega repro/bodega | wc -l
     101
## LC_UUID
[…]    uuid 4C4C4401-5555-3144-A107-CC88F2AC6917   (both)
## clusters of differing bytes (offsets decimal, gap>4096 starts a new cluster)
  5922298..5922303 (5 bytes)
  5932001..5932032 (32 bytes)
  6009981..6010044 (64 bytes)
## where: __LINKEDIT / code signature offsets
  dataoff 5998192
 datasize 12016
  fileoff 5947392
[…]
```

**[POST] State at the end of the group**
```
## source hashes BEFORE (00-environment.txt)
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
## source hashes AFTER (12-post-state.txt)
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
## all processes whose command mentions CrossOver (pid ppid start command, args trimmed to 160 chars)
  PID  PPID STARTED                      COMMAND
47400     1 Mon Nov  2 15:32:21 2026     /Users/quasar/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/../../bin/wineserver
79727     1 Fri Oct 30 15:11:15 2026     /Users/quasar/Applications/CrossOver.app/Contents/MacOS/CrossOver
## does bodega code reference CrossOver / an absolute wineserver path?
$ (cd P &&) grep -rniE 'crossover|Applications/' lib bin
[exit=1]  (1 = no match)
## timeline of this verification (evidence file mtimes, local time)
[…]
15:31:42  10-static-extras.txt
15:35:23  11-repro-and-code.txt
[…]
## creation (birth) and mtime of repro/ dir and repro/bodega (block 11's first write; local time)
birth 15:35:22  mtime 15:35:22  repro
birth 15:35:22  mtime 15:35:22  repro/bodega
```
While writing this report, this group's roots still have no runtime, so no invocation could resolve a `wine` or a `wineserver`:
```
$ ls -A h-ab.wvnuTE/runtimes
[exit=0]
$ ls -A h-x.Wg78U7/runtimes
[exit=0]
```
The hashes also match while writing this report [V1]: what was verified is the code that is there now.

### 3.2 Group `headless-runtime`

Evidence in `$SCR/verify-headless-evidence-20261102T203816Z`, from 2026-11-02 between 20:38 and 20:47 UTC. `<H>` = `$SCR/verify-headless-home-20261102T203816Z`, new (it did not exist) and deleted in [H6]. The binary is the `build/bodega` recompiled in [S5] (`7c10f6ab…`). The tarballs are the ones from `RT` and the hostlibs from T4.

**[H1] `install` with the real tarballs** (R1, R2, R3 positive, R4, R5, R7; R20, consuming the tarball)
```
$ cd B && BODEGA_HOME=<H> /usr/bin/time -p build/bodega install /Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine-wine-11.0-20261030T202616Z-primer-build.tar.gz /Users/quasar/Documents/GitHub/Bodega/runtimes/hostlibs-x86_64-20261102T194229Z-primer-hostlibs/hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
start=2026-11-02T20:38:24Z
exit=0
end=2026-11-02T20:38:28Z
== stdout
<H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
== stderr
real 4.28
user 2.16
sys 1.26
== runtimes/
lrwxr-xr-x  current -> engine-wine-11.0-20261030T202616Z-primer-build
drwxr-xr-x  engine-wine-11.0-20261030T202616Z-primer-build
== x86_64-unix dylibs
libfreetype.6.dylib libgmp.10.dylib libgnutls.30.dylib libhogweed.7.dylib libidn2.0.dylib libintl.8.dylib libMoltenVK.dylib libnettle.9.dylib libp11-kit.0.dylib libpng16.16.dylib libtasn1.6.dylib libunistring.5.dylib
974M  <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
.tmp-* entries in runtimes/: 0 ; bottles/ entries: 0
```

**[H2] `real runtime` group with hostlibs** (R7, R9, R10, R11, R13, R14, R15, R16, R21)
```
$ cd P && TMPDIR=$SCR/verify-headless-tmpdir-20261102T203816Z BODEGA_TEST_RUNTIME=<H>/runtimes/current dart test -N 'real runtime'
start=2026-11-02T20:39:05Z
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: real runtime (setUpAll)
00:00 +0: test/engine_test.dart: real runtime cycle
create: 0:00:19.454293
00:25 +1: test/engine_test.dart: real runtime (tearDownAll)
00:25 +1: All tests passed!
end=2026-11-02T20:39:31Z
rc=0
```
The runtime has `x86_64-unix/libgnutls.30.dylib`, so the test took the branch that requires no FreeType or GnuTLS hints (test:337-344). Logs copied before `tearDownAll` deleted its root (`2-test-logs/`):
```
== 2026-11-02T20-39-25.432780Z-cmd.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv cmd /c echo ok
msync: bootstrapped mach port on wine-4c4a479-msync.
msync: up and running.
009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
ok
# exit=0
== 2026-11-02T20-39-27.850869Z-cmd.log (.exit 7)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv cmd /c exit 7
# exit=7
== 2026-11-02T20-39-28.496377Z-rundll32.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/verify-headless-tmpdir-20261102T203816Z/bodega-reals5Z6l9/bottles/t/prefix/drive_c
# argv rundll32 dwrite.dll,BodegaProbe
00f8:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"dwrite.dll"
# exit=0
== 2026-11-02T20-39-30.132522Z-rundll32.log (.exit 0)
[…same header]
# argv rundll32 bcrypt.dll,BodegaProbe
0144:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
== markers (cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK) count per log:
...20-39-05.974359Z-wineboot.log:0
...20-39-28.496377Z-rundll32.log:0
...20-39-27.850869Z-cmd.log:0
...20-39-25.432780Z-cmd.log:0
...20-39-30.132522Z-rundll32.log:0
== TMPD after test: empty (test home deleted by tearDownAll)
== pgrep -fl "<H>|<TMPD>": (none)
```
`Unable to find the entry point L"BodegaProbe"` is expected: the probe only needs `DllMain` to load the library (design §6).

**[H3a] `create t`** (R2, R8, R9, R10, R15; R16 and R21, no hints)
```
$ BODEGA_HOME=<H> /usr/bin/time -p build/bodega create t
start=2026-11-02T20:40:11Z
exit=0
end=2026-11-02T20:40:23Z
== stdout
log: <H>/bottles/t/logs/2026-11-02T20-40-11.179908Z-wineboot.log
== stderr
real 12.52
user 0.13
sys 0.11
== pista lines: 0
== ready files
-rw-r--r--  889967  <H>/bottles/t/prefix/drive_c/windows/syswow64/kernel32.dll
-rw-r--r-- 3354095  <H>/bottles/t/prefix/system.reg
== processes referencing H after create (wineserver -w returned):
(none)
== 6-bottle-t-logs/2026-11-02T20-40-11.179908Z-wineboot.log (.exit 0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd <H>/bottles/t
# argv wineboot
wine: created the configuration directory '<H>/bottles/t/prefix'
msync: bootstrapped mach port on wine-4c4ae29-msync.
msync: up and running.
[…11 err:ole, err:setupapi and err:ntoskrnl (winebth) lines]
# exit=0
```

**[H3] Live `stop`** (R11, R12, R13, R14, R15, R21). `3-live-stop.py` launches `run` and leaves it waiting, as in a Terminal; once the bottle's wineserver is alive, it takes a snapshot of the processes and runs `stop`, polling `ps` every 100 ms.
```
launch 2026-11-02T20:45:15Z BODEGA_HOME=<H> bodega run t cmd /c 'ping -n 120 127.0.0.1'
run printed: log: <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log
alive check at +12.2s after launch, 2026-11-02T20:45:27Z
run CLI still waiting: True | .exit exists: False
--- pgrep -fl <H>
54728 /bin/sh -c l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s bodega <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/bin/wine cmd /c ping -n 120 127.0.0.1
54732 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/../../bin/wineserver
--- prefix dev/ino -> wineserver dir /tmp/.wine-501/server-100000d-4c4ae29
--- 10 processes whose open files/mappings mention <H> (lsof):
  PID  PPID  PGID STAT ELAPSED COMMAND
54728     1 54727 S      00:12 /bin/sh -c l=$1; shift; […]
54729 54728 54727 S      00:12 start.exe /exec cmd /c
54732     1 54732 Ss     00:12 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/../../bin/wineserver
54736     1 54736 Ss     00:12 C:\windows\system32\services.exe 
54738     1 54738 Ss     00:11 C:\windows\system32\winedevice.exe 
54740     1 54740 Ss     00:11 C:\windows\system32\plugplay.exe 
54751     1 54751 Ss     00:11 C:\windows\system32\svchost.exe -k LocalServiceNetworkRestricted 
54753     1 54753 Ss     00:11 C:\windows\system32\winedevice.exe 
54755     1 54727 S      00:10 C:\windows\system32\cmd.exe /c ping -n 120 127.0.0.1 
54757     1 54727 S      00:10 ping -n 120 127.0.0.1
[…]
wineserver pid 54732 cwd: wineserve 54732 quasar  cwd    DIR   1,13      192 79998510 /private/tmp/.wine-501/server-100000d-4c4ae29 | matches prefix server dir: True
--- stop at +12.7s after launch, 2026-11-02T20:45:27Z
stop: exit=0 returned at +0.25s stdout='' stderr=''
  pid  54753 gone at +0.13s  C:\windows\system32\winedevice.exe 
  pid  54755 gone at +0.13s  C:\windows\system32\cmd.exe /c ping -n 120 127.0.0.1 
  pid  54757 gone at +0.13s  ping -n 120 127.0.0.1 
  pid  54728 gone at +0.13s  /bin/sh -c l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; echo "# exit=$s" >>"$l"; echo "
  pid  54729 gone at +0.13s  start.exe /exec cmd /c
  pid  54732 gone at +0.13s  $SCR/veri
  pid  54736 gone at +0.13s  C:\windows\system32\services.exe 
  pid  54738 gone at +0.13s  C:\windows\system32\winedevice.exe 
  pid  54740 gone at +0.13s  C:\windows\system32\plugplay.exe 
  pid  54751 gone at +0.13s  C:\windows\system32\svchost.exe -k LocalServiceNetworkRestricted 
last tracked process gone at +0.13s; wineserver gone at +0.13s
waiting run CLI: exit=0 returned at +0.38s after stop
.exit file: 2026-11-02T20-45-15.066826Z-cmd.exit -> 0
log has "# exit=" lines: ['# exit=0'] | "Reply from" lines: 0 | log has "Ping statistics": False
[…]
run stdout: log: <H>/bottles/t/logs/2026-11-02T20-45-15.066826Z-cmd.log
run stderr: ''
launch -> run returned: 13.1s (ping -n 120 alone would need >= 119 s)
--- wait t: exit=0 in 0.036s stdout='' stderr=''
--- pgrep -fl <H> after stop+wait:
(none)
--- processes with open files/mappings under <H> (lsof): (none)
```
Hostlibs lines in the `lsof` snapshot taken before the `stop` (`3-lsof-before.txt`, filtered to `<H>` by the script), queried while writing this report:
```
$ grep -nE 'libfreetype|libgnutls|libMoltenVK' 3-lsof-before.txt
20:start.exe 54729 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
249:plugplay. 54740 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
309:winedevic 54753 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
350:cmd.exe   54755 quasar  txt       REG               1,13     658384            79995838 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
$ grep -E 'x86_64-unix/lib[^/]+\.dylib' 3-lsof-before.txt | awk '{print $NF}' | sort | uniq -c
   4 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
   4 <H>/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libpng16.16.dylib
$ head -3 3-lsof-before.txt   (first line)
bash      54728 quasar  cwd       DIR               1,13        224            79998507 <H>/bottles/t/prefix/drive_c
```
First attempt, with the same result (its probe expected a process titled `ping.exe`, ran out its 90 s and its cleanup ran `bodega stop t`; §5.9):
```
launch 2026-11-02T20:41:29Z BODEGA_HOME=<H> bodega run t cmd /c 'ping -n 120 127.0.0.1'
run printed: log: <H>/bottles/t/logs/2026-11-02T20-41-29.185096Z-cmd.log
[…]
FAIL: ping.exe or wineserver not seen within 90 s -> cleanup: bodega stop t = 0
$ (while writing) header and tail of 6-bottle-t-logs/2026-11-02T20-41-29.185096Z-cmd.log, grep -c and stat of the .exit
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd <H>/bottles/t/prefix/drive_c
# argv cmd /c ping -n 120 127.0.0.1
[…]
Reply from 127.0.0.1: bytes=32 time<1ms TTL=64
R# exit=0
Reply-from lines: 86  Ping statistics lines: 0
2026-11-02T15:42:59-0500 …/6-bottle-t-logs/2026-11-02T20-41-29.185096Z-cmd.exit   (contents: 0)
```

**[H4] `wait` right after the `stop`** (R11): the line `--- wait t: exit=0 in 0.036s stdout='' stderr=''` from [H3].

**[H5] Deliberate failures** (R2, R8, R13, R14, R15, R16; `5-failures.txt`)
```
=== bodega run t nonexistent.exe
exit=1 in 4.95s
stdout: 'log: <H>/bottles/t/logs/2026-11-02T20-46-14.412988Z-nonexistent.log\n'
stderr: ''
new files in bottles/t/logs: ['2026-11-02T20-46-14.412988Z-nonexistent.exit', '2026-11-02T20-46-14.412988Z-nonexistent.log']
  2026-11-02T20-46-14.412988Z-nonexistent.exit -> 1
  2026-11-02T20-46-14.412988Z-nonexistent.log:
   | # runtime engine-wine-11.0-20261030T202616Z-primer-build
   | # cwd <H>/bottles/t/prefix/drive_c
   | # argv nonexistent.exe
   | msync: bootstrapped mach port on wine-4c4ae29-msync.
   | msync: up and running.
   | 009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
   | Application could not be started, or no application associated with the specified file.
   | ShellExecuteEx failed: Environment variable not found.
   | # exit=1
=== bodega run t C:\nope\x.exe
exit=53 in 0.41s
stdout: 'log: <H>/bottles/t/logs/2026-11-02T20-46-19.356089Z-x.log\n'
stderr: 'pista: Wine no pudo abrir el programa: revisa su ruta (trampa 11)\n'
new files in bottles/t/logs: ['2026-11-02T20-46-19.356089Z-x.exit', '2026-11-02T20-46-19.356089Z-x.log']
  2026-11-02T20-46-19.356089Z-x.exit -> 53
  2026-11-02T20-46-19.356089Z-x.log:
   | # runtime engine-wine-11.0-20261030T202616Z-primer-build
   | # cwd <H>/bottles/t/prefix/drive_c
   | # argv C:\nope\x.exe
   | wine: failed to open "C:\\nope\\x.exe"
   | # exit=53
=== bodega run t /nonexistent/x.exe
exit=1 in 0.03s
stdout: ''
stderr: "bodega: FileSystemException: Cannot resolve symbolic links, path = '/nonexistent/x.exe' (OS Error: No such file or directory, errno = 2)\n"
new files in bottles/t/logs: none
=== bodega run nope cmd /c echo hi
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bodega wait nope
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bodega stop nope
exit=1 in 0.02s
stdout: ''
stderr: 'bodega: no existe la botella nope\n'
new files in bottles/t/logs: none
=== bottles/ now: ['t']
```
`[H5a]` is the first case, `[H5b]` the second, `[H5c]` the third and `[H5d]` the last three.

**[H6] Cleanup** (R11, `stop` without a server; design §6)
```
== 6.1 bodega stop t
real 0.04
user 0.01
sys 0.01
exit=0
== 6.2 pgrep -fl <H> after stop
(none)
== 6.3 lsof (system-wide) lines mentioning <H>: 0
== 6.4 copy logs/ (+ .exit) to evidence
[…10 files: wineboot, cmd (attempt 1), cmd (live stop), nonexistent and x, each with its .log and its .exit]
== 6.5 du -sh <H> before rm
1.5G	<H>
== 6.6 rm -rf <H>
rm exit=0
ls: <H>: No such file or directory
== 6.7 pgrep -fl verify-headless-home-20261102T203816Z after rm
(none)
== 6.8 lsof lines mentioning verify-headless-home-20261102T203816Z: 0
== TMPDIR used by the test group:
[…empty]
(no process references it)
rmdir ok
== unrelated CrossOver processes (start times, local):
77714 Fri Oct 30 15:10:47 2026     C:\windows\system32\winedevice.exe 
79727 Fri Oct 30 15:11:15 2026     /Users/quasar/Applications/CrossOver.app/Contents/MacOS/CrossOver
== stale wineserver dir of the deleted prefix:
drwx------@ 3 quasar  wheel  96 Nov  2 15:46 /private/tmp/.wine-501/server-100000d-4c4ae29
```
The wineserver left behind by [H5a] and [H5b] had already exited on its own, so this `stop` took the no-server path; the `stop` with a server is [H3].

### 3.3 Group `ci-evidence`

Evidence in `$SCR/verify-ci-evidence-20261102`, which keeps a full copy of the log of run 41512345512 (`run-41512345512.log`, 1661 lines). The log lines are shown without ANSI codes, and a decorative Homebrew glyph has been removed.

**[C1] Run and job** (R17, scenario 1; T3)
```
$ gh run view 41512345512 -R dany021115/bodega-engine --json conclusion,jobs,createdAt,updatedAt   (durations computed from that)
run: conclusion=success createdAt=2026-11-02T19:41:54Z updatedAt=2026-11-02T19:42:45Z wall=51s
job build (125507111934): status=completed conclusion=success startedAt=2026-11-02T19:42:01Z completedAt=2026-11-02T19:42:44Z duration=43s
  1. Set up job                       success     1s
  2. guard                            success     4s
  3. install                          success     6s
  4. bundle                           success    12s
  5. probe                            success     3s
  6. tarball                          success     4s
  7. Run actions/upload-artifact@v4   success     3s
  8. publish                          success     5s
  9. Complete job                     success     0s
$ gh api repos/dany021115/bodega-engine/actions/jobs/125507111934 ; gh api repos/dany021115/bodega-engine/actions/runs
labels=["macos-15-intel"] runner_name=GitHub Actions 1000000439 runner_group=GitHub Actions head_sha=8a00dea8a08f5fa71444384113d28ce3b9bef1c9 head_branch=main workflow_name=build-hostlibs run_attempt=1
id=41512345512 path=.github/workflows/build-hostlibs.yml event=workflow_dispatch head_branch=main actor=dany021115 triggering_actor=dany021115
```

**[C2] `Set up job`, `guard` and `install`** (R17)
```
build	Set up job	2026-11-02T19:42:03.2082640Z Image: macos-15
build	Set up job	2026-11-02T19:42:03.2083630Z Version: 20260824.0482.1
build	Set up job	2026-11-02T19:42:03.2102840Z Contents: write
build	guard	2026-11-02T19:42:04.4737950Z ##[group]Run brew list --versions freetype gnutls || { echo 'runner image lacks freetype/gnutls; would build from source'; exit 1; }
build	guard	2026-11-02T19:42:04.4859230Z shell: /bin/bash -e {0}
build	guard	2026-11-02T19:42:04.4861190Z env:
build	guard	2026-11-02T19:42:04.4862270Z   HOMEBREW_NO_AUTO_UPDATE: 1
build	guard	2026-11-02T19:42:04.4866050Z   HOMEBREW_NO_INSTALL_UPGRADE: 1
build	guard	2026-11-02T19:42:04.4867910Z   HOMEBREW_NO_INSTALL_CLEANUP: 1
build	guard	2026-11-02T19:42:04.4869550Z   HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK: 1
build	guard	2026-11-02T19:42:04.4871570Z   ROOTS: libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib
build	guard	2026-11-02T19:42:08.9729960Z freetype 2.14.3
build	guard	2026-11-02T19:42:08.9732430Z gnutls 3.8.13_2
build	install	2026-11-02T19:42:09.0077360Z ##[group]Run brew install freetype gnutls molten-vk
build	install	2026-11-02T19:42:10.9197720Z Warning: freetype 2.14.3 is already installed and up-to-date.
build	install	2026-11-02T19:42:10.9273240Z Warning: gnutls 3.8.13_2 is already installed and up-to-date.
build	install	2026-11-02T19:42:11.3169840Z ==> Would install 1 formula:
build	install	2026-11-02T19:42:14.1168050Z ==> Pouring molten-vk--1.4.2.sonoma.bottle.tar.gz
build	install	2026-11-02T19:42:14.8435160Z /usr/local/Cellar/molten-vk/1.4.2: 84 files, 92.2MB
```
`install` runs from 19:42:08 to 19:42:14 (6 s) without any build-from-source line; the `Cellar` in `/usr/local` is Intel Homebrew's.

**[C3] `bundle`** (R18)
```
build	bundle	2026-11-02T19:42:14.8879650Z ##[group]Run python3 - $ROOTS <<'PY'
build	bundle	2026-11-02T19:42:14.9049300Z shell: /bin/bash -e {0}
[…]
build	bundle	2026-11-02T19:42:14.9053530Z   ROOTS: libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib
build	bundle	2026-11-02T19:42:26.4660220Z x86_64-unix: ['libMoltenVK.dylib', 'libfreetype.6.dylib', 'libgmp.10.dylib', 'libgnutls.30.dylib', 'libhogweed.7.dylib', 'libidn2.0.dylib', 'libintl.8.dylib', 'libnettle.9.dylib', 'libp11-kit.0.dylib', 'libpng16.16.dylib', 'libtasn1.6.dylib', 'libunistring.5.dylib']
```
In the YAML, the `print` (`:80`) comes after `assert not left, left` (`:78-79`), which fails on any reference outside `@loader_path/`, `/usr/lib/` and `/System/`.

**[C4] `probe`** (R19; R18 and R21, mechanism). Queries made while writing this report on `step-probe.txt` (the step's 1467 lines) and `probe-images-unique.txt`:
```
$ sed … step-probe.txt | grep -nE 'clang |env -i|probe=|for r in|brew --prefix'
18:2026-11-02T19:42:26.4963230Z clang -DMOD -dynamiclib -Wl,-rpath,@loader_path/ -o out/engine/lib/wine/x86_64-unix/probe.so probe.c
19:2026-11-02T19:42:26.4965120Z clang -o probe probe.c
20:2026-11-02T19:42:26.4966340Z probe="$PWD/probe"; dir=$(cd out/engine/lib/wine/x86_64-unix && pwd -P); log="$RUNNER_TEMP/probe.log"
21:2026-11-02T19:42:26.4968160Z (cd / && env -i DYLD_PRINT_LIBRARIES=1 "$probe" "$dir/probe.so" $ROOTS) 2>"$log" || { cat "$log"; exit 1; }
23:2026-11-02T19:42:26.4970110Z for r in $ROOTS; do grep -F "$dir/$r" "$log"; done
24:2026-11-02T19:42:26.4971330Z if grep -q "$(brew --prefix)/" "$log"; then exit 1; fi
--- last 3 lines of probe step:
2026-11-02T19:42:29.1597870Z dyld[1607]: <BF093AA5-07EE-3280-982D-20E79E6B7A25> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libfreetype.6.dylib
2026-11-02T19:42:29.1605930Z dyld[1607]: <346AFE88-06F2-3373-86DA-DD755E38609A> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libgnutls.30.dylib
2026-11-02T19:42:29.1610200Z dyld[1607]: <F92483CA-A7D5-3552-9360-C6F6A3470C00> /Users/runner/work/bodega-engine/bodega-engine/out/engine/lib/wine/x86_64-unix/libMoltenVK.dylib
--- /usr/local lines: 0  /opt/homebrew lines: 0
$ wc -l probe-images-unique.txt ; classification by prefix
     605 probe-images-unique.txt
OTHER: /Users/runner/work/bodega-engine/bodega-engine/probe
System=424 usr/lib=167 out/x86_64-unix=13 other=1
```

**[C5] `tarball`, artifact and `publish`** (R20)
```
build	tarball	2026-11-02T19:42:29.2290430Z ##[group]Run set -o pipefail
build	tarball	2026-11-02T19:42:29.2292170Z name="hostlibs-x86_64-$(date -u +%Y%m%dT%H%M%SZ)-$(printf %s "$NOTE" | tr -c 'A-Za-z0-9_-' -)"
[…]
build	tarball	2026-11-02T19:42:29.2298700Z if tar -tzf "$name.tar.gz" | grep -E '/$|^\./'; then exit 1; fi
build	tarball	2026-11-02T19:42:29.2300040Z shasum -a 256 "$name.tar.gz" | tee "$name.tar.gz.sha256"
build	tarball	2026-11-02T19:42:29.2301120Z ls -la "$name.tar.gz"
build	tarball	2026-11-02T19:42:29.2301860Z test "$(stat -f %z "$name.tar.gz")" -lt $((30 * 1024 * 1024))
build	tarball	2026-11-02T19:42:29.2414250Z shell: /bin/bash -e {0}
build	tarball	2026-11-02T19:42:29.2430730Z   NOTE: primer-hostlibs
build	tarball	2026-11-02T19:42:33.5442490Z 3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
build	tarball	2026-11-02T19:42:33.5558310Z -rw-r--r--  1 runner  staff  5121991 Nov  2 19:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
build	Run actions/upload-artifact@v4	2026-11-02T19:42:33.6294860Z   retention-days: 14
build	Run actions/upload-artifact@v4	2026-11-02T19:42:34.1975640Z ##[warning]Retention days cannot be greater than the maximum allowed retention set within the repository. Using 1 instead.
build	Run actions/upload-artifact@v4	2026-11-02T19:42:36.8190010Z Artifact hostlibs has been successfully uploaded! Final size is 5062830 bytes. Artifact ID is 13171974984
build	publish	2026-11-02T19:42:36.8577300Z ##[group]Run f=$(ls hostlibs-*.tar.gz)
[…]
build	publish	2026-11-02T19:42:36.8687790Z   GH_TOKEN: ***
build	publish	2026-11-02T19:42:36.8688290Z   GH_REPO: dany021115/bodega-engine
build	publish	2026-11-02T19:42:41.2248050Z https://github.com/dany021115/bodega-engine/releases/tag/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
```
The step runs with `bash -e`; it ended in `success`, so neither the `grep` for directory entries nor the size `test` (the last command) failed.

**[C6] What ran is the YAML from the commit** (R17–R20)
```
ruby exit=0
guard: CI-echoed script == YAML run block (1 lines)
install: CI-echoed script == YAML run block (1 lines)
bundle: CI-echoed script == YAML run block (42 lines)
probe: CI-echoed script == YAML run block (23 lines)
tarball: CI-echoed script == YAML run block (10 lines)
publish: DIFFERS
$ cat scripts-diff-publish.txt
3c3
< gh release create "$tag" "$f" "$f.sha256" --title "$tag" --notes "FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run ${{ github.run_id }}. Versions in hostlibs.txt inside, checksum in the .sha256 file."
---
> gh release create "$tag" "$f" "$f.sha256" --title "$tag" --notes "FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run 41512345512. Versions in hostlibs.txt inside, checksum in the .sha256 file."
$ (while writing) size of each scripts-diff-*.txt
guard diff bytes=       0
install diff bytes=       0
bundle diff bytes=       0
probe diff bytes=       0
tarball diff bytes=       0
publish diff bytes=     569
```
The only difference is GitHub's expansion of `${{ github.run_id }}`.

**[C7] Workflow configuration and state of `BE`** (R17, R20; T1)
```
$ /usr/bin/ruby -ryaml -e 'YAML.load_file(ARGV[0])' /Users/quasar/Documents/GitHub/Bodega/bodega-engine/.github/workflows/build-hostlibs.yml   (+ dump of the structure)
exit=0
triggers: ["workflow_dispatch"]
inputs: publish_release(type=boolean, default=false), ref_note(type=string, default="manual")
permissions: {"contents"=>"write"}
jobs: ["build"]  runs-on: macos-15-intel  timeout-minutes: 15
env: {"HOMEBREW_NO_AUTO_UPDATE"=>"1", "HOMEBREW_NO_INSTALL_UPGRADE"=>"1", "HOMEBREW_NO_INSTALL_CLEANUP"=>"1", "HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"=>"1", "ROOTS"=>"libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib"}
step 1: name=guard    uses=- timeout-minutes=- if=- env=[]
step 2: name=install  uses=- timeout-minutes=5 if=- env=[]
step 3: name=bundle   uses=- timeout-minutes=- if=- env=[]
step 4: name=probe    uses=- timeout-minutes=- if=- env=[]
step 5: name=tarball  uses=- timeout-minutes=- if=- env=["NOTE"]
step 6: name=-        uses=actions/upload-artifact@v4 timeout-minutes=- if=- env=[]
step 7: name=publish  uses=- timeout-minutes=- if=${{ github.event.inputs.publish_release == 'true' }} env=["GH_TOKEN", "GH_REPO"]
any checkout step: false
build.yml:22:    runs-on: macos-15-intel
build.yml:45:          brew install -q mingw-w64 bison pkg-config ccache gnutls freetype sdl2 libpng jpeg-turbo gstreamer molten-vk || true
$ git -C BE log --oneline -2
8a00dea build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball
e497c41 Merge pull request #22 from gauthierpiarrette/dotlocal-dll-redirection
exit=0
$ git -C BE status --short
exit=0 (no lines above = clean)
$ git -C BE rev-parse HEAD origin/main
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
$ git -C BE show --stat --format=%H%n%an%n%aI%n%B HEAD
8a00dea8a08f5fa71444384113d28ce3b9bef1c9
Daniel Medina
2026-11-02T14:41:49-05:00
build-hostlibs: FreeType, GnuTLS and MoltenVK from Intel Homebrew in a separate tarball

 .github/workflows/build-hostlibs.yml | 137 +++++++++++++++++++++++++++++++++++
 1 file changed, 137 insertions(+)
```
The run's `head_sha` is that same commit [C1]. In the YAML, `ref_note` has no `type` key (§5.10).

**[C8] Releases** (R4, R6, R20; provenance of `RT`)
```
$ gh release view engine-wine-11.0-20261030T202616Z-primer-build -R dany021115/bodega-engine
title:	engine-wine-11.0-20261030T202616Z-primer-build
tag:	engine-wine-11.0-20261030T202616Z-primer-build
draft:	false
prerelease:	false
immutable:	false
author:	github-actions[bot]
created:	2026-10-26T14:22:39Z
published:	2026-10-30T20:28:31Z
url:	https://github.com/dany021115/bodega-engine/releases/tag/engine-wine-11.0-20261030T202616Z-primer-build
asset:	engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
asset:	engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256
--
Wine from the pinned CrossOver source (inputs.json) with the patch series in patches/. Built by run 41110607147. Checksum in the .sha256 file.
$ gh release view hostlibs-x86_64-20261102T194229Z-primer-hostlibs -R dany021115/bodega-engine
title:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs
tag:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs
draft:	false
prerelease:	false
immutable:	false
author:	github-actions[bot]
created:	2026-11-02T19:41:49Z
published:	2026-11-02T19:42:41Z
url:	https://github.com/dany021115/bodega-engine/releases/tag/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
asset:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
asset:	hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256
--
FreeType, GnuTLS and MoltenVK with what they link, from the runner's Intel Homebrew, for engine/lib/wine/x86_64-unix. Built by run 41512345512. Versions in hostlibs.txt inside, checksum in the .sha256 file.
$ (while writing) assets from the .json files saved by `gh release view --json assets`
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz size=334861341 state=uploaded digest=sha256:c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256 size=120 state=uploaded digest=sha256:fe2b347aca8eb66eff6b614a27b2017056399e283d6d78bc21dc588102766e7d
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz size=5121991 state=uploaded digest=sha256:3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256 size=122 state=uploaded digest=sha256:7d5b97a86ef3f1f87ca355b7051e1d501cc7ff3abbfb8dabcbdb5beddb158f87
$ gh release list -R dany021115/bodega-engine
hostlibs-x86_64-20261102T194229Z-primer-hostlibs	Latest	hostlibs-x86_64-20261102T194229Z-primer-hostlibs	2026-11-02T19:42:41Z
engine-wine-11.0-20261030T202616Z-primer-build		engine-wine-11.0-20261030T202616Z-primer-build	2026-10-30T20:28:31Z
```
`created` is the date of the commit the tag points to (8a00dea, 14:41:49-05:00); `published` is that of the `publish` step.

**[C9] Local `shasum -c` and comparison with the release** (R4, R6, R20; T4)
```
=================== /Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
-rw-r--r--@ 1 quasar  staff  334861341 Oct 30 16:32 engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
-rw-r--r--@ 1 quasar  staff        120 Oct 30 16:30 engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256
--- cat *.sha256
c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62  engine-wine-11.0-20261030T202616Z-primer-build.tar.gz
--- (cd engine-wine-11.0-20261030T202616Z-primer-build && /usr/bin/shasum -a 256 -c engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256)
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz: OK
exit=0
--- local size vs release asset size; local sha vs GitHub asset digest
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz          local=334861341  release=334861341  size_match=True digest_match=True
engine-wine-11.0-20261030T202616Z-primer-build.tar.gz.sha256   local=120        release=120        size_match=True digest_match=True
=================== /Users/quasar/Documents/GitHub/Bodega/runtimes/hostlibs-x86_64-20261102T194229Z-primer-hostlibs
-rw-r--r--@ 1 quasar  staff  5121991 Nov  2 14:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
-rw-r--r--@ 1 quasar  staff      122 Nov  2 14:42 hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256
--- cat *.sha256
3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
--- (cd hostlibs-x86_64-20261102T194229Z-primer-hostlibs && /usr/bin/shasum -a 256 -c hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256)
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz: OK
exit=0
--- local size vs release asset size; local sha vs GitHub asset digest
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz        local=5121991    release=5121991    size_match=True digest_match=True
hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz.sha256 local=122        release=122        size_match=True digest_match=True
```
The hostlibs hash is the same one that the CI's `tarball` step printed [C5].

**[C10] Shape of the hostlibs tarball** (R20)
```
$ /usr/bin/tar -tzvf hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz
-rw-r--r--  0 runner staff    2772 Nov  2 14:42 hostlibs.txt
-rwxr-xr-x  0 runner staff  658384 Nov  2 14:42 engine/lib/wine/x86_64-unix/libfreetype.6.dylib
-rwxr-xr-x  0 runner staff  440864 Nov  2 14:42 engine/lib/wine/x86_64-unix/libgmp.10.dylib
-rwxr-xr-x  0 runner staff 2118016 Nov  2 14:42 engine/lib/wine/x86_64-unix/libgnutls.30.dylib
-rwxr-xr-x  0 runner staff  280880 Nov  2 14:42 engine/lib/wine/x86_64-unix/libhogweed.7.dylib
-rwxr-xr-x  0 runner staff  230560 Nov  2 14:42 engine/lib/wine/x86_64-unix/libidn2.0.dylib
-rwxr-xr-x  0 runner staff  209600 Nov  2 14:42 engine/lib/wine/x86_64-unix/libintl.8.dylib
-rwxr-xr-x  0 runner staff 5664496 Nov  2 14:42 engine/lib/wine/x86_64-unix/libMoltenVK.dylib
-rwxr-xr-x  0 runner staff  320784 Nov  2 14:42 engine/lib/wine/x86_64-unix/libnettle.9.dylib
-rwxr-xr-x  0 runner staff 1460656 Nov  2 14:42 engine/lib/wine/x86_64-unix/libp11-kit.0.dylib
-rwxr-xr-x  0 runner staff  192400 Nov  2 14:42 engine/lib/wine/x86_64-unix/libpng16.16.dylib
-rwxr-xr-x  0 runner staff   87616 Nov  2 14:42 engine/lib/wine/x86_64-unix/libtasn1.6.dylib
-rwxr-xr-x  0 runner staff 2061056 Nov  2 14:42 engine/lib/wine/x86_64-unix/libunistring.5.dylib
entries: 13 ; tar -tzf exit=0
R20 scenario grep -E "/$|^\./": no output, grep exit=1
entries outside {hostlibs.txt, engine/lib/wine/x86_64-unix/*.dylib}: none, grep exit=1
non-regular entries in verbose listing: none, grep exit=1
size check: 5121991 < 31457280 ? yes
b'c3708cbaa0509732507b5ec7051c64a506a3a09bb55fae4a1ed64fd7fc6c4c62  engine-wine-11.0-20261030T202616Z-primer-build.tar.gz\n'
b'3c9eb7f519f0e51e6cb9eb41d159b8e0849363d7d3d1d646d9ce60a3e0597fd4  hostlibs-x86_64-20261102T194229Z-primer-hostlibs.tar.gz\n'
$ (while writing) head -3 hostlibs.txt ; grep -nE '^(freetype|gnutls|molten-vk) ' hostlibs.txt ; echo "file lines: $(grep -c x86_64-unix hostlibs.txt)"
hostlibs-x86_64-20261102T194229Z-primer-hostlibs
runner image: macos15 20260824.0482.1
ant 1.10.17
28:freetype 2.14.3
44:gnutls 3.8.13_2
92:molten-vk 1.4.2
file lines: 12
```

**[C11] The 12 published `.dylib` files** (R18; R21, prerequisite). `otool -L`, `otool -l`, `otool -D`, `lipo -archs`, `codesign -dv` and `codesign -v` in a new folder, deleted afterwards:
```
dependency refs NOT under @loader_path/, /usr/lib/, /System/ (expect none): (none) grep exit=1
distinct ref prefixes:
  25 @loader_path/
  16 /System/
  22 /usr/lib/
/usr/local: -L 0  -l 0 ; /opt/homebrew: -L 0  -l 0 ; @rpath: -L 0  -l 0 ; LC_RPATH: -L 0  -l 0
@loader_path refs that do not resolve to a file in the tarball: (none)
libfreetype.6.dylib      id=@loader_path/libfreetype.6.dylib         id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libgmp.10.dylib          id=@loader_path/libgmp.10.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libgnutls.30.dylib       id=@loader_path/libgnutls.30.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libhogweed.7.dylib       id=@loader_path/libhogweed.7.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libidn2.0.dylib          id=@loader_path/libidn2.0.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libintl.8.dylib          id=@loader_path/libintl.8.dylib             id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libMoltenVK.dylib        id=@loader_path/libMoltenVK.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libnettle.9.dylib        id=@loader_path/libnettle.9.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libp11-kit.0.dylib       id=@loader_path/libp11-kit.0.dylib          id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libpng16.16.dylib        id=@loader_path/libpng16.16.dylib           id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libtasn1.6.dylib         id=@loader_path/libtasn1.6.dylib            id_ok=yes arch=x86_64 Signature=adhoc verify=valid
libunistring.5.dylib     id=@loader_path/libunistring.5.dylib        id_ok=yes arch=x86_64 Signature=adhoc verify=valid
```

**[C12] `LC_RPATH` of the engine modules** (R21, mechanism; design §1)
```
$ /usr/bin/tar -xzf <RT> -C <new folder> ./engine/lib/wine/x86_64-unix/{win32u,dwrite,bcrypt,crypt32,secur32}.so ./engine/lib/wine/x86_64-unix/wine ; lipo -archs ; otool -l (LC_RPATH) ; strings | leaf names   (folder deleted afterwards)
tar exit=0
win32u.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libfreetype.6.dylib libMoltenVK.dylib 
dwrite.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libfreetype.6.dylib 
bcrypt.so   arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
crypt32.so  arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
secur32.so  arch=x86_64 LC_RPATH=[@loader_path/ ] hostlib leaf strings: libgnutls.30.dylib 
wine        arch=x86_64 LC_RPATH=[] hostlib leaf strings: 
```

**[C13] Engine run and retention** (provenance of `RT`; §5.3 and §5.4)
```
# captured 2026-11-02T20:37:44Z
$ gh run view 41110607147 -R dany021115/bodega-engine --json conclusion,jobs,createdAt,updatedAt
failed to get run: HTTP 404: Not Found (https://api.github.com/repos/dany021115/bodega-engine/actions/runs/41110607147?exclude_pull_requests=true)
exit=1
$ gh api repos/dany021115/bodega-engine/actions/runs/41110607147
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/actions/workflow-runs#get-a-workflow-run","status":"404"}gh: Not Found (HTTP 404)
$ gh api repos/dany021115/bodega-engine/actions/runs/41110607147/logs (log archive)
{"message":"Not Found","documentation_url":"https://docs.github.com/rest/actions/workflow-runs#download-workflow-run-logs","status":"404"}gh: Not Found (HTTP 404)
$ gh api repos/dany021115/bodega-engine/actions/workflows/build.yml/runs --jq .total_count
0
$ gh api repos/dany021115/bodega-engine/actions/runs --jq .total_count
1
$ gh api repos/dany021115/bodega-engine/commits/e497c41/check-runs
{"total_count":0,"check_runs":[]}
(check summary, same API queries)
GET workflows/402129994 (build-arm64.yml) runs -> total_count: 0
GET commits/e497c41/check-suites -> total_count: 6, all third-party apps (render, codemagic-ci-cd, vercel, railway-app, openship-io, cloudflare-workers-and-pages) status=queued since 2026-10-30T18:52:3xZ; NO app=github-actions suite
(contrast) GET commits/8a00dea/check-suites -> 112494463517 app=github-actions status=completed conclusion=success runs=1
engine release target commit: e497c41d16a1... committed 2026-10-26T15:22:39+01:00 (= release 'created: 2026-10-26T14:22:39Z')
$ gh api repos/dany021115/bodega-engine/actions/permissions/artifact-and-log-retention
{"days":1,"maximum_allowed_days":400}
$ gh api 'repos/dany021115/bodega-engine/actions/artifacts?per_page=50'
total_count: 1
13171974984 hostlibs size=5062830 run=41512345512 expired=false created=2026-11-02T19:42:36Z expires=2026-11-03T19:41:55Z
```

### 3.4 Earlier evidence from T15 and T16, reread while writing this report

The files are the ones left by T15, T16 and its rerun; the counts and excerpts were taken now with read-only `cat`, `grep -c`, `head` and `tail`.

**[P1] T15, runtime without hostlibs** (`$SCR/t15-run/run2`; R9, R14, R16, R21 scenario 2)
```
$ cat test.out ; cat test.rc ; cat times
00:00 +0: loading test/engine_test.dart
00:00 +0: test/engine_test.dart: real runtime (setUpAll)
00:00 +0: test/engine_test.dart: real runtime cycle
create: 0:00:10.369397
00:13 +1: test/engine_test.dart: real runtime (tearDownAll)
00:13 +1: All tests passed!
0
start 2026-11-02T19:23:53Z
end 2026-11-02T19:24:07Z
$ (for each log in logs/) grep -c 'cannot find the FreeType', grep -c 'ailed to load libgnutls', grep -c 'Failed to load libMoltenVK' and the .exit
2026-11-02T19-23-54.003978Z-wineboot.log FreeType=15 GnuTLS=6 FailedMVK=1 exit=0
2026-11-02T19-24-04.374577Z-cmd.log FreeType=6 GnuTLS=0 FailedMVK=0 exit=0
2026-11-02T19-24-05.245607Z-cmd.log FreeType=2 GnuTLS=0 FailedMVK=0 exit=7
2026-11-02T19-24-05.608747Z-rundll32.log FreeType=4 GnuTLS=0 FailedMVK=1 exit=0
2026-11-02T19-24-06.495018Z-rundll32.log FreeType=2 GnuTLS=1 FailedMVK=0 exit=0
== 2026-11-02T19-23-54.003978Z-wineboot.log (header)
# runtime t15-rt
# cwd /private/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega-realJzHoRj/bottles/t
# argv wineboot
[…]
# exit=0
== 2026-11-02T19-24-05.245607Z-cmd.log (.exit=7)
# runtime t15-rt
# cwd /private/var/folders/hd/cy1qwxbj14dbnp0v1k1nsx3r0000gn/T/bodega-realJzHoRj/bottles/t/prefix/drive_c
# argv cmd /c exit 7
Wine cannot find the FreeType font library.  To enable Wine to
[…]
# exit=7
== 2026-11-02T19-24-06.495018Z-rundll32.log (.exit=0)
# runtime t15-rt
[…]
# argv rundll32 bcrypt.dll,BodegaProbe
[…]
0144:err:winediag:gnutls_process_attach failed to load libgnutls, no support for encryption
0144:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
== 2026-11-02T19-24-05.608747Z-rundll32.log (dwrite), MoltenVK line
00fc:err:vulkan:vulkan_init_once Failed to load libMoltenVK.dylib: dlopen(libMoltenVK.dylib, 0x0002): tried: 'libMoltenVK.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/RosettalibMoltenVK.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OSlibMoltenVK.dylib' (no such file), '$SCR/t15-rt/engine/lib/wine/x86_64-unix/libMoltenVK.dylib' (no such file), '/usr/lib/libMoltenVK.dylib' (no such file, not in dyld cache), 'libMoltenVK.dylib' (no such file)
```
dyld's search goes through `…/x86_64-unix/`, the `LC_RPATH @loader_path/` folder, and through the Rosetta cryptex: it is the same mechanism that, with hostlibs, leaves the count at 0.

**[P2] T16, runtime with hostlibs** (`$SCR/t16-evidence-20261102T194630Z/logs`; R13, R15, R21 scenarios 1 and 3)
```
$ (for each log) .exit and grep -cE 'cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK'
2026-11-02T19-47-16.113573Z-wineboot.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-00.690739Z-cmd.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-18.908812Z-rundll32.log exit=0 markers(4+mvk)=0
2026-11-02T19-48-24.821389Z-rundll32.log exit=0 markers(4+mvk)=0
2026-11-02T19-49-03.057629Z-cscript.log exit=0 markers(4+mvk)=0
$ cat logs/*.log | grep -cE 'mvk-info|Failed to load libMoltenVK'     (T16 step 6, literal)
0
rc=1
== 2026-11-02T19-49-03.057629Z-cscript.log (.exit=0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv cscript //nologo C:\https.js
msync: bootstrapped mach port on wine-4bdb0b2-msync.
msync: up and running.
009c:err:ntoskrnl:ZwLoadDriver failed to create driver L"\\Registry\\Machine\\System\\CurrentControlSet\\Services\\winebth": c00000e5
011c:err:kerberos:kerberos_LsaApInitializePackage no Kerberos support, expect problems
status=200
# exit=0
== 2026-11-02T19-48-18.908812Z-rundll32.log (.exit=0)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv rundll32 dwrite.dll,BodegaProbe
[…msync and winebth]
00d8:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"dwrite.dll"
# exit=0
== 2026-11-02T19-48-24.821389Z-rundll32.log (.exit=0)
[…same header]
# argv rundll32 bcrypt.dll,BodegaProbe
0124:err:rundll32:wWinMain Unable to find the entry point L"BodegaProbe" in L"bcrypt.dll"
# exit=0
```

**[P3] T16, `run t cmd /c set`** (R12, scenario 3; R21)
```
$ grep -cE 'DYLD_|WINEARCH|CX_|LANG=' $SCR/t16-evidence-20261102T194630Z/logs/2026-11-02T19-48-00.690739Z-cmd.log
0
rc=1
$ grep -cE 'DYLD_|WINEARCH|CX_|LANG=' $SCR/t16v-capture-20261102T200201Z/2026-11-02T20-02-57.191529Z-cmd.log
0
rc=1
$ head -3 <T16 log> ; names of the variables in the rest of the log (no values)
# runtime engine-wine-11.0-20261030T202616Z-primer-build
# cwd $SCR/t16-home-20261102T194630Z/bottles/t/prefix/drive_c
# argv cmd /c set
_ __CF_USER_TEXT_ENCODING ALLUSERSPROFILE APPDATA CLIENTNAME CommonProgramFiles CommonProgramFiles(x86) CommonProgramW6432 COMPUTERNAME ComSpec DOTNET_EnableWriteXorExecute HOMEDRIVE HOMEPATH LOCALAPPDATA LOGNAME LOGONSERVER MVK_CONFIG_LOG_LEVEL NUMBER_OF_PROCESSORS OS PATH PATHEXT PROCESSOR_ARCHITECTURE PROCESSOR_IDENTIFIER PROCESSOR_LEVEL PROCESSOR_REVISION ProgramData ProgramFiles ProgramFiles(x86) ProgramW6432 PROMPT PUBLIC ROSETTA_ADVERTISE_AVX SESSIONNAME SHLVL SystemDrive SystemRoot TEMP TMP USER USERDOMAIN USERNAME USERPROFILE windir WINE_HOST_HOME WINE_HOST_PATH WINE_HOST_PWD WINE_HOST_TMPDIR WINECONFIGDIR WINEDATADIR WINEDEBUG WINEDLLDIR0 WINEDLLOVERRIDES WINEHOMEDIR WINELOADER WINEMSYNC WINEPREFIX WINEUSERLOCALE WINEUSERNAME winsysdir
$ grep -nE '^(WINEDEBUG|WINE_HOST_PATH|WINEPREFIX|WINEMSYNC|WINEDLLOVERRIDES|MVK_CONFIG_LOG_LEVEL|ROSETTA_ADVERTISE_AVX|DOTNET_EnableWriteXorExecute|WINELOADER|SHLVL|_)=' <T16 log>
7:_=$SCR/t16-home-20261102T194630Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/bin/wine
17:DOTNET_EnableWriteXorExecute=0
23:MVK_CONFIG_LOG_LEVEL=2
38:ROSETTA_ADVERTISE_AVX=1
40:SHLVL=1
51:WINE_HOST_PATH=/usr/bin:/bin:/usr/sbin:/sbin
56:WINEDEBUG=fixme-all
58:WINEDLLOVERRIDES=winemenubuilder.exe=d
60:WINELOADER=\??\Z:\private\tmp\claude-501\-Users-quasar\cabea996-65df-4091-b3df-9592ba319dd4\scratchpad\t16-home-20261102T194630Z\runtimes\engine-wine-11.0-20261030T202616Z-primer-build\engine\lib\wine\x86_64-unix\wine
61:WINEMSYNC=1
62:WINEPREFIX=$SCR/t16-home-20261102T194630Z/bottles/t/prefix
```
`WINELOADER` (as an NT path), the Windows variables and `WINE_HOST_*` (from `PATH`, `HOME`, `TMPDIR` and the cwd) are set by Wine; `_` and `SHLVL`, by `/bin/sh`. Bodega does not pass them.

**[P4] T16, `otool -L` of the installed `.dylib` files** (R18, scenario)
```
$ grep -P '^\t' $SCR/t16-evidence-20261102T194630Z/otool-L.txt | grep -vE '^\s+(@loader_path/|/usr/lib/|/System/)'
rc=1
$ (headers of otool-L.txt)
libfreetype.6.dylib: libgmp.10.dylib: libgnutls.30.dylib: libhogweed.7.dylib: libidn2.0.dylib: libintl.8.dylib: libMoltenVK.dylib: libnettle.9.dylib: libp11-kit.0.dylib: libpng16.16.dylib: libtasn1.6.dylib: libunistring.5.dylib:
$ head -6 otool-L.txt
$SCR/t16-home-20261102T194630Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/engine/lib/wine/x86_64-unix/libfreetype.6.dylib:
	@loader_path/libfreetype.6.dylib (compatibility version 27.0.0, current version 27.6.0)
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.12)
	/usr/lib/libbz2.1.0.dylib (compatibility version 1.0.0, current version 1.0.8)
	@loader_path/libpng16.16.dylib (compatibility version 72.0.0, current version 72.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.120.2)
```

**[P5] T16 rerun by its verifier** (`$SCR/t16v-capture-20261102T200201Z`; R3 positive, R5, R21). It only saved stdout and stderr, without the CLI's exit codes:
```
$ (per file) size and contents of 1-install, 2-create, 3-run and 8-stop (.out and .err)
### 1-install.out (     169 bytes)
$SCR/t16v-home-20261102T200201Z/runtimes/engine-wine-11.0-20261030T202616Z-primer-build
### 1-install.err (       0 bytes)
### 2-create.out (     174 bytes)
log: $SCR/t16v-home-20261102T200201Z/bottles/t/logs/2026-11-02T20-02-23.145206Z-wineboot.log
### 2-create.err (       0 bytes)
### 3-run.out (     169 bytes)
log: $SCR/t16v-home-20261102T200201Z/bottles/t/logs/2026-11-02T20-02-57.191529Z-cmd.log
### 3-run.err (       0 bytes)
### 8-stop.out (       0 bytes)
### 8-stop.err (       0 bytes)
### wineboot exit: 0  cmd exit: 0
$ grep -cE 'cannot find the FreeType|ailed to load libgnutls|version mismatch|wine: failed to open|mvk-info|Failed to load libMoltenVK' *.log
…/2026-11-02T20-02-57.191529Z-cmd.log:0
…/2026-11-02T20-02-23.145206Z-wineboot.log:0
```

### 3.5 Checks made while writing this report

**[V1] Code, binary, environment, machine and repo** (R8, R12, R21; T17)
```
$ date -u '+%Y-%m-%dT%H:%M:%SZ'
2026-11-02T21:48:54Z
$ (cd P &&) shasum -a 256 pubspec.yaml pubspec.lock lib/engine.dart bin/bodega.dart test/engine_test.dart
ac0732f132240516645726aac6e2f9d5b30d8ab1b5989462a3016554d4aecb77  pubspec.yaml
efbc8199e3db1e283958154527d25cd5b7f43b16de2033834fa9544783abb8e3  pubspec.lock
e6da3d4512365f2832e8cea331bf5d8c1eaeb6eed4004040957ae555d9c39a60  lib/engine.dart
8f21a81ddcd19608cfe9518d668ad32439bd81a381179f970a525ba0eb1ae20c  bin/bodega.dart
511fa6cf9b3a0f3b32623b96345f5cacbe4da9af27a25fec85d380485bf9ac26  test/engine_test.dart
$ shasum -a 256 B/build/bodega
7c10f6ab9737594ba73b7466e43b1d9c24ad40eebe5fe9cb318004a863c8400f  /Users/quasar/Documents/GitHub/Bodega/bodega/build/bodega
$ (cd P &&) grep -niE 'uuid|bottle\.json|\.json' lib/engine.dart bin/bodega.dart
[exit=1]
$ (presence in this session's shell, no values)
LANG=<set>
LC_ALL=<unset>
WINEPREFIX=<set>
WINEARCH=<unset>
DYLD_LIBRARY_PATH=<unset>
BODEGA_HOME=<unset>
BODEGA_WINEDEBUG=<unset>
$ sysctl -n machdep.cpu.brand_string; uname -m; sw_vers -productVersion
Apple M2 Pro
arm64
27.0.1
$ git -C B status --short --branch
## No commits yet on master
?? .gitignore
?? .sdd/
?? packages/
$ git -C B log --oneline -3
fatal: your current branch 'master' does not have any commits yet
$ git -C B remote -v
(no output)
```

**[V2] CX code cited in §5.1** (`CX` = `$SCR/research/src/cx-26.3/sources/wine`, alias from `exploration.md`)
```
$ sed -n '751,755p' server/process.c
/* forced shutdown, used for wineserver -k */
void shutdown_master_socket(void)
{
    kill_all_processes();
    shutdown_stage = 2;
$ sed -n '1107,1117p' server/process.c
/* kill all processes */
static void kill_all_processes(void)
{
    struct list *ptr;

    while ((ptr = list_head( &process_list )))
    {
        struct process *process = LIST_ENTRY( ptr, struct process, entry );
        terminate_process( process, NULL, 1 );
    }
}
$ sed -n '266,267p;1031,1032p' dlls/ntdll/unix/server.c
    /* the server closed the connection; time to die... */
    abort_thread(0);
    /* the server closed the connection; time to die... */
    abort_thread(0);
$ sed -n '1499,1513p' dlls/ntdll/unix/thread.c
void abort_thread( int status )
{
    pthread_sigmask( SIG_BLOCK, &server_block_set, NULL );
    if (InterlockedDecrement( &nb_threads ) <= 0) abort_process( status );
    pthread_exit_wrapper( status );
}
[…]
void abort_process( int status )
{
    _exit( get_unix_exit_code( status ));
}
```

## 4. Pending on the user

No requirement is left **not met**. What is missing depends on your U steps, on the M2 Pro and with windows, and on T17.

**What each step closes or confirms**

| Req | Status | Closed by | Confirmed by |
|---|---|---|---|
| R11 | partial | U7 and U6.3 | — |
| R13 | partial | U3 and U5 | — |
| R14 | partial | U6.1 and U6.2 | U3, U5 |
| R17 | partial | no U step (scenario 2) | — |
| R21 | partial | U3 | U2 |
| R1, R5, R6, R7 | met | — | U1 |
| R9, R10, R16 | met | — | U2 |
| R12, R15 | met | — | U3 (and U5 for R15) |
| R2, R3 | met | — | U1–U3 (the CLI with your PATH and without `BODEGA_HOME`) |
| R4, R8, R18, R19, R20 | met | — | — |

**Steps** (what is expected is the text from `tasks.md`; the notes are from this verify)
- **U1** · `bodega install <engine…tar.gz> <hostlibs…tar.gz>`. Expected: within 2 min it prints `…/Application Support/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build`, and `ls` of `runtimes/current/engine/lib/wine/x86_64-unix/*.dylib` shows `libfreetype.6`, `libgnutls.30`, `libMoltenVK` and their closure. It exercises the default root for the first time (R1) and repeats R5 and R7 in it. Afterwards, do not delete `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/` (R6). Headless reference: 4.28 s [H1].
- **U2** · `time bodega create prueba`. Expected: exit 0, no `pista:` line (R16, R21) and about 300 MB from `du -sh`. Write down the time (R9). Reference: 12.52 s [H3a], 19.45 s [H2] and 10.37 s in T15 [P1]. The `err:ole`, `err:setupapi` and `winebth … c00000e5` lines in the wineboot log showed up in every `create` of T16 and of this verify, and did not keep the bottle from ending up ready [H3a].
- **U3** · `bodega run prueba notepad`, type "Caña, acción, pingüino" and, in another Terminal, `lsof -p $(pgrep -n -f notepad) | grep -E 'libfreetype|libgnutls|libMoltenVK'`. Expected: the glyphs look right and every `lsof` line is under `…/Bodega/runtimes/<id>/engine/lib/wine/x86_64-unix/` (closes R21); the header says `# cwd …/prefix/drive_c` (R13, scenario 2); and on closing, `echo $?` gives 0 and the log has `# exit=0` and the 3-line header, with no variables from your environment (R15, R12, R14).
- **U4** · `bodega run prueba winecfg`. It does not close any specific requirement: it is a general check of the prefix (Windows 10).
- **U5** · `bodega run prueba "$HOME/Juegos/Cave Story ñ/Doukutsu.exe"`. Expected: `# cwd` ends in `Cave Story ñ` and `bodega run` ends with the game's exit code. It is R13's Unix-path branch, which no check has run; together with U3 it closes R13. The log will be named `…-Doukutsu.log` (R15).
- **U6** · Detachment. U6.1 (Ctrl-C) and U6.2 (closing the Terminal with the program open) close R14. U6.3 (`bodega wait prueba` and closing the program; it returns about 3 s later) is the part of R11 that here only ran without a server.
- **U7** · `bodega run prueba notepad` in one Terminal and `bodega stop prueba` in another. Expected: `stop` exits with 0, notepad closes within about 11 s at most and the first `run` ends; together with U6.3, it closes R11. Keep two things in mind:
  - That first `run` will exit with **0** and its log will say `# exit=0` (§5.1). U7 does not prescribe that code, so it is not a failure of the step.
  - `pgrep -fl wine` is not enough to look for survivors. In [H3], `pgrep -fl <H>` only found 2 of the bottle's 10 processes: the rest are titled `C:\windows\system32\…`, without the bottle's path, and most of them do not contain `wine` either (`services.exe`, `plugplay.exe`, `svchost.exe`, `cmd.exe`; presumably `notepad.exe` too). Also, `pgrep -fl wine` lists processes of your CrossOver.app (§5.6). What did find all 10 was `lsof` searching for the path of the bottle or of the runtime, for example `lsof -n -P -w | grep -F "Application Support/Bodega/" | awk '{print $1, $2}' | sort -u`, which has to come out empty after the `stop`.
- **U8** · Optional: a DX9 or DX11 game of yours. It closes no requirement; it is information for the DXMT change.
- **T17** · Commit in `B`, with the commands from `tasks.md:104-110`. No requirement depends on it to be met, but right now nothing in this change is under version control: `## No commits yet on master` with `.gitignore`, `.sdd/` and `packages/` untracked [V1]. Since the `git add` includes `.sdd`, it is best done with this `verify.md` already reviewed so that it goes into the commit. `build/` is in `.gitignore`, so `build/bodega` is not versioned. `archive` uses `git mv`, which requires versioned files: T17 goes before `archive`. Agent check: `git -C B log --oneline -1` shows the commit and `git -C B status --short` comes out empty.

## 5. Observations

1. **`stop` does not leave 128 + the signal; the stopped `run` exits with 0.** It happened 2 times out of 2: with the `stop` at +12.7 s [H3] and with the one from the first attempt's cleanup, at +90 s, when the log already had 86 ping replies and no `Ping statistics` line [H3]. In the process tree, the direct child of the `sh` is `start.exe /exec cmd /c` (54729), and `cmd.exe` and `ping` have PPID 1 [H3]. In the CX code [V2], `wineserver -k` calls `shutdown_master_socket` → `kill_all_processes` → `terminate_process(process, NULL, 1)`; each client, on seeing its connection to the server closed, does `abort_thread(0)` → `abort_process(0)` → `_exit(get_unix_exit_code(0))`. That is, it exits with `_exit` and 0, it does not die from a signal, and `$?` is 0. In [H3] everything ended at +0.13 s; the case where `-k` gets as far as the SIGKILL (about 10.5 s, according to decision 10 in `proposal.md`) has not been observed.
   - Effect: going by the exit code, a `run` ended with `stop` cannot be told apart from a program that exits cleanly with 0. Also, the program's output can be left half-written: the first attempt's log ends in `R# exit=0`, with the last line cut off.
   - R11 (it closes within about 11 s and ends the `run`) and R14 (the CLI exits with the N from the `.exit`) are met as written. What is false for this runtime is the example in `design.md:89` ("If the process dies from a signal, `$?` is 128 + the signal, for example after `stop`").
   - It needs a decision before `archive`: correct that line of the design or require something else in the spec. Verify has not changed code, specs, design or `tasks.md`.
2. **Nonexistent bare name, no hint.** `bodega run t nonexistent.exe` exits with 1 after 4.95 s and the log only says `Application could not be started, or no application associated with the specified file.` and `ShellExecuteEx failed: Environment variable not found.`, a misleading text. No `pista:` comes out because R16's markers only catch `wine: failed to open`, which is what a `C:\…` path gives (exit 53 and a hint) [H5]. It does not break R16, which sets the list of markers.
3. **The engine run no longer exists on GitHub.** `gh run view 41110607147` and its `/jobs`, `/attempts/1` and `/logs` give HTTP 404; the Actions history only has run 41512345512, `build.yml` and `build-arm64.yml` have 0 runs, and commit e497c41, the target of the engine release, has no check runs [C13]. The conclusion, steps and duration of that run are left without evidence. There is only indirect proof: the engine release was published by `github-actions[bot]` on 2026-10-30T20:28:31Z, its text says `Built by run 41110607147` and its asset matches `RT` in size and digest [C8, C9]. The cause has not been found (manual deletion or retention). `exploration.md:39` is the only record that it finished successfully. It does not affect any requirement.
4. **1-day retention.** The repo has `{"days":1,"maximum_allowed_days":400}`; the workflow's `retention-days: 14` was cut down to 1 with a warning, and artifact 13171974984 expires on 2026-11-03T19:41:55Z [C5, C13]. The log of run 41512345512 may disappear just like the engine's. There is a full copy in `$SCR/verify-ci-evidence-20261102/run-41512345512.log`, but the scratchpad is temporary: the excerpts in §3.3 are the copy that lasts. Releases do not expire. The specs do not set a retention, so it is not a breach.
5. **`build/bodega` changed hash without its code changing.** The recompilation that T13 asked for in this verify replaced it: the 14:15 binary, which T15, T16 and its rerun ran with, was `e39ad46d…`; the current one, from 15:30 and used by the headless group, is `7c10f6ab…` [S5]. The sources are the same before, after and now [POST, V1], and two back-to-back compilations of the same code differ in 101 bytes with the same size and the same `LC_UUID` [X8]: it is non-determinism in `dart compile exe`, not a code change.
6. **Unrelated processes.** During the checks, processes of your CrossOver.app were running: its GUI (79727, since October 30), a `winedevice.exe` (77714, since October 30, which the headless check attributes to CrossOver) and a `wineserver` (47400) that started at 15:32:21 local time, during a pause in the static group [POST, H6]. Bodega's code does not mention CrossOver (`grep` → exit 1) and no invocation of that group got as far as resolving a runtime. Nobody touched them. In U7 and in any cleanup, do not count them as Bodega's and do not kill them blindly.
7. **Leftover outside the scratchpad.** `/private/tmp/.wine-501/server-100000d-4c4ae29` remains, the Wine socket folder of the already deleted prefix; no process uses it. It is Wine's normal behavior, and it was not deleted because it is outside the scratchpad.
8. **Not exercised (residual risks).**
   - R3: the path without Rosetta (code review only).
   - R5: deleting a `.tmp-<id>` left by an earlier attempt.
   - R7: `run` and `wait` without a runtime from the CLI.
   - R9: wineboot with a non-zero code and the 10-min cap on `-w`.
   - R10: `run` on a bottle that is not ready.
   - R13: an existing Unix path (U5 will do it).
   - R14: `bodega run t cmd /c exit 7; echo $?` literally from the CLI.
   - R15: the 40-character cap on the label.
   - R16: the hints after a `create` that fails.
   - R17: scenario 2 (guard with an image without freetype or gnutls).
   - R18 and R19: the output of the T2 dry run is not in this evidence.
   - R20: the sanitizing of `ref_note`.
9. **Issues in the verify itself, not in the product.** The first attempt at the live `stop` expected a process titled `ping.exe`, but this runtime titles it `ping -n 120 127.0.0.1` (comm `ping`); it ran out its 90 s and its cleanup ran `bodega stop t`, which served as the second observation for §5.1 [H3]. In T13, the `BODEGA_HOME` roots pointed to new folders in the scratchpad and not to `$(mktemp -d)` in `$TMPDIR`, and the usage check also got one, to prove that nothing is created [§3.1]. The check of `install` without `.sha256` used paths whose tarball does not exist either [X5].
10. **Corrections made while writing this report** (no effect on any status):
    - T15's logs carry `# runtime t15-rt`, not the release id, because T15 pointed `current` at the extraction folder `t15-rt` [P1]. R15 does not change: the header is `# runtime <id>` of the resolved runtime.
    - In the CI's `probe` step, `grep -ciE 'error|fail|not loaded|image not found'` gives 1, not 0: it is the `probe.c` source line that the CI prints (`if (!probe) { fprintf(stderr, "%s\n", dlerror()); return 1; }`), not an output line.
    - The Ruby dump shows `ref_note(type=string, …)`, but in the YAML `ref_note` has no `type` key (`build-hostlibs.yml:12-15`); in `workflow_dispatch`, an input without a type is text, which is what R17 asks for.
11. **Informational.** The `Complete job` step warns that `actions/upload-artifact@v4` uses Node.js 20, which is deprecated, and is forced to Node.js 24; nothing failed. T16's `cscript` log has `err:kerberos:kerberos_LsaApInitializePackage no Kerberos support, expect problems`, and still gives `status=200` [P2]; no spec covers Kerberos.

## 6. Added after the adversarial review

**R17, scenario 2 (local dry run of the guard, with a fake `brew`).** The `guard` step was extracted from the YAML and run with `bash -e`. It is a dry run of the step's logic, not a run on a real runner image; that is why R17 stays partial.

```
--- image WITHOUT freetype/gnutls
runner image lacks freetype/gnutls; would build from source
exit=1
--- image WITH them
freetype 2.14.3
gnutls 3.8.13_2
exit=0
```

**User decisions (2026-11-03):**
- `design.md` corrected: a `run` ended by `stop` exits with 0, and that is accepted.
- U7's check in `tasks.md`: `lsof` instead of `pgrep`.
- R17 is accepted as partial, with the local dry run of the guard.
- T17 done: commit `de9fce1`.

## 7. User acceptance (2026-11-03, MacBook Pro M2 Pro, macOS 27.0.1)

| Test | Result | Evidence |
|---|---|---|
| U1 install | OK | Prints `…/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build` |
| U2 create | OK | 19.454 s, no `pista:` lines |
| U3 notepad | OK | The user confirms that the menus and "Caña, acción, pingüino" are legible. `lsof` shows `…/Bodega/runtimes/…/engine/lib/wine/x86_64-unix/libfreetype.6.dylib` and its Rosetta `.aot`. Log: `# cwd …/prefix/drive_c`, `# exit=0` |
| U4 winecfg | OK | The user confirms Windows 10. Log: `# exit=0` |
| U5 Cave Story | **Not done** | Replaced by the check below: it tests the path, not a game with graphics and sound |
| U6 detachment | OK | The user confirms that notepad survives Ctrl-C and closing the Terminal. `wait` waited 15.735 s until notepad was closed; that includes the time the user took, so it does not measure the ~3 s |
| U7 stop | OK | The user confirms that notepad closed when `stop` ran (0.217 s). `lsof` shows no Bodega processes; `# exit=0`, as decided in §6 |
| U8 own game | **Not done** | Optional |

**U5 substitute for R13 (Unix-path branch), without windows:** a copy of `cmd.exe` in a folder with a space and an ñ, with a temporary `BODEGA_HOME` that has since been deleted.

```
run exit=7
# cwd $SP/r13 Juegos ñ/Cave Story ñ
# argv $SP/r13 Juegos ñ/Cave Story ñ/Mi Juego ñ.exe /c exit 7
# exit=7
stop=0
```

**Limit of this verification:** no real game has been run with Bodega yet. What was tested is the engine with notepad, winecfg and cmd. The log label replaces each non-ASCII byte with `_` (`Mi_Juego__`), with no functional effect.
