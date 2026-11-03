part of 'engine.dart';

/// Every backend, in the order a UI should offer them. `wine` is wined3d plus
/// vkd3d and needs no layer.
const backendNames = ['wine', 'dxmt', 'dxvk', 'd3dmetal'];

/// Pinned downloads (B1). D3DMetal is never here: the user imports it (B2).
/// `dxmt` is Highball's fork, because launchers need its cross-process
/// swapchain and the official v0.80 does not have it (A3).
const _pinned = {
  'dxmt': (
    url:
        'https://github.com/gauthierpiarrette/highball-engine/releases/download/'
        'dxmt-highball-20261017T231707Z-331c552/'
        'dxmt-highball-20261017T231707Z-331c552.tar.gz',
    sha256: '89e731b81cc1ef741accb2e707159f121ed822a083f14f16da445cd8dbbf4703',
  ),
  'dxvk': (
    url:
        'https://github.com/Gcenx/DXVK-macOS/releases/download/'
        'v1.10.3-20230507-repack/'
        'dxvk-macOS-async-v1.10.3-20230507-repack-builtin.tar.gz',
    sha256: '810b1e5caf8ce975b784fae866a130ad23fa0ea233b0e5609cbc4a45f3ef6f00',
  ),
};

const _crossProcess = {'DXMT_ALLOW_CROSS_PROCESS_SWAPCHAIN': '1'};

String _layer(String home, String name) => '$home/backends/$name/wine';

bool _installed(String home, String name) =>
    name == 'wine' || Directory(_layer(home, name)).existsSync();

/// Which backends are installed (B3).
Map<String, bool> listBackends(String home) => {
  for (final name in backendNames) name: _installed(home, name),
};

/// What [wineEnv] gains for [backend] (S4): one layer in front of Wine's own
/// DLLs per process, with nothing copied into the prefix (design §1).
Map<String, String> backendEnv(
  String home,
  String backend, {
  bool hud = false,
}) => {
  'CX_ACTIVE_GRAPHICS_BACKEND': backend == 'wine' ? 'wined3d' : backend,
  ...switch (backend) {
    'dxmt' => {'WINEDLLPATH_PREPEND': _layer(home, 'dxmt'), ..._crossProcess},
    'dxvk' => {
      'WINEDLLPATH_PREPEND': _layer(home, 'dxvk'),
      'WINEDLLOVERRIDES': '$_overrides;d3d10core,d3d11=n,b',
    },
    'd3dmetal' => {
      // D3DMetal is 64-bit only: DXMT behind it serves 32-bit D3D10/11.
      'WINEDLLPATH_PREPEND': [
        _layer(home, 'd3dmetal'),
        if (_installed(home, 'dxmt')) _layer(home, 'dxmt'),
      ].join(':'),
      'CX_APPLEGPTK_LIBD3DSHARED_PATH':
          '$home/backends/d3dmetal/external/libd3dshared.dylib',
      if (_installed(home, 'dxmt')) ..._crossProcess,
    },
    _ => const <String, String>{},
  },
  if (hud) 'MTL_HUD_ENABLED': '1',
};

/// Downloads or takes [tarball], checks its pinned SHA-256 and installs the
/// layer as `backends/<name>/wine` (B1). Returns its folder.
Future<String> installBackend(
  String home,
  String name, {
  String? tarball,
  String? url,
  String? sha256,
}) async {
  if (name == 'd3dmetal') {
    throw 'd3dmetal no se descarga: bodega backend import d3dmetal <carpeta>';
  }
  final pin = _pinned[name];
  if (pin == null) throw 'backend sin instalador: $name';
  final dest = _backendSlot(home, name);
  final want = sha256 ?? pin.sha256;
  final file = tarball ?? await _download(home, url ?? pin.url, want);
  final got = await _sha256(file);
  if (got != want) {
    throw 'checksum incorrecto en $file: $got, se esperaba $want';
  }
  return _intoSlot(home, name, dest, (tmp) async {
    await _run('/usr/bin/tar', ['-xzf', file, '-C', tmp.path]);
    final root = tmp
        .listSync()
        .whereType<Directory>()
        .where((dir) => Directory('${dir.path}/x86_64-windows').existsSync())
        .firstOrNull;
    if (root == null ||
        !File('${root.path}/x86_64-windows/d3d11.dll').existsSync()) {
      throw 'tarball sin x86_64-windows/d3d11.dll: $file';
    }
    root.renameSync('${tmp.path}/wine');
  });
}

