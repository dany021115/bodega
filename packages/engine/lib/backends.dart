part of 'engine.dart';

/// Every backend, in the order a UI should offer them.
List<String> get backendNames => hostPlatform.backendNames;

String _layer(String home, String name) => '$home/backends/$name/wine';

bool _installed(String home, String name) =>
    name == 'wine' || Directory(_layer(home, name)).existsSync();

/// Which backends are installed (B3).
Map<String, bool> listBackends(String home) => {
  for (final name in backendNames) name: _installed(home, name),
};

/// What [wineEnv] gains for [backend] (S4).
Map<String, String> backendEnv(
  String home,
  String backend, {
  bool hud = false,
}) => hostPlatform.backendEnv(home, backend, hud: hud);

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
    if (!hostPlatform.capabilities.d3dmetal) {
      throw 'd3dmetal no disponible en ${hostPlatform.displayName}';
    }
    throw 'd3dmetal no se descarga: bodega backend import d3dmetal <carpeta>';
  }
  final pin = hostPlatform.pinnedBackends[name];
  if (pin == null) throw 'backend sin instalador: $name';
  final dest = _backendSlot(home, name);
  final want = sha256 ?? pin.sha256;
  final file = tarball ?? await _download(home, url ?? pin.url, want);
  final got = await sha256Of(file);
  if (got != want) {
    throw 'checksum incorrecto en $file: $got, se esperaba $want';
  }
  return _intoSlot(home, name, dest, (tmp) async {
    await _run(hostPlatform.tool('tar'), ['-xzf', file, '-C', tmp.path]);
    final check = hostPlatform.layerCheck;
    final root = tmp
        .listSync()
        .whereType<Directory>()
        .where((dir) => Directory('${dir.path}/${check.dir}').existsSync())
        .firstOrNull;
    if (root == null || !File('${root.path}/${check.file}').existsSync()) {
      throw 'tarball sin ${check.file}: $file';
    }
    root.renameSync('${tmp.path}/wine');
  });
}

/// I1: the Game Porting Toolkit versions offered, oldest first, with where
/// Apple serves each. Only 3.0 has been checked with Bodega. Apple asks for an
/// Apple ID before the download: the user's browser gets it, never Bodega (B2).
const gptkReleases = [
  (
    version: '3.0',
    tested: true,
    url:
        'https://download.developer.apple.com/Developer_Tools/'
        'Game_Porting_Toolkit_3.0/Game_Porting_Toolkit_3.0.dmg',
  ),
  (
    version: '4.0',
    tested: false,
    url: 'https://developer.apple.com/download/all/?q=game%20porting%20toolkit',
  ),
];

/// I2: the newest `Game_Porting_Toolkit_<version>….dmg` in [dir], or null. A
/// download still running has another extension, so it does not count. Async:
/// the first read of Downloads waits for the user to allow it.
Future<String?> findGptkDmg(String version, String dir) async {
  final prefix = 'game_porting_toolkit_${version.toLowerCase()}';
  final found = [
    await for (final file in Directory(dir).list())
      if (file is File &&
          file.uri.pathSegments.last.toLowerCase().startsWith(prefix) &&
          file.path.toLowerCase().endsWith('.dmg'))
        file,
  ]..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return found.firstOrNull?.path;
}

/// I1: the version of the D3DMetal imported, from its framework, or null.
Future<String?> d3dmetalVersion(String home) async {
  final plist =
      '$home/backends/d3dmetal/external/D3DMetal.framework/Resources/Info.plist';
  if (!File(plist).existsSync()) return null;
  final result = await Process.run('/usr/bin/plutil', [
    '-extract',
    'CFBundleShortVersionString',
    'raw',
    plist,
  ]);
  return result.exitCode == 0 ? (result.stdout as String).trim() : null;
}

