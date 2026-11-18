part of 'engine.dart';

/// A Windows runtime that Bodega installs from its vendor's own installer
/// (D2). [name] is a product name, shown as it is.
typedef Dependency = ({
  String id,
  String name,

  /// Lowercase names of the DLLs that point to it in a program (D5).
  List<String> imports,

  /// Set to `native,builtin` for the whole bottle once it is installed (D6).
  List<String> dlls,

  /// The Windows version its installer must see, or null.
  String? windows,
  DependencyFile x86,
  DependencyFile x64,
});

/// One installer of a [Dependency]. [file] is its name in `downloads/`;
/// [marker] is under `drive_c`, with at most one `*` in one folder name, and
/// shows the runtime is installed when Microsoft's DLL is there (D3).
/// [wineManifests] are Wine's own manifests in `winsxs/manifests` of the
/// assemblies the installer brings at the same version: Wine's side-by-side
/// installer skips an assembly whose manifest exists (`dlls/sxs/cache.c`,
/// `install_assembly`), so they move aside during the run (D6).
typedef DependencyFile = ({
  String url,
  String sha256,
  int bytes,
  String file,
  List<String> args,
  String marker,
  List<String> wineManifests,
});

/// The runtimes Bodega installs (D2). The installers are Microsoft's own, from
/// Microsoft's servers, never stored in Bodega. The 2005–2013 pins are the ones
/// winetricks (LGPL-2.1-or-later) lists in `load_vcrun2005` to `load_vcrun2013`
/// at version 20260125-next; the 2015–2026 pins and their need of Windows 10
/// are highball-db's `recipes/tweaks/vcrun2022.json` at 7a008d5 (CC0). Facts,
/// not code: the sizes and the SHA-256 were checked against Microsoft's
/// servers on 2026-11-16.
const dependencies = <Dependency>[
  (
    id: 'vcrun2005',
    name: 'Visual C++ 2005',
    imports: ['msvcr80.dll', 'msvcp80.dll', 'mfc80.dll', 'mfc80u.dll'],
    dlls: ['atl80', 'msvcm80', 'msvcp80', 'msvcr80', 'vcomp'],
    windows: null,
    x86: (
      url: 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE',
      sha256:
          '8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd',
      bytes: 2710520,
      file: 'vcrun2005-x86.exe',
      args: ['/q'],
      marker: 'windows/winsxs/x86_microsoft.vc80.crt_1fc8b3b9a1e18e3b_8.0.50727.6195_*/msvcr80.dll',
      wineManifests: [],
    ),
    x64: (
      url: 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE',
      sha256:
          '4487570bd86e2e1aac29db2a1d0a91eb63361fcaac570808eb327cd4e0e2240d',
      bytes: 3179000,
      file: 'vcrun2005-x64.exe',
      args: ['/q'],
      marker: 'windows/winsxs/amd64_microsoft.vc80.crt_1fc8b3b9a1e18e3b_8.0.50727.6195_*/msvcr80.dll',
      wineManifests: [],
    ),
  ),
  (
    id: 'vcrun2008',
    name: 'Visual C++ 2008',
    imports: ['msvcr90.dll', 'msvcp90.dll', 'mfc90.dll', 'mfc90u.dll'],
    dlls: ['atl90', 'msvcm90', 'msvcp90', 'msvcr90', 'vcomp90'],
    windows: null,
    x86: (
      url: 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe',
      sha256:
          '8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92',
      bytes: 4483040,
      file: 'vcrun2008-x86.exe',
      args: ['/q'],
      marker: 'windows/winsxs/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*/msvcr90.dll',
      wineManifests: [
        'x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
        'x86_microsoft.vc90.atl_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
      ],
    ),
    x64: (
      url: 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe',
      sha256:
          'c5e273a4a16ab4d5471e91c7477719a2f45ddadb76c7f98a38fa5074a6838654',
      bytes: 5211080,
      file: 'vcrun2008-x64.exe',
      args: ['/q'],
      marker: 'windows/winsxs/amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*/msvcr90.dll',
      wineManifests: [
        'amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
        'amd64_microsoft.vc90.atl_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
      ],
    ),
  ),
  (
    id: 'vcrun2010',
    name: 'Visual C++ 2010',
    imports: ['msvcr100.dll', 'msvcp100.dll', 'mfc100.dll', 'mfc100u.dll'],
    dlls: ['atl100', 'msvcp100', 'msvcr100', 'vcomp100'],
    windows: null,
    x86: (
      url: 'https://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe',
      sha256:
          '31d32fa39d52cac9a765a43660431f7a127eee784b54b2f5e2af3e2b763a1af8',
      bytes: 5076456,
      file: 'vcrun2010-x86.exe',
      args: ['/q'],
      marker: 'windows/syswow64/msvcr100.dll',
      wineManifests: [],
    ),
    x64: (
      url: 'https://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe',
      sha256:
          '2fddbc3aaaab784c16bc673c3bae5f80929d5b372810dbc28649283566d33255',
      bytes: 5677032,
      file: 'vcrun2010-x64.exe',
      args: ['/q'],
      marker: 'windows/system32/msvcr100.dll',
      wineManifests: [],
    ),
  ),
  (
    id: 'vcrun2012',
    name: 'Visual C++ 2012',
    imports: ['msvcr110.dll', 'msvcp110.dll', 'mfc110.dll', 'mfc110u.dll'],
    dlls: ['atl110', 'msvcp110', 'msvcr110', 'vcomp110'],
    windows: null,
    x86: (
      url: 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe',
      sha256:
          'b924ad8062eaf4e70437c8be50fa612162795ff0839479546ce907ffa8d6e386',
      bytes: 6554576,
      file: 'vcrun2012-x86.exe',
      args: ['/q'],
      marker: 'windows/syswow64/msvcr110.dll',
      wineManifests: [],
    ),
    x64: (
      url: 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe',
      sha256:
          '681be3e5ba9fd3da02c09d7e565adfa078640ed66a0d58583efad2c1e3cc4064',
      bytes: 7186992,
      file: 'vcrun2012-x64.exe',
      args: ['/q'],
      marker: 'windows/system32/msvcr110.dll',
      wineManifests: [],
    ),
  ),
  (
    id: 'vcrun2013',
    name: 'Visual C++ 2013',
    imports: ['msvcr120.dll', 'msvcp120.dll', 'mfc120.dll', 'mfc120u.dll'],
    dlls: ['atl120', 'msvcp120', 'msvcr120', 'vcomp120'],
    windows: null,
    x86: (
      url: 'https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe',
      sha256:
          '89f4e593ea5541d1c53f983923124f9fd061a1c0c967339109e375c661573c17',
      bytes: 6510544,
      file: 'vcrun2013-x86.exe',
      args: ['/q'],
      marker: 'windows/syswow64/msvcr120.dll',
      wineManifests: [],
    ),
    x64: (
      url: 'https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe',
      sha256:
          '20e2645b7cd5873b1fa3462b99a665ac8d6e14aae83ded9d875fea35ffdd7d7e',
      bytes: 7201032,
      file: 'vcrun2013-x64.exe',
      args: ['/q'],
      marker: 'windows/system32/msvcr120.dll',
      wineManifests: [],
    ),
  ),
  (
    id: 'vcrun2022',
    name: 'Visual C++ 2015–2026',
    imports: [
      'vcruntime140.dll',
      'vcruntime140_1.dll',
      'msvcp140.dll',
      'msvcp140_1.dll',
      'msvcp140_2.dll',
      'concrt140.dll',
      'mfc140.dll',
      'mfc140u.dll',
    ],
    dlls: [
      'concrt140',
      'msvcp140',
      'msvcp140_1',
      'msvcp140_2',
      'msvcp140_atomic_wait',
      'msvcp140_codecvt_ids',
      'vcamp140',
      'vccorlib140',
      'vcomp140',
      'vcruntime140',
      'vcruntime140_1',
    ],
    // Its installers exit 1 when they see Windows 7 (highball-db's recipe).
    windows: 'win10',
    x86: (
      url: 'https://download.visualstudio.microsoft.com/download/pr/6ad63323-a427-4c58-8464-9f1f19f62359/F0BAB33A302B3CDB2E11113760D016F54FD3D2632C65BA7834FAC4F0ABD7F1A3/VC_redist.x86.exe',
      sha256:
          'f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3',
      bytes: 6941536,
      file: 'vcrun2022-x86.exe',
      args: ['/install', '/quiet', '/norestart'],
      marker: 'windows/syswow64/vcruntime140.dll',
      wineManifests: [],
    ),
    x64: (
      url: 'https://download.visualstudio.microsoft.com/download/pr/ebdab8e5-1d7b-4d9f-a11b-cbb1720c3b12/843068991DAAA1F73AD9F6239BCE4D0F6A07A51F18C37EA2A867E9BECA71295C/VC_redist.x64.exe',
      sha256:
          '843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c',
      bytes: 18731856,
      file: 'vcrun2022-x64.exe',
      args: ['/install', '/quiet', '/norestart'],
      marker: 'windows/system32/vcruntime140.dll',
      wineManifests: [],
    ),
  ),
];

