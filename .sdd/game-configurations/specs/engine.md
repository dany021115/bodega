# Spec · Engine and CLI

Requirements E1..E8 cover `design.md` §1–§6.

`engine/` is `packages/engine/`. The test home, the bottle `b` and the fake Wine are those of `engine/test/engine_test.dart`; the fake Wine writes its environment to `<prefix>/last-env`.

## E1 · The importer

`tool/import_fixes.py` shall write `fixes_data.dart` from highball-db at `bc72f85` as §1 says, and print its counts.

- **Given** a small source tree in a temporary folder:
  - two games, one with a recipe;
  - a `wined3d` game and a `vkd3d` game;
  - a blocked game with an anti-cheat;
  - reports rated 5, 3 and `x`, and one without `game_id`;
  - a recipe that requires `dotnet48` and `steam`, with a `renderer` step and a `sync` step.
- **When** `tool/import_fixes.py --src <tree> --out <file>` runs, **then** the file's JSON holds:
  - one entry per game, in id order;
  - for the `wined3d` game, `backends == {"mac": "wine"}`;
  - for the `vkd3d` game, `backends == {}`;
  - for the blocked game, `status == "blocked"` and `antiCheat.verdict == "blocked"`;
  - `reports == {"count": 2, "median": 3, "last": …}`, where the `x` report and the report without `game_id` are not counted;
  - `requires == ["dotnet48"]`;
  - the recipe's `renderer` step as `backends`;
  - no `provenance`.

  The printed report counts the skipped `vkd3d`, `steam`, `sync` and missing `game_id`.
- **Check:** `python3 -I tool/test_import_fixes.py`, which is new and uses the standard library only.

## E2 · The data

The committed `fixes_data.dart` shall be the importer's output at `bc72f85`.

- **Given** `gameFixes()`, **then**:
  - it holds at least 890 entries;
  - every id of the 20 fixes Bodega had at `7a008d5` is still there;
  - every `requires` names a row of `dependencies`;
  - every `backends` value is a backend name of `platform_mac.dart`;
  - `blur` and `need-for-speed-most-wanted-2012` read `status == "verified"`.
- **Given** the file, **then** `fixesCommit` starts with `bc72f85` and the header names CC0-1.0.
- **Check:** `dart test test/fixes_test.dart`; `tool/import_fixes.py` run again gives no diff (`git diff --exit-code packages/engine/lib/fixes_data.dart`).

## E3 · The model

`GameFix` shall read §2's fields, with the old shape's defaults, and expose `backend` and `rating`.

- **Given** an entry with `backends {"mac": "dxmt"}`:
  - on the Mac host its `backend` is `dxmt`;
  - on the Linux host it is null;
  - with `{"linux": "dxmt"}` on Linux, it is null, because Linux has no DXMT.
- **Given** medians 5, 4, 3, 2 and none, **then** `rating` is `works`, `works`, `playable`, `broken` and null. With `status: blocked` it is `blocked`.
- **Given** an entry without the new keys, **then** it reads as `status community` with empty `backends`.
- **Given** the same `fixesSource`, **then** `gameFixes()` twice returns entries parsed once (the same `GameFix` instances). A replaced source is parsed again.
- **Check:** `dart test test/fixes_test.dart`.

## E4 · Matching

`gameFor(app)` shall follow §3's order and say how it matched.

- **Given** fixes A (`steam: 10`, title "Alpha™: Game"), B (`exes: ["beta.exe"]`) and C (title "Gamma"), **then**:

  | The app | The result |
  |---|---|
  | `steam:10` | A, by `steam` |
  | `steam:99` | null, and its title is never tried |
  | a hand-added app whose exe is `Games/BETA.EXE` | B, by `exe` |
  | a hand-added app titled "alpha: game" | A, by `title` |
  | a hand-added app titled "gamma 2" | null |

- **Given** an app whose exe matches B and whose title matches C, **then** the result is B.
- **Check:** `dart test test/fixes_test.dart`.

## E5 · The backend's order

`resolveBackend` shall put `config` after the bottle's own backend and before `auto`.

- **Given** `config: dxmt`, the results are:

  | Setting | Result |
  |---|---|
  | none | `(dxmt, config)` |
  | the bottle on `dxvk` | `(dxvk, bottle)` |
  | a program exception `wine` | `(wine, program)` |
  | the launch's option `d3dmetal` | `(d3dmetal, option)` |
  | the launch's option `auto` | the auto result, and `config` is not used |

- **Given** `config: null`, **then** the result is as before this change.
- **Check:** `dart test test/backends_test.dart`.

## E6 · The switch and the verdict

`setGameConfig` and `setGameVerdict` shall work as §4 says.

- **Given** an app matched to a fix with one `registry` step, **when** it is switched off:
  - `configOff` holds its key;
  - the fake Wine's log holds `reg delete <key> /v <name> /f`;
  - the next `openApp` neither writes the value nor adds the fix's variables to `last-env`.
- **When** it is switched on again, **then** the next `openApp` writes the value and adds the variables.
- **Given** the fake `reg delete` exiting 1, **then** switching off succeeds. Exiting 5, it throws `WineToolFailed`.
- **Given** an unknown key, **then** it throws `AppNotFound`.
- **Given** a verdict:
  - `setGameVerdict(..., 'playable')` saves it and `null` clears it;
  - `'great'` throws `BadChoice`;
  - `settings.json` holds `configOff` and `verdicts` only when they are not empty.
- **Check:** `dart test test/fixes_test.dart test/options_test.dart`.

## E7 · The plan is what runs

`gamePlan` shall return §5's record, and `openApp` shall launch from it.

- **Given** a matched app with `backends {"mac": "dxmt"}` (DXMT installed in the test home), one env step and one override:
  - `gamePlan` gives `backend (dxmt, config)`, its env pair, its override and its registry step;
  - after `openApp`, the run log's backend line is `dxmt (config)`;
  - `last-env` holds the pair, and holds `WINEDLLOVERRIDES` containing the override.
- **Given** an unmatched app, **then** `match == null` and `backend.origin == 'auto'`, with `graphics` read from its exe.
- **Given** a switched-off app, **then** `on == false` and `match == null`.
- **Given** an `ini` step, **then** it is in `ini` and is never applied by `openApp`.
- **Check:** `dart test test/fixes_test.dart`.

## E8 · CLI

`bodega game show|use` and the new `fix show` lines shall print as §6 says.

- **Given** the E7 bottle, **then**:
  - `bodega game show b <key>` prints `match: …, by exe, community`, `backend: dxmt (config)`, and one `env:`, one `override:` and one `registry:` line;
  - after `bodega game use b <key> off`, `show` prints `match: off`.
- **Given** a bad state word, **then** the usage is printed and the exit code is 64.
- **Given** a fix with reports and an anti-cheat, **then** `bodega fix show <id>` prints `status:`, `backend:`, `anti-cheat:`, `reports:` and `native mac:`.
- **Check:** `dart test test/cli_test.dart`, or the CLI group of `fixes_test.dart`.
