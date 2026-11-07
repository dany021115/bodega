/// Bodega's engine: installs the Wine runtime, creates bottles and launches
/// programs in them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'catalog_data.dart';
import 'probe_data.dart';

part 'apps.dart';
part 'backends.dart';
part 'catalog.dart';
part 'platform.dart';
part 'platform_linux.dart';
part 'platform_mac.dart';

/// The data root (R1): `BODEGA_HOME`, or else the host's default, created and
/// canonical.
String bodegaHome(Map<String, String> env) {
  final dir = Directory(env['BODEGA_HOME'] ?? hostPlatform.defaultHome(env));
  // Also before creating it, so that a bad root is not left on disk.
  if (winPathProblem(dir.absolute.path) case final problem?) {
    throw FormatException(problem);
  }
  final home = (dir..createSync(recursive: true)).resolveSymbolicLinksSync();
  if (winPathProblem(home) case final problem?) throw FormatException(problem);
  for (final sub in ['runtimes', 'bottles']) {
    Directory('$home/$sub').createSync();
  }
  hostPlatform.prepareHome(home);
  return home;
}

/// Trap 11: Wine exits 53 when a path component ends in `.` or space or
/// contains `<>:"|?*`. Returns what is wrong, or null. `.` and `..` only
/// navigate, so they pass.
String? winPathProblem(String path) {
  final bad = path
      .split('/')
      .where((part) => part != '.' && part != '..')
      .where(RegExp(r'[<>:"|?*]|[. ]$').hasMatch)
      .firstOrNull;
  if (bad == null) return null;
  return '"$bad" en $path: Windows no admite nombres que acaben en punto o '
      'espacio ni que lleven <>:"|?*';
}

/// `bottles/<name>`, once [name] passes R8.
String bottleDir(String home, String name) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(name)) {
    throw FormatException(
      'nombre de botella no válido: "$name" (letras, números, _ y -, '
      'hasta 64, sin empezar por _ ni -)',
    );
  }
  return '$home/bottles/$name';
}

const _overrides = 'winemenubuilder.exe=d';

/// The whole environment of every process the engine starts (R12): nothing
/// else from [parent] gets in; [extra] is what the backend adds (S4).
Map<String, String> wineEnv(
  String prefix,
  Map<String, String> parent, [
  Map<String, String> extra = const {},
]) => {
  ...hostPlatform.baseEnv(parent),
  'WINEPREFIX': prefix,
  'WINEDLLOVERRIDES': _overrides,
  // ponytail: BODEGA_WINEDEBUG is the only knob read from the caller.
  'WINEDEBUG': parent['BODEGA_WINEDEBUG'] ?? hostPlatform.defaultWineDebug,
  ...extra,
};

/// What an installed runtime must contain (R5), for this host.
List<String> get requiredFiles => hostPlatform.requiredFiles;

/// Whether the host can run Windows programs, and what is missing (R10).
Future<List<HostIssue>> checkHost() => hostPlatform.checkHost();

/// What the host offers, so that a UI hides the rest (R11).
HostCapabilities hostCapabilities() => hostPlatform.capabilities;