/// Where the runtimes come from. A test replaces it; the app never does.
List<Dependency> dependencyTable = dependencies;

/// The architectures of a runtime: the program's bits decide (D5).
const dependencyArches = ['x86', 'x64'];

/// The row [id] of [dependencyTable], and its installer for [arch].
(Dependency, DependencyFile) _dependencyFile(String id, String arch) {
  final row =
      dependencyTable.where((row) => row.id == id).firstOrNull ??
      (throw BadChoice(ChoiceKind.dependency, '$id $arch'));
  return switch (arch) {
    'x86' => (row, row.x86),
    'x64' => (row, row.x64),
    _ => throw BadChoice(ChoiceKind.dependency, '$id $arch'),
  };
}

/// Whether Microsoft's runtime [id] for [arch] is in the bottle (D3), read
/// from the bottle itself: its marker is a regular file, reached without a
/// link, that starts as a PE does and carries none of the marks Wine writes in
/// its own DLLs. A runtime a game's own installer added counts too.
bool dependencyInstalled(String home, String bottle, String id, String arch) {
  final (_, file) = _dependencyFile(id, arch);
  final drive = '${_existing(home, bottle)}/prefix/drive_c';
  return _markerFiles(drive, file.marker).any(_isMicrosofts);
}

/// Where a UI puts the installer of [id] for [arch] before handing it to
/// [installDependency] (`downloads/<id>-<arch>.exe`, the cache `_download`
/// uses too), and what it must be.
({String url, String sha256, int bytes, String path}) dependencyDownload(
  String home,
  String id,
  String arch,
) {
  final (_, pin) = _dependencyFile(id, arch);
  return (
    url: pin.url,
    sha256: pin.sha256,
    bytes: pin.bytes,
    path: '$home/downloads/${pin.file}',
  );
}

