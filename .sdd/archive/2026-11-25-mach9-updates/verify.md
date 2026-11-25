# Verify · mach9-updates

Date: 2026-11-25.
- Branch `feat/rosetta-game-mode`, cut from `origin/main` (v1.8.0), uncommitted, with the Rosetta Game Mode change beside it.
- Version 1.9.0+17.

## Requirements

| Requirement | Verdict | Evidence |
|---|---|---|
| MU1 · no fixed versions | Met | The grep below finds only `minimumVersion: '0.4.0'`, the floor MU1 keeps on purpose. `runtimes_test`, "MU1 no fixed version", checks that `lib/mach9.dart` holds neither hash nor a release or Wine Mono URL. |
| MU2 · the latest release | Met | `mach9_test`, "MU2 and MU3" (4 tests): version, digest, size, URL, the appcast's macOS, the cache, `maxAge`, and `NoMach9Release` for a bad digest or an old version. Real: tasks, notes T11, `latest 0.4.0`, digest `3b5dd83e…`, macOS 26.4. |
| MU3 · Wine Mono from the copy | Met | The same group: `monoVersionOf` and `monoRelease`. `mach9_test`, "MU3 an MSI unlike its release stops before the switch". Real: `11.3.0` and `df2dfc16…`. |
| MU4 · install, probe, rollback | Met | `mach9_test`: "MU4 a failed probe puts the previous version back", "MU4 with nothing before, a failed probe leaves it unchecked", "a downloaded source must match its digest", "from the Mach9.app it finds" (the latest version, nothing downloaded), "an open Mach9 bottle stops it before the copy" (MR8), "a newer version switches the link and removes the old" (D4.7). Real: an install from local files with the probe, `checked: true`, no bottle left. |
| MU5 · runtime info and CLI | Met | `runtimes_test`, "MU5 checked is what runtime.json says": a 1.8 `runtime.json` without `checkedAt` reads checked, and `latest` comes from the cache. `mach9_test`, "runtime check mach9 says what is out". Real: `bodega runtime check mach9`. |
| MA1 · looking | Met | `backends_bloc_test`, "MA1 and MA2 a newer Mach9 is told once per version" and "MA1 offline says nothing". The 24 h limit lives in the engine (`mach9Latest(maxAge:)`), tested in MU2's "a young cache answers without asking", not with a fake clock in the bloc. |
| MA2 · notice and card | Partly | Bloc: one notice per version (`noticeId` 1 after two looks). Card: `pages_test` shows "Update to 0.4.0" for an older install. Not covered: the shell's toast for `mach9Notice` has no widget test of its own. |
| MA3 · the update | Partly | The install runs its steps, `probing` among them: real run and `mach9_test`. `Mach9CheckFailed` maps to `AppError.mach9CheckFailed` and has its words in both languages. Not covered: no widget test shows that error on the card. |
| MA4 · text | Met | `l10n_parity_test` +24 passes. `engineStepProbing`, `engineNewVersion`, `errNoMach9Release` and `errMach9CheckFailed` are in both ARBs with descriptions. The wording switches are exhaustive, and the analyzer is clean. |
| MC1 · automated | Met | Output below. |
| MC2 · real | Met | Tasks, notes T11 (2026-11-24), all three steps. |
| MC3 · user | Open | The card saying "Checked by Bodega" in the real app, and the notice and update when Mach9 ships its next version. |

## Output (2026-11-25)

```
$ grep pins in packages/engine/lib/
lib/mach9.dart:24:  minimumVersion: '0.4.0',
$ dart analyze
No issues found!
$ dart test
01:24 +516 ~5: All tests passed!
$ dart test test/mach9_test.dart --plain-name 'MU2 and MU3'
+0: … the version, the digest, and the macOS its appcast asks
+1: … a release Bodega cannot use is NoMach9Release
+2: … the Wine Mono a Mach9 names, and its release's digest
+3: … runtime check mach9 says what is out
+4: All tests passed!
$ dart test test/mach9_test.dart --plain-name 'MU4'
+0: MR4–MR9 installMach9 MU4 a failed probe puts the previous version back
+1: MR4–MR9 installMach9 MU4 with nothing before, a failed probe leaves it unchecked
+2: All tests passed!
$ dart test test/runtimes_test.dart --plain-name 'MU'
+0: MR1 listRuntimes MU5 checked is what runtime.json says
+1: MU1 no fixed version only who Mach9 is, and what Bodega needs of it
+2: All tests passed!

$ flutter analyze
No issues found! (ran in 4.1s)
$ flutter test
00:36 +1029: All tests passed!
$ tool/check_layers.sh
Layers OK
$ flutter test test/app/backends_bloc_test.dart --plain-name 'MA1'
00:00 +2: All tests passed!
$ flutter test test/data/backend_repository_test.dart --plain-name 'installRuntime'
00:00 +5: All tests passed!
$ flutter test test/l10n_parity_test.dart
00:00 +24: All tests passed!
```

## Known

- **Two widget tests missing:** MA2's shell toast and MA3's error on the card. The code is there and the analyzer checks the exhaustive cases.
- **"Once per version" is per run of the app:** reopening Bodega tells of the same version once more.
- **The probe's bottle:** `mach9-check` can show in the bottle list during the minute the probe runs.
- **Older timing tests:** PE4 retina and MG8 Steam failed once under load and passed alone. They share the 1 s `_serverRunning` wait; this change did not touch them.
