# Spec · engine

Extends `.sdd/archive/2026-11-23-mach9-parity/specs/engine.md` (PE7, PE11).

## FE1 · Two native options

`NativeOption` (`packages/engine/lib/runtimes.dart`) shall gain, after `vulkanWined3d`:

| Option | Field | Value |
|---|---|---|
| `strictCodeTracking` | `env` | `FEX_SMCCHECKS=full` |
| `fullX87Precision` | `env` | `FEX_X87REDUCEDPRECISION=0` |

- Each value's doc comment says what FEX does with it and cites its source: FEX's `Config.json.in`, and Mach9's `builtin.rs` for x87.
- Storing, reading and sending them is PE7's, unchanged:
  - the sorted `native` list of `settings.json`;
  - `setNativeOption` and `nativeOptions`;
  - the app's own line, only in a `mach9` launch.

Scenarios:
- **Given** an app with `strictCodeTracking`, `fullX87Precision` and `largeAddressAware`, **then** its line is `exe=game.exe;large_address_aware=true;env=FEX_X87REDUCEDPRECISION=0;env=FEX_SMCCHECKS=full`. (golden test)
- **Given** a Steam app `steam:220` with the HUD on and `strictCodeTracking`, **then** its line is `exe=steam:220;metal_hud=true;env=FEX_SMCCHECKS=full`. (golden test)
- **Given** the same app in a Rosetta bottle, **then** no `WINE_COMPATDB` is sent. (PE7's existing test covers every value)
- **Given** `setNativeOption` with each new option on, then off, **then** `settings.json` holds the sorted names, then has no `native`. (existing loop over `NativeOption.values`)

## FE2 · CLI

`nativeOptionNames` (`packages/engine/lib/cli.dart`) shall gain:
- `strictCodeTracking`: `strict-code-tracking`;
- `fullX87Precision`: `full-x87-precision`.

Scenarios:
- **Given** `bodega native m9 g/game.exe strict-code-tracking on`, **then**:
  - it exits 0;
  - `bodega native m9 g/game.exe` lists `strict-code-tracking`. (test)
`bodega rules` does not show an app's native options: it passes no app key to `compatdbRules` (`cli.dart:193-207`). This change leaves that alone. FE1's golden tests cover the line.
