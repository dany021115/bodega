# Verify · fex-options

Date: 2026-11-24.
- Branch `feat/fex-options`, cut from `origin/main` (f9b2c54, v1.7.0), working tree uncommitted.
- Version 1.8.0+16.

## Requirements

| Requirement | Verdict | Evidence |
|---|---|---|
| FE1 · two `NativeOption` values, `env` field, exact values, after `vulkanWined3d`, doc comments with sources | Met | `runtimes.dart:387` `strictCodeTracking('env', 'FEX_SMCCHECKS=full')` and `:392` `fullX87Precision('env', 'FEX_X87REDUCEDPRECISION=0')`, after `vulkanWined3d`. Their comments cite FEX's `Config.json.in` (`SMCChecks`) and Mach9's `builtin.rs` (`fex_reduced_x87_precision`). |
| FE1 · golden line with LAA and both | Met | `compatdb_test`, "FE1 the FEX options are env fields, last and exact": `exe=game.exe;large_address_aware=true;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full` |
| FE1 · Steam app with the HUD | Met | Same test: `exe=steam:220;metal_hud=true;env=FEX_SMCCHECKS=full` |
| FE1 · nothing sent in a Rosetta bottle | Met, by code path | `compatdbRules` returns `null` before it reads any option when the bottle is not `mach9` (`runtimes.dart:196`); test "a Rosetta bottle sends no rules at all". That test's fixture uses the old options. The spec's "(covers every value)" means the path, not a fixture with the new names. |
| FE1 · `setNativeOption` stores them sorted, and off removes them | Met | On, real: FC2.2's `settings.json` held `"native": {"fc2/probe-64.exe": ["fullX87Precision", "strictCodeTracking"]}`, written by `setNativeOption`. Off: "setNativeOption keeps them sorted, and off removes the app" turns every `NativeOption.values` off and finds no `native`. |
| FE2 · CLI names | Met | `cli.dart:133-134`. `mach9_test`, "PE11 option retina and native": the listing ends `strict-code-tracking: off`, `full-x87-precision: off`; `native m9 g/game.exe strict-code-tracking on` gives `(0, 'strict-code-tracking: on\n')`, and `nativeOptions` then holds it. |
| FE2 · `bodega rules` left alone | Met | `cli.dart` unchanged there, as the spec says. |
| FA1 · domain values, mapped by name | Met | `native_option.dart:20,23`. `bottle_repository_test`, "PA2 an app's native options reach its library entry": `largeAddressAware` and both new options set through the repository come back in `LibraryApp.nativeOptions`. |
| FA2 · seven switches, state shown, a switch sends the event | Met | `pages_test`, "FA2 the FEX switches show their state and save": 7 switches inside `NativeOptionsDialog`; strict code tracking on, full x87 off; tapping "Full x87 precision" sends `setNativeOption(…, fullX87Precision, true)` once and shows it on. The 8 cases of "the Native engine options fit at … px en/es" count 7 switches. |
| FA3 · four keys in both ARBs, descriptions, `switch` cases, the wording of the table | Met | `app_en.arb`: 8 lines (4 keys, 4 `@` descriptions); `app_es.arb`: 4 keys. Both match FA3's table word for word. `native_text.dart:24-25,36-37`. `text_test`, "PA6 each retina mode and native option has words, in both", passes; `l10n_parity_test` passes. |
| FA3 · no text about getting around a protection | Met | A grep of the new keys for `protec`, `bypass`, `crack`, `drm`, `denuvo` and `anti` matched only "antiguo" ("old") in the Spanish x87 hint. |
| FC1 · automated | Met | Output below. |
| FC2.1 · Mach9 parses the line (wineboot) | Met | Output below. |
| FC2.2 · Mach9 gives both to an x86 program (probe, user agreed) | Met | Output below. |
| FC3 · user | Pending | For the user: the dialog in the real app in both languages, and a game on the Native engine with each switch. |

## FC1 · Command output

