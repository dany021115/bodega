# Spec · App

Requirements A1..A7 cover `design.md` §7–§9.

`lib/` and `test/` are `apps/bodega/`'s. Every check ends with `flutter analyze && flutter test && tool/check_layers.sh` green.

## A1 · Domain and data

`GameRepository` and its implementation shall map the engine's fixes and plans as §7 says.

- **Given** the engine's real data, **then**:
  - `games()` returns at least 890 `GameConfig`s;
  - Blur is `verified`, with a null `sourceUrl`;
  - a highball-db entry's `sourceUrl` is `https://github.com/gauthierpiarrette/highball-db/blob/<fixesCommit>/db/games/<id>.json`.
- **Given** a test bottle with a matched app and an unmatched one, **then**:
  - `appGames(b)` returns two `AppGame`s;
  - the first has its config, `by`, backend `(…, config)` and steps;
  - the second has a null config and backend origin `auto`.
- **Given** `setOn(b, key, false)`, **then** `appGames` shows it off. A `reg` failure becomes an `AppError`.
- **Given** a verdict and a note, **then** `reportUrl` is an `https` URL on `github.com/dany021115/bodega/issues/new`, with `template=game-report.yml` and each field, encoded.
- **Check:** `test/data/game_repository_test.dart`.

## A2 · The Games page

`GamesPage` at `/games`, reached from the sidebar, shall list every game, with search and two filters.

- **Given** the mocked repository with games of each rating, **then**:
  - every game shows a card with its title and chips;
  - typing text keeps the games whose title contains it, ignoring case;
  - the Broken chip keeps only broken ones;
  - the DXMT chip keeps only games whose backend here is DXMT.
- **Given** the sidebar's entry, **when** it is tapped, **then** the route is `/games`.
- **Given** a tap on a card, **then** the route is `/games/<id>`.
- **Check:** `test/app/games_page_test.dart`, `test/app/games_bloc_test.dart`.

## A3 · The game's page

`GameDetailPage` shall show §7's sections, in that order. Every word is from the ARBs, except the game's own notes.

- **Given** a game that is blocked by anti-cheat, **then** the banner says online play won't work and names the anti-cheat.
- **Given** a warning, **then** the softer banner shows.
- **Given** reports `(3, 3, 2026-11-11)`, **then** the line says 3 reports, mostly Playable, with the last one on 2026-11-11, and that they came from Highball's players.
- **Given** steps, **then** "What it changes here" lists each one, with its value.
- **Given** none, **then** it says "Nothing on this computer".
- **Given** notes, **then** they are shown under "From highball-db, in English", and the source line links `sourceUrl`.
- **Given** Bodega's own entry, **then** the label is "From Bodega" and there is no link.
- **Check:** `test/app/game_detail_page_test.dart`.

## A4 · The bottle's Games section

The bottle page shall list its apps with their plans, as §7 says.

- **Given** a matched app, **then** it shows:
  - its game, "by Steam" (or by exe or by name);
  - its chips;
  - one line per step;
  - the switch, on;
  - "Open page" and "Report how it ran".
- **Given** an unmatched app, **then** it shows "Automatic", its backend and the graphics read, and no switch.
- **When** the switch is turned off, **then** `setOn(b, key, false)` is called and the row shows it off.
- **Given** a blocked match, **then** the anti-cheat banner shows in the row.
- **Check:** `test/app/games_section_test.dart`, `test/app/bottle_detail_bloc_test.dart`.

## A5 · The report

`ReportDialog` shall save the verdict and open the prefilled form.

- **Given** Playable and the note "menu only", **when** the user taps Send, **then**:
  - `setVerdict(b, key, playable)` is called;
  - `launchUrl` gets `reportUrl(…, playable, "menu only")`;
  - the row shows "You said: Playable".
- **Given** no choice, **then** Send is disabled.
- **Given** `.github/ISSUE_TEMPLATE/game-report.yml`, **then**:
  - it parses as YAML;
  - it has the ids `game`, `steam_appid`, `rating`, `backend`, `bodega`, `os`, `cpu` and `notes`;
  - its intro names CC0-1.0.
- **Check:** `test/app/report_dialog_test.dart`; the YAML check in `test/data/game_repository_test.dart`.

## A6 · Text

Every new string shall be in both ARBs, with `@` descriptions, and worded through `game_text.dart`'s exhaustive switches.

- **Given** `l10n_parity_test.dart`, **then** it passes.
- **Given** every value of `GameStatus`, `GameRating`, `MatchKind`, the step kinds and the anti-cheat verdicts, **then** `game_text.dart` words each of them in both languages, with no empty text.
- **Check:** `test/app/text_test.dart`, `test/l10n_parity_test.dart`.

## A7 · Rules

`.claude/CLAUDE.md` and `.claude/rules/architecture.md` shall say what §9 says.

- **Check:** read in verify, with the lines quoted.