/// Every runtime and arch of the table, with whether the bottle has it.
List<({String id, String arch, bool installed})> bottleDependencies(
  String home,
  String bottle,
) => [
  for (final row in dependencyTable)
    for (final arch in dependencyArches)
      (
        id: row.id,
        arch: arch,
        installed: dependencyInstalled(home, bottle, row.id, arch),
      ),
];

/// The files under [drive] that [marker] names: each part matched without case
/// among the real entries of the folder before it, a `*` standing for any run
/// of characters. No link is followed: `dosdevices/z:` is `/`.
List<String> _markerFiles(String drive, String marker) {
  final parts = marker.split('/');
  var found = [drive];
  for (final (i, part) in parts.indexed) {
    final last = i == parts.length - 1;
    found = [
      for (final dir in found)
        if (_isRealDirectory(dir))
          for (final entry in Directory(dir).listSync(followLinks: false))
            if (_nameMatches(entry.path.split('/').last, part) &&
                FileSystemEntity.typeSync(entry.path, followLinks: false) ==
                    (last
                        ? FileSystemEntityType.file
                        : FileSystemEntityType.directory))
              entry.path,
    ];
  }
  return found;
}

/// [name] against [pattern], without case, with at most one `*`.
bool _nameMatches(String name, String pattern) {
  final text = name.toLowerCase(), wanted = pattern.toLowerCase();
  final star = wanted.indexOf('*');
  if (star < 0) return text == wanted;
  final head = wanted.substring(0, star), tail = wanted.substring(star + 1);
  return text.length >= head.length + tail.length &&
      text.startsWith(head) &&
      text.endsWith(tail);
}