/// I3: installs D3DMetal from the Game Porting Toolkit dmg the user got from
/// Apple. It sits in `redist/lib`, usually in a dmg inside that dmg which
/// shows Apple's license: macOS opens that one so the user accepts it
/// themselves (design §1), and Bodega waits for its volume. What it mounted is
/// detached at the end, whatever happens. Returns the version installed.
Future<String> installD3DMetalDmg(
  String home,
  String dmg, {
  void Function(String step)? onStep,
  bool Function()? cancelled,
  Duration wait = const Duration(minutes: 5),
}) async {
  if (!hostPlatform.capabilities.d3dmetal) {
    throw 'd3dmetal no disponible en ${hostPlatform.displayName}';
  }
  final mounted = <String>[];
  Future<String> attach(String image) async {
    final mount = Directory.systemTemp.createTempSync('bodega-gptk').path;
    for (var tries = 1; ; tries++) {
      final result = await Process.run('/usr/bin/hdiutil', [
        'attach',
        '-nobrowse',
        '-readonly',
        '-mountpoint',
        mount,
        image,
      ]);
      if (result.exitCode == 0) break;
      final why = '${result.stdout}${result.stderr}'.trim().split('\n').last;
      // A dmg just downloaded stays busy for some seconds, held by the
      // browser or by macOS's malware check.
      if (why.contains('Resource busy') && tries < 15) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      Directory(mount).deleteSync();
      throw 'no se pudo abrir ${image.split('/').last}: $why';
    }
    mounted.add(mount);
    return mount;
  }

  String? redist(String root) =>
      Directory('$root/redist/lib').existsSync() ? '$root/redist' : null;

  onStep?.call('Abriendo ${dmg.split('/').last}');
  try {
    final outer = await attach(dmg);
    var found = redist(outer);
    if (found == null) {
      // `Evaluation environment for Windows games <version>.dmg`, beside the
      // samples and the tools' installers.
      final inner = Directory(outer).listSync().whereType<File>().where((file) {
        final name = file.uri.pathSegments.last.toLowerCase();
        return name.startsWith('evaluation environment') &&
            name.endsWith('.dmg');
      }).firstOrNull;
      if (inner == null) throw 'no hay D3DMetal en $dmg: falta redist/lib';
      final info = await Process.run('/usr/bin/hdiutil', [
        'imageinfo',
        inner.path,
      ]);
      if (!'${info.stdout}'.contains('Software License Agreement: true')) {
        found = redist(await attach(inner.path));
      } else {
        onStep?.call('Acepta la licencia de Apple en la ventana que se abrió');
        await _run('/usr/bin/open', [inner.path]);
        final deadline = DateTime.now().add(wait);
        while (found == null) {
          if (cancelled?.call() ?? false) throw 'instalación cancelada';
          if (DateTime.now().isAfter(deadline)) {
            throw 'no se aceptó la licencia de Apple';
          }
          await Future<void>.delayed(const Duration(seconds: 1));
          for (final volume in Directory('/Volumes').listSync()) {
            if (Directory(
              '${volume.path}/redist/lib/external/D3DMetal.framework',
            ).existsSync()) {
              mounted.add(volume.path);
              found = '${volume.path}/redist';
              break;
            }
          }
        }
      }
      if (found == null) throw 'no hay D3DMetal en $dmg: falta redist/lib';
    }
    onStep?.call('Importando D3DMetal');
    // Replaces the one there was, and puts it back if the new one fails.
    final dest = Directory('$home/backends/d3dmetal');
    final old = Directory('${dest.path}.old');
    if (old.existsSync()) old.deleteSync(recursive: true);
    if (dest.existsSync()) dest.renameSync(old.path);
    try {
      await importD3DMetal(home, found);
    } catch (_) {
      if (old.existsSync()) old.renameSync(dest.path);
      rethrow;
    }
    if (old.existsSync()) old.deleteSync(recursive: true);
  } finally {
    // The inner volume first: its image lives in the outer one.
    for (final mount in mounted.reversed) {
      await Process.run('/usr/bin/hdiutil', ['detach', mount]);
      try {
        Directory(mount).deleteSync();
      } on FileSystemException {
        // A volume in /Volumes goes away with the detach.
      }
    }
  }
  return await d3dmetalVersion(home) ?? 'desconocida';
}

/// Copies D3DMetal from a folder the user provides (B2). Its unix modules are
/// all one library: each must stay a symlink to it, because separate copies
/// load as separate images and crash on device creation (design §2).
/// Returns its folder.
Future<String> importD3DMetal(String home, String folder) async {
  if (!hostPlatform.capabilities.d3dmetal) {
    throw 'd3dmetal no disponible en ${hostPlatform.displayName}';
  }
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
    await hostPlatform.afterExtract(tmp.path);
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
      await sha256Of(file.path) == sha256) {
    return file.path;
  }
  final part = File('${file.path}.part');
  await _run(hostPlatform.tool('curl'), [
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
    final got = await sha256Of(file.path);
    if (got != sha256) {
      file.deleteSync();
      throw 'checksum incorrecto en ${file.path}: $got, se esperaba $sha256';
    }
  }
  return file.path;
}

/// The SHA-256 of [file], in hex, from the host's own tool.
Future<String> sha256Of(String file) async {
  final (tool, args) = hostPlatform.sha256Tool;
  return (await _run(tool, [...args, file])).split(' ').first;
}

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

