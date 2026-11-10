# Spec: CLI and data root

The tests cited are in `packages/engine/test/engine_test.dart`. Tasks `Tn` and steps `Un` are in `tasks.md`.

### R1 · Data root
- The root is `BODEGA_HOME`, if it is set, or `$HOME/Library/Application Support/Bodega`.
- It is created and canonicalized with `resolveSymbolicLinksSync()`.
- The root is also validated before creating it (not counting `.` and `..`), so that a rejected root is never left on disk.
- No path component may end in `.` or in a space, or contain `<>:"|?*` (pitfall 11). `winPathProblem` checks it.
- Inside it go `runtimes/` and `bottles/`.

Scenarios:
- **Given** `BODEGA_HOME=/tmp/b`, **when** a verb runs, **then** everything ends up under `/private/tmp/b`.
- **Given** `BODEGA_HOME=/tmp/a./b`, **when** a verb runs, **then** it exits with 1 and the message names the `a.` component.

**Check:** test `names and windows paths` and T13 (headless).

### R2 · Verbs and exit codes
Verbs: `bodega install <engine.tar.gz> <hostlibs.tar.gz>`, `create <b>`, `run <b> <program> [args…]`, `wait <b>` and `stop <b>`.

Exit codes:
- With no arguments or an unknown verb: prints the usage to stderr and exits with 64.
- On any error: writes `bodega: <message>` to stderr and exits with 1.
- `run` exits with the program's code; `wait` and `stop`, with their own (R11).

It is compiled with `dart compile exe` and produces `build/bodega` (arm64, ad hoc signature). It has no runtime dependencies.

Scenarios:
- **Given** `bodega` with no arguments, **then** it prints the usage and exits with 64.
- **Given** `bodega create 'a b'`, **then** it exits with 1 and does not create `bottles/a b`.

**Check:** T13 (`build/bodega; echo $?`).

### R3 · Rosetta
Before creating the root and running any valid verb, the CLI runs `/usr/bin/arch -x86_64 /usr/bin/true`. If it fails, it writes `bodega: falta Rosetta: softwareupdate --install-rosetta --agree-to-license` ("bodega: Rosetta is missing: …") and exits with 1 (`INV/INFORME-FINAL.md:321`).

Scenario:
- **Given** a Mac without Rosetta, **when** `bodega create x` runs, **then** it exits with 1, shows that message and `bottles/x` does not exist.

**Check:** code review in verify, because Rosetta is not uninstalled to test it. The positive case is exercised by T13 and T16, which use the CLI.