/// Whether [path] starts as a PE does and lacks Wine's marks in its first 128
/// bytes, where Wine writes them in its own DLLs.
bool _isMicrosofts(String path) {
  final file = File(path).openSync();
  try {
    final head = file.readSync(128);
    if (head.length < 64 || head[0] != 0x4D || head[1] != 0x5A) return false;
    final text = latin1.decode(head);
    return !text.contains('Wine builtin DLL') &&
        !text.contains('Wine placeholder DLL');
  } finally {
    file.closeSync();
  }
}

/// What a program shows of its needs (D4): its bits, the DLLs it imports or
/// delay-loads, the side-by-side assemblies its manifest names, and the DLLs
/// that sit beside it. Names are lowercase.
typedef ProgramScan = ({
  int bits,
  Set<String> imports,
  Set<String> assemblies,
  Set<String> besideIt,
});

/// D4: reads [path]'s headers, import tables and manifest, never the whole
/// file, in another isolate. Null if it is not a PE on x86. A table that leads
/// outside the file ends the reading there: what was read stands.
Future<ProgramScan?> scanProgram(String path) =>
    Isolate.run(() => _scanProgram(path));

ProgramScan? _scanProgram(String path) {
  if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) return null;
  final bits = _peBits(path);
  if (bits == null) return null;
  final file = File(path).openSync();
  final ({Set<String> imports, Set<String> assemblies}) found;
  try {
    found = _Pe(file, bits).read();
  } finally {
    file.closeSync();
  }
  // ponytail: only the DLLs' names; the DLLs beside an exe import runtimes
  // too, and reading them is the upgrade path.
  final folder = File(path).parent;
  return (
    bits: bits,
    imports: found.imports,
    assemblies: found.assemblies,
    besideIt: {
      for (final entry in folder.listSync(followLinks: false))
        if (entry.path.toLowerCase().endsWith('.dll') &&
            FileSystemEntity.typeSync(entry.path, followLinks: false) ==
                FileSystemEntityType.file)
          entry.path.split('/').last.toLowerCase(),
    },
  );
}

/// Reads one PE by positions: headers, the import and delay-import tables,
/// and the manifest resource.
class _Pe {
  _Pe(this.file, this.bits);

  final RandomAccessFile file;
  final int bits;
  late final int _length = file.lengthSync();
  final _sections = <({int va, int size, int raw})>[];
  int _imageBase = 0;
  List<({int rva, int size})> _directories = const [];

