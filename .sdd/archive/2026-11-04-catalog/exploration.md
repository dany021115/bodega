# Exploration: catalog

**Paths:** `P` = `bodega/packages/engine`; `BE` = `bodega-engine`; `HBDB` = `gauthierpiarrette/highball-db` (commit `f0bf6a2`, 2026-11-03); `HB` = `gauthierpiarrette/highball` (GPL; personal use). Code reading and local read-only checks. **No launcher has been installed in Bodega.**

## 1. Problem and scope

The user wants a screen like CrossOver's "Install a Windows Application": a search box, popular applications with their rating, and one-click install. Also "install another application" for any `.exe`.

This change covers only the **engine**: the catalog format, installation, per-program settings and the CLI (`bodega catalog …`). The screen goes in the `flutter-app` change, on top of this engine.

**What is not reused:** CrossOver's profiles, list and stars (`crossover.tie`, CrossTie) are proprietary data. Project rule: neither copy nor extract them.

## 2. Where the data comes from

`HBDB` is licensed CC0 for curated data and recipes (`db/derived` is ODbL; `db/anticheat.json`, MIT; `README.md:22-25`).

- `recipes/launchers/`: 7 recipes (Steam, Epic, Battle.net, EA, GOG Galaxy, Rockstar, Ubisoft).
- `recipes/games/`: 44 recipes.
- `db/games/`: 737 game records with `status` (`verified-local`, `reported-upstream`, `community`, `blocked-anticheat`), `rendererResults` and `anticheat`. Not all of them have been read.

**Shape of a recipe.** Steps in order: `sync`, `environment`, `registry`, `winetricks`, `installer` (`url`, `sha256`, `arguments`, `msi`), `pin` (`path`, `arguments`, `environment`, `renderer`), `note`. Plus `kind`, `renderer`, `knownIssues`, `lastVerified`, `blocked` and `flaky`. Highball's engine supports more steps (`winver`, `file`, `copy`, `dlloverride`…; `HB/Sources/HighballKit/Recipe.swift:8-54`), which these 7 recipes do not use.

**What the 7 use:** `sync` ×7, `installer` ×7, `pin` ×7, `environment` ×4, `registry` ×2 (Rockstar only), `winetricks` ×1 (GOG Galaxy only).

**Copy the catalog with judgment:** those recipes were tested with Highball's engines and patches. They are a starting point, not a guarantee for Bodega.

## 3. Status of each launcher according to `HBDB`

All of it is self-reported by Highball, not reproduced here.

| Launcher | Last verified | Status in the recipe | Engine | Program backend |
|---|---|---|---|---|
| Steam | 2026-08-24, Sikarugir's Wine 10 engine | Not blocked | Not pinned | `dxmt` |
| Rockstar | 2026-09-18, CX 26.3 r15 | Not blocked | CX 26.3 r15 or later | `dxvk` |
| EA app | 2026-10-05, CX 26.3 r15 | `flaky` | CX 26.3 r15 or later | `dxmt` |
| Battle.net | 2026-09-18, Wine 10 r5 engine | `flaky`; black on Wine 11 r8–r10 engines, according to a note | Wine 10 r5 | `dxmt` |
| Ubisoft | 2026-09-05, CX 26.3 r4 | `blocked` on Wine 10; works on Wine 11 r15+ with the cross-process fix | Not pinned | `d3dmetal` |
| Epic | 2026-08-25, Wine 10 engine | **`blocked`:** the installer audits ACLs that Wine does not store. Highball uses Legendary | Not pinned | `dxvk` |
| GOG Galaxy | No data | **`blocked`:** black login window or crash; the offline installers do work | Not pinned | `dxmt` |

**Conclusion:** of the 7, only **Rockstar, EA and Ubisoft** have Highball verification on an engine like ours (the CX 26.3 tree). The Steam recipe was verified on another engine, although other projects report Steam working on this tree (`gap-cx-tree-build-and-smoke.md`). A five-star list like CrossOver's does not hold up today, and Epic and GOG Galaxy cannot be promised.

## 4. What the runtime already has

Checked in `~/Library/Application Support/Bodega/runtimes/current`:

- **`0006` (per-exe arguments):** present in the 64-bit and 32-bit `kernelbase.dll`. It reads `HKCU\Software\Wine\AppDefaults\<exe>\CommandLineAppend` (`BE/patches/0006-*.patch:17,33-35`).
- **`0007` (cross-process Chromium windows):** present in `winemac.so` (strings `CALayerHost`/`CAContext`). It is the piece that avoids the black window in launchers (`BE/patches/0007-*.patch:1-12`).
- **`tools/`:** empty, no winetricks.

