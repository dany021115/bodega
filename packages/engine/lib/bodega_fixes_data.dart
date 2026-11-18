/// Bodega's own per-game fixes (F1, D7), written by hand, beside the ones
/// generated from highball-db (`fixes_data.dart`, which is never edited by
/// hand). Same shape, plus `exes` (lowercase exe file names that match a game
/// added by hand), `requires` (runtimes of `dependencies.dart`) and the `ini`
/// step. Each entry says how and when it was verified. Text in the app, not a
/// file, because `dart compile exe` carries no assets. Nothing here comes from
/// CrossOver's data.
const bodegaFixesJson = r'''
[
 {
  "id": "blur",
  "title": "Blur",
  "steam": null,
  "exes": ["blur.exe"],
  "optIn": false,
  "requires": ["vcrun2008"],
  "steps": [],
  "notes": [
   "Blur crashes now and then in Wine's msvcr90.dll: sin and cos get a huge argument while Direct3D 9 holds the x87 unit at single precision. Microsoft's Visual C++ 2008 runtime does not crash there."
  ],
  "knownIssues": [],
  "verified": {
   "date": "2026-11-12",
   "chip": "Apple Silicon",
   "macos": "27",
   "result": "73 minutes without a crash, with Microsoft's msvcr90.dll in place of Wine's"
  },
  "source": "bodega"
 },
 {
  "id": "need-for-speed-most-wanted-2012",
  "title": "Need for Speed: Most Wanted (2012)",
  "steam": null,
  "exes": ["nfs13.exe"],
  "optIn": false,
  "requires": [],
  "steps": [
   {
    "type": "ini",
    "file": "%USERPROFILE%\\Documents\\Criterion Games\\Need For Speed(TM) Most Wanted\\config.NFS13Save",
    "section": "Sound",
    "name": "Reverb",
    "data": "0",
    "platforms": ["mac"]
   }
  ],
  "notes": [
   "The game's audio engine is x87 code, which Rosetta runs slowly: with reverb on, its sound thread keeps a core busy and the sound stutters. The file exists once the game has run once."
  ],
  "knownIssues": [],
  "verified": {
   "date": "2026-11-16",
   "chip": "Apple Silicon",
   "macos": "27",
   "result": "95 late DirectSound writes in 71 s with reverb, 6 in 190 s without it; the stutter is gone"
  },
  "source": "bodega"
 }
]
''';
