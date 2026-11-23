# Proposal · dependencies

Input: `exploration.md`, approved by the user on 2026-11-16 together with its four recommendations, which are the decisions here:
1. this change installs only what a vendor's own installer installs (the Visual C++ runtimes); winetricks comes in a later change;
2. "recommended" only when a curated entry says so (or when Wine has no copy of a DLL the program imports), "optional" with its size otherwise, and a file the user already has can stand in for the download;
3. Bodega's own per-game entries live in a hand-written file beside the generated one, and a game that is not on Steam is matched by its exe's file name;
4. a setting in a game's own file is changed once, when the user accepts it, so a change the user makes later in the game wins.

The rest of exploration's open questions get the defaults written in `design.md` (§9 lists them).

## Why
- Games fail under Wine because a Microsoft runtime they expect is missing or because Wine's own copy of it misbehaves. Blur crashed now and then in Wine's `msvcr90.dll` until Microsoft's VC++ 2008 runtime replaced it in the user's bottle (exploration, "Problem"). Today a Bodega user has to find that out on forums and copy DLLs by hand, and loses the fix with the bottle.
- Some games need a change in their own settings file. Need for Speed: Most Wanted (2012) stutters on Apple Silicon until its reverb is off (`[Sound] Reverb=0`), because its audio engine is x87 code that Rosetta runs slowly. Bodega's fixes can't change a game's files today.
- Bodega's fixes reach only Steam games (`fixes.dart:105-108`); most games users add by hand match none.

## What
**In**
- **Runtimes.** A table of six Visual C++ runtimes, 2005, 2008, 2010, 2012, 2013 and 2015–2026, each for 32 and 64 bits: Microsoft's installer URL, its SHA-256, its size, its silent arguments, the DLLs Wine should then prefer, and the file that shows it is installed. Installing one downloads the installer (or takes a file the user picked, checked against the same SHA-256), runs it silently in the bottle, and sets those DLLs to `native,builtin` for the whole bottle. "Installed" is always read from the bottle: Microsoft's DLL in place, not Wine's.
- **Reading a program.** Bodega reads an exe's import tables and its manifest to find which runtime it uses, and its bits to pick 32 or 64.
- **Proposals.** For each program, Bodega proposes what is missing:
  - *recommended*: a runtime a Bodega entry names for that game, or one whose DLL the program imports and Wine does not have (the MFC libraries);
  - *optional*: a runtime the program imports that Wine also provides, which usually works;
  - *a setting*: a change to the game's own file that a Bodega entry names, shown as recommended.
  A program's runtime that the game ships in its own folder is not proposed.
- **When.** Right after "Add program" and after a catalog install, a dialog lists the proposals for that program when at least one is recommended: recommended items checked, optional ones unchecked, each with its size and the reason. In the bottle's panel, a Dependencies section always lists what the bottle's programs need and what is installed, and opens the same dialog for any runtime, by hand.
- **Bodega's own entries.** A hand-written `bodega_fixes_data.dart` in the same shape as the generated fixes, matched by exe file name: Blur (`blur.exe`) recommends VC++ 2008; Need for Speed: Most Wanted 2012 (`nfs13.exe`) changes `[Sound] Reverb` to `0` in its settings file, on the Mac only.
- **A new fix step**, `ini`: one key of one section of a file under the bottle user's profile, applied when the user accepts it and never at launch.
- **CLI**: `bodega deps list|check|install` and `bodega fix apply`.
- English and Spanish texts; the rules in `.claude/CLAUDE.md` for the new data file.

**Out**
- winetricks, `cabextract`, and everything only they install: .NET, the DirectX extras (`d3dx9`, XACT), PhysX, fonts. highball-db's `requires` and its tweaks stay unimported: at the pinned commit no game requires a tweak this change can install (design §9).
- Uninstalling a runtime, and undoing a setting (the game's own menu does that).
- #15's performance options and #16's database, ratings and user reports.
- Scanning the DLLs beside an exe, and folders below it: only the exe and the CRT DLLs its folder holds (design §3).
- The Wine patch for `__rem_pio2` (a later change; it would mend Blur without Microsoft's DLL).

## Milestones
One change on one branch, built in the working tree uncommitted, for the user to read and run; the user commits each milestone with a script beside the repo (design §11).

| | Content | Done when |
|---|---|---|
| M1 | Engine and CLI: the runtime table, reading programs, proposals, install, status, Bodega's entries and the `ini` step, the CLI verbs, two failures | `dart analyze && dart test` pass in `packages/engine`; a headless install of VC++ 2008 (32-bit) into a scratch bottle leaves Microsoft's `msvcr90.dll` in place and the overrides in `user.reg` |
| M2 | App: entities, repository, `DependenciesBloc`, the proposal dialog, the Dependencies section, texts in both languages | `flutter analyze`, `flutter test` and `tool/check_layers.sh` pass; `pages_test.dart` renders the section and the dialog in `en` and `es` |
| M3 | Real checks, rules and docs, version | the USER checks of `specs/rules-and-checks.md` pass (Blur in a new bottle, NFS13's setting from Bodega); `tool/version.sh check` passes |

## Impact
- Engine: new part `dependencies.dart` (table, reading programs, proposals, install, status); new library file `bodega_fixes_data.dart`; `fixes.dart` gains the `ini` step, `exes`, `requires` and a nullable `steam`; `failures.dart` two classes and one `ChoiceKind`; `bin/bodega.dart` two verbs. `fixes_data.dart` and `tool/import_fixes.py` do not change.
- App: two `AppError` codes; new entities, `DependencyRepository` and its implementation, `DependenciesBloc` (a lazy singleton, so an install outlives the page), the dialog and the section, `dependency_text.dart`; hooks in the add-app flow and the catalog install; about 30 keys per ARB.
- Users: a dialog after adding a game that has a known need, a new section in the bottle's panel, and downloads only when they accept them, from Microsoft's servers, of 2.7 to 18.7 MB each.

## Risks
| Risk | Mitigation |
|---|---|
| Microsoft replaces a file at its URL and the SHA-256 goes stale (winetricks#2195) | a mismatch fails with its own message and leaves the bottle as it was; a network test, off by default, checks every pin |
| Microsoft blocks downloads in some countries, or the link is slow | sizes shown before anything downloads; resumable downloads; "Choose the installer file…" after a failed download, checked against the same SHA-256 |
| Bottle-wide `native,builtin` changes how other programs in the bottle load the CRT | the dialog says it is for the whole bottle; native-then-builtin falls back to Wine's copy when Microsoft's is absent, as winetricks and highball-db do |
| An installer leaves nothing behind although it exits 0 | "installed" is read from the bottle after the run, and a run that left no Microsoft DLL fails as `DependencyNotInstalled` |
| Writing a game's settings file through the profile's `Documents` link | only the one file the entry names, after checking that its real path is in the bottle or in the user's home; refused while the bottle runs, since the game rewrites its file when it exits |
| A wrong match by exe name proposes another game's fix | the dialog names the game and the reason, nothing installs without a click, and settings steps are host-scoped |
