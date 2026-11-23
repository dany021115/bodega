# Tasks · game-configurations

**Conventions**
- `engine/` is `packages/engine/`, where `dart` runs. `lib/` and `test/` are `apps/bodega/`'s, where `flutter` runs.
- **Every task ends green:**
  - in `engine/`: `dart analyze && dart test`;
  - in `apps/bodega`, from T9 on: `flutter analyze && flutter test && tool/check_layers.sh`.
- Run `flutter gen-l10n` after an ARB edit, and build_runner after a Freezed or Injectable one.
- **(USER)** means only the user or the collaborator can do it.
- **Committing:** the agent never commits or pushes. The user commits once, at the end (their word of 2026-11-18), with T19's script.

## Starting point

- [x] **T1** A snapshot of #15, kept out of the repo.
  - **2026-11-19:**
    - `../snapshots/runtimes-and-performance.patch` covers 45 files, +2724 and −630.
    - Its sha256 is `71cf6040bfec58b0908b1f2b430e3f1059a7a96b65aebe0178e4b22c1482b735`.
    - `git apply --cached --check` passed on the clean index.
  - **Context:** #15 (`runtimes-and-performance`) is not committed, and this change works on top of it, on `feat/runtimes-and-performance`'s working tree.
  - **Does:**
    - before any code of this change, `git diff HEAD --binary > ../snapshots/runtimes-and-performance.patch`;
    - writes the patch's `sha256` here.
  - **Why:** T19 stages #15's commits from the patch (`git apply --cached --include=…`), then this change's commits from what remains, without touching the working tree. #15's own untracked files are only `.sdd/runtimes-and-performance/`.
  - **Check:** `git apply --cached --check` of the patch passes on a clean index; `git status --short` is unchanged.

## M1 · Engine and CLI

- [x] **T2** The importer (E1).
  - **Does:**
    - `tool/import_fixes.py` reads `db/games`, `db/reports` and `recipes/games` at `bc72f85`, as §1 says;
    - adds `--out`;
    - adds the stdlib test `tool/test_import_fixes.py`.
  - **Check:** `python3 -I tool/test_import_fixes.py`.
  - **2026-11-19:** done; `python3 -I tool/test_import_fixes.py` prints `import_fixes: ok`.
- [x] **T3** The data (E2, C1).
  - **Does:**
    - runs the importer against the real source and pastes its counts here;
    - adds `"status": "verified"` to Bodega's two entries.
  - **Check:** a second run gives no diff; `dart test test/fixes_test.dart`.
  - **2026-11-19:** the importer's counts against the real source:
    - 893 games: 21 with steps, 412 with a backend, 50 blocked, 771 with reports, 3 with runtimes.
    - Skipped:
      - `requires steam` (47);
      - Highball's own variables (`HB_*`, `FEX_*`, `MVK_*`, `CX_*`: 22);
      - the steps `file` (4), `copy` (2), `dxvkconfig` (1) and `sync` (1);
      - `renderer vkd3d` (1);
      - 5 reports without a rating.
    - The file holds one game per line: 858 KB in 903 lines. A second run gave the same file (`cmp`).
    - All 20 ids of `7a008d5` are still there.
- [x] **T4** The model and its cache (E3).
  - **Does:** `GameFix`'s new fields, `backend`, `rating`, and the cache in `gameFixes()`.
  - **Check:** the E3 tests.
  - **2026-11-19:** done; the E3 tests pass.
- [x] **T5** Matching (E4).
  - **Does:**
    - adds `MatchKind`, `GameMatch`, `normalTitle` and `gameFor(app)`;
    - moves `openApp`, `appNeeds` and the CLI onto `gameFor`.
  - **Check:** the E4 tests, and the dependencies tests still green.
  - **2026-11-19:** done, with S2 (below).
- [x] **T6** The backend's order (E5).
  - **Does:** adds `resolveBackend(config:)`, and the origin `config`.
  - **Check:** the E5 tests.
  - **2026-11-19:** done, with S3 (below).
- [x] **T7** The switch, the verdict and the plan (E6, E7).
  - **Does:**
    - adds `configOff` and `verdicts` to `BottleSettings`;
    - adds `setGameConfig`, `setGameVerdict` and `gamePlan`;
    - makes `openApp` launch from the plan;
    - teaches the fake Wine `reg delete`.
  - **Check:** the E6 and E7 tests.
  - **2026-11-19:** done. The fake Wine's `reg` exits 1 for `GONE`. `dart test` passes: 349 tests, 4 skipped.
- [x] **T8** CLI (E8).
  - **Does:** adds `bodega game show|use` and the new `fix show` lines, and updates the usage.
  - **Check:** the E8 tests; `dart compile exe bin/bodega.dart -o ../../build/bodega` builds.

  - **2026-11-19:** done, with S4 (below).
