# Spec: host libraries

### R17 · A manual, cheap workflow
File: `bodega-engine/.github/workflows/build-hostlibs.yml`.

**Configuration**
- Trigger: only `workflow_dispatch`, with two inputs: `publish_release` (boolean) and `ref_note` (text).
- `permissions: contents: write`.
- `runs-on: macos-15-intel`: the same Intel Homebrew as `BE/.github/workflows/build.yml:22,45`.
- `timeout-minutes: 15`.
- No checkout and no Wine build.
- Environment variables: `HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_UPGRADE=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`, `HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1` and `ROOTS="libfreetype.6.dylib libgnutls.30.dylib libMoltenVK.dylib"`, the only list of roots, used by `bundle` and `probe`.
- Guard before installing: `brew list --versions freetype gnutls || { echo 'runner image lacks freetype/gnutls; would build from source'; exit 1; }`. Without them preinstalled, `brew install` would build from source (there is no Intel bottle, design §1) and burn through the whole time limit, billed ×10.
- Installs `freetype`, `gnutls` and `molten-vk`.
- The `install` step has `timeout-minutes: 5`: a bottle pours in seconds, so any formula that switches to building from source is cut off at 5 min.

Scenarios:
- **Given** a dispatch, **then** the job finishes green in under 10 min.
- **Given** a runner image without freetype or gnutls, **then** the job fails within seconds with that message and builds nothing.

**Check:** T1 (valid YAML) and T3 (real job).

### R18 · Closure and names
A `python3` script is a port of `BE/.github/workflows/build-arm64.yml:223-268` without the SDL3 part:
- It receives the roots in `$ROOTS` as arguments.
- It walks `otool -L` and follows the Homebrew paths and the `@rpath/` ones.
- It copies each leaf to `out/engine/lib/wine/x86_64-unix/`.
- It rewrites the id and the dependencies of each one to `@loader_path/<leaf>` and signs it ad hoc.
- It fails if any reference to `$(brew --prefix)` or to `@rpath/` remains.

It does not include SDL2, FFmpeg or GStreamer.

Scenario:
- **Given** the copied closure, **then** `otool -L` on each `.dylib` only shows `@loader_path/…`, `/usr/lib/…` or `/System/…`.

**Check:** the step's assertion in the CI; T2 (dry run on arm64); T16.

### R19 · Load probe by leaf name
Setup:
- A module compiled with `-Wl,-rpath,@loader_path/` is placed in the destination folder.
- An executable without `LC_RPATH` loads it.
- With `env -i`, cwd `/` and `DYLD_PRINT_LIBRARIES=1`, the module opens the roots in `$ROOTS` by leaf name.
- Its stderr goes to `$RUNNER_TEMP/probe.log`, an absolute path redirected outside the `cd /` (design §1).

The probe passes if every root loads from the destination folder and no image comes from `$(brew --prefix)`.

Scenario:
- **Given** macos-15-intel, the project's minimum platform, **then** the probe passes.

**Check:** the `probe` step in the CI (T3); T2 on arm64.

### R20 · Artifact
- **Name:** `hostlibs-x86_64-<UTC>-<ref_note>.tar.gz`, with `<ref_note>` sanitized: every character outside `[A-Za-z0-9_-]` is replaced with `-`, and the note reaches the script through `env`, without interpolating it into the shell.
- **Contents:** only files, no directory entries:
  - `hostlibs.txt`, with the name, the runner image (`$ImageOS` and `$ImageVersion`), the brew versions and the list of files;
  - `engine/lib/wine/x86_64-unix/*.dylib`.
- **Size:** under 30 MiB, asserted in the CI.
- **`.sha256`:** in the same format as the engine's, `<hex>  <name>`.
- **Release:** if `publish_release` is on, the tag is the file name and it is created with `gh release create`, using `GH_TOKEN` and `GH_REPO`.

Scenario:
- **Given** `tar -tzf` of the tarball, **then** no line ends in `/` or starts with `./`.

**Check:** the CI's assertions; T4 (`shasum -c`).

### R21 · Use without variables
Once installed with `install`, the hostlibs load from `x86_64-unix/` thanks to the `LC_RPATH @loader_path/` of the Wine modules. No variable is needed, and this holds for any process in the bottle.

Scenarios:
- **Given** a runtime with hostlibs, **when** `create`, `rundll32 dwrite.dll,BodegaProbe` and `rundll32 bcrypt.dll,BodegaProbe` run, **then** no log gives FreeType or GnuTLS hints or contains `[mvk-info]` or `Failed to load libMoltenVK`. That line appears if MoltenVK or its closure does not load (`CX/dlls/win32u/vulkan.c:3013-3016`), and without it the missing `[mvk-info]` would prove nothing.
- **Given** a runtime without hostlibs, **when** the same probes run, **then** the FreeType and GnuTLS hints appear.
- **Given** a `.js` that uses `WinHttp.WinHttpRequest.5.1` against `https://example.com/`, **when** `bodega run t cscript //nologo 'C:\https.js'` runs, **then** the log contains `status=200`.
- **Given** notepad open on the M2 Pro, **then** `lsof` on its process shows the hostlibs loaded from `runtimes/<id>/engine/lib/wine/x86_64-unix/`: direct proof of the `LC_RPATH` under Rosetta.

**Check:** T15 and T16 (headless); U3 (glyphs drawn with FreeType, and `lsof`).