/// Checks both tarballs, unpacks them into one staging dir that becomes
/// `runtimes/<id>`, and points `runtimes/current` at it (R4–R7).
Future<String> installRuntime(
  String home,
  String engine,
  String hostlibs,
) async {
  final id = _tag(engine);
  final dest = Directory('$home/runtimes/$id');
  if (dest.existsSync()) {
    throw 'ya instalado: ${dest.path}. Para reinstalarlo, o para cambiar las '
        'hostlibs: bodega stop de cada botella, rm -rf "${dest.path}" y otra '
        'vez bodega install con los tarballs guardados';
  }
  for (final tarball in [engine, hostlibs]) {
    if (!File('$tarball.sha256').existsSync()) {
      throw 'falta $tarball.sha256: gh release download ${_tag(tarball)} '
          '-R dany021115/bodega';
    }
    final name = tarball.split('/').last, dir = File(tarball).parent.path;
    // -c checks whatever file the .sha256 names, so it must name this one.
    final (shasum, shaArgs) = hostPlatform.sha256Tool;
    final out = await _run(shasum, [...shaArgs, '-c', '$name.sha256'], dir);
    if (out != '$name: OK\n') {
      throw '$name.sha256 no corresponde a $name: ${out.trim()}';
    }
  }
  final tmp = Directory('$home/runtimes/.tmp-$id');
  if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  tmp.createSync();
  try {
    for (final tarball in [engine, hostlibs]) {
      await _run(hostPlatform.tool('tar'), ['-xzf', tarball, '-C', tmp.path]);
    }
    await hostPlatform.afterExtract(tmp.path);
    for (final file in requiredFiles) {
      if (!File('${tmp.path}/$file').existsSync()) {
        throw 'runtime incompleto: falta $file';
      }
    }
    // --version only checks that WINEPREFIX is absolute; it never creates it
    // (CX/dlls/ntdll/unix/loader.c:462,2619).
    final version = await Process.run(
      '${tmp.path}/engine/bin/wine',
      ['--version'],
      environment: wineEnv('${tmp.path}/prefix', Platform.environment),
      includeParentEnvironment: false,
    );
    if (!'${version.stdout}'.startsWith('wine-')) {
      throw 'wine --version no responde: ${version.stdout}${version.stderr}';
    }
    tmp.renameSync(dest.path);
  } catch (_) {
    tmp.deleteSync(recursive: true);
    rethrow;
  }
  // ponytail: one global runtime; installing another while bottles run gives
  // "version mismatch" (trap 16).
  final link = Link('$home/runtimes/current.tmp');
  if (link.existsSync()) link.deleteSync();
  (link..createSync(id)).renameSync('$home/runtimes/current');
  return dest.path;
}

/// The runtime every bottle uses: `runtimes/current`, resolved (R7).
String currentRuntime(String home) {
  // Directory follows the link, so a dangling `current` counts as none.
  final current = Directory('$home/runtimes/current');
  if (!current.existsSync()) {
    throw 'no hay runtime: bodega install <engine.tar.gz> <hostlibs.tar.gz>';
  }
  return current.resolveSymbolicLinksSync();
}

/// Builds `bottles/<name>` with a plain `wine wineboot`, whose automatic
/// `--init` creates the prefix, then waits for the server to save the
/// registry (R9, R10, design §5). Returns the log.
Future<String> createBottle(String home, String name) async {
  final dir = bottleDir(home, name);
  final rt = currentRuntime(home);
  if (Directory(dir).existsSync()) {
    throw 'ya existe $dir; para empezar de cero: '
        'bodega stop $name y rm -rf "$dir"';
  }
  Directory('$dir/logs').createSync(recursive: true);
  final prefix = '$dir/prefix';
  final log = _newLog(dir, 'wineboot', rt, dir, ['wineboot']);
  final wineboot = await _start(rt, prefix, log, dir, ['wineboot']);
  final code = await wineboot.exitCode;
  if (code != 0) {
    await _wineserver(rt, prefix, '-k');
    throw 'wineboot salió con $code; log: $log';
  }
  await _wineserver(rt, prefix, '-w').timeout(
    const Duration(minutes: 10),
    onTimeout: () async {
      await _wineserver(rt, prefix, '-k');
      throw 'wineserver -w pasó de 10 min y se paró la botella; log: $log';
    },
  );
  // ponytail: syswow64 is not repaired (Highball copies i386-windows); in a
  // prototype that failure has to show.
  if (!_ready(prefix)) {
    throw 'la botella no quedó lista: falta syswow64/kernel32.dll o '
        'system.reg; log: $log';
  }
  await hostPlatform.prepareBottle(home, name);
  return log;
}

