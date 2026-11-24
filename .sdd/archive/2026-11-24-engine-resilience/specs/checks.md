# Spec · checks

## EC1 · Automated, after each part

- In `packages/engine`: `dart analyze` and `dart test`.
- In `apps/bodega`: build_runner, `flutter gen-l10n`, `flutter analyze`, `flutter test` and `tool/check_layers.sh`.

## EC2 · AGENT, real, part A

In a temporary `BODEGA_HOME` with Mach9 from `~/Downloads/Mach9-0.4.0.dmg` and a Mach9 bottle:

1. **ER1:**
   - `wineboot` through Bodega leaves `DisableHidraw`, `Enable SDL` and `DisableInput` in `system.reg`, and `gamepads: 3`;
   - a second run writes nothing.
2. **ER2:** during that session, `bottleProcesses` lists its wineserver and services, and the folder name matches `stat` of the prefix.
3. **ER3:** `stopBottle` leaves `lsof +d <server folder>` empty.

The bottle is removed and the folder deleted.

## EC3 · USER, part A, before part B starts

- **Games (Native):** with the hand-set `env` taken out of its `settings.json`, the pad works in Blur.
- **Orphans:** reopening Bodega ends nothing, or shows the toast when something was left.
- **Fifa22 (Rosetta):** with retina on auto, the game fills the screen. The game stays "open" in Bodega while it runs, after its relaunch.

## EC4 · USER and AGENT, part B

- **The hang:** a game that hangs on the Native engine shows the hint within about 2 minutes, and "Open with the Rosetta engine" opens it in a Rosetta bottle while the Native entry hides.
- **Measuring:** while the user plays on the Rosetta engine, the agent runs `bodega measure Fifa22 60` three times: as is, with `metal4`, and with AVX off. The averages go in `verify.md`. No default changes in this change.
