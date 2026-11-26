# Spec · checks

What proves this change, and what only a person can prove.

## Headless, in this repository

| Check | Command | Expected |
|---|---|---|
| Engine analyses | `cd packages/engine && dart analyze` | no issues |
| Engine tests | `cd packages/engine && dart test` | all pass |
| App analyses | `cd apps/bodega && flutter analyze` | no errors |
| App tests | `cd apps/bodega && flutter test` | all pass, except the nine update tests that need `/usr/bin/shasum` on macOS |
| Layers | `cd apps/bodega && bash tool/check_layers.sh` | `Layers OK` |
| Version | `tool/version.sh check` | passes, 1.11.0 |

## What only a person can prove (USER)

1. A bottle on the Rosetta engine with an ARM64 Windows program added to it: Run says the program needs the Native engine, in the language of the app.
2. The same program in a Native bottle: it launches.
3. If the person has no ARM64 Windows program, this check waits: the header cases above cover the engine's half, and Wine's own behaviour for the executable's half.
