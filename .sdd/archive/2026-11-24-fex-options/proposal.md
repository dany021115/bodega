# Proposal · fex-options

## Why

On the Native engine a game's x86 code runs through FEX.

- Some games fail under FEX's defaults and run under Rosetta.
- FEX has options that change how it translates, and Mach9 lets a launcher set them for one program through compatdb's `env` key (exploration, "What Mach9 does with `env`").
- Bodega's "Native engine options…" offers none of them.

## What

Two more Native engine options per app, in the same dialog and the same `native` list of `settings.json`:

| Option | Sends | When it helps |
|---|---|---|
| `strictCodeTracking` | `env=FEX_SMCCHECKS=full` | Games that change their own code while they run: protections that decrypt their code, hooks, mod loaders, overlays. |
| `fullX87Precision` | `env=FEX_X87REDUCEDPRECISION=0` | Old games whose physics, timing or picture go wrong with Mach9's 64-bit x87. |

Both cost speed, so both are off by default, like the other five.

## Decisions

1. **One `NativeOption` value per switch.** Each value has its compatdb field `env` and the whole `NAME=value` as its value.
   - `_compatdbLine` already keeps repeated keys and escapes only `%`, `;` and control bytes.
   - The engine needs no new structure.
2. **The values are exact.**
   - FEX maps any `FEX_SMCCHECKS` text other than `none`, `mtrack` or `full` to `none`, which turns the checks off.
   - A golden test pins both values.
3. **`FEX_X87REDUCEDPRECISION=0`, not an empty value.**
   - An empty value removes the variable in the game's process only: a child it starts gets Mach9's built-in default 1 again.
   - `0` is inherited, and the built-in default leaves an inherited variable alone.
4. **Left out:**
   - the TSO emulation options: Mach9 runs x86 code with the hardware's memory ordering, so they would change nothing;
   - `HideHypervisorBit`: hiding the emulator from a program is the line `CLAUDE.md` draws at anti-cheat;
   - `Multiblock`: no game needs it yet;
   - shipping these options in `bodega_fixes_data.dart`: per-game fixes stay as they are.
5. **Order on the line:**
   - the two `env` fields come last, by `Key::ALL`;
   - between them, the order of the sorted `native` names: `fullX87Precision`, then `strictCodeTracking`.

## Impact

- **Engine:**
  - `NativeOption` gains two values (`runtimes.dart`);
  - the CLI gains two names (`cli.dart`).
- **App:**
  - the domain enum gains two values;
  - two names and two hints in each ARB, and their `switch` cases (`native_text.dart`);
  - the dialog shows seven switches.
- **Specs:** this extends mach9-parity's PE7, PE11, PA2 and PA6, archived. Their tables and "five switches" now read as these specs say.
- **Compatibility:**
  - bottles need no migration;
  - an older Bodega that reads a bottle with one of the new names on refuses its `settings.json`, as it would any unknown option. Turning the switch off in this version undoes it.
- **Nothing for Rosetta bottles:** the options are saved in either runtime but sent only to Mach9, as now.
- **No promise for a given game:** the hints say when to try a switch, not that it fixes anything.
