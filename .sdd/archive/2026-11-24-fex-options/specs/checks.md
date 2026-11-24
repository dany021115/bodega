# Spec · checks

## FC1 · Automated

The commands of `CLAUDE.md` pass, with their output in `verify.md`:
- in `packages/engine`: `dart analyze` and `dart test`;
- in `apps/bodega`: `flutter gen-l10n`, then `flutter analyze`, `flutter test` and `tool/check_layers.sh`.

## FC2 · AGENT, real Mach9

In a temporary `BODEGA_HOME` with Mach9 0.4.0 installed from `~/Downloads/Mach9-0.4.0.dmg`, with no download, and a Mach9 bottle `m9`:

1. **Mach9 parses the line:**
   - `wineboot`, which the rules allow, runs headless in `m9` with `WINE_COMPATDB` set to `exe=*` plus a line `exe=wineboot.exe;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full`. That is FE1's fields as `_compatdbLine` writes them, for an exe the rules let an agent run.
   - wineboot's `compatdb:` lines show both entries `set` from that line, with no `warning:`.
   - wineboot is ARM64, so FEX is not loaded in it. This checks compatdb's reading only.
2. **Mach9 reads them:**
   - This step runs only if the user agrees, because the rules name only `bodega backend test`, as in mach9-parity's PE7 check.
   - The probe's own x86 exe runs headless as a library app of `m9`, with both options on.
   - Each process's `compatdb:` lines show `env FEX_SMCCHECKS=full` and `env FEX_X87REDUCEDPRECISION=0` from `WINE_COMPATDB` line 2, with no `warning:`.
   - Without that agreement, this step moves to FC3.

The bottle is stopped, waited on and removed, and the temporary `BODEGA_HOME` deleted.

## FC3 · USER

- The dialog of a Mach9 bottle's game shows the seven switches in English and in Spanish.
- A game on the Native engine still starts with each new switch on, and its launch log shows the switch's `env` line.
- Whether a switch fixes a given game is not a check of this change.
