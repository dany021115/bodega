# Design · Game configurations

`engine/` is `packages/engine/`. `app/` is `apps/bodega/lib/app/`.

## §1 · The data (`tool/import_fixes.py`)

**What it reads**
- It pins highball-db at `bc72f85` (2026-11-17) for everything it reads: `db/games/*.json`, `recipes/games/*.json` and `db/reports/*.jsonl`.
- **The match between files:**
  - every recipe's id is a game's id (measured: 47 of 47);
  - a report names its game by `game_id`;
  - a report without `game_id` is counted and skipped.

**What it writes**

One entry per game in `db/games`, in id order, into `fixesJson`:

```json
{
 "id": "age-of-empires-ii-definitive-edition",
 "title": "Age of Empires II: Definitive Edition",
 "steam": 813780,
 "status": "community",
 "backends": {"mac": "dxmt"},
 "antiCheat": null,
 "reports": {"count": 3, "median": 3, "last": "2026-11-11"},
 "nativeMac": true,
 "optIn": false,
 "requires": ["vcrun2022"],
 "steps": [],
 "notes": ["…"],
 "knownIssues": [{"symptom": "…", "cause": "…", "fix": "…"}],
 "verified": null,
 "source": "db/games/age-of-empires-ii-definitive-edition.json"
}
```

**How each field is filled**
- **`status`:**
  - `blocked-anticheat` and `blocked-publisher` → `blocked`;
  - anything else → `community`.
- **`backends`:**
  - the recipe's `renderer`, or its `renderer` step, else the game's `renderer`;
  - `wined3d` → `wine`;
  - `vkd3d` and an unknown value are left out, and counted;
  - always under `mac`, the only platform upstream verified.
- **`antiCheat`:** `{"names": [...], "verdict": "warning"|"blocked"}` from the game's `anticheat`, or null.
- **`reports`:**
  - `count` counts every report whose `rating` is a digit from 1 to 5;
  - `median` is the median rating (`statistics.median_low`);
  - `last` is the newest `date`'s day;
  - null when there is no report.
- **`requires`:** the recipe's `requires` that name a row of `dependencies.dart` (today `vcrun2022`, `dotnet48`, `physx`, `corefonts` and `xact`). The launchers and the other tweaks are counted and skipped.
- **The steps and the recipe notes** follow today's rules: the env allow-list, the registry roots, `dlloverride`, and every step tagged `mac`. A `renderer` step becomes `backends`. `sync`, `dxvkconfig`, `file` and `copy` are counted and skipped.
- **`notes`:** the game's `notes`, when present, first, then the recipe's notes.
- **`knownIssues`:** the game's, then the recipe's.
- **Left out:** `provenance`, because the app links the entry's file at the commit instead.

**The report it prints**
- how many games, how many with steps, with a backend, blocked, and with reports;
- every skipped thing, counted by kind.

`fixesCommit` becomes `bc72f85…`, and the file's header names `db/games`, `db/reports` and `recipes/games`, with CC0-1.0.

**Bodega's own entries** (`bodega_fixes_data.dart`) gain `"status": "verified"`.

## §2 · The model (`engine/lib/fixes.dart`)

`GameFix` gains these fields:

```dart
final String status;                 // verified | community | blocked
final Map<String, String> backends;  // platform id → backend name
final ({List<String> names, String verdict})? antiCheat;
final ({int count, int median, String last})? reports;
final bool nativeMac;

/// The backend this host gets: only one it has.
String? get backend => switch (backends[hostPlatform.id]) {
  final name? when backendNames.contains(name) => name,
  _ => null,
};

/// works | playable | broken | blocked | null (no reports)
String? get rating => status == 'blocked' ? 'blocked' : switch (reports?.median) {
  null => null, >= 4 => 'works', 3 => 'playable', _ => 'broken' };
```

For the old shape, missing keys read as follows: `status` → `community`, `backends` → `{}`, the rest → null or false. A test file with the old shape stays valid.

`gameFixes()` keeps a cache keyed by the identity of `fixesSource` and `bodegaFixesSource`. Tests replace those strings, so a replaced string is parsed again.

## §3 · Matching

```dart
enum MatchKind { steam, exe, title }
typedef GameMatch = ({GameFix fix, MatchKind by});

GameMatch? gameFor(InstalledApp app);
```