void _checkGpu(String gpu) {
  if (gpu != 'auto' && gpu != 'discrete') {
    throw 'gpu desconocida: $gpu (auto, discrete)';
  }
}

void _checkSync(String sync) {
  final modes = hostPlatform.capabilities.syncModes;
  if (!modes.contains(sync)) {
    throw 'sync desconocido: $sync (${modes.join(', ')})';
  }
}

typedef BottleSettings = ({
  String backend,
  String sync,
  Map<String, ({String? backend, Map<String, String> env, bool hud})> programs,

  /// Which version of [_ensureGamepads] the bottle has had; 0 for none.
  int gamepads,
  bool highRes,
  bool dlss,

  /// False takes `ROSETTA_ADVERTISE_AVX` out of every launch (M8).
  bool avx,
  String windows,
  Map<String, String> env,

  /// `auto` or `discrete` (R14).
  String gpu,
  bool gamemode,

  /// The Windows user name its games see (U1); empty for the host's.
  String user,
});

/// What [setWindowsVersion] admits, newest first.
const windowsVersions = ['win11', 'win10', 'win81', 'win7'];

/// The two names of DLSS: D3DMetal's and DXMT's (INFORME §5).
const _dlssEnv = {'D3DM_ENABLE_METALFX': '1', 'DXMT_ENABLE_NVEXT': '1'};

BottleSettings get _defaults => (
  backend: 'auto',
  sync: hostPlatform.defaultSync,
  programs: {},
  gamepads: 0,
  highRes: false,
  dlss: false,
  avx: true,
  windows: 'win10',
  env: {},
  gpu: 'auto',
  gamemode: hostPlatform.defaultGamemode,
  user: '',
);

/// [settings] with these fields changed: records have no `copyWith`.
BottleSettings _with(
  BottleSettings settings, {
  String? backend,
  String? sync,
  Map<String, ({String? backend, Map<String, String> env, bool hud})>? programs,
  int? gamepads,
  bool? highRes,
  bool? dlss,
  bool? avx,
  String? windows,
  Map<String, String>? env,
  String? gpu,
  bool? gamemode,
  String? user,
}) => (
  backend: backend ?? settings.backend,
  sync: sync ?? settings.sync,
  programs: programs ?? settings.programs,
  gamepads: gamepads ?? settings.gamepads,
  highRes: highRes ?? settings.highRes,
  dlss: dlss ?? settings.dlss,
  avx: avx ?? settings.avx,
  windows: windows ?? settings.windows,
  env: env ?? settings.env,
  gpu: gpu ?? settings.gpu,
  gamemode: gamemode ?? settings.gamemode,
  user: user ?? settings.user,
);

/// `bottles/<b>/settings.json` (S1, A1, A2, M8). A missing file or field means
/// its default; a broken one is an error, never ignored.
BottleSettings _settings(String dir) {
  final file = File('$dir/settings.json');
  if (!file.existsSync()) return _with(_defaults, programs: {}, env: {});
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final programs = (json['programs'] ?? <String, dynamic>{}) as Map;
    final BottleSettings settings = (
      backend: (json['backend'] ?? 'auto') as String,
      sync: (json['sync'] ?? hostPlatform.defaultSync) as String,
      programs: {
        for (final MapEntry(:key, :value) in programs.entries)
          key as String: (
            backend: (value as Map)['backend'] as String?,
            env: Map<String, String>.from((value['env'] ?? const {}) as Map),
            hud: (value['hud'] ?? false) as bool,
          ),
      },
      gamepads: (json['gamepads'] ?? 0) as int,
      highRes: (json['highRes'] ?? false) as bool,
      dlss: (json['dlss'] ?? false) as bool,
      avx: (json['avx'] ?? true) as bool,
      windows: (json['windows'] ?? 'win10') as String,
      env: Map<String, String>.from((json['env'] ?? const {}) as Map),
      gpu: (json['gpu'] ?? 'auto') as String,
      gamemode: (json['gamemode'] ?? hostPlatform.defaultGamemode) as bool,
      user: (json['user'] ?? '') as String,
    );
    _checkChoice(settings.backend);
    _checkSync(settings.sync);
    _checkGpu(settings.gpu);
    _checkWindows(settings.windows);
    for (final program in settings.programs.values) {
      if (program.backend case final backend?) _checkChoice(backend);
    }
    return settings;
  } on Object catch (e) {
    throw '${file.path} no es válido: $e';
  }
}

void _checkWindows(String version) {
  if (!windowsVersions.contains(version)) {
    throw 'versión de Windows desconocida: $version '
        '(${windowsVersions.join(', ')})';
  }
}