/// Copies D3DMetal from a folder the user provides (B2). Its unix modules are
/// all one library: each must stay a symlink to it, because separate copies
/// load as separate images and crash on device creation (design §2).
/// Returns its folder.
Future<String> importD3DMetal(String home, String folder) async {
  final real = Directory(folder).resolveSymbolicLinksSync();
  // ponytail: a guard against an easy mistake, not security; a manual copy of
  // the files gets past it (design §6).
  if ('$real/'.contains('/CrossOver.app/')) {
    throw 'no se importa desde CrossOver.app: usa tu propia copia de D3DMetal';
  }
  final src = Directory('$real/wine').existsSync() ? real : '$real/lib';
  const pe = 'wine/x86_64-windows', unix = 'wine/x86_64-unix';
  const lib = 'external/libd3dshared.dylib';
  const framework = 'external/D3DMetal.framework';
  final required = [
    for (final module in ['d3d11', 'd3d12', 'dxgi']) ...[
      '$pe/$module.dll',
      '$unix/$module.so',
    ],
    lib,
  ];
  for (final file in required) {
    if (!File('$src/$file').existsSync()) throw 'falta $file en $src';
  }
  if (!Directory('$src/$framework').existsSync()) {
    throw 'falta $framework en $src';
  }
  const modules = ['d3d11', 'd3d12', 'dxgi', 'atidxx64', 'nvapi64', 'nvngx'];
  final size = File('$src/$lib').lengthSync();
  for (final module in modules) {
    final so = File('$src/$unix/$module.so');
    if (so.existsSync() && so.lengthSync() != size) {
      throw '${so.path} no es la misma biblioteca que $lib';
    }
  }
  final dest = _backendSlot(home, 'd3dmetal');
  return _intoSlot(home, 'd3dmetal', dest, (tmp) async {
    final peOut = Directory('${tmp.path}/$pe')..createSync(recursive: true);
    final unixOut = Directory('${tmp.path}/$unix')..createSync();
    final external = Directory('${tmp.path}/external')..createSync();
    Directory('${tmp.path}/wine/i386-windows').createSync();
    for (final module in modules) {
      final dll = File('$src/$pe/$module.dll');
      if (dll.existsSync()) dll.copySync('${peOut.path}/$module.dll');
      if (File('$src/$unix/$module.so').existsSync()) {
        // Rebuilt even if the source lost its links.
        Link('${unixOut.path}/$module.so').createSync('../../$lib');
      }
    }
    final core = File('$src/$pe/d3d12core.dll');
    if (core.existsSync()) core.copySync('${peOut.path}/d3d12core.dll');
    File('$src/$lib').copySync('${tmp.path}/$lib');
    // cp -R keeps the framework's Versions/ symlinks.
    await _run('/bin/cp', ['-R', '$src/$framework', external.path]);
  });
}

/// `backends/<name>`, refusing to overwrite an installed backend.
String _backendSlot(String home, String name) {
  final dest = '$home/backends/$name';
  if (Directory(dest).existsSync()) {
    throw 'ya instalado: $dest. Para cambiarlo: rm -rf "$dest"';
  }
  Directory('$home/backends').createSync(recursive: true);
  return dest;
}

/// Fills a staging dir with [fill] and renames it to [dest], so a failure
/// leaves neither `.tmp-*` nor a partial backend.
Future<String> _intoSlot(
  String home,
  String name,
  String dest,
  Future<void> Function(Directory tmp) fill,
) async {
  final tmp = Directory('$home/backends/.tmp-$name');
  if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  tmp.createSync();
  try {
    await fill(tmp);
    await Process.run('/usr/bin/xattr', [
      '-dr',
      'com.apple.quarantine',
      tmp.path,
    ]);
    tmp.renameSync(dest);
  } catch (_) {
    tmp.deleteSync(recursive: true);
    rethrow;
  }
  return dest;
}

