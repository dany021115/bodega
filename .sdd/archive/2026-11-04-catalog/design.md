# Design: catalog

Only what is not obvious. `HB` = `gauthierpiarrette/highball`; `HBDB` = `gauthierpiarrette/highball-db` at commit `f0bf6a2`.

## 1. A flat entry, not steps

Highball interprets a list of steps because its recipes also cover games and settings (`HB/Sources/HighballKit/Recipe.swift:8-54`). The 7 in this change only need the registry, the installer and the executable, always in that order. A flat entry avoids the interpreter and is what the screen wants to read. If game recipes come in later, the interpreter can be added then.

`winetricks` is dropped: only GOG Galaxy uses it, and that entry is `blocked`. Also, `pin.renderer` becomes the entry's `backend`.

## 2. `installEntry` takes the entry

`bodega catalog install` looks up the `id` and calls `installEntry(home, entry, …)`. The tests pass their own entries with `file://` URLs, with no extra parameters and without touching the real data.

The I6 timings are parameters with default values, so that a test does not wait 60 s.

## 3. Waiting after the installer

`wineserver -w` returns when the last client goes away, but Battle.net and Rockstar leave processes alive, so `-w` would never return. Stopping right when the installer exits does not work either: a bootstrapper can exit while the work is still running in a child process. Hence:

```
done = wineserver -w (not awaited)
repeat every 2 s until: done finished | (exe exists and the grace period passed) | the maximum passed
wineserver -k
```

It is the same idea as Highball's `installerGrace = 60` (`HB/…/Recipe.swift:510,605-611`), without its process table: since the bottle is new, everything running in it belongs to the installer. The pending `-w` returns once `-k` shuts the server down.

// ponytail: the grace clock starts when the installer exits, not when the exe appears. Good enough for these 7.

## 4. Per-bottle msync

Measured in this test: with a server without msync, a client with `WINEMSYNC=1` exits with 1. Also checked: `wineserver -w` with `WINEMSYNC=1` works against a server without msync, so `_wineserver` needs no changes.

The Steam recipe leaves the bottle in msync and only turns msync off for the Steam window, restarting the server when it opens (`HBDB/recipes/launchers/steam.json`). That requires knowing which mode the server is in and restarting it automatically. Per bottle is much simpler, but it carries the cost of decision 6: games opened from that bottle run without msync. If U3 confirms it as a real problem, per-program msync is the next step.

## 5. Download

`_download` (`P/lib/backends.dart:193`) gains the HTTPS flags and the `.part` file. `file` stays allowed only for the initial URL: `--proto-redir =https` stops a redirect from reaching another protocol. `catalog data` checks that no real entry uses `file://`.

Without `sha256` there is no cache: an old installer might not work, and the file is small (its downloaders fetch the rest).

## 6. Checked before writing this

In a temporary bottle, since deleted, with the real runtime:

| Test | Result |
|---|---|
| DXMT fork: contains `DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN` | Yes, 2 matches; the official one, 0 |
| `backend test t dxmt` with the fork | `OK` in 64 and 32 bits |
| Probe with the fork, `WINEMSYNC=0` and the variable | `OK` in 64 and 32 bits, "Apple M2 Pro", level 11_0 |
| Server without msync + client with `WINEMSYNC=1` | Exit 1 |
| `Blur.exe`: `d3d9` / `d3d10` / `dxgi.dll` / `d3d11.dll` / `d3d12.dll` | 12 / 1 / 1 / 0 / 0 lines: `auto` sent it to DXMT |

**Not checked:** the probe opens no windows, so this does not show that a launcher renders correctly. The Steam installer never got to run: auto mode blocked downloading and running it, so it is left for U3.
