# Engine

Everything in `packages/engine`, with tests that use the existing fake Wine. A bottle path never follows links: `dosdevices/z:` points to `/`.

## Milestone 1

### M1 · `apps.json` without losing data
`bottles/<b>/apps.json` stores `{"apps": [{id, title, exe, args, installedAt}], "hidden": [key]}`.

- Without `apps.json`, an existing `app.json` counts as the only application.
- The first write creates `apps.json` and only then deletes `app.json`.
- Atomic write, like all of the engine's JSON. A broken file gives an error; it is not ignored.

**Scenarios (test `apps.json`):** an old bottle lists its application; after adding another one, both remain and `app.json` disappears; broken, an error with the path.

### M2 · Application key
Each application has a `key`: the exe path relative to `drive_c`, in lowercase and with `/`, or the absolute path if it is outside, or `steam:<appid>`.

**Scenario (test `appKey`):** `C:\Program Files\X\A.EXE` and `Program Files/X/a.exe` give the same key.

### M3 · Reading `.lnk`
`readLnk(path)` returns `{target, args, workingDir}` or `null`, never an error. It supports a local path in `LinkInfo` and ANSI or Unicode strings.

**Scenarios (test `readLnk`):** bytes with the real shape of `Steam.lnk`; with arguments; truncated or without a header, `null`.

### M4 · Detection
`bottleApps(home, bottle)` returns the registered ones first and then the ones detected in `users/*/Desktop`, `users/*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs` and `ProgramData/Microsoft/Windows/Start Menu/Programs`, in alphabetical order.

- Title: the name of the `.lnk` without its extension.
- Only `.exe` targets that exist inside `drive_c`.
- Left out: those in `hidden`, and `unins*.exe` and `uninstall*.exe`.
- No duplicates by key. The registered one wins.

**Scenarios (test `bottleApps`):** three `.lnk` files pointing to the same exe give one; one pointing to the registered exe does not duplicate it; an uninstaller and one pointing to a URL don't show up; a `z:` in the tree is not walked.

### M5 · Steam games
If `Program Files (x86)/Steam/steam.exe` exists, each `steamapps/appmanifest_*.acf` with bit 4 set in `StateFlags` gives an application:

- `key` equal to `steam:<appid>`, `title` equal to `name`, `exe` Steam's own, and `args` `-applaunch <appid>`.
- Left out: `228980`, Steamworks Common Redistributables.

**Scenarios (test `steam games`):** Muck shows up and the redistributables don't; a half-finished install doesn't show up; without Steam, none.

### M6 · Open and register
- `openApp(home, bottle, {key, backend, hud})`: without `key`, it opens the first registered one, or the first one if there are no registered ones.
- `addApp` allows several, and rejects the same exe by key.
- `hideApp(home, bottle, key)`: a registered one is removed; a detected one goes to `hidden`.
- `listBottles` gives `apps` instead of `app`. `installedApps` gives those of all bottles, and is still the basis of `bodega apps`.
- `bodega open <bottle> [key]`.

**Scenarios (tests `addApp`, `openApp`, `hideApp`):** two applications open their own program; `open steam` without a key opens Steam; the same exe twice, an error; once hidden, it is not listed again; the CLI on `steam` gives the same as before.

### M7 · Icons
`appIcon(home, app)` returns the path of an image or `null`, never an error.

- **With an exe:** extracts the largest icon from `.rsrc` to `bottles/<b>/icons/<key hash>.ico`. If the `.ico` is newer than the exe, it doesn't read the exe again.
- **Steam games:** `appcache/librarycache/<appid>/` with its 40-character `<hash>.jpg`, or `logo.png`.

**Scenarios (test `appIcon`):** PNG and DIB from a PE built in the test; without `.rsrc`, `null`; not a PE, `null`; the second time it uses the cache.

## Milestone 2

### M8 · Bottle settings
`settings.json` gains `highRes` (false), `dlss` (false), `avx` (true), `windows` (`win10`) and `env` (empty). Without them, the default values apply.

- `avx` false **removes** `ROSETTA_ADVERTISE_AVX` from the environment.
- `dlss` adds `D3DM_ENABLE_METALFX=1` and `DXMT_ENABLE_NVEXT=1`.
- Environment order: backend, bottle, program, and whatever that launch adds.

**Scenarios (test `settings`):** a bottle without these fields gets the defaults; the environment changes as described, checked in the fake Wine's log.

### M9 · High resolution
`setHighRes(home, bottle, value)` stops the bottle if the value changes, and with `reg add` writes `HKCU\Software\Wine\Mac Driver\RetinaMode` (`y` or `n`) and `HKCU\Control Panel\Desktop\LogPixels` (192 or 96). It returns whether it stopped the bottle, like `setSync`.

**Scenario (test `setHighRes`):** with the fake Wine, the two commands and the saved setting; repeating the value stops nothing.

### M10 · Windows version
`setWindowsVersion(home, bottle, version)` runs `winecfg -v <version>` and saves it. It accepts `win11`, `win10`, `win81` and `win7`; anything else, an error.

**Scenario (test `setWindowsVersion`):** the command with the fake Wine; `foo`, an error without changing anything. **Real, headless:** `winecfg -v` answers with what was set.

### M11 · Launch with options
`runInBottle` and `openApp` gain `env` and `avx`. `addApp` gains `args` and `env`, the latter stored in the exe's `programs` entry.

**Scenario (test `runInBottle`):** `env` reaches the program; `avx: false` removes the variable only for that launch.

### M12 · Install into an existing bottle
`installEntry(…, bottle: b, intoExisting: true)` does not create a bottle or change its backend or its sync: it adds the program's exception, the registry entries and the application. Without `intoExisting`, it still rejects a bottle that exists. If the entry asks for a different sync, it returns the warning through `onStep`.

**Scenarios (test `installEntry`):** two entries in one bottle, both remain; the bottle's sync doesn't change; a bottle that isn't set up, an error.

## Milestone 3

### M13 · Duplicate and rename
- `duplicateBottle(home, source, destination)`: stops the source and runs `cp -cR`. A destination that exists or has an invalid name, an error without touching anything.
- `renameBottle(home, source, destination)`: stops the bottle and renames it.

**Scenarios (test `duplicateBottle`, `renameBottle`):** links are still links and `z:` points where it pointed before; the copy is independent. **Real, headless:** a program runs in the copy and in the renamed bottle.

### M14 · Export and import
- `exportBottle(home, bottle, file)`: stops the bottle and creates a `.tar.gz` with `tar`, without `logs` or `icons`.
- `importBottle(home, file)`: lists the contents before extracting; requires a single root folder with `prefix/`, with no absolute paths or `..`; extracts to `bottles/.tmp-import`; and renames it. If the name already exists, it appends `-2`. It returns the name. A failure leaves nothing behind.
- `listBottles` ignores anything that starts with a dot.

**Scenarios (test `exportBottle`, `importBottle`):** a round trip that keeps `z:`; an archive with two roots or with `..`, an error and nothing left behind; a repeated name, `-2`.

### M15 · Installer cache
`downloadsSize(home)` and `clearDownloads(home)`, which deletes what is in `downloads/` without following links.

**Scenario (test `downloads`):** the size, and emptying it.