/// A resumable download (slow links) to `downloads/`, HTTPS only, redirects
/// included; `file` only serves tests. With [sha256] it is checked, and a file
/// that already matches is not fetched again (B1, I3).
Future<String> _download(
  String home,
  String url,
  String? sha256, {
  String? name,
}) async {
  final dir = Directory('$home/downloads')..createSync(recursive: true);
  final file = File('${dir.path}/${name ?? url.split('/').last}');
  if (sha256 != null &&
      file.existsSync() &&
      await _sha256(file.path) == sha256) {
    return file.path;
  }
  final part = File('${file.path}.part');
  await _run('/usr/bin/curl', [
    '-fLsS',
    '--proto',
    '=https,file',
    '--proto-redir',
    '=https',
    '-C',
    '-',
    '--retry',
    '5',
    '-o',
    part.path,
    url,
  ]);
  part.renameSync(file.path);
  if (sha256 != null) {
    final got = await _sha256(file.path);
    if (got != sha256) {
      file.deleteSync();
      throw 'checksum incorrecto en ${file.path}: $got, se esperaba $sha256';
    }
  }
  return file.path;
}

Future<String> _sha256(String file) async =>
    (await _run('/usr/bin/shasum', ['-a', '256', file])).split(' ').first;

/// Lowercase `name.exe` without its path: the key of a per-program setting.
String _exeKey(String program) {
  final name = program.split(RegExp(r'[/\\]')).last.toLowerCase();
  return name.endsWith('.exe') ? name : '$name.exe';
}

void _checkChoice(String backend) {
  if (backend != 'auto' && !backendNames.contains(backend)) {
    throw 'backend desconocido: $backend (auto, ${backendNames.join(', ')})';
  }
}

void _checkSync(String sync) {
  if (sync != 'msync' && sync != 'none') {
    throw 'sync desconocido: $sync (msync, none)';
  }
}

typedef _Settings = ({
  String backend,
  String sync,
  Map<String, ({String? backend, Map<String, String> env})> programs,
});

/// `bottles/<b>/settings.json` (S1, A1, A2). A missing file means `auto` with
/// msync; a broken one is an error, never ignored.
_Settings _settings(String dir) {
  final file = File('$dir/settings.json');
  if (!file.existsSync()) return (backend: 'auto', sync: 'msync', programs: {});
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final programs = (json['programs'] ?? <String, dynamic>{}) as Map;
    final _Settings settings = (
      backend: (json['backend'] ?? 'auto') as String,
      sync: (json['sync'] ?? 'msync') as String,
      programs: {
        for (final MapEntry(:key, :value) in programs.entries)
          key as String: (
            backend: (value as Map)['backend'] as String?,
            env: Map<String, String>.from((value['env'] ?? const {}) as Map),
          ),
      },
    );
    _checkChoice(settings.backend);
    _checkSync(settings.sync);
    for (final program in settings.programs.values) {
      if (program.backend case final backend?) _checkChoice(backend);
    }
    return settings;
  } on Object catch (e) {
    throw '${file.path} no es válido: $e';
  }
}

/// Atomic, like every JSON the engine keeps.
void _writeJson(String path, Object value) {
  File('$path.tmp')
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value))
    ..renameSync(path);
}

void _saveSettings(String dir, _Settings settings) {
  _writeJson('$dir/settings.json', {
    'backend': settings.backend,
    'sync': settings.sync,
    'programs': {
      for (final MapEntry(:key, :value) in settings.programs.entries)
        key: {
          if (value.backend case final backend?) 'backend': backend,
          if (value.env.isNotEmpty) 'env': value.env,
        },
    },
  });
}