  /// [count] bytes at [offset], or null when the file ends before them.
  ByteData? _at(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > _length) return null;
    file.setPositionSync(offset);
    final bytes = file.readSync(count);
    return bytes.length == count ? ByteData.sublistView(bytes) : null;
  }

  int? _offset(int rva) {
    for (final s in _sections) {
      if (rva >= s.va && rva < s.va + s.size) {
        final offset = s.raw + rva - s.va;
        return offset < _length ? offset : null;
      }
    }
    return null;
  }

  /// The zero-ended text at [rva], at most 256 bytes.
  String? _name(int rva) {
    final offset = _offset(rva);
    if (offset == null) return null;
    file.setPositionSync(offset);
    final bytes = file.readSync(256);
    final end = bytes.indexOf(0);
    if (end <= 0) return null;
    return latin1.decode(bytes.sublist(0, end)).toLowerCase();
  }

  ({Set<String> imports, Set<String> assemblies}) read() {
    final imports = <String>{}, assemblies = <String>{};
    if (!_headers()) return (imports: imports, assemblies: assemblies);
    _table(1, 20, 12, imports, delay: false);
    _table(13, 32, 4, imports, delay: true);
    final manifest = _manifest();
    if (manifest != null) {
      for (final match in RegExp(
        r'''name\s*=\s*["'](microsoft\.vc[0-9]+\.(?:crt|mfc))["']''',
        caseSensitive: false,
      ).allMatches(manifest)) {
        assemblies.add(match[1]!.toLowerCase());
      }
    }
    return (imports: imports, assemblies: assemblies);
  }

  bool _headers() {
    final dos = _at(0, 64);
    if (dos == null) return false;
    final pe = dos.getUint32(60, Endian.little);
    final coff = _at(pe + 4, 20);
    if (coff == null) return false;
    final sections = coff.getUint16(2, Endian.little);
    final optionalSize = coff.getUint16(16, Endian.little);
    final optional = pe + 24;
    final header = _at(optional, optionalSize);
    if (header == null) return false;
    final wide = bits == 64;
    if (header.lengthInBytes < (wide ? 112 : 96)) return false;
    _imageBase = wide
        ? header.getUint64(24, Endian.little)
        : header.getUint32(28, Endian.little);
    final count = header.getUint32(wide ? 108 : 92, Endian.little);
    final first = wide ? 112 : 96;
    _directories = [
      for (var i = 0; i < count && first + 8 * i + 8 <= optionalSize; i++)
        (
          rva: header.getUint32(first + 8 * i, Endian.little),
          size: header.getUint32(first + 8 * i + 4, Endian.little),
        ),
    ];
    final table = _at(optional + optionalSize, 40 * sections);
    if (table == null) return false;
    for (var i = 0; i < sections; i++) {
      final virtualSize = table.getUint32(40 * i + 8, Endian.little);
      final rawSize = table.getUint32(40 * i + 16, Endian.little);
      _sections.add((
        va: table.getUint32(40 * i + 12, Endian.little),
        size: virtualSize > rawSize ? virtualSize : rawSize,
        raw: table.getUint32(40 * i + 20, Endian.little),
      ));
    }
    return true;
  }

  /// The DLL names of the table in data directory [index], whose entries are
  /// [size] bytes with the name's address at [nameAt]; it ends at an entry of
  /// zeros, or where the file does. A delay-load entry of the oldest kind
  /// (attributes 0) holds addresses rather than RVAs.
  void _table(
    int index,
    int size,
    int nameAt,
    Set<String> into, {
    required bool delay,
  }) {
    if (index >= _directories.length || _directories[index].rva == 0) return;
    var offset = _offset(_directories[index].rva);
    for (var i = 0; offset != null && i < 4096; i++, offset += size) {
      final entry = _at(offset, size);
      if (entry == null) return;
      if (Iterable<int>.generate(size, entry.getUint8).every((b) => b == 0)) {
        return;
      }
      var rva = entry.getUint32(nameAt, Endian.little);
      if (delay && entry.getUint32(0, Endian.little) & 1 == 0) {
        rva -= _imageBase;
      }
      if (_name(rva) case final name?) into.add(name);
    }
  }

  /// The text of the first RT_MANIFEST resource (type 24), at most 64 KiB.
  String? _manifest() {
    if (_directories.length < 3 || _directories[2].rva == 0) return null;
    final root = _offset(_directories[2].rva);
    if (root == null) return null;

    /// The offset of the entry with [id] (or the first, for null) in the
    /// resource directory at [dir], and whether it is a directory.
    (int, bool)? entry(int dir, int? id) {
      final head = _at(dir, 16);
      if (head == null) return null;
      final count =
          head.getUint16(12, Endian.little) + head.getUint16(14, Endian.little);
      for (var i = 0; i < count && i < 512; i++) {
        final item = _at(dir + 16 + 8 * i, 8);
        if (item == null) return null;
        final name = item.getUint32(0, Endian.little);
        if (id != null && name != id) continue;
        final to = item.getUint32(4, Endian.little);
        return (root + (to & 0x7fffffff), to & 0x80000000 != 0);
      }
      return null;
    }

    final type = entry(root, 24);
    if (type == null || !type.$2) return null;
    final name = entry(type.$1, null);
    if (name == null || !name.$2) return null;
    final language = entry(name.$1, null);
    if (language == null || language.$2) return null;
    final data = _at(language.$1, 8);
    if (data == null) return null;
    final at = _offset(data.getUint32(0, Endian.little));
    final size = data.getUint32(4, Endian.little);
    if (at == null) return null;
    final text = _at(at, size < 65536 ? size : 65536);
    return text == null
        ? null
        : latin1.decode(
            text.buffer.asUint8List(text.offsetInBytes, text.lengthInBytes),
          );
  }
}