/// Atomic, like every JSON the engine keeps.
void _writeJson(String path, Object value) {
  File('$path.tmp')
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(value))
    ..renameSync(path);
}

/// Only what differs from the defaults, besides backend and sync.
void _saveSettings(String dir, BottleSettings settings) {
  _writeJson('$dir/settings.json', {
    'backend': settings.backend,
    'sync': settings.sync,
    'programs': {
      for (final MapEntry(:key, :value) in settings.programs.entries)
        key: {
          if (value.backend case final backend?) 'backend': backend,
          if (value.env.isNotEmpty) 'env': value.env,
          if (value.hud) 'hud': true,
        },
    },
    if (settings.gamepads > 0) 'gamepads': settings.gamepads,
    if (settings.highRes) 'highRes': true,
    if (settings.dlss) 'dlss': true,
    if (!settings.avx) 'avx': false,
    if (settings.windows != _defaults.windows) 'windows': settings.windows,
    if (settings.env.isNotEmpty) 'env': settings.env,
    if (settings.gpu != _defaults.gpu) 'gpu': settings.gpu,
    if (settings.gamemode != hostPlatform.defaultGamemode)
      'gamemode': settings.gamemode,
    if (settings.user.isNotEmpty) 'user': settings.user,
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
    final hud = programs[key]?.hud ?? false;
    if (backend != 'auto') {
      programs[key] = (backend: backend, env: env, hud: hud);
    } else if (env.isEmpty && !hud) {
      programs.remove(key);
    } else {
      programs[key] = (backend: null, env: env, hud: hud);
    }
  }
  _saveSettings(
    dir,
    _with(
      settings,
      backend: exe == null ? backend : settings.backend,
      programs: programs,
    ),
  );
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
  _saveSettings(dir, _with(settings, sync: sync));
  return true;
}

/// DLSS, AVX, GPU, GameMode and the bottle's own variables (M8): they apply
/// from the next launch, so nothing is stopped.
void setBottleOptions(
  String home,
  String name, {
  bool? dlss,
  bool? avx,
  String? gpu,
  bool? gamemode,
  Map<String, String>? env,
}) {
  final dir = _existing(home, name);
  if (gpu != null) _checkGpu(gpu);
  _saveSettings(
    dir,
    _with(
      _settings(dir),
      dlss: dlss,
      avx: avx,
      gpu: gpu,
      gamemode: gamemode,
      env: env,
    ),
  );
}

/// The user name Wine takes when Bodega sets none: the host's (design §4).
String get hostUser => hostPlatform.baseEnv(Platform.environment)['USER'] ?? '';

/// U3: why [user] cannot be a Windows user name, or null if it can.
String? badUser(String user) {
  if (user.isEmpty) return 'el nombre está vacío';
  if (user.length > 20) return 'el nombre tiene más de 20 caracteres';
  if (RegExp(r'["/\\\[\]:;|=,+*?<>\x00-\x1f]').hasMatch(user)) {
    return r'el nombre no puede llevar " / \ [ ] : ; | = , + * ? < >';
  }
  if (RegExp(r'^[. ]+$').hasMatch(user)) {
    return 'el nombre no puede ser solo puntos o espacios';
  }
  return null;
}

/// U4: the Windows user of the bottle; null or empty means the host's. Stops
/// the bottle and renames its profile folder, so saved games and the links to
/// the host's folders stay with it, and points TEMP and TMP at the profile.
/// Returns whether anything changed.
Future<bool> setBottleUser(String home, String name, String? user) async {
  final dir = _existing(home, name);
  final wanted = (user ?? '').trim();
  if (wanted.isNotEmpty) {
    if (badUser(wanted) case final why?) throw why;
  }
  final settings = _settings(dir);
  final saved = wanted == hostUser ? '' : wanted;
  if (saved == settings.user) return false;
  final from = settings.user.isEmpty ? hostUser : settings.user;
  final to = saved.isEmpty ? hostUser : saved;
  final users = '$dir/prefix/drive_c/users';
  final old = Directory('$users/$from');
  final hasOld =
      from.isNotEmpty &&
      FileSystemEntity.typeSync(old.path, followLinks: false) ==
          FileSystemEntityType.directory;
  // A change of case only is the same folder on the Mac.
  if (hasOld &&
      from.toLowerCase() != to.toLowerCase() &&
      FileSystemEntity.typeSync('$users/$to', followLinks: false) !=
          FileSystemEntityType.notFound) {
    throw 'ya existe C:\\users\\$to en la botella: bórrala o elige otro nombre';
  }
  await stopBottle(home, name);
  // `rename` moves the links inside as links: nothing they point to is touched.
  if (hasOld) old.renameSync('$users/$to');
  _saveSettings(dir, _with(settings, user: saved));
  for (final variable in const ['TEMP', 'TMP']) {
    final log = await _launchIn(
      home,
      name,
      'reg',
      [
        'add',
        r'HKCU\Environment',
        '/v',
        variable,
        '/t',
        'REG_EXPAND_SZ',
        '/d',
        r'%USERPROFILE%\AppData\Local\Temp',
        '/f',
      ],
      backend: 'wine',
      label: 'usuario',
    );
    final code = await exitOf(log);
    if (code != 0) throw 'reg add salió con $code; log: $log';
  }
  return true;
}

/// `RetinaMode` and the doubled `LogPixels` (M9, INFORME §6.1). Wine reads them
/// when a process starts, and they apply to the whole prefix, so a change stops
/// the bottle first. Returns whether it did.
Future<bool> setHighRes(String home, String name, bool value) async {
  final dir = _existing(home, name);
  if (_settings(dir).highRes == value) return false;
  await stopBottle(home, name);
  for (final args in hostPlatform.highResRegistry(value)) {
    final log = await _launchIn(
      home,
      name,
      'reg',
      ['add', args[0], '/v', args[1], '/t', args[2], '/d', args[3], '/f'],
      backend: 'wine',
      label: 'resolucion',
    );
    final code = await exitOf(log);
    if (code != 0) throw 'reg add salió con $code; log: $log';
  }
  _saveSettings(dir, _with(_settings(dir), highRes: value));
  return true;
}

/// `winecfg -v` (M10): measured without a window, it answers what was set.
Future<void> setWindowsVersion(String home, String name, String version) async {
  final dir = _existing(home, name);
  _checkWindows(version);
  final log = await _launchIn(
    home,
    name,
    'winecfg',
    ['-v', version],
    backend: 'wine',
    label: 'windows',
  );
  final code = await exitOf(log);
  if (code != 0) throw 'winecfg salió con $code; log: $log';
  _saveSettings(dir, _with(_settings(dir), windows: version));
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
    return (
      name: await hostPlatform.autoBackend(home, exePath),
      origin: origin,
    );
  }
  if (!_installed(home, name)) throw _notInstalled(name);
  return (name: name, origin: origin);
}

