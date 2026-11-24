# Exploration · fex-options

Date: 2026-11-24. Base: `feat/mach9-parity` (ce35b65) in the worktree `../pr22`.

Below:
- `M/` is Mach9 v0.4.0's tree (athei/mach9 at tag `v0.4.0`).
- `FEX/` is the FEX that Mach9 pins (`M/pins/fex-src.ref`: athei/FEX at `macos-patched`).
- `ENG/` is `packages/engine/` and `APP/` is `apps/bodega/`.

## Problem

On the Native engine a game's x86 code runs through FEX, not Rosetta 2.

- A game can fail under FEX and run under a Rosetta-based Wine. One the user tried hangs on the Native engine with `RtlpWaitForCriticalSection … wait timed out … blocked by 0000` at 0% CPU. The same game runs in Whisky, whose bottle is Wine 7.7 for x86_64 under Rosetta.
- FEX has options that change how it translates. Mach9 lets a launcher set them for one program through compatdb's `env` key.
- Bodega's "Native engine options…" offers five compatdb settings, but none of FEX's own options.

The goal is that a user can turn on, for one game, the FEX options that help where FEX's defaults don't. Nothing is promised for a given game: these are switches to try.

## What Mach9 does with `env`

- **Wire format:**
  - an `env` field is `env=NAME=value`;
  - the name ends at the first `=` (`M/compatdb/core/src/wire.rs:10-11`);
  - the key repeats, one entry per field (`M/compatdb/core/src/key.rs:194-198`);
  - an empty value removes the variable (`key.rs:77-78`).
- **FEX reads it:** "FEX reads its options from the Windows environment block, which compatdb.so has already rewritten, so a compatdb `env` entry sets one for one program. A FEX config file does not override such an entry" (`M/docs/internals.md`, section FEX).
- **Built-in default:**
  - every process gets `FEX_X87REDUCEDPRECISION=1` (`M/compatdb/core/src/builtin.rs:170-189`, rule `fex_reduced_x87_precision`);
  - the entries of a built-in rule that matches every process are defaults, which "leave a variable the process already has alone" (`M/compatdb/core/src/resolve.rs:141-145`);
  - a launcher's rule is not a default, so its entry replaces what the process inherited.
- **Proof in a real log:** a launch log of 2026-11-24 in one of the user's Mach9 bottles shows:
  - `compatdb:   env FEX_X87REDUCEDPRECISION=1, built-in: set` in the first process;
  - `… left alone, the process has FEX_X87REDUCEDPRECISION=1` in the processes that inherited it.

## FEX's options that matter

From `FEX/FEXCore/Source/Interface/Config/Config.json.in`:

| Option (variable) | Default | What it does |
|---|---|---|
| `SMCChecks` (`FEX_SMCCHECKS`) | `mtrack` | Code that changes itself: `none` skips the checks, `mtrack` invalidates by page tracking, `full` validates code before every run (slow). |
| `X87ReducedPrecision` (`FEX_X87REDUCEDPRECISION`) | false in FEX, but Mach9's built-in rule sets it to 1 | x87 in 64-bit precision: faster, less exact. |
| `TSOEnabled`, `VectorTSOEnabled`, `MemcpySetTSOEnabled`, `HalfBarrierTSOEnabled` | true, false, false, true | Only for emulated x86 memory ordering. |
| `Multiblock` | true | Larger JIT blocks; "can cause long JIT compilation times and stutter". |
| `HideHypervisorBit` | false | Hides the CPUID hypervisor bit. |

### SMCChecks

- The Windows frontend reads it (`FEX/Source/Windows/Common/InvalidationTracker.cpp:21-22`) and handles `full` (`FEX/Source/Windows/ARM64EC/Module.cpp:953`).
- Text values go through `SMCCheckHandler` (`FEX/FEXCore/include/FEXCore/Config/Config.h:24-33`): `none`, `mtrack` and `full` map to 0, 1 and 2.
- **Any other text maps to 0, `none`: a typo turns the checks off.** The value must be exactly `full`.
- It helps code that rewrites itself or is patched while it runs: copy protections that decrypt their code (Denuvo, Arxan), hooks, mod loaders and overlays.

### TSO

- Mach9's FEX runs x86 code with the hardware's x86 memory ordering whenever `FEX_HARDWARE_TSO` is unset or 1 (`M/docs/internals.md`, section FEX; `FEX/Source/Windows/Common/HardwareTSO.cpp:39-60`).
- The loader's entitlement gates it, and Wine doesn't run without that entitlement (`M/docs/internals.md`, "Loader app"). So in Bodega's Mach9 bottles the ordering is already the strict one.
- The Vector, Memcpy and HalfBarrier TSO options apply only to emulated TSO.
- **Dropped:** they would change nothing. This corrects the third switch proposed to the user in chat.

### HideHypervisorBit

- **Excluded:** its only use is hiding the emulator from a program that checks for one. That is the same line as "don't help bypass anti-cheat" in `CLAUDE.md`.

### Multiblock

- It may help stutter. Nothing points at it yet.
- **Left out** until a game shows the need.

## Candidates