The rules, in order:
1. **`steam:<appid>`** matches the fix with that `steam`.
2. **Otherwise the exe's file name**, lowercase, matches `exes`.
3. **Otherwise the title:** `normalTitle(app.title) == normalTitle(fix.title)`, where `normalTitle`:
   - lowercases;
   - removes `™`, `®` and `©`;
   - turns every run of non-letters and non-digits into one space;
   - trims.

**Callers**
- `fixForApp(key)` is replaced by `gameFor(app)` in `openApp`, `appNeeds` and the CLI.
- `fixForSteamApp` and `gameFix` stay.

## §4 · The launch layer

**`BottleSettings` gains two fields.** Both are saved only when they are not empty.
- **`configOff`:** a set of app keys whose configuration is off.
- **`verdicts`:** a map from app key to `works`, `playable` or `broken`.

**`resolveBackend` gains `String? config`.** The order becomes:
1. the launch's option;
2. the program's exception;
3. the bottle's own backend, when it is not `auto`;
4. `config`, with origin `config`;
5. `auto`.

**Applying the configuration.** `gamePlan` (§5) gives the match, which is null when the app is in `configOff`.
- `openApp` passes the match's fix to `_launchIn` as today, and also `config: fix.backend`.
- `_applyFixRegistry` is unchanged.

**Switching it on or off.** `setGameConfig(home, bottle, key, {required bool on})` does this:
- **Off:**
  - adds `key` to `configOff`;
  - then, for each active `registry` step, runs `reg delete <key> /v <name> /f`. An exit code of 0 or 1 (the value is not there) is fine; anything else throws `WineToolFailed(WineTool.reg, …)`.
- **On:** removes `key` from `configOff`.

The values come back at the next launch. An unknown key throws `AppNotFound`.

`setGameVerdict(home, bottle, key, String? verdict)` saves or clears a verdict, and checks its value (`BadChoice`).

## §5 · The plan (what the user sees is what runs)

```dart
typedef GamePlan = ({
  GameMatch? match,        // null: no entry, or switched off
  bool on,                 // false when the app is in configOff
  ({String name, String origin}) backend,
  ExeGraphics? graphics,   // what auto read, for "automatic"
  Map<String, String> env, // the fix's env steps, after fixValue
  List<String> overrides,  // the fix's dlloverride values
  List<FixStep> registry, ini,
  List<String> requires,
  String? verdict,
});
Future<GamePlan> gamePlan(String home, String bottle, String key);
```

- `openApp` calls `gamePlan` and launches with:
  - `fix: plan.match?.fix`;
  - `config: plan.match?.fix.backend`.

  `_launchIn` keeps building the environment from `fix.active`, so the plan's `env` and `overrides` are the same steps.
- **The check:**
  - with the fake Wine, the backend in the run log is `"${plan.backend.name} (${plan.backend.origin})"`;
  - `last-env` holds every `plan.env` pair and every `plan.overrides` value.
- `ini` steps are listed for the user to apply, as now with `applyFixSettings`.
- For a Steam game, the backend is the one its Steam launch gets, read from Steam's exe (as `openApp` does today), so `graphics` reads that exe.

## §6 · CLI (`engine/bin/bodega.dart`)

```
bodega game show <bottle> <key>            # the plan, one line per thing
bodega game use <bottle> <key> on|off
```

**`show` prints:**
- `match: <title> (<id>), by steam|exe|title, <status>`, or `match: none (automatic)`, or `match: off`;
- `backend: <name> (<origin>)`;
- `graphics: DX11, 64-bit` when `auto` read it;
- one line for each `env`, `override`, `registry`, `ini` and `requires`.

**`fix show`** gains these lines:
- `status:`;
- `backend:`, with the mac one;
- `anti-cheat:`;
- `reports: 3, median 3/5, last 2026-11-11`;
- `native mac: yes`.

`fix list` is unchanged; it is filtered by text.

## §7 · App

**Domain** (`domain/entities/game.dart`, Freezed)
- **`GameConfig`:** id, title, steam, status (enum `GameStatus { verified, community, blocked }`), rating (enum `GameRating { works, playable, broken, blocked }`, nullable), the backend for this host, anti-cheat (names, verdict enum `{ warning, blocked }`), reports (count, median, last), nativeMac, steps (each a `GameStep` union: env / override / registry / ini), requires, notes, knownIssues, and `sourceUrl`.
- **`AppGame`:** the plan for one app: the app key and title, `GameConfig? config`, `MatchKind? by`, on, backend name and origin, graphics (DirectX, bits), steps, requires, verdict.
- **`GameRepository`:** `games()`, `game(id)`, `appGames(bottle)`, `setOn(bottle, key, on)`, `setVerdict(bottle, key, verdict)`, `reportUrl(bottle, key, verdict, note)`.

