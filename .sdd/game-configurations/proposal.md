# Proposal · Game configurations (issue #16)

## Decisions approved on 2026-11-19

The user approved the exploration's recommendations:

1. **The Mac's data.**
   - Import highball-db's `db/games/` (893 games) and its 47 `recipes/games/`, with a summary of `db/reports/`, at a new pinned commit.
   - Recipe `requires` that name Bodega's runtimes are mapped to them.
   - An entry from highball-db is "community" until it is verified on Bodega.
2. **Linux.** This change gives Linux the automatic layer, the per-app switch and the preview. umu-protonfixes is a later change.
3. **Not imported:**
   - ODbL's `derived.json`;
   - Whisky's GameDB.
4. **Reports.**
   - Bodega opens a prefilled GitHub issue form of its own repo in the browser, and the user sends it with their own account.
   - Bodega keeps the user's verdict for each app locally.
   - A report becomes curated data by hand, in `bodega_fixes_data.dart`.
5. **Language.** highball-db's notes and known issues are shown in English, under a label that says so. Everything Bodega words itself is in the ARBs.
6. **A layer at launch, not a copy into the settings.**
   - A game's configuration is resolved at each launch, as fixes are today.
   - What the user set by hand wins.
   - The per-app switch "Use this game's configuration" takes the place of Revert.
   - The preview comes from the same function the launch uses.
   - Runtimes are proposed, never downloaded by themselves.
7. **Matching.** By Steam AppID, then exe name, then normalized title. A match by title is shown as such.
8. **Milestones:**
   - **M1:** engine and CLI;
   - **M2:** app;
   - **M3:** checks.

## Why

A game that fails under Wine usually fails for a known reason with a known fix. Today Bodega knows 22 such fixes and applies them silently, and the app never shows them:
- the user cannot see what a game will get;
- the user cannot turn it off;
- the user cannot tell Bodega whether it worked.

highball-db now describes 893 Mac games, with:
- the renderer that worked for each;
- its anti-cheat verdict;
- 1,203 player reports.

All of it is CC0, from the same project Bodega already pins.

## What

**Engine**
- **The importer.** `tool/import_fixes.py` also reads `db/games/` and `db/reports/`. It writes one entry per game into `fixes_data.dart`, with:
  - its status (community or blocked);
  - its backend per platform;
  - its anti-cheat names and verdict;
  - a report summary (how many, the median rating, the last date);
  - whether it has a native Mac version;
  - its mapped runtimes.
- **`GameFix`** gains those fields, and is read once per data source, not on every call.
- **`gameFor(app)`** matches by Steam AppID, exe name or title, and says which one matched.
- **At launch:**
  - the configuration's backend comes between the bottle's own backend and `auto`;
  - an app the user switched off gets nothing from its configuration;
  - switching an app off deletes the registry values its configuration wrote.
- **`gamePlan(home, bottle, key)`** gives what a launch of that app will get: the match, the backend and where it comes from, the variables, overrides, registry values, settings-file steps and runtimes. The launch itself uses the same function.
- **The CLI:** `bodega game show <bottle> <key>` and `bodega game use <bottle> <key> on|off`.

**App**
- **A Games page in the sidebar:**
  - search, with filters by rating and by backend;
  - a page per game: status, reports, anti-cheat, native Mac version, what it changes on this host, notes and known issues (in English, labeled), and its source and license.
- **The bottle's page gains a Games section:** each app with its match (or "automatic"), what it changes, the switch, "Open page" and "Report how it ran".
- **The report dialog** asks how the game ran (Works / Playable / Broken) and for an optional note. It saves the verdict and opens `.github/ISSUE_TEMPLATE/game-report.yml` prefilled.
- **Text:** every new string goes in both ARBs. The Text rule gains its exception for third-party prose.

## Out of scope

- **Exe hashes:** no source Bodega may ship has them, except Whisky's.
- **Engine detection** (Unity, Unreal).
- **Staleness:** the game page shows the date of its last report instead.
- **The sync step:** highball-db's one `sync: msync` is Bodega's default on the Mac.
- **Recipe steps of type `dxvkconfig`, `file` and `copy`:** they are counted and reported by the importer, as skipped steps are today.
- **Installing runtimes by themselves.**
- **Any server of Bodega's.**
- **umu-protonfixes, ProtonDB and Whisky's data.**

## Milestones

**M1 · Engine and CLI**
- importer and data;
- model;
- matching;
- launch layer and switch;
- plan;
- CLI.

**M2 · App**
- domain and data;
- Games page and game page;
- the bottle's Games section;
- report dialog and issue form;
- ARBs;
- rules.

**M3 · Checks**
- **Real, headless:** the importer at the pinned commit, and `bodega game show` on a real bottle.
- **The user:**
  - a matched game launches with its backend;
  - the switch;
  - the report form.
- **The collaborator, on Linux:** the plan and the switch.

## Impact

- **`packages/engine/`:** `fixes.dart`, `fixes_data.dart` (regenerated, about 0.6 MB of text), `apps.dart`, `engine.dart`, `backends.dart` (`configOff`, `verdicts`, the backend order), `bin/bodega.dart` and the tests.
- **`tool/import_fixes.py`.**
- **`apps/bodega/`:**
  - domain: entities and repository;
  - data: repository implementation;
  - app: bloc, two pages, the bottle section and the report dialog;
  - the router, the sidebar, both ARBs and the tests.
- **`.github/ISSUE_TEMPLATE/game-report.yml`**, which is new.
- **`.claude/CLAUDE.md` and `.claude/rules/architecture.md`:** where the data comes from, and the Text exception.

## Risks

- **Renderers that worked on other Wine builds may not work on Bodega's.** Each entry from highball-db is shown as "community", and its reports as "from Highball's players", with the switch at hand.
- **A wrong match by title.** It is shown as "matched by name". The user turns it off with the switch.
- **The data's size.** About 0.6 MB, compiled into the binary and parsed once. The notes' provenance stays out, linked by the entry's file at the commit.
- **A Steam that is already open does not pass variables to the game.** Bodega already says so, with `fixNotApplied`.