| Switch | compatdb field | Why |
|---|---|---|
| Strict code tracking | `env=FEX_SMCCHECKS=full` | Games that change their own code: protections, hooks, overlays. Slower. |
| Full x87 precision | `env=FEX_X87REDUCEDPRECISION=0` | Old games whose physics, timing or picture break with 64-bit x87. Slower. |

Why `=0` and not an empty value:
- An empty value removes the variable in the game's process only. A child process it starts, such as a launcher's game, gets the built-in default 1 back, since it doesn't have the variable.
- With `0` the child inherits `0`, and the built-in default leaves it alone.
- Mach9 names both ways (`builtin.rs`, `Former` "fex-x87-reduced-precision": "start Wine with `FEX_X87REDUCEDPRECISION=0`, or remove the variable").

## Bodega's code that this touches

### Engine

- **`ENG/lib/runtimes.dart:365`:** `enum NativeOption`.
  - Each value has one `(field, value)`.
  - `('env', 'FEX_SMCCHECKS=full')` fits as it is.
- **`ENG/lib/runtimes.dart:259`:** `_mach9Rules`.
  - The app's options go on its own line (`:275`).
  - Two `env` fields can share a line.
- **`ENG/lib/runtimes.dart:307`:** `_compatdbLine`.
  - It takes a list of pairs and keeps repeated keys in their order, by `Key::ALL`.
  - `env` is already in `_compatdbKeys` (`:320`), last.
  - It escapes only `%`, `;` and control bytes, so the `=` inside the value passes.
- **`ENG/lib/apps.dart:667` and `:693`:** `setNativeOption` and `nativeOptions` store enum names.
  - New names are additive: `settings.json` needs no migration.
- **`ENG/lib/backends.dart:478`:** the `native` field.
- **`ENG/lib/backends.dart:614`:** reading `settings.json` checks each name with `NativeOption.values.byName`.
  - An older Bodega reading a bottle saved by this one would throw on the new names.
- **`ENG/lib/cli.dart:126`:** `nativeOptionNames`, the CLI's names for `bodega native <bottle> <key> [<option> on|off]` (`:215`, `:223`).

### App

- **`APP/lib/domain/entities/native_option.dart`:** the domain's own `NativeOption` enum, mapped by name.
  - `APP/lib/data/service/app_mapper.dart:26-29`;
  - `APP/lib/data/repository/bottle_repository_impl.dart:203-213`.
- **`APP/lib/app/shared/text/native_text.dart`:** one name and one hint per option, an exhaustive `switch`. A new value fails the build until it has its words.
- **`APP/lib/app/presentation/library/widgets/native_options_dialog.dart:57`:** loops over `NativeOption.values`, so the dialog picks the new switches up by itself.
- **ARBs:**
  - `APP/lib/l10n/app_en.arb:3462-3520`: `nativeOptionsTitle`, `nativeOptionsNote`, `native<Option>` and `native<Option>Hint`;
  - their Spanish in `app_es.arb:572-582`.

### Tests

- **`ENG/test/compatdb_test.dart:266-295`:** `setNativeOption`.
- **`ENG/test/runtimes_test.dart`:** the golden lines of PE7.
- **`APP/test/app/text_test.dart:2772-2788`:** every option has a distinct name and hint.
- **`APP/test/app/pages_test.dart`:** the dialog.
- **`APP/test/app/library_bloc_test.dart`** and **`APP/test/data/bottle_repository_test.dart`**.

### Specs

- The options were specified in `.sdd/archive/2026-11-23-mach9-parity/specs/engine.md` (PE7, PE11) and `specs/app.md` (PA2, PA6). PA2 says "five switches".
- This change extends them.

## Constraints

- **Mach9's tree:** never touched. The options travel only in `WINE_COMPATDB`, as the five do now.
- **Running Wine:** agents run Wine headless and only wineboot, `msiexec /qn` and the probe in Mach9 bottles. Games are the user's to run.
- **Verification precedent:** mach9-parity's check of PE7 ran the probe's own exe as a library app, with the user's agreement (`.sdd/archive/2026-11-23-mach9-parity/specs/checks.md:24-28`).
  - The probe's exe is x86, so FEX is loaded in it.
  - Its `compatdb:` lines would show `env FEX_SMCCHECKS=full, WINE_COMPATDB line 2: set`.
- **Language:** everything in git is in English; only the ARB's Spanish is Spanish.
- **Versioning:** the `bump-version` skill before any commit.
- **Wording:** no text ties a switch to getting around a protection. The hint names what FEX does ("games that change their own code while they run"), as the other hints name when to turn theirs on.

## Open questions

1. **Names and hints of the two switches.** For example:
   - "Strict code tracking": "Turn it on when a game hangs or closes at start on the Native engine but runs on Rosetta: for games that change their own code. Slower.";
   - "Full x87 precision": "Turn it on when an old game's physics, timing or picture go wrong. Slower."
2. **Does FEX confirm what it read?** Is there a way short of a game (FEX's own log) to see that the probe process ran with `SMCChecks=full`? Otherwise the check stops at compatdb's lines plus Mach9's documented contract.
3. **Verification:** the same as mach9-parity, if the user agrees: the probe's exe as a library app with both switches on.
4. **Per-game fixes:** should `bodega_fixes_data.dart` be able to turn a native option on for a game verified by hand? Not needed for this change. Left out unless the user wants it.
