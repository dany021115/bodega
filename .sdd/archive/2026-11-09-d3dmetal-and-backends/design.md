# Design · d3dmetal-and-backends

## 1. The user accepts the license in Apple's window
`hdiutil attach` in the terminal stops and asks for the license; answering "Y" would be accepting
it on the user's behalf. Better `open <Evaluation environment….dmg>`: macOS opens its own license
window (DiskImageMounter), the user accepts it and the volume appears in `/Volumes`.
Bodega only waits for that volume. Zero code to read or show licenses.

## 2. One bloc for the exes' graphics
`GraphicsBloc` (one for the whole app) holds `Map<exe, ExeGraphics>`. The screens that
draw apps ask it to `load(exes)`; what it already has is not read again. `ExeGraphics` carries
the label and the notices already computed for each installed backend
(`misfits: {backend: aviso}`): the dropdowns only look up the map, without waiting.
That way `LibraryBloc` and `BottleDetailBloc` stay untouched, and reading large exes does not delay the list.

## 3. Rules per platform
`Platform.backendFits(backend, exe) → bool` and `backendUse(backend)`. Mac has the G3 table;
Linux always says yes. The app builds the notice texts, since it knows the title. They are pure rules (they do not look at the real OS), so the tests with a simulated Mac
on Linux still hold.

## 4. Reading the exe without blocking
The current read (decode as latin1 and strip NULs) moves to `exeGraphics` and runs in
`Isolate.run`. The cache is the `GraphicsBloc` map (§2): a date-based cache in the engine
failed with exes rewritten within the same millisecond. `autoBackend` reuses that read.

## 5. Waiting for the download
A 3 s `Timer.periodic` in the Backends bloc, only while the card is
"waiting". macOS will ask once for permission to access Downloads: that needs
`NSDownloadsFolderUsageDescription` in the `Info.plist`.