```
$ cd packages/engine && dart analyze
No issues found!
$ dart test
01:27 +483 ~5: All tests passed!
$ dart test test/compatdb_test.dart -r expanded --plain-name FE1
00:00 +0: test/compatdb_test.dart: PE7 and PE8 the app's own line FE1 the FEX options are env fields, last and exact
00:00 +1: All tests passed!
$ dart test test/mach9_test.dart -r expanded --plain-name 'PE11 option retina and native'
00:00 +0: MC1–MC8 the CLI PE11 option retina and native
00:00 +1: All tests passed!

$ cd apps/bodega && flutter gen-l10n
$ flutter analyze
No issues found! (ran in 2.4s)
$ flutter test
00:32 +1021: All tests passed!
$ tool/check_layers.sh
Layers OK
$ flutter test test/app/pages_test.dart --plain-name FA2
00:00 +1: All tests passed!
$ flutter test test/data/bottle_repository_test.dart --plain-name "PA2 an app's native options reach its library entry"
00:00 +1: All tests passed!
$ flutter test test/app/pages_test.dart --plain-name 'the Native engine options fit'
00:00 +8: All tests passed!
$ flutter test test/l10n_parity_test.dart
00:00 +24: All tests passed!
$ flutter test test/app/text_test.dart --plain-name 'PA6 each retina mode and native option has words, in both'
00:00 +1: All tests passed!

$ tool/version.sh check
OK: version 1.8.0 (tag v1.7.0).
```

## FC2 · Real Mach9, headless

Setup:
- a temporary `BODEGA_HOME` with the CLI compiled from this tree;
- `runtime install mach9 ~/Downloads/Mach9-0.4.0.dmg --mono ~/Downloads/wine-mono-11.3.0-x86.msi` took 5.4 s;
- `create --runtime mach9 fc2` took 39 s.

**FC2.1:** wineboot with `WINE_COMPATDB` = `exe=*;dll_overrides=winemenubuilder.exe=` and `exe=wineboot.exe;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full`, exit 0:

```
compatdb: wineboot.exe [aarch64]
compatdb:   env FEX_X87REDUCEDPRECISION=1, built-in: replaced by a later entry from WINE_COMPATDB line 2
compatdb:   env FEX_X87REDUCEDPRECISION=0, WINE_COMPATDB line 2: set
compatdb:   env FEX_SMCCHECKS=full, WINE_COMPATDB line 2: set
… in the processes it started:
compatdb:   env FEX_X87REDUCEDPRECISION=1, built-in: left alone, the process has FEX_X87REDUCEDPRECISION=0
warning: lines: 0
```

The last line is proposal Decision 3 at work: `=0` reaches the children, which an empty value would not.

**FC2.2**, with the user's agreement ("Sí, córrelo"):
- `probe-64.exe` was added as library app `fc2/probe-64.exe` with both options on;
- then `bodega open fc2 fc2/probe-64.exe`, exit 0.

```
# rules exe=*;dll_overrides=winemenubuilder.exe= | exe=probe-64.exe;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full
compatdb: probe-64.exe [x86_64 (arm64ec)]
compatdb:   env FEX_X87REDUCEDPRECISION=1, built-in: replaced by a later entry from WINE_COMPATDB line 2
compatdb:   env FEX_X87REDUCEDPRECISION=0, WINE_COMPATDB line 2: set
compatdb:   env FEX_SMCCHECKS=full, WINE_COMPATDB line 2: set
warning: lines: 0
OK
# exit=0
```

- `[x86_64 (arm64ec)]`: FEX is loaded in that process. Mach9 documents that FEX reads its options from the environment block compatdb has rewritten (`M/docs/internals.md`, section FEX).
- The probe ran its checks with `SMCChecks=full` and printed `OK`.
- After `wineserver -w`, the 2.0 GB temporary home was removed.

## FC3 · First user run (2026-11-24)

The user opened a game of their Native bottle with "Strict code tracking" on:
- `settings.json` held `"native": {"/volumes/ssd daniel/…/<game>.exe": ["strictCodeTracking"]}`;
- the log header read `# rules … | exe=<game>.exe;env=FEX_SMCCHECKS=full | …`;
- the game's own process (`[x86_64 (arm64ec)]`) logged `env FEX_SMCCHECKS=full, WINE_COMPATDB line 2: set`, with 0 `warning:`.

The game did not start: `"MSVCP140.dll" failed to initialize, aborting`, status c0000005, exit 5. Its run one minute before, without the switch (the rules have no `env` field), ended with the same two lines. So the failure is not the switch's.

## Open

- **FC3 (user):**
  - see the seven switches in the real app, in English and Spanish;
  - open a game that starts without the switches, with each one on, and find its `env` lines in the log;
  - "Full x87 precision" on a real game.
- **Not checked, by design:** whether a switch fixes a given game. The hints promise only when to try it.
- **Known limit (proposal, Impact):** a Bodega older than 1.8.0 refuses a `settings.json` with one of the new names on. Turning the switch off undoes it.