## M2 · App

- [x] **T9** Domain and data (A1).
  - **Does:**
    - `GameConfig`, `AppGame` and the enums;
    - `GameRepository` and its implementation, with `reportUrl`;
    - the `AppError` mapping for anything new.
  - **Check:** `test/data/game_repository_test.dart`.
  - **2026-11-19:** done. `test/data/game_repository_test.dart` has 4 tests. The YAML is checked by its ids and its CC0 line, because the app has no YAML package.
- [x] **T10** The Games page and its bloc (A2).
  - **Does:** `GamesBloc`, `GamesPage`, `GameCard`, the route and the sidebar entry.
  - **Check:** the A2 tests.
  - **2026-11-19:** done. `GamesPage`/`GamesView`, `GameCard` and `GameChips`, `/games` and `/games/:id`, and the sidebar entry below Library. The tests are in `test/app/games_page_test.dart` and `games_bloc_test.dart`.
- [x] **T11** The game's page (A3).
  - **Does:** `GameDetailBloc` and `GameDetailPage`.
  - **Check:** the A3 tests.
  - **2026-11-19:** done. `GameDetailPage`/`GameDetailView`, `AntiCheatBanner` and `GameChanges`.
- [x] **T12** The bottle's Games section (A4).
  - **Does:**
    - `BottleDetailBloc` gains `appGames`, `setGameOn` and `setVerdict`;
    - adds `GamesSection`.
  - **Check:** the A4 tests; the bottle detail tests are updated.
  - **2026-11-19:** done, with S6. `GamesSection` sits under Dependencies. The tests of the bottle's page (`text_test`, `bottle_detail_page_test`, `pages_test`) provide a quiet `AppGamesBloc`.
- [x] **T13** The report (A5).
  - **Does:** `ReportDialog` and `.github/ISSUE_TEMPLATE/game-report.yml`.
  - **Check:** the A5 tests.
  - **2026-11-19:** done. `ReportDialog` (with `ChoiceChip`s) and `.github/ISSUE_TEMPLATE/game-report.yml`. Its label `game-report` does not exist in the repository yet: the user creates it, or GitHub leaves the report without a label.
- [x] **T14** Text (A6).
  - **Does:** adds `game_text.dart` and every `games…` key to both ARBs, with descriptions.
  - **Check:** the A6 tests.
  - **2026-11-19:** done. 55 `games…` keys in both ARBs, worded through `game_text.dart`. `l10n_parity_test` and the new A6 test in `text_test` pass.
- [x] **T15** Rules (A7).
  - **Does:** edits `.claude/CLAUDE.md` line 69 and the Text section of `.claude/rules/architecture.md`.
  - **Check:** quoted in verify.

  - **2026-11-19:** done, in `.claude/CLAUDE.md` (the per-game configurations line) and in the Text section of `.claude/rules/architecture.md`.
## M3 · Checks

- [x] **T16** The plan on a real bottle, headless (C2).
  - **Does:** a scratch bottle, `bodega game show` and `use`, and `reg query`; the output is pasted here; the bottle is deleted after.
  - **2026-11-19:** the scratch bottle `games-check` was made headless, with a Steam app entry for Five Nights at Freddy's (319510), using `build/bodega`:
    ```
    $ bodega game show games-check steam:319510
    match: Five Nights at Freddy's (five-nights-at-freddys), by steam, community
    backend: dxvk (config)
    registry: HKCU\Software\Wine\AppDefaults\FiveNightsatFreddys.exe\X11 Driver EmulateModeset = y
    reg query after the value is written:   exit 0, EmulateModeset REG_SZ y
    $ bodega game use games-check steam:319510 off
    off: steam:319510
    reg query after "game use off":         exit 1, reg: Unable to find the specified registry value
    $ bodega game show games-check steam:319510
    match: off
    backend: wine (auto)
    $ bodega game use games-check steam:319510 on   ->  match: … by steam, community / backend: dxvk (config)
    ```
    The bottle was stopped (`bodega stop`, `wait`), then deleted.
- [ ] **T17 (USER)** The app (C3).
  - **Does:** the debug app is started by the agent; the user goes through C3's three steps; the agent reads the run logs.
  - **2026-11-19:** the agent started the debug app (`flutter run -d macos`). It waits for the user's three steps.
