# Design: flutter-app

Only what is not obvious. `TS` = TeeShot.

## 1. The engine as the data source

Only `data/` imports `package:engine`. `data/repository/*_impl.dart` turns engine types into `domain/` entities and catches what the engine throws, which is `String` and `FormatException`, to return `Left(EngineError)`. The engine knows nothing about Flutter and the CLI keeps working. `data/service/engine_home.dart` keeps the result of `bodegaHome(Platform.environment)` as a singleton.

**Repositories:** `Runtime`, `Catalog`, `Install`, `Library`, `Bottle`, `Backend` and `AntiCheat`.

## 2. `AppError` in `domain`

In TeeShot, `AppError` lives in `data/api/catch_error.dart` and `domain/repository` imports it (`TS/.claude/skills/create-feature`), which contradicts its layer rule. Here it goes in `domain/entities/app_error.dart`. It is the only deliberate deviation from its structure, along with having no Phoenix, no auth and nothing from the mobile product.

## 3. Modern Freezed

TeeShot writes `@freezed class X with _$X`. With `freezed` 4 it is `abstract class` for states and entities, and `sealed class` for events. The rest of the pattern does not change: a single state with `@Default` and `copyWith`, and `part` for event and state (tested in §7).

## 4. Downloads with `dio`

**Change made during `apply`:** `dio.download` was the plan, but the status and the final URL have to be seen before writing anything, so `Downloader` reads the stream by hand. It asks for uncompressed bytes because, with gzip, `Content-Length` and `Range` count something else: against real HTTPS, a good download failed with "se cortó en 251114 de 30766 bytes" ("cut off at 251114 of 30766 bytes").

```
Downloader.fetch(url, dest, cancel, onProgress)
  dio.get as a stream, with Accept-Encoding: identity, and Range if there is a .part → <dest>.part → rename
→ installEntry(setup: path) or installBackend(tarball: path)
```

- **The engine keeps using `curl`** for the CLI, and checks the SHA on both paths.
- **HTTPS only:** `dio` follows redirects on its own. The code checks `response.realUri.scheme == 'https'` and that the catalog URL starts with `https://`.
- **If the server ignores `Range`:** it answers 200 instead of 206, and the download has to start from scratch.
- **Anti-cheat list:** `raw.githubusercontent.com` serves `text/plain`, so `retrofit` requests it with `ResponseType.plain` and it is decoded separately (tested in §7).

## 5. Open or closed

`waitBottle` (`wineserver -w`) ends when the last process goes away, and returns at once if there is no server (measured: 0.03–0.04 s). With that, per bottle:

```
final wait = waitBottle(...);
open = (Future.any([wait, delay(1 s)]) did not end because of wait)
wait.then(closed)
```

This solves Steam's `exit=42`: what matters is the bottle, not the first process. A server stays alive for 3 s after the last process (measured: 3,104 ms), so "Cerrada" ("Closed") takes that long to appear. One `wineserver -w` per open bottle is a small process.

// ponytail: changes made outside the app (for example, opening with the CLI) are not watched. The state is rebuilt at startup and when going back to Library.

## 6. The interface does not own the programs

Programs run detached: closing Bodega does not close them, and opening it again rebuilds the state from `listBottles` and `waitBottle`. If it is closed during an install, the installer keeps going, but a bottle without `app.json` is left behind; it shows up with no application and can be deleted from its detail view. `Incompleta` ("Incomplete") is kept for an unfinished prefix (`ready` false, E2).

Synchronous reads in the interface: `antiCheatHints` reads a log of about 600 KB every 5 s at most, as long as it is newer than the opening time (measured with 614 KB: median 3.8 ms and maximum 12.5 ms, under one frame). If it were noticeable in U, it moves to `Isolate.run`. That is not done before measuring.

## 7. Checked before writing this

In a temporary workspace, since deleted, with this Mac's real runtime (M2 Pro, macOS 27.0.1, Flutter 3.47.0, Dart 3.13.0):

| Test | Result |
|---|---|
| `flutter pub add` with the whole stack | Resolves: `freezed` 4.0.1, `build_runner` 2.16.1, `injectable` 3.0.0, `go_router` 18.1.2, `retrofit` 4.10.0, `retrofit_generator` 10.3.3, `dio` 5.11.1 |
| `dart run build_runner build` in `apps/bodega` | OK, 24 s: freezed, json, retrofit and injectable |
| Engine inside the workspace | Its tests and `dart compile exe` work |
| `flutter build macos --debug` without the sandbox | OK, 40 s; 115 MB in debug |
| App opened with `open` (as from Finder) | `HOME`, `USER`, `LOGNAME`, `TMPDIR` and `__CF_USER_TEXT_ENCODING` present |
| From the app: `runInBottle` with `cmd /c set` | `exit=0`, `WINEMSYNC=1`, `CX_ACTIVE_GRAPHICS_BACKEND=wined3d` |
| From the app: bloc + freezed + injectable | OK |
| From the app: `retrofit` + JSON | 1,166 games, parsed |
| From the app: `Dio.download` | OK |
| From the app: `installedApps`, `listBackends`, `catalogEntries` | `steam`; the 4 backends; 7 entries |
| `wineserver -w` with no server | 0.03–0.04 s |

**Not checked:** how any of this looks. The test app did not draw any screen.
