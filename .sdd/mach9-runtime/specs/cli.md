# Spec · CLI

Requirements MC1..MC8: new and changed verbs of `ENG/bin/bodega.dart` (usage text `:6-39`; `design.md` §6). Parsing is tested through the verb functions, as `apps_test.dart` tests `parseOpen`; output goes to stdout, errors print the failure's English message.

## MC1 · runtime list
`bodega runtime list` shall print one line per `listRuntimes` entry: `bodega: installed (<id>)` or `bodega: not installed`; on the Mac `mach9: installed <v> (<id>)`, `mach9: installed <v> (not checked with this Bodega)`, `mach9: not installed`, or `mach9: not available (<reason's English>)`. Linux prints only the bodega line.
- **Given** the test Mac with 0.5.0 installed, **then** `mach9: installed 0.5.0 (not checked with this Bodega)`. (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MC2 · runtime install mach9
`bodega runtime install mach9 [Mach9.dmg|Mach9.app] [--mono <msi>]` shall call `installMach9`, printing each `Mach9Step`'s English; with no file it downloads (pinned) or uses the found app (MR4).
- **Given** the fake Mach9.app path and an MSI, **then** exit 0 and `runtimes/mach9` exists. (test)
- **Given** `/Applications/Mach9.app`, and separately the scratchpad's `Mach9.dmg` with `--mono` the scratchpad's MSI, **then** each installs into a temporary `BODEGA_HOME`. (headless V2)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MC3 · create --runtime
`bodega create [--runtime bodega|mach9] <bottle>` shall create on bodega by default and on Mach9 with `--runtime mach9`, which also installs Mono (MB5). An unknown runtime is a usage error (exit 64).
- **Given** `create x`, **then** the bottle's settings have no `runtime` key (scripts and `tool/smoke_linux.sh` unchanged). (test)
- **Check:** `fvm dart test test/mach9_test.dart`.

## MC4 · mono install
`bodega mono install <bottle>` shall call `installMono` and print whether Mono was installed, already present, or not needed (a Rosetta bottle).
- **Check:** `fvm dart test test/mach9_test.dart`.

## MC5 · rules
`bodega rules <bottle> [--backend <b>] [--hud] <program>` shall print `compatdbRules`'s value, or a line saying a Rosetta bottle sends none.
- **Given** design §4.2's second case, **then** its golden string. (test)
- **Check:** `fvm dart test test/compatdb_test.dart`.

## MC6 · backend list --runtime
`bodega backend list` shall print exactly what it prints today; `--runtime mach9` prints `listBackends(runtime: mach9)` in the same form.
- **Given** no flag, **then** the output equals today's (`smoke_linux.sh` greps `dxvk: installed`). (test)
- **Check:** `fvm dart test test/mach9_test.dart`; `tool/smoke_linux.sh` unchanged.

## MC7 · catalog install --runtime
`bodega catalog install <id> [bottle] [--runtime mach9]` shall pass `runtime` to `installEntry` for a new bottle (MB9).
- **Check:** `fvm dart test test/catalog_test.dart test/mach9_test.dart`.

## MC8 · Existing verbs follow the bottle
`run`, `open`, `backend set`, `backend test`, `sync`, `stop`, `wait`, `rename` and `hud` shall keep their syntax and act on the bottle's own runtime (MB3, MG3). `needsHost` (the Rosetta check) is unchanged; the usage text lists MC1–MC7.
- **Given** `bodega` with no arguments, **then** the usage holds every new verb. (test)
- **Check:** `fvm dart test`; `fvm dart run bin/bodega.dart` prints the usage.