## 5. What the engine is missing

| Missing | Today | Why it is needed | Ref |
|---|---|---|---|
| **DXMT with `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN`** | The official DXMT v0.80 does not contain that variable (0 matches in `dxgi.dll`, `d3d11.dll` and `winemetal.so`) | `0007` only draws if DXMT accepts another process's swapchain. Without this, Steam, Rockstar, EA, Battle.net and Ubisoft can stay black with `dxmt` | `INFORME-FINAL.md` §7.2; `HBDB/recipes/launchers/battle-net.json`. Public tarball: `gauthierpiarrette/highball-engine`, release `dxmt-highball-20261017T231707Z-331c552` (18 MB, LGPL) |
| **Per-program msync** | `WINEMSYNC=1` hard-coded (`P/lib/engine.dart:75`) | Recipes with `sync none`; Steam turns msync off for its own window. One mode for the whole session: a process with a different one exits with 1 (pitfall 3) | `HBDB/recipes/launchers/steam.json` |
| **Server restart when switching modes** | Does not exist | If the bottle stays in msync after a game, the Steam window comes up empty | `steam.json`, `knownIssues` |
| **Per-program variables** | `settings.json` only stores the backend (`P/lib/backends.dart:227-245`) | `WINE_SIMULATE_WRITECOPY`, `DXMT_ALLOW_…` | Recipes |
| **Per-program arguments** | Not in the settings; patch `0006` does support them | Epic, GOG and Chromium-based launchers | §4 |
| **Registry** | Does not exist | Rockstar: `ServicesPipeTimeout` and `GlobalFlag`; Warframe: `dwrite` | `rockstar.json`, `recipes/games/warframe.json` |
| **Running an installer** | `_launchIn` launches a program, with game settings (`P/lib/engine.dart:227`) | Exit codes, MSI, waiting for and stopping leftovers | Below |
| **Downloading without a pinned SHA** | `_download` requires SHA-256 (`P/lib/backends.dart:193`) | 6 of the 7 installers do not pin a SHA (they are links that change) | Recipes |
| **Library** | Does not exist | Knowing what is installed and what to launch | For the app |

**How Highball installs** (`HB/…/Recipe.swift:567-600`):
1. Downloads the installer; verifies it if the recipe has a SHA.
2. MSI: `msiexec /i <archivo> /qn` + arguments; otherwise: `<archivo>` + arguments.
3. Always runs it with `wined3d`.
4. If the bottle was idle, kills the processes that remain, because Battle.net and Rockstar leave services running with the install environment, which later launch the client with the wrong configuration.

That last point matters: without it, the first "Jugar" ("Play") inherits the wrong environment (pitfall 4 of the prototype).

**Timing:** Steam downloads its client on first launch, and under WoW64 + Rosetta it takes 15–25 min and can look frozen (`steam.json`). The screen must warn about it.

## 6. Security

- **Without a pinned SHA, the installer cannot be verified.** The only safeguards are HTTPS and the official domain. Bodega does not validate the Authenticode signature.
- Recipes are executable data: a recipe decides what gets downloaded and run. If the catalog is updated over the network, it has to be signed.
- `winetricks` accepts wrong hashes in unattended mode (`INFORME-FINAL.md` §12.2). Only GOG Galaxy uses it, and it is blocked.

## 7. Constraints

- No data or images from CrossOver. Provenance in every recipe (`HBDB`, commit, CC0).
- Ratings are not made up.
- Logos: they are third-party trademarks. Personal use leaves some room, but it is better to take the icon from the `.exe` after installing.
- Highball's GPL code can be reused as long as this is for personal use. **If it is ever published, that code must be rewritten, or the source code published.**
- No AI attribution; commits and pushes only with the user's OK; minimalism.
- Agents cannot check windows or log in to stores: the user tests that.

## 8. Open questions for the proposal

1. **Catalog:** JSON bundled in the app (recommended to start) or downloaded from the network? Downloading requires signing.
2. **First list:** all 7, marking Epic and GOG Galaxy as not installable for now, or only the ones with a real chance?
3. **Status:** the three proposed levels (tested by you, reported, untested) plus "blocked"?
4. **Bottles:** one per application (recommended, it isolates failures) or a shared one?
5. **Patched DXMT:** replace the official one with Highball's fork (18 MB) or keep it as a separate backend? Without this, launchers will probably come up black.
6. **msync:** a per-bottle setting (recommended), or also per program, with a server restart like Highball?
7. **Epic and GOG:** add `legendary` and offline installers now or in another change? I would leave it for another one.
8. **Real test:** Steam with the user's account, in a new bottle (the first launch takes 15–25 min). It is the test that decides whether this works.