/// Sets the bottle's backend or, with [exe], that program's exception; `auto`
/// removes the exception and keeps the program's variables (S1, A2).
void setBackend(String home, String name, String backend, {String? exe}) {
  final dir = _existing(home, name);
  _checkChoice(backend);
  final settings = _settings(dir);
  final programs = settings.programs;
  if (exe != null) {
    final key = _exeKey(exe);
    final env = programs[key]?.env ?? const <String, String>{};
    if (backend != 'auto') {
      programs[key] = (backend: backend, env: env);
    } else if (env.isEmpty) {
      programs.remove(key);
    } else {
      programs[key] = (backend: null, env: env);
    }
  }
  _saveSettings(dir, (
    backend: exe == null ? backend : settings.backend,
    sync: settings.sync,
    programs: programs,
  ));
}

/// Sets the bottle's sync mode (A1). The mode is fixed while the bottle runs
/// and a process with the other one exits with 1, so a change stops the bottle
/// first. Returns whether it did.
Future<bool> setSync(String home, String name, String sync) async {
  final dir = _existing(home, name);
  _checkSync(sync);
  final settings = _settings(dir);
  if (settings.sync == sync) return false;
  await stopBottle(home, name);
  _saveSettings(dir, (
    backend: settings.backend,
    sync: sync,
    programs: settings.programs,
  ));
  return true;
}

/// Applies S2: option, then the program's exception, then the bottle, then
/// auto. [dir] is the bottle; [exePath] is null for a program without a path.
/// Throws if the choice is not installed (S5): it never falls back silently.
Future<({String name, String origin})> resolveBackend(
  String home,
  String dir,
  String program,
  String? exePath, {
  String? option,
}) async {
  if (option != null) _checkChoice(option);
  final settings = _settings(dir);
  final exception = settings.programs[_exeKey(program)]?.backend;
  final bottle = settings.backend == 'auto' ? null : settings.backend;
  final (name, origin) = option == 'auto'
      ? (null, 'auto')
      : option != null
      ? (option, 'opcion')
      : exception != null
      ? (exception, 'exe')
      : bottle != null
      ? (bottle, 'botella')
      : (null, 'auto');
  if (name == null) {
    return (name: await _autoBackend(home, exePath), origin: origin);
  }
  if (!_installed(home, name)) throw _notInstalled(name);
  return (name: name, origin: origin);
}

String _notInstalled(String name) =>
    '$name no está instalado: bodega backend '
    '${name == 'd3dmetal' ? 'import d3dmetal <carpeta>' : 'install $name'}';

/// S3: looks for the DLL names anywhere in the exe, because imports alone miss
/// LoadLibrary (design §4). NULs are dropped to catch UTF-16 strings too.
Future<String> _autoBackend(String home, String? exePath) async {
  if (exePath == null || !File(exePath).existsSync()) return 'wine';
  final bits = _peBits(exePath);
  if (bits == null) return 'wine';
  final found = <String>{};
  var tail = '';
  await for (final chunk in File(
    exePath,
  ).openRead().transform(latin1.decoder)) {
    final text = tail + chunk.replaceAll('\x00', '').toLowerCase();
    found.addAll(
      [
        'd3d12.dll',
        'd3d11.dll',
        'd3d10',
        'dxgi.dll',
        'd3d9.dll',
      ].where(text.contains),
    );
    if (found.contains('d3d12.dll')) break;
    tail = text.substring(text.length < 16 ? 0 : text.length - 16);
  }
  if (found.contains('d3d12.dll')) {
    return bits == 64 && _installed(home, 'd3dmetal') ? 'd3dmetal' : 'wine';
  }
  // A D3D9 game can mention d3d10 or dxgi just to probe them, as Blur does (A4).
  if (!found.contains('d3d11.dll') &&
      (found.isEmpty || found.contains('d3d9.dll'))) {
    return 'wine';
  }
  return ['dxmt', 'dxvk'].where((b) => _installed(home, b)).firstOrNull ??
      'wine';
}