**Data** (`data/repository/game_repository_impl.dart`)
- It maps `GameFix`, and `gamePlan` for each of the bottle's apps.
- **`sourceUrl`:**
  - `https://github.com/gauthierpiarrette/highball-db/blob/<fixesCommit>/<source>`;
  - null for `source == 'bodega'`.
- **`reportUrl`:**
  - builds `https://github.com/dany021115/bodega/issues/new?template=game-report.yml&title=…&game=…&steam_appid=…&rating=…&backend=…&bodega=…&os=…&cpu=…&notes=…`, with `Uri.https` for the encoding;
  - its OS and CPU come from what the engine already reports, and its Bodega version from the package info the app already reads.

**Blocs**
- `GamesBloc` (`@injectable`, from the page) handles `load`, `search(text)`, `filter(rating, backend)`.
- `GameDetailBloc` (`@injectable`) handles `load(id)`.
- **The bottle's section** reads `AppGame`s from `BottleDetailBloc`, which gains `appGames`, and the events `setGameOn(key, on)` and `setVerdict(key, verdict)`.

**Pages and widgets**
- **`AppRoute.games`** (`/games`) and `AppRoute.game` (`/games/:id`), with a sidebar entry under the catalog.
- **`GamesPage`:**
  - a search field;
  - two chip rows, rating (Works, Playable, Broken, Blocked, No reports) and backend (this host's backends);
  - a list of `GameCard` (title, status chip, rating chip, backend chip, an anti-cheat icon).
- **`GameDetailPage`** shows, in order:
  1. a header with the title and chips;
  2. an anti-cheat banner, "blocked" or "warning";
  3. the reports line, saying they come from Highball's players on other Wine builds;
  4. the native-Mac line;
  5. "What it changes here": backend, variables, overrides, registry values, settings-file steps, runtimes. "Nothing on this computer" when it is empty;
  6. notes and known issues, under "From highball-db, in English" (or "From Bodega" for Bodega's own);
  7. the source with its license and the link.
- **`GamesSection`** in `bottle_column.dart`, under Dependencies. One row per app:
  - title;
  - the match, as "<game> · by Steam/exe/name" or "Automatic";
  - the status and rating chips;
  - what it changes, in one line per step;
  - the switch "Use this game's configuration", on matched apps only;
  - "Open page";
  - "Report how it ran".

  A `blocked` match shows the anti-cheat banner in the row.
- **`ReportDialog`:** three choices and a note field. Send saves the verdict and opens `reportUrl` with `launchUrl`. The row shows "You said: Works".

**Text**
- The ARB keys gain the prefix `games…`.
- Statuses, ratings, match kinds, step kinds and anti-cheat verdicts are worded in `app/shared/text/game_text.dart`, with exhaustive switches.
- Upstream notes are rendered as they are, under the label.

## §8 · The issue form (`.github/ISSUE_TEMPLATE/game-report.yml`)

- **Fields:** `game`, `steam_appid`, `rating` (dropdown: works, playable, broken), `backend`, `bodega`, `os`, `cpu`, `notes`. Each is a text input, except `rating` and `notes`, and has the id the URL fills.
- **Its intro** says three things:
  - Bodega filled the form in;
  - nothing is sent until the user submits it;
  - by submitting, the user releases the report under CC0-1.0, so that it can be shared with highball-db.
- **The label is `game-report`.**

## §9 · Rules and docs

- **`.claude/CLAUDE.md` line 69:** the fixes are generated from highball-db's `recipes/games`, `db/games` and `db/reports`, at a pinned commit.
- **`.claude/rules/architecture.md`, Text:** prose from third-party data (highball-db's notes and known issues) is shown as it is, under a label naming its source and language. It is never stored in an ARB, and it is never Bodega's own copy.

## §10 · Defaults

- The data for the Mac comes only from highball-db.
- Linux applies none of it, because there are no `linux` steps and no `linux` backends. Linux shows its notes and anti-cheat, and the automatic layer.
- **The rating chips use the median of the reports:**
  - 4 or 5 → Works;
  - 3 → Playable;
  - 1 or 2 → Broken;
  - with `blocked` before all of them.
