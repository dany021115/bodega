# Spec · Docs, rules, version and real checks

Requirements MD1..MD8: the archived requirements this change amends, the docs and rules, the notice, the version, the headless real check, the USER checks and delivery (`design.md` §9, §10).

## MD1 · Amended archived requirements
This change shall amend, and these lines shall name:
- engine-prototype **R5** (`.sdd/archive/2026-11-03-engine-prototype/specs/runtime.md`): required files are per kind (design §2.1 for mach9), and Mach9 is staged in `.tmp-mach9-<v>` by `installMach9`, not `installRuntime`.
- engine-prototype **R7** (`runtime.md`): one runtime per kind; `current` is Bodega's and every bottle runs on its own kind (MB2, MB3), not on `current`.
- engine-prototype **R10** (`specs/bottles.md`): a Mach9 bottle is ready by the same markers; its kind comes from `system32/kernel32.dll` (MB2).
- engine-prototype **R12** (`specs/launch.md`): the hermetic environment is per kind (MG6).
- graphics-backends **S4** (`.sdd/archive/2026-11-03-graphics-backends/specs/selection.md`): the environment table gains the Mach9 column (design §4.3); **B4** (`specs/backends.md`): probe cases per kind (MG10).
- d3dmetal-and-backends **G3** (`.sdd/archive/2026-11-09-d3dmetal-and-backends/specs/exe-graphics.md`): fits per kind (MG2).
- versioning-and-releases **R3/R4** (`.sdd/versioning-and-releases/design.md:25-26`): Mach9 is never in the DMG nor copied at first launch (MR12).
- **Check:** each archived file is left as it is; this spec is the amendment.

## MD2 · README
`README.md` shall describe the Native engine: the intro (`:3-5`) and "What it does" (`:11-14`); Requirements (`:31-34`): Mach9 needs macOS 26.4 or later on Apple silicon, and Rosetta is still needed for Bodega's own engine; Install: Backends ▸ Native engine; D3DMetal (`:61-65`): Rosetta engine only; License and Credits (`:118-128`): Mach9 (Zlib, © 2026 Alexander Theißen), mtld3d (Zlib), FEX, DXMT, vkd3d-proton and Wine Mono (MIT/MPL), all downloaded, neither bundled nor modified.
- **Check:** `grep -n 'Mach9' README.md` shows those sections.

## MD3 · Agent rules
`.claude/CLAUDE.md:3` and `AGENTS.md:3` shall describe the two engines, and CLAUDE.md's Commands the new verbs. "Lines not to cross" gains: never re-sign, edit or move Mach9's tree; strip quarantine only from Bodega's own copy, never from the source; Wine Mono goes only into prefixes; agents may run wineboot, `msiexec /qn` and the probe in Mach9 bottles. `.claude/rules/architecture.md` (Host platform, `:57-64`) gains that the runtime is chosen per bottle and that Mach9 bottles get `WINE_COMPATDB` instead of `WINEDLLPATH_PREPEND` and `WINEDLLOVERRIDES`.
- **Check:** `awk 'FNR == 3' .claude/CLAUDE.md AGENTS.md | grep -c Mach9` prints 2.

## MD4 · Notice
`wine/NOTICE.md` shall gain a Mach9 row (downloaded from its GitHub release, pinned, not modified, Zlib) and tie the Wine Mono pin to it.
- **Check:** `grep -n 'Mach9' wine/NOTICE.md`.

## MD5 · Version
One `tool/version.sh bump minor` shall take `1.6.0+14` to `1.7.0+15`, covering dxvk9 and Mach9; `tool/version.sh check` then passes (apart from the untracked `.fvmrc`, which the user decides on, proposal Q3).
- **Check:** `tool/version.sh check`.

## MD6 · Headless real check (agent)
On this Mac, in a temporary `BODEGA_HOME`, headless only (wineboot, `msiexec /qn`, the probe): `runtime install mach9` from the scratchpad's `mach9/Mach9.dmg` with `--mono` the scratchpad's `winemono/wine-mono-11.3.0-x86.msi`, and again from `/Applications/Mach9.app`; `create --runtime mach9 m9t`, timed, with Mono and MB6's values present; `rules m9t <program>`; `backend test m9t mtld3d`, `dxmt`, `wine`, each log's `compatdb:` lines showing `WINE_COMPATDB line N` with no `warning:`; `codesign --verify --strict` on the copied `wine.app`; `runtimes/current` unchanged and an existing x86 bottle still passing `backend test <x86> dxmt`; then stop and remove `m9t`. Results go into `spike.md` and `verify.md`.
- **Check:** the outputs in `verify.md`.

## MD7 · USER checks
The user shall run MW3 through Plutonium in a Bodega Mach9 bottle, the game added by its Unix path on "/Volumes/Satechi HD"; compare CPU and GPU use with Mach9.app and with the Rosetta bottle; with the HUD on, see it inside iw5mp.exe; note whether Game Mode turns on and that the Dock shows "Mach9"; and check that existing Rosetta bottles still open and play.
- **Check:** the user's notes and numbers in `verify.md`.

## MD8 · Delivery
Agents shall not commit or push. The user commits from a script beside the repo on `feat/mach9-runtime`, made with `git switch --no-track -c`, in English, with no AI attribution, running `tool/version.sh check` before each commit. `verify.md` records date, machine, macOS, commit, the `| Requirement | Status | Evidence |` table and the USER checks, and `tasks.md` is ticked.
- **Check:** `verify.md` exists and every MR, MB, MG, MC, MA and MD row has a status.