/// How much Bodega wants a runtime for a program (D5).
enum Need { recommended, optional }

/// Why: a fix names it, Wine has no copy of a DLL the program imports, or the
/// program imports a DLL that Wine also provides.
enum NeedReason { knownFix, notInWine, imported }

/// One runtime a program needs. [dll] is the import that pointed to it, [fix]
/// the fix that named it; [installed] keeps a need that is met in the list.
typedef DependencyNeed = ({
  String id,
  String arch,
  Need need,
  NeedReason reason,
  String? dll,
  String? fix,
  bool installed,
});

/// Where a fix's settings step stands in the game's file (D9).
enum SettingState { applied, notApplied, noFile }

/// One setting a fix changes in the game's own file.
typedef SettingNeed = ({
  String fix,
  String section,
  String name,
  String value,
  SettingState state,
});

/// What Bodega proposes for one application of a bottle (D5).
typedef AppNeeds = ({
  String key,
  List<DependencyNeed> dependencies,
  List<SettingNeed> settings,
});

/// D5: worked out each time from the bottle, the program and the fixes, never
/// stored. Recommended: a runtime a fix names, or one whose MFC library the
/// program imports, which Wine lacks. Optional: one whose other DLLs it
/// imports, which Wine also provides. An import the game ships beside its exe
/// proposes nothing. Steam games open through steam.exe, so nothing is read
/// for them, and only their fixes' settings count. ponytail: a Steam fix that
/// names a runtime would need the game's own exe (the appmanifest's
/// `installdir`) for its arch; none does yet.
Future<AppNeeds> appNeeds(String home, String bottle, String key) async {
  final dir = _existing(home, bottle);
  final app =
      _appsIn(bottle, dir).where((app) => app.key == key).firstOrNull ??
      (throw AppNotFound(bottle, key));
  final fix = fixForApp(app.key);
  final needs = <String, DependencyNeed>{};
  void add(String id, String arch, Need need, NeedReason reason, String? dll) {
    final old = needs[id];
    if (old != null &&
        (old.need == Need.recommended || need == Need.optional)) {
      return;
    }
    needs[id] = (
      id: id,
      arch: arch,
      need: need,
      reason: reason,
      dll: dll,
      fix: reason == NeedReason.knownFix ? fix?.id : null,
      installed: dependencyInstalled(home, bottle, id, arch),
    );
  }

  if (!key.startsWith('steam:')) {
    final exe = app.exe.startsWith('/')
        ? app.exe
        : findCI('$dir/prefix/drive_c', app.exe);
    if (await scanProgram(exe) case final scan?) {
      final arch = scan.bits == 64 ? 'x64' : 'x86';
      for (final id in fix?.requires ?? const <String>[]) {
        add(id, arch, Need.recommended, NeedReason.knownFix, null);
      }
      for (final row in dependencyTable) {
        for (final dll in row.imports) {
          if (!scan.imports.contains(dll) || scan.besideIt.contains(dll)) {
            continue;
          }
          final mfc = dll.startsWith('mfc');
          add(
            row.id,
            arch,
            mfc ? Need.recommended : Need.optional,
            mfc ? NeedReason.notInWine : NeedReason.imported,
            dll,
          );
        }
      }
      for (final assembly in scan.assemblies) {
        final id = switch (RegExp(r'vc(\d+)').firstMatch(assembly)?[1]) {
          '80' => 'vcrun2005',
          '90' => 'vcrun2008',
          _ => null,
        };
        if (id == null || !dependencyTable.any((row) => row.id == id)) continue;
        final mfc = assembly.endsWith('.mfc');
        add(
          id,
          arch,
          mfc ? Need.recommended : Need.optional,
          mfc ? NeedReason.notInWine : NeedReason.imported,
          assembly,
        );
      }
    }
  }
  final order = [for (final row in dependencyTable) row.id];
  return (
    key: app.key,
    dependencies: needs.values.toList()
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id))),
    settings: [
      if (fix != null)
        for (final step in fix.steps)
          if (step.type == 'ini' && step.applies)
            (
              fix: fix.id,
              section: step.section!,
              name: step.name!,
              value: step.data!,
              state: fixStepState(home, bottle, step),
            ),
    ],
  );
}