/// Starts [program] detached, so it outlives the CLI and the Terminal, and
/// returns its log (R13–R15); [exitOf] gives its exit code. [backend] is the
/// `run --backend` option (S2), and [hud] turns on the Metal HUD (S4).
Future<String> runInBottle(
  String home,
  String name,
  String program,
  List<String> args, {
  String? backend,
  bool hud = false,
  Map<String, String> env = const {},
  bool? avx,
}) async {
  await hostPlatform.prepareBottle(home, name);
  return _launchIn(
    home,
    name,
    program,
    args,
    backend: backend,
    hud: hud,
    env: env,
    avx: avx,
  );
}

Future<String> _launchIn(
  String home,
  String name,
  String program,
  List<String> args, {
  String? backend,
  bool hud = false,
  String? label,
  Map<String, String> env = const {},
  bool? avx,
  Map<String, String> extra = const {},
}) async {
  final dir = _existing(home, name);
  final rt = currentRuntime(home);
  final prefix = '$dir/prefix';
  final drive = '$prefix/drive_c';
  if (!_ready(prefix)) {
    throw 'la botella $name no está lista: bodega stop $name, '
        'rm -rf "$dir" y bodega create $name';
  }
  var exe = program, cwd = drive;
  String? scan;
  if (program.contains('/')) {
    exe = File(program).resolveSymbolicLinksSync();
    if (winPathProblem(exe) case final problem?) throw FormatException(problem);
    cwd = File(exe).parent.path;
    scan = exe;
  } else if (program.toLowerCase().startsWith(r'c:\')) {
    scan = findCI(drive, program.substring(3).replaceAll(r'\', '/'));
    final folder = File(scan).parent;
    if (folder.existsSync()) cwd = folder.path;
  }
  final choice = await resolveBackend(
    home,
    dir,
    program,
    scan,
    option: backend,
  );
  final tag =
      label ??
      program
          .split(RegExp(r'[/\\]'))
          .last
          .replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final argv = [exe, ...args];
  final settings = _settings(dir);
  // The HUD saved for the program, or else asked for by this launch.
  final hudOn = hud || (settings.programs[_exeKey(program)]?.hud ?? false);
  final log = _newLog(
    dir,
    tag.length > 40 ? tag.substring(0, 40) : tag,
    rt,
    cwd,
    argv,
    backend: '${choice.name} (${choice.origin})',
  );
  await _start(
    rt,
    prefix,
    log,
    cwd,
    argv,
    detached: true,
    wrapper: hostPlatform.launchWrapper(gamemode: settings.gamemode),
    // Backend, then bottle, then program, then this launch (M8).
    extra: {
      ...backendEnv(home, choice.name, hud: hudOn),
      if (hudOn) ...hostPlatform.perfEnv(dir),
      if (settings.dlss) ..._dlssEnv,
      ...hostPlatform.gpuEnv(settings.gpu),
      ...settings.env,
      ...?settings.programs[_exeKey(program)]?.env,
      ...hostPlatform.syncEnv(settings.sync),
      ...env,
      ...extra,
    },
    remove: {if (!(avx ?? settings.avx)) 'ROSETTA_ADVERTISE_AVX'},
  );
  return log;
}

/// `wineserver -w`: returns when the bottle's last process is gone, or at
/// once if none runs (R11).
Future<int> waitBottle(String home, String name) async {
  final prefix = '${_existing(home, name)}/prefix';
  return _wineserver(currentRuntime(home), prefix, '-w');
}

/// `wineserver -k`; its 1 means there was no server, so it counts as 0 (R11).
Future<int> stopBottle(String home, String name) async {
  final prefix = '${_existing(home, name)}/prefix';
  // ponytail: no reaper; whatever survives -k (trap 6) stays, and acceptance
  // looks for it with pgrep.
  final code = await _wineserver(currentRuntime(home), prefix, '-k');
  return code == 1 ? 0 : code;
}

/// The program's exit code, from the `.exit` file that the launch script
/// renames into place (R14).
Future<int> exitOf(String log) async {
  final exitFile = File(log.replaceFirst(RegExp(r'\.log$'), '.exit'));
  // ponytail: no timeout; if the shell dies by SIGKILL there is no .exit and
  // `bodega run` waits until Ctrl-C.
  while (!exitFile.existsSync()) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return int.parse(exitFile.readAsStringSync().trim());
}

const _hints = {
  'cannot find the FreeType':
      'Wine no encuentra FreeType: reinstala el runtime con sus hostlibs',
  'ailed to load libgnutls':
      'Wine no carga GnuTLS: reinstala el runtime con sus hostlibs',
  'version mismatch':
      'hay un wineserver de otro runtime: bodega stop <botella>',
  'wine: failed to open':
      'Wine no pudo abrir el programa: revisa su ruta (trampa 11)',
};

/// One hint per marker found in [log] (R16), read as a stream so that a huge
/// log never sits in memory.
Future<List<String>> hintsIn(String log) async {
  final found = <String>{};
  final lines = File(log)
      .openRead()
      .transform(latin1.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    found.addAll(_hints.keys.where(line.contains));
  }
  return [
    for (final MapEntry(:key, :value) in _hints.entries)
      if (found.contains(key)) value,
  ];
}

String _existing(String home, String name) {
  final dir = bottleDir(home, name);
  if (!Directory(dir).existsSync()) throw 'no existe la botella $name';
  return dir;
}

/// Wine keeps the case a program gave each name, so a name from a `.lnk`, the
/// catalog or the user may differ from the disk. Returns the real path if it
/// finds one, else `root/relative`. Never follows a link: `dosdevices/z:`
/// points to `/`.
String findCI(String root, String relative) {
  final direct = '$root/$relative';
  if (FileSystemEntity.typeSync(direct, followLinks: false) !=
      FileSystemEntityType.notFound) {
    return direct;
  }
  var current = root;
  for (final segment in relative.split(RegExp(r'[/\\]'))) {
    if (segment.isEmpty) continue;
    if (!_isRealDirectory(current)) return direct;
    final wanted = segment.toLowerCase();
    final match = Directory(current)
        .listSync(followLinks: false)
        .where((entity) => entity.path.split('/').last.toLowerCase() == wanted)
        .firstOrNull;
    if (match == null) return direct;
    current = match.path;
  }
  return current;
}

bool _ready(String prefix) =>
    File('$prefix/drive_c/windows/syswow64/kernel32.dll').existsSync() &&
    File('$prefix/system.reg').existsSync();

/// Design §2: the shell stays alive (no `exec`) to append `# exit=N` and to
/// write the `.exit` file atomically.
const _launch =
    r'l=$1; shift; "$@" >>"$l" 2>&1 </dev/null; s=$?; '
    r'echo "# exit=$s" >>"$l"; '
    r'echo "$s" >"$l.x" && mv -f "$l.x" "${l%.log}.exit"; exit $s';

Future<Process> _start(
  String rt,
  String prefix,
  String log,
  String cwd,
  List<String> args, {
  bool detached = false,
  Map<String, String> extra = const {},
  Set<String> remove = const {},
  List<String> wrapper = const [],
}) => Process.start(
  '/bin/sh',
  ['-c', _launch, 'bodega', log, ...wrapper, '$rt/engine/bin/wine', ...args],
  workingDirectory: cwd,
  // [extra] can change a variable but not take one out: [remove] does (§7).
  environment: wineEnv(prefix, Platform.environment, extra)
    ..removeWhere((key, _) => remove.contains(key)),
  includeParentEnvironment: false,
  mode: detached ? ProcessStartMode.detached : ProcessStartMode.inheritStdio,
);

Future<int> _wineserver(String rt, String prefix, String flag) async {
  final server = await Process.start(
    '$rt/engine/bin/wineserver',
    [flag],
    environment: wineEnv(prefix, Platform.environment),
    includeParentEnvironment: false,
    mode: ProcessStartMode.inheritStdio,
  );
  return server.exitCode;
}

/// The official SDL2 release (zlib licence): its universal framework, from
/// which only the x86_64 part is kept. Checked: Wine loads it and maps an Xbox
/// pad through SDL (design §10).
const _sdl = (
  url:
      'https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/'
      'SDL2-2.32.10.dmg',
  sha256: '4a7ac31640d70214e848f994be8a12849c0f97918a7e6c2e27a40036166d1a7f',
);

/// Where Wine's winebus looks for SDL2: beside itself, as for FreeType.
String _sdlPath(String home) =>
    '${currentRuntime(home)}/engine/lib/wine/x86_64-unix/libSDL2-2.0.0.dylib';

/// Whether the current runtime has SDL2, so that gamepads go through it.
bool hasSdl(String home) =>
    hasRuntime(home) && File(_sdlPath(home)).existsSync();

/// Downloads the pinned SDL2, or takes [dmg], checks its SHA-256, and puts its
/// x86_64 part in the current runtime. Bottles switch to it on their next
/// launch. Returns where it went.
Future<String> installSdl(String home, {String? dmg}) async {
  if (!hostPlatform.capabilities.sdl) {
    throw 'SDL no disponible en ${hostPlatform.displayName}';
  }
  final dest = _sdlPath(home);
  final file = dmg ?? await _download(home, _sdl.url, _sdl.sha256);
  final got = await _sha256(file);
  if (got != _sdl.sha256) {
    throw 'checksum incorrecto en $file: $got, se esperaba ${_sdl.sha256}';
  }
  final mount = Directory.systemTemp.createTempSync('bodega-sdl');
  await _run('/usr/bin/hdiutil', [
    'attach',
    '-nobrowse',
    '-readonly',
    '-mountpoint',
    mount.path,
    file,
  ]);
  try {
    final framework = File('${mount.path}/SDL2.framework/Versions/A/SDL2');
    final slice = x86Slice(framework.readAsBytesSync());
    if (slice == null) throw 'SDL2 sin parte x86_64 en $file';
    // The part alone keeps the framework's signature, which names files it
    // no longer has beside it: Wine loads it anyway, but a local signature
    // leaves nothing to object to.
    File('$dest.tmp').writeAsBytesSync(slice);
    await _run('/usr/bin/codesign', ['--force', '--sign', '-', '$dest.tmp']);
    File('$dest.tmp').renameSync(dest);
  } finally {
    await _run('/usr/bin/hdiutil', ['detach', mount.path]);
    mount.deleteSync();
  }
  return dest;
}

/// The x86_64 part of a Mach-O, universal or not, or null if it has none.
Uint8List? x86Slice(Uint8List bytes) {
  if (bytes.length < 8) return null;
  final data = ByteData.sublistView(bytes);
  const x86_64 = 0x01000007;
  // A thin 64-bit Mach-O, little-endian.
  if (data.getUint32(0, Endian.little) == 0xfeedfacf) {
    return data.getUint32(4, Endian.little) == x86_64 ? bytes : null;
  }
  final magic = data.getUint32(0);
  if (magic != 0xcafebabe && magic != 0xcafebabf) return null;
  final wide = magic == 0xcafebabf;
  final entry = wide ? 32 : 20;
  final count = data.getUint32(4);
  for (var i = 0; i < count; i++) {
    final at = 8 + i * entry;
    if (at + entry > bytes.length) return null;
    if (data.getUint32(at) != x86_64) continue;
    final offset = wide ? data.getUint64(at + 8) : data.getUint32(at + 8);
    final size = wide ? data.getUint64(at + 16) : data.getUint32(at + 12);
    if (offset + size > bytes.length) return null;
    return bytes.sublist(offset, offset + size);
  }
  return null;
}

/// A new `logs/<UTC>-<label>.log` with the R15 header, which never includes
/// the environment.
String _newLog(
  String bottle,
  String label,
  String rt,
  String cwd,
  List<String> argv, {
  String? backend,
}) {
  final now = DateTime.now().toUtc();
  final iso = now.toIso8601String();
  // toIso8601String leaves the microseconds out when they are 000.
  final stamp = (now.microsecond == 0 ? iso.replaceFirst('Z', '000Z') : iso)
      .replaceAll(':', '-');
  // ponytail: no size cap or rotation; patch 0014 fixed the known runaway log
  // and fixme-all leaves only the err: lines.
  final log = File('$bottle/logs/$stamp-$label.log')
    ..createSync(exclusive: true)
    ..writeAsStringSync(
      '# runtime ${rt.split('/').last}\n'
      '${backend == null ? '' : '# backend $backend\n'}'
      '# cwd $cwd\n'
      '# argv ${argv.join(' ')}\n',
    );
  return log.path;
}

Future<String> _run(String exe, List<String> args, [String? cwd]) async {
  final result = await Process.run(exe, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    throw '$exe ${args.join(' ')} salió con ${result.exitCode}: '
        '${result.stdout}${result.stderr}';
  }
  return '${result.stdout}';
}

String _tag(String tarball) =>
    tarball.split('/').last.replaceFirst(RegExp(r'\.tar\.gz$'), '');

/// Whether this Mac can run x86_64 programs (E5).
Future<bool> rosettaInstalled() async {
  final result = await Process.run('/usr/bin/arch', [
    '-x86_64',
    '/usr/bin/true',
  ]);
  return result.exitCode == 0;
}

/// Like [currentRuntime], without the error (E5).
bool hasRuntime(String home) =>
    Directory('$home/runtimes/current').existsSync();

/// Stops the bottle and deletes its folder. `deleteSync` removes links without
/// following them, which matters because `dosdevices/z:` points to / (E4).
Future<void> removeBottle(String home, String name) async {
  final dir = _existing(home, name);
  if (hasRuntime(home)) {
    final rt = currentRuntime(home);
    await _wineserver(rt, '$dir/prefix', '-k');
    await _wineserver(rt, '$dir/prefix', '-w');
  }
  Directory(dir).deleteSync(recursive: true);
}

/// Renames `bottles/<from>` to `bottles/<to>`. The bottle must be stopped: its
/// processes carry the old prefix path. `rename` never follows links, so
/// `dosdevices/z:` stays a link (E4).
Future<void> renameBottle(String home, String from, String to) async {
  final target = bottleDir(home, to);
  final dir = _existing(home, from);
  if (Directory(target).existsSync()) throw 'ya existe la botella $to';
  if (hasRuntime(home) && await _serverRunning(home, dir)) {
    throw 'la botella $from está abierta: bodega stop $from';
  }
  Directory(dir).renameSync(target);
  await hostPlatform.prepareBottle(home, to);
}

/// `wineserver -w` returns at once when the bottle has no server, so one still
/// waiting after a second is running (as the app's watch assumes).
Future<bool> _serverRunning(String home, String dir) async {
  var ended = false;
  final wait = _wineserver(
    currentRuntime(home),
    '$dir/prefix',
    '-w',
  ).whenComplete(() => ended = true);
  await Future.any<void>([
    wait,
    Future<void>.delayed(const Duration(seconds: 1)),
  ]);
  return !ended;
}

typedef BottleLog = ({
  String path,
  String name,
  DateTime modified,
  int? exitCode,
});

/// The bottle's run logs, newest first (E7).
List<BottleLog> bottleLogs(String home, String name) {
  final dir = Directory('${_existing(home, name)}/logs');
  if (!dir.existsSync()) return [];
  return [
    for (final file in dir.listSync().whereType<File>())
      if (file.path.endsWith('.log'))
        (
          path: file.path,
          name: file.path.split('/').last,
          modified: file.lastModifiedSync(),
          exitCode: switch (File(
            file.path.replaceFirst(RegExp(r'\.log$'), '.exit'),
          )) {
            final exit when exit.existsSync() => int.tryParse(
              exit.readAsStringSync().trim(),
            ),
            _ => null,
          },
        ),
  ]..sort((a, b) => b.name.compareTo(a.name));
}