- [ ] **T18 (USER, collaborator)** Linux (C4).
  - **Does:** the commands are written here once M1 is done.
  - **The commands**, from the repo's root, on the Linux host with this branch's working tree:
    ```
    cd packages/engine && dart test test/fixes_test.dart && dart compile exe bin/bodega.dart -o ../../build/bodega && cd ../..
    build/bodega create games-check
    S="$HOME/.local/share/bodega/bottles/games-check/prefix/drive_c/Program Files (x86)/Steam"
    mkdir -p "$S/steamapps" && : > "$S/steam.exe"
    printf '"appid" "319510"\n"name" "FNAF"\n"StateFlags" "4"\n' > "$S/steamapps/appmanifest_319510.acf"
    build/bodega game show games-check steam:319510     # expect: match … by steam, community; backend: … (auto); no registry line
    build/bodega game use games-check steam:319510 off && build/bodega game show games-check steam:319510   # expect: match: off
    build/bodega game use games-check steam:319510 on
    build/bodega stop games-check && rm -rf "$HOME/.local/share/bodega/bottles/games-check"
    cd apps/bodega && flutter test && flutter run -d linux   # open Games in the sidebar
    ```
    On Linux, the backend must not say `(config)`, because highball-db's backends are the Mac's. Send the output back.
- [x] **T19** The commit script, for #15 and this change together. It is written by the agent and run by the user.
  - **Does:** `../changes-commit.sh` replaces `../runtimes-commit.sh`. It runs:
    1. its checks: the branch, an empty index, and the patch's `sha256` equal to T1's;
    2. `tool/version.sh bump minor`, then the version commit, when it moves;
    3. #15's three commits, each staged with `git apply --cached --include=<paths>` from T1's patch, plus `git add .sdd/runtimes-and-performance`;
    4. this change's commits, `feat(engine)`, `feat(app)` and `docs`, each from `git add <paths>` of what remains.

    It pushes nothing.
  - **Check:** `bash -n`; a dry run in a temporary clone (`git clone --local`), with the working tree copied in, that ends with `git status --short` empty and `git diff <final tree>` empty.

  - **2026-11-19:** `../changes-commit.sh` is written, and `../runtimes-commit.sh` is deleted, because it would have put #16's files into #15's commits.
    - **The dry run**, in a `git clone --local` copy with the same working tree:
      - 6 commits; the version did not have to move, since 1.7.0 is already above the last tag;
      - `git status --short` empty afterwards;
      - each of the 98 changed or new files equal to the working tree (`cmp`);
      - #15's three commits give the same `git patch-id` as its patch (`265cb3c…`).
    - The user runs `bash /Users/quasar/Documents/GitHub/Bodega/changes-commit.sh`.
## Spec changes found in apply (waiting for the user's approval)

- **S1 (E1):** a report counts toward the game its file is named after.
  - 4 early reports in highball-db have no `game_id`, but they sit in their game's file. The importer counts them instead of skipping them.
  - Only a report without a rating (`x`, null) is skipped.
- **S2 (§1, E2):** Bodega's own entry replaces highball-db's entry of the same id.
  - highball-db now has `blur` and `need-for-speed-most-wanted-2012` too, so the old "the id is there twice" check would refuse the data.
  - A repeated id inside `bodega_fixes_data.dart` is still refused.
  - Bodega's NFS entry gains `"steam": 1262560`, from highball-db's entry, so the Steam copy matches too.
  - Matching looks at Bodega's entries first.
- **S3 (§4, E5):** a configuration's backend that is not installed is ignored, and auto decides.
  - Throwing `BackendNotInstalled` is kept for what the user chose.
  - A program exception's origin is `exe`, as it already was, not `program`.
- **S4 (E8):** the CLI is tested in `fixes_test.dart`'s group "the CLI (E8)", on the Mac only.
  - The group builds `bin/bodega.dart` once and runs it against the shipped data: Alice's Steam app, Armored Core VI and Baldur's Gate 3.
- **S5 (§5, E7):** a switched-off app's plan keeps its match, with `on: false`, and nothing comes from it: no backend, steps or runtimes. The app needs the match to show the switch so it can be turned back on. The CLI still prints `match: off`.
- **S6 (§7, A4):** the bottle's section has its own bloc, `AppGamesBloc`, provided by the bottle's page, instead of new events in `BottleDetailBloc`.
  - It reads the bottle again when the page's `BottleDetail` changes.
  - The report's URL comes back in its state, as a one-shot value, and the section opens it.
  - The domain reuses the existing `AntiCheatVerdict`, from the catalog's anti-cheat list, instead of a second enum.
- **S7 (open question, risk):** highball-db's `dxvk` is Highball's DXVK, which also runs Direct3D 9. Bodega's DXVK on the Mac has no `d3d9`.
  - Five Nights at Freddy's, a Direct3D 9 game, gets `dxvk (config)`. Since Bodega's DXVK does not replace `d3d9`, it still draws with Wine's own Direct3D 9, as `auto` would, and nothing breaks.
  - But highball-db's reports for `dxvk` describe a different layer.
  - Possible fix, not done: apply a `dxvk` from the configuration only to a hand-added exe that `exeGraphics` reads as DX10 or DX11. A Steam game's exe is Steam's, so it cannot be checked.