/// D6: installs runtime [id] for [arch] in the bottle from its installer:
/// [file], or else the download into `downloads/`, which a matching file
/// already there saves. Either must match the pinned SHA-256. Refused while
/// the bottle runs: an installer replaces DLLs that a game may hold, and the
/// overrides reach only processes that start afterwards. Wine's own manifests
/// that would make the installer skip its assemblies wait outside the prefix
/// during the run, and go back if anything fails. The overrides are written
/// after a good run only, "installed" is read from the bottle after it, and it
/// returns once Wine's server is gone, so that a queue's next item does not
/// find the bottle open. Returns the installer's log.
Future<String> installDependency(
  String home,
  String bottle,
  String id,
  String arch, {
  String? file,
}) async {
  final (row, pin) = _dependencyFile(id, arch);
  final dir = _existing(home, bottle);
  if (!_ready('$dir/prefix')) throw BottleNotReady(bottle);
  if (await _serverRunning(home, dir)) throw BottleOpen(bottle);
  final installer =
      file ?? await _download(home, pin.url, pin.sha256, name: pin.file);
  if (FileSystemEntity.typeSync(installer) != FileSystemEntityType.file) {
    throw MissingFile(installer);
  }
  if (await sha256Of(installer) != pin.sha256) {
    throw ChecksumMismatch(installer);
  }
  if (row.windows case final version?) {
    await _reg(home, bottle, [
      'add',
      'HKCU\\Software\\Wine\\AppDefaults\\${installer.split('/').last}',
      '/v',
      'Version',
      '/t',
      'REG_SZ',
      '/d',
      version,
      '/f',
    ]);
  }
  final manifests = '$dir/prefix/drive_c/windows/winsxs/manifests';
  final aside = Directory('$dir/wine-manifests');
  final moved = <String>[
    for (final pattern in pin.wineManifests)
      for (final path in _markerFiles(
        '$dir/prefix/drive_c',
        'windows/winsxs/manifests/$pattern',
      ))
        path.split('/').last,
  ];
  if (moved.isNotEmpty) aside.createSync(recursive: true);
  for (final name in moved) {
    File('$manifests/$name').renameSync('${aside.path}/$name');
  }
  var installed = false;
  try {
    final log = await _launchIn(
      home,
      bottle,
      installer,
      pin.args,
      backend: 'wine',
      label: '$id-$arch',
    );
    final code = await exitOf(log).timeout(
      const Duration(minutes: 10),
      onTimeout: () async {
        await stopBottle(home, bottle);
        return -1;
      },
    );
    await waitBottle(home, bottle);
    if (!_installerOk.contains(code)) {
      throw WineToolFailed(WineTool.installer, code, log);
    }
    for (final dll in row.dlls) {
      await _reg(home, bottle, [
        'add',
        r'HKCU\Software\Wine\DllOverrides',
        '/v',
        dll,
        '/t',
        'REG_SZ',
        '/d',
        'native,builtin',
        '/f',
      ]);
    }
    if (!dependencyInstalled(home, bottle, id, arch)) {
      throw DependencyNotInstalled(id, arch, log);
    }
    installed = true;
    return log;
  } finally {
    // Back where they were, unless the installer wrote one of the same name;
    // after a good install, Microsoft's stand in their place.
    for (final name in moved) {
      final saved = File('${aside.path}/$name');
      if (!installed && !File('$manifests/$name').existsSync()) {
        saved.renameSync('$manifests/$name');
      } else {
        saved.deleteSync();
      }
    }
    if (aside.existsSync() && aside.listSync().isEmpty) aside.deleteSync();
    await waitBottle(home, bottle);
  }
}