/// 64 or 32 from the PE header, or null if [path] is not a PE on x86.
int? _peBits(String path) {
  final file = File(path).openSync();
  try {
    final dos = file.readSync(64);
    if (dos.length < 64 || dos[0] != 0x4D || dos[1] != 0x5A) return null;
    final offset = ByteData.sublistView(dos).getUint32(60, Endian.little);
    file.setPositionSync(offset);
    final pe = file.readSync(6);
    if (pe.length < 6 || pe[0] != 0x50 || pe[1] != 0x45) return null;
    return switch (ByteData.sublistView(pe).getUint16(4, Endian.little)) {
      0x8664 => 64,
      0x14C => 32,
      _ => null,
    };
  } finally {
    file.closeSync();
  }
}

/// Options before the bottle (S7), and what follows them; null for a bad one.
({String? backend, bool hud, List<String> rest})? _parseOptions(
  List<String> args,
) {
  String? backend;
  var hud = false;
  var i = 0;
  for (; i < args.length && args[i].startsWith('--'); i++) {
    if (args[i] == '--hud') {
      hud = true;
    } else if (args[i] == '--backend' && i + 1 < args.length) {
      backend = args[++i];
    } else {
      return null;
    }
  }
  return (backend: backend, hud: hud, rest: args.sublist(i));
}

/// The arguments of `run`, or null for a bad usage.
({String? backend, bool hud, String bottle, String program, List<String> args})?
parseRun(List<String> args) {
  final options = _parseOptions(args);
  if (options == null || options.rest.length < 2) return null;
  return (
    backend: options.backend,
    hud: options.hud,
    bottle: options.rest[0],
    program: options.rest[1],
    args: options.rest.sublist(2),
  );
}

/// The arguments of `open`, or null for a bad usage.
({String? backend, bool hud, String bottle})? parseOpen(List<String> args) {
  final options = _parseOptions(args);
  if (options == null || options.rest.length != 1) return null;
  return (
    backend: options.backend,
    hud: options.hud,
    bottle: options.rest.single,
  );
}

/// The `# backend` line of a log, without the `# `: what was chosen and why.
String? backendOf(String log) =>
    File(log)
        .readAsLinesSync(encoding: latin1)
        .take(4)
        .where((line) => line.startsWith('# backend '))
        .map((line) => line.substring(2))
        .firstOrNull;

/// Runs the probe with [backend] (B4). It stops the bottle first, because its
/// services keep the environment they started with, and a run that hangs is
/// stopped too.
Future<List<({int bits, String d3d, bool ok, String log})>> backendTest(
  String home,
  String name,
  String backend,
) async {
  _existing(home, name);
  if (!backendNames.contains(backend)) {
    throw 'indica un backend: ${backendNames.join(', ')}';
  }
  // Throws with the install order if it is missing (S5).
  await resolveBackend(home, bottleDir(home, name), 'x', null, option: backend);
  final probes = Directory('$home/backends/probe')..createSync(recursive: true);
  final files = {
    64: File('${probes.path}/probe-64.exe')
      ..writeAsBytesSync(base64.decode(probe64Base64)),
    32: File('${probes.path}/probe-32.exe')
      ..writeAsBytesSync(base64.decode(probe32Base64)),
  };
  final cases = switch (backend) {
    'wine' => [(64, '11'), (64, '12')],
    'd3dmetal' => [
      (64, '11'),
      (64, '12'),
      if (_installed(home, 'dxmt')) (32, '11'),
    ],
    _ => [(64, '11'), (32, '11')],
  };
  // A crash must end the run, not wait on a debugger nobody can see.
  final overrides = backendEnv(home, backend)['WINEDLLOVERRIDES'] ?? _overrides;
  await stopBottle(home, name);
  return [
    for (final (bits, d3d) in cases)
      await () async {
        final log = await _launchIn(
          home,
          name,
          files[bits]!.path,
          [d3d],
          backend: backend,
          extra: {'WINEDLLOVERRIDES': '$overrides;winedbg.exe=d'},
        );
        final code = await exitOf(log).timeout(
          const Duration(seconds: 90),
          onTimeout: () async {
            await stopBottle(home, name);
            return -1;
          },
        );
        return (bits: bits, d3d: d3d, ok: code == 0, log: log);
      }(),
  ];
}
