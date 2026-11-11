# Proposal · i18n

Input: `exploration.md` (approved). Its 14 defaults (§7) are the decisions, with two changes from the lead: the language is the only choice offered, without the theme toggle, and the two dead widgets are deleted. The user later replaced the dialog that offered it with a short menu in the sidebar (design §2).

## Why
- Bodega is public on GitHub under the GPL-3.0-or-later (`.claude/CLAUDE.md:3`), and its releases live in this repository (`AGENTS.md:18`). Its UI is Spanish only, so most people who find it cannot use it.
- The repo rule keeps everything in git in English except the app's Spanish UI text, "which the `i18n` change moves to the Spanish translation file" (`.claude/CLAUDE.md:7`). Today Spanish is in every layer: 42 widget files, a bloc, `data/`, `domain/`, 74 engine throws and its steps and hints, the catalog prose, the CLI, logs, tests and `Info.plist`.

## What
**In**
- Every text the app shows comes from `lib/l10n/app_en.arb` (the template) or `app_es.arb`, read through `context.l10n` (Flutter gen-l10n, class `AppL10n`), set up as in gym-coach. About 360 keys per locale.
- The language follows the system's ordered list; a system in neither language gets English. A "Language" item in the sidebar footer opens a short menu: System, English, Español. The choice is saved and applies at once.
- `domain/` and `data/` return codes, never sentences; only `app/` words them. The engine throws a sealed `EngineFailure` and returns enums and records instead of text. The engine, the CLI, logs and the catalog data are English only.
- The catalog prose (56 strings) gets ARB keys per entry and field, looked up by app id.
- Text the OS shows for the app exists in both languages and follows the system: macOS permission prompts and menu bar, the Linux desktop entry.
- Tests assert English through shared pump helpers, check Spanish through the Spanish ARB, render every screen in both locales, and fail on a missing key or placeholder.
- One key per meaning: the inconsistent copy found in explore is settled, and the plural bug ("1 apps en 1 botellas") is fixed.
- Deleted, not translated: `lib/app/presentation/library/widgets/library_card.dart` (unused), and `lib/app/presentation/bottles/widgets/app_tile.dart` with `test/app/app_tile_test.dart`, its only user.
- The app's name stays **Bodega** in both languages, in the app, the Dock and the menus ("About Bodega", "Acerca de Bodega"): a brand, never translated.
- Rules and docs follow: `.claude/CLAUDE.md`, `code-style.md`, `architecture.md`, with gym-coach's i18n rules.

**Out**
- The theme toggle stays hidden (`main.dart:62`). The menu bar's "Preferences…" item (`MainMenu.xib:36`) stays unwired: there is no dialog for it to open.
- A third language. The language games and Wine run in: they keep the system's (`platform_linux.dart:65-66`, `platform_mac.dart:84`).
- `.sdd/`, docs, scripts, README and `packaging/macos/README.txt` (separate work); `fixes_data.dart` (generated, already English); release notes in the update dialog (content, shown as written); AppStream metainfo.

## Milestones
One change, applied in three milestones, with no release between them.

| | Content | Done when |
|---|---|---|
| M1 | gen-l10n setup, `test/support/pump.dart`, parity test, every presentation string in both ARBs, dead widgets removed | widget tests pass in English through the helpers; `pages_test.dart` renders both locales |
| M2 | codes from the engine (`EngineFailure`, enums, records, English CLI and logs), `data/` and `domain/`; words in `app/shared/text/`; catalog prose | no Spanish under `packages/engine/`, `lib/data/`, `lib/domain/`; engine tests check types |
| M3 | `LocaleBloc` and the language menu; `Info.plist`, `.lproj` files, desktop entry; rules and docs; layer rule; smoke test; cleanup | every check in `design.md` §9 passes; Spanish is left only in the allowed files |

## Impact
- App: `pubspec.yaml`, new `l10n.yaml` and `lib/l10n/`, `main.dart`, `router.dart`, the sidebar, 42 presentation files, new `lib/app/shared/text/`, `LocaleBloc`, the language menu, one new preference.
- Domain and data: `AppError` becomes a union of codes; `HostIssue`, `BackendInfo`, `CatalogApp` and `ExeGraphics` lose their text; 14 data sentences and 8 mappers change; steps and hints arrive as codes.
- Engine and CLI: new `failures.dart` and `english.dart`, the 74 throws, 8 kinds of other text, log labels, the prose in `catalog_data.dart`, `bin/bodega.dart` (34 sites). CLI output turns English, so `tool/smoke_linux.sh:46` changes with it.
- Tests: about 130 widget tests move to the helpers (20 `MaterialApp`s in 15 files); 36 `AppError`s built from Spanish text; about 52 engine assertions move from text to types; new parity, catalog-keys, `LocaleBloc` and language menu tests.
- Native and CI: `Info.plist`, `en.lproj` and `es.lproj`, `project.pbxproj` (edited with a tool), `bodega.desktop`; `test.yml` validates the desktop entry. `flutter pub get`, already first in CI and in packaging, regenerates the localizations.
- Users: a Spanish system keeps Spanish; any other language now gets English, and the language menu can force either. Material's own text (text-field menu, tooltips) follows. Old logs keep their Spanish notes; nothing is migrated.

## Risks
| Risk | Mitigation |
|---|---|
| Every widget test breaks at once on the `context.l10n` assert | the pump helpers are M1's first task |
| A missing key or dropped placeholder builds and analyzes clean | the parity test |
| Text frozen in bloc state stays in the old language after a switch | state keeps codes; pages word them |
| Breadth of the engine refactor (74 throws, about 52 assertions) | one sealed type, one exhaustive mapper, tests on types |
| A half-done release: an English UI with Spanish errors | no release between milestones |
| Spanish runs longer and overflows | `pages_test.dart` widths in both locales |
| A hand-edited `project.pbxproj` breaks the macOS project | edited with a tool; `plutil` and a build check it |
| macOS per-app language and Spanish prompts cannot be seen off a Mac | a user check on the Mac |

## Version
**Decision (the user, 2026-11-10): 1.5.0.** A feature raises the minor number (`AGENTS.md:8`): `tool/version.sh bump minor` takes `apps/bodega/pubspec.yaml:20` from `1.4.2+11` to `1.5.0+12`, once, before the change's first commit. The tag `v1.4.2` (`tag-version` made it at `b4e1752`, with the MW3 microphone fix and the open-source license) stays as it is: it can still be released from its tag (`AGENTS.md:17`), for example to test the in-app update from 1.4.1, or left unreleased. No tag is created, moved or deleted by hand (`AGENTS.md:16`).

## Specs
- `specs/app-text.md` (L1..): what the app shows and in which language: ARB text, system language and the language menu's choice, plurals and formats, codes worded in `app/`, catalog prose, "Copy details".
- `specs/engine-codes.md` (E1..): `EngineFailure`, the other engine codes, English CLI and logs, and the codes `data/` and `domain/` carry.
- `specs/native-and-tooling.md` (N1..): macOS and Linux native text, pump helpers, parity and catalog-keys tests, the layer rule, the smoke test, CI and the rules.