/// `reg` with [args] in the bottle, headless; a failure throws (F3).
Future<void> _reg(String home, String bottle, List<String> args) async {
  final log = await _launchIn(home, bottle, 'reg', args, backend: 'wine');
  final code = await exitOf(log);
  if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
}

/// The size of [bytes] as the CLI prints it: megabytes with one decimal.
String megabytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(1)} MB';

/// `bodega deps <args>` (D11): the work of the verb [args] names, which writes
/// its output to [out] and gives the exit code, or null for a bad usage, which
/// the CLI answers with its usage before it touches anything.
Future<int> Function(String home)? depsVerb(
  List<String> args,
  StringSink out,
) => switch (args) {
  ['list', final bottle] => (home) async {
    for (final line in bottleDependencies(home, bottle)) {
      final (row, pin) = _dependencyFile(line.id, line.arch);
      out.writeln(
        line.installed
            ? '${row.id} ${line.arch} installed'
            : '${row.id} ${line.arch} not installed ${megabytes(pin.bytes)}',
      );
    }
    return 0;
  },
  ['check', final bottle, final key] => (home) async {
    final needs = await appNeeds(home, bottle, key);
    needs.dependencies.map(needLine).forEach(out.writeln);
    needs.settings.map(settingLine).forEach(out.writeln);
    if (needs.dependencies.isEmpty && needs.settings.isEmpty) {
      out.writeln('nothing to propose');
    }
    return 0;
  },
  ['install', final bottle, final id, final arch, ...final rest]
      when dependencyArches.contains(arch) && rest.length < 2 =>
    (home) async {
      out.writeln(
        'log: ${await installDependency(home, bottle, id, arch, file: rest.firstOrNull)}',
      );
      return 0;
    },
  _ => null,
};

/// One line of `deps check` for [need].
String needLine(DependencyNeed need) {
  final why = switch (need.reason) {
    NeedReason.knownFix => 'fix ${need.fix}',
    NeedReason.notInWine => 'imports ${need.dll}, which Wine lacks',
    NeedReason.imported => 'imports ${need.dll}',
  };
  return '${need.need.name} ${need.id} ${need.arch} ($why)'
      '${need.installed ? ' installed' : ''}';
}

/// One line of `deps check` for [setting].
String settingLine(SettingNeed setting) =>
    'setting [${setting.section}] ${setting.name}=${setting.value} '
    '${switch (setting.state) {
      SettingState.applied => 'applied',
      SettingState.notApplied => 'not applied',
      SettingState.noFile => 'no file yet: open the game once',
    }} (fix ${setting.fix})';
