# Checks · mach9-parity

Requirements PC1..PC4.

## PC1 · Suites
- In `packages/engine`: `dart analyze` and `dart test` pass.
- In `apps/bodega`, all pass:
  - `build_runner`;
  - `flutter gen-l10n`;
  - `flutter analyze`;
  - `flutter test`;
  - `tool/check_layers.sh`.
- `python3 tool/test_import_fixes.py` still passes.

## PC2 · Real, headless (agent)
This runs in a temporary `BODEGA_HOME`, with Mach9 0.4.0 installed from a `Mach9.dmg` downloaded once (283 MB), or from the user's `/Applications/Mach9.app` if they have it. Only wineboot, `msiexec /qn` and the probe run, as the rules allow.

1. **PE1:** no real run. The catalog would run Steam's own installer, which agents may not run, so PE1's tests and PC3 cover it.
2. **PE4:**
   - `bodega option <b> retina on`, then `bodega backend test <b> mtld3d`:
     - `user.reg` holds `"RetinaMode"="y"` and `"LogPixels"=dword:000000c0`;
     - the log header has `# retina on (on)`.
   - A second probe makes no `reg` call.
3. **PE7 and PE8:**
   - The golden tests of PE7 and PE8 check the lines' text; this check asks Mach9 whether it reads them.
   - Then, if the user agrees, the probe's own exe runs headless as a library app of the bottle, with all five options on and once more as `steam:220` with `SteamAppId=220`. The user's agreement is needed because the rules name only `bodega backend test`.
   - Each process's `compatdb:` lines show `force_nx`, `large_address_aware`, `dpi_aware`, `opengl` and `wined3d` from Bodega's line, with no `warning:`.
   - Without that agreement, this part moves to PC3.
4. **PE9:** `bodega mono install <b>`, then a fake `clr.dll` placed at the marker and `mono-2.0` moved aside: `monoMissing` reads false; with `clr.dll` moved aside too, it reads true.

Each output goes in `verify.md`. The bottle is stopped, waited on and removed.

## PC3 · USER
- **#22's V6:** a game in a Mach9 bottle, the HUD, Game Mode, the Dock, and a Rosetta bottle still playing.
- **Steam from the catalog on the Native engine:** it opens without hanging, and a Steam game starts with its HUD (PE1, PE8).
- **On a Retina display:**
  - Automatic gives a sharp game;
  - Off gives the old picture.

  On this Mac's current 2048-pixel mode, Automatic is Off.
- **Optional:** a 32-bit game that ran out of memory, or an old launcher that crashed, with the matching option on.
- **Report how it ran:** the GitHub form opens with Engine filled in.

## PC4 · Delivery
- The branch is `feat/mach9-parity`, from `feat/mach9-runtime` after `../mach9-merge-commit.sh`.
- The commits come from a script beside the repo, with no AI attribution, and `tool/version.sh check` runs before each one.
- The agent leaves the script unrun.
