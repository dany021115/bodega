# Spec: runtime

### R4 · Verification before extracting
`install` requires a `<tarball>.sha256` next to each tarball and checks it with `/usr/bin/shasum -a 256 -c`, run in the tarball's folder. The CLI never downloads anything.

Scenarios:
- **Given** a tampered `.sha256`, **when** `install` runs, **then** it gives an error and nothing new appears in `runtimes/`, not even `.tmp-*`.
- **Given** that the `.sha256` is missing, **then** the error includes `gh release download <tag> -R dany021115/bodega-engine`.

**Check:** test `installRuntime`, and `grep -n HttpClient lib/` returns nothing.

### R5 · Extraction into a single staging folder
`install` follows these steps:
1. Extracts with `/usr/bin/tar -xzf` first the engine and then the hostlibs, both into `runtimes/.tmp-<id>`. If that directory was left over from an earlier attempt, it deletes it first.
2. Removes the quarantine with `/usr/bin/xattr -dr com.apple.quarantine`, without looking at its exit code.
3. Requires the 8 paths in `requiredFiles`: the 6 from `HBK/EngineStore.swift#L637-L646` plus `libfreetype.6.dylib` and `libgnutls.30.dylib`, both in `engine/lib/wine/x86_64-unix/`.
4. Runs `engine/bin/wine --version`, whose output must start with `wine-`.
5. Renames the staging folder to `runtimes/<id>`, where `<id>` is the engine tarball's name without `.tar.gz`.

If anything fails, it deletes the staging folder.

Scenarios:
- **Given** hostlibs without `libgnutls.30.dylib`, **then** it gives the error `runtime incompleto: falta …` ("incomplete runtime: … is missing") and no `.tmp-*` is left.
- **Given** correct tarballs, **then** `runtimes/<id>/engine/lib/wine/x86_64-unix/libgnutls.30.dylib` exists and the CLI prints the runtime's folder.

**Check:** test `installRuntime` (with the fake runtime); T16 and U1 with the real tarballs.

### R6 · Immutable runtimes
It is the first thing `install` checks, before R4 and R5: if `runtimes/<id>` already exists, it fails right away and gives instructions: `bodega stop` the bottles, `rm -rf` the runtime and install again from the local tarballs. It is also the way to change the hostlibs, so the engine tarball and its `.sha256` are kept in `/Users/quasar/Documents/GitHub/Bodega/runtimes/engine-wine-11.0-20261030T202616Z-primer-build/`: without them, changing the hostlibs would mean downloading 335 MB again.

Scenario:
- **Given** a runtime that is already installed, **when** `install` is repeated, even with the `.sha256` missing, **then** it gives the error `ya instalado` ("already installed") and nothing changes.

**Check:** test `installRuntime`.

### R7 · Current runtime
`install` creates the symlink `runtimes/current.tmp` → `<id>` (first deleting any that was left over) and renames it over `runtimes/current`. rename(2) replaces the previous link atomically; `Link.updateSync` does not work because it deletes and recreates (`DSDK/lib/io/link.dart:279-285`). Every bottle uses that runtime, resolved with `resolveSymbolicLinksSync()`. If none is installed, `create`, `run`, `wait` and `stop` fail with `no hay runtime: bodega install …` ("no runtime: bodega install …").

Scenarios:
- **Given** a correct installation, **then** `currentRuntime(home)` returns the resolved `runtimes/<id>` folder.
- **Given** runtime A installed, **when** B is installed, **then** `currentRuntime(home)` returns B.

**Check:** test `installRuntime`.
