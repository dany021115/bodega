# Spec · the engine

## HE1 · D3DMetal launches ask for it

`backendEnv` for `d3dmetal` sets `BODEGA_HOOKABLE_THUNKS` to `dxgi.dll,d3d11.dll,d3d12.dll,d3d12core.dll,nvapi64.dll`.

Scenarios (unit tests):
- **Given** the `d3dmetal` backend, **then** the variable is that list.
- **Given** `dxmt`, `dxvk`, `wine` or a Mach9 bottle, **then** the variable is absent.

## HE2 · Not for anti-cheat games

Scenarios (unit tests):
- **Given** a launch from the library whose recognised game names an anti-cheat (`GameFix.antiCheat` is not null), **then** the launch environment has no `BODEGA_HOOKABLE_THUNKS`, even when the bottle's or the program's environment sets it.
- **Given** the same game with its configuration turned off, **then** the same: the anti-cheat stays known (added in apply, the user's decision of 2026-11-26).

Not covered, and written in the docs:
- "Run .exe" (`runInBottle`) looks up no game, so it cannot know of an anti-cheat.
- A game started by a launcher that is already running inherits the launcher's environment.
- The rule was kept as it is, also for FIFA 23, whose highball-db entry names EA anticheat (the user's decision 1a of 2026-11-26).

## HE3 · A program can turn it off

Scenario (unit test): **given** a program whose environment sets `BODEGA_HOOKABLE_THUNKS` to empty, **then** the launch carries it empty. The patch treats empty as off.