String _notInstalled(String name) =>
    '$name no está instalado: bodega backend '
    '${name == 'd3dmetal' ? 'import d3dmetal <carpeta>' : 'install $name'}';

/// What an exe draws with (G1): its bits, and the newest DirectX it names
/// (`DX12`, `DX11`, `DX10`, `DX9`, or empty when it names none).
typedef ExeGraphics = ({int bits, String directx});

/// G1: looks for the DLL names anywhere in the exe, because imports alone miss
/// LoadLibrary (design §4). Null if [path] is not a PE on x86. Runs in another
/// isolate: a big exe takes a while to read.
Future<ExeGraphics?> exeGraphics(String path) =>
    Isolate.run(() => _readGraphics(path));

Future<ExeGraphics?> _readGraphics(String path) async {
  if (!File(path).existsSync()) return null;
  final bits = _peBits(path);
  if (bits == null) return null;
  final found = <String>{};
  var tail = '';
  // NULs are dropped to catch UTF-16 strings too.
  await for (final chunk in File(path).openRead().transform(latin1.decoder)) {
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
  return (
    bits: bits,
    directx: found.contains('d3d12.dll')
        ? 'DX12'
        : found.contains('d3d11.dll')
        ? 'DX11'
        // A D3D9 game can mention d3d10 or dxgi just to probe them, as Blur
        // does (A4).
        : found.contains('d3d9.dll')
        ? 'DX9'
        : found.isNotEmpty
        ? 'DX10'
        : '',
  );
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
({String? backend, bool hud, String bottle, String? key})? parseOpen(
  List<String> args,
) {
  final options = _parseOptions(args);
  if (options == null || options.rest.isEmpty || options.rest.length > 2) {
    return null;
  }
  return (
    backend: options.backend,
    hud: options.hud,
    bottle: options.rest.first,
    key: options.rest.length == 2 ? options.rest.last : null,
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
  final cases = hostPlatform.probeCases(home, backend);
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

/// The bottle's settings, for a UI (E3).
BottleSettings bottleSettings(String home, String name) =>
    _settings(_existing(home, name));

/// Where a backend's pinned tarball comes from, or null if it has none (E9).
({String url, String sha256})? pinnedBackend(String name) =>
    hostPlatform.pinnedBackends[name];
