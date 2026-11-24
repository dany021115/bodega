/// Bodega's engine: installs the Wine runtime, creates bottles and launches
/// programs in them.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'bodega_fixes_data.dart';
import 'catalog_data.dart';
import 'fixes_data.dart';
import 'probe_data.dart';

part 'apps.dart';
part 'backends.dart';
part 'catalog.dart';
part 'cli.dart';
part 'dependencies.dart';
part 'english.dart';
part 'failures.dart';
part 'fixes.dart';
part 'mach9.dart';
part 'processes.dart';
part 'platform.dart';
part 'platform_linux.dart';
part 'platform_mac.dart';
part 'gamepads.dart';
part 'runtimes.dart';
part 'switch.dart';

/// The data root (R1): `BODEGA_HOME`, or else the host's default, created and
/// canonical.
String bodegaHome(Map<String, String> env) {
  final dir = Directory(env['BODEGA_HOME'] ?? hostPlatform.defaultHome(env));
  // Also before creating it, so that a bad root is not left on disk.
  if (winPathProblem(dir.absolute.path) case final problem?) {
    throw BadWindowsPath(problem);
  }
  final home = (dir..createSync(recursive: true)).resolveSymbolicLinksSync();
  if (winPathProblem(home) case final problem?) throw BadWindowsPath(problem);
  for (final sub in ['runtimes', 'bottles']) {
    Directory('$home/$sub').createSync();
  }
  hostPlatform.prepareHome(home);
  return home;
}

/// Trap 11: Wine exits 53 when a path component ends in `.` or space or
/// contains `<>:"|?*`. Returns the first such component with the whole path,
/// or null. `.` and `..` only navigate, so they pass.
PathProblem? winPathProblem(String path) {
  final bad = path
      .split('/')
      .where((part) => part != '.' && part != '..')
      .where(RegExp(r'[<>:"|?*]|[. ]$').hasMatch)
      .firstOrNull;
  return bad == null ? null : (part: bad, path: path);
}

/// `bottles/<name>`, once [name] passes R8.
String bottleDir(String home, String name) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(name)) {
    throw BadBottleName(name);
  }
  return '$home/bottles/$name';
}

const _overrides = 'winemenubuilder.exe=d';

/// The whole environment of every process the engine starts (R12): nothing
/// else from [parent] gets in; [extra] is what the backend adds (S4). A Mach9
/// prefix gets design §4.3's Mach9 column (MG6): no Rosetta or .NET knobs, no
/// `WINEDLLOVERRIDES`, and the menu builder off through `WINE_COMPATDB`.
Map<String, String> wineEnv(
  String prefix,
  Map<String, String> parent, [
  Map<String, String> extra = const {},
]) {
  final dir = Directory(prefix).parent.path;
  final mach9 = _bottleRuntimeIn(dir) == RuntimeKind.mach9;
  return {
    ...hostPlatform.baseEnv(parent)
      ..removeWhere((key, _) => mach9 && _notOnMach9.contains(key)),
    // U2: Wine names the Windows user after USER. Every process of the bottle
    // gets it, or wineboot would make a profile for the host's name again.
    if (_settings(dir).user case final user when user.isNotEmpty) 'USER': user,
    'WINEPREFIX': prefix,
    if (mach9)
      'WINE_COMPATDB': _compatdbLine([
        ('exe', '*'),
        ('dll_overrides', _mach9MenuOverride),
      ])
    else
      'WINEDLLOVERRIDES': _overrides,
    // ER1: Mach9's SDL3 gives winedevice.exe, which has no window, no pad
    // input without it; winedevice inherits the session's first process's.
    if (mach9) 'SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS': '1',
    // ponytail: BODEGA_WINEDEBUG is the only knob read from the caller.
    'WINEDEBUG':
        parent['BODEGA_WINEDEBUG'] ??
        (mach9 ? _mach9WineDebug : hostPlatform.defaultWineDebug),
    ...extra,
  };
}

/// What the host's base environment sets for Rosetta's Wine only (MG6).
const _notOnMach9 = {
  'ROSETTA_ADVERTISE_AVX',
  'DOTNET_EnableWriteXorExecute',
  'MVK_CONFIG_LOG_LEVEL',
};

/// Mach9.app's own default, which also quiets dbghelp's readers.
const _mach9WineDebug =
    'fixme-all,-dbghelp_msc,-dbghelp_dwarf,-dbghelp_pdb,-dbghelp_macho';

/// What an installed runtime must contain (R5), for this host.
List<String> get requiredFiles => hostPlatform.requiredFiles;

/// Whether the host can run Windows programs, and what is missing (R10).
Future<List<HostIssue>> checkHost() => hostPlatform.checkHost();

/// The gamepads and what is wrong with them, or null where Bodega sets them up
/// itself (the Mac).
Future<GamepadReport?> checkGamepads() => hostPlatform.gamepads();

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
  if (dest.existsSync()) throw AlreadyInstalled(dest.path);
  for (final tarball in [engine, hostlibs]) {
    if (!File('$tarball.sha256').existsSync()) {
      throw ChecksumMissing('$tarball.sha256');
    }
    final name = tarball.split('/').last, dir = File(tarball).parent.path;
    // -c checks whatever file the .sha256 names, so it must name this one. It
    // exits 1 on a wrong hash, which is a mismatch too, not a failed tool.
    final (shasum, shaArgs) = hostPlatform.sha256Tool;
    final check = await Process.run(shasum, [
      ...shaArgs,
      '-c',
      '$name.sha256',
    ], workingDirectory: dir);
    if (check.exitCode != 0 || check.stdout != '$name: OK\n') {
      throw ChecksumMismatch(tarball);
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
        throw IncompleteArchive(id, file);
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
      throw ProcessFailed(
        'wine --version',
        null,
        '${version.stdout}${version.stderr}',
      );
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
  if (!current.existsSync()) throw const NoRuntime();
  return current.resolveSymbolicLinksSync();
}

/// Builds `bottles/<name>` with a plain `wine wineboot`, whose automatic
/// `--init` creates the prefix, then waits for the server to save the
/// registry (R9, R10, design §5). Returns the log. [runtime] is fixed for the
/// bottle's life (MB5); [mono] and [onStep] serve Mach9 bottles.
Future<String> createBottle(
  String home,
  String name, {
  RuntimeKind runtime = RuntimeKind.bodega,
  bool mono = true,
  void Function(BottleStep step)? onStep,
}) async {
  final dir = bottleDir(home, name);
  final mach9 = runtime == RuntimeKind.mach9;
  if (mach9) {
    if (hostPlatform.mach9Block case final block?) {
      throw RuntimeUnavailable(runtime, block);
    }
  }
  final rt = runtimeDir(home, runtime);
  if (Directory(dir).existsSync()) throw BottleExists(name);
  Directory('$dir/logs').createSync(recursive: true);
  // Before wineboot: wineEnv gives a Mach9 prefix its own environment (MB5).
  if (mach9) _saveSettings(dir, _with(_settings(dir), runtime: runtime));
  // ER7: a new Rosetta bottle on the Mac follows the display, as Mach9's do.
  if (!mach9 && hostPlatform is MacPlatform) {
    _saveSettings(dir, _with(_settings(dir), retina: 'auto'));
  }
  final prefix = '$dir/prefix';
  onStep?.call(BottleStep.prefix);
  final log = _newLog(dir, 'wineboot', rt, dir, ['wineboot']);
  final wineboot = await _start(rt, prefix, log, dir, ['wineboot']);
  final code = await wineboot.exitCode;
  if (code != 0) {
    await _wineserver(rt, prefix, '-k');
    throw WineToolFailed(WineTool.wineboot, code, log);
  }
  await _wineserver(rt, prefix, '-w').timeout(
    const Duration(minutes: 10),
    onTimeout: () async {
      await _wineserver(rt, prefix, '-k');
      throw BottleSetupFailed(log, true);
    },
  );
  // ponytail: syswow64 is not repaired (Highball copies i386-windows); in a
  // prototype that failure has to show.
  if (!_ready(prefix)) throw BottleSetupFailed(log, false);
  await _prepareBottle(home, name);
  if (mach9) {
    for (final value in _mach9Registry) {
      final reg = await _launchIn(home, name, 'reg', [
        'add',
        value.key,
        '/v',
        value.name,
        '/t',
        value.type,
        '/d',
        value.data,
        '/f',
      ], backend: 'wine');
      final code = await exitOf(reg);
      if (code != 0) throw WineToolFailed(WineTool.reg, code, reg);
    }
    // PE5: the values reach user.reg when the session ends, and the next one
    // boots with them in place.
    await _wineserver(rt, prefix, '-w');
    if (mono) {
      onStep?.call(BottleStep.mono);
      await installMono(home, name);
    }
  }
  return log;
}

/// What a Mach9 prefix gets at creation (MB6), as Mach9.app sets it: no crash
/// dialog nobody can see, and mode changes emulated for full-screen games.
const _mach9Registry = [
  (
    key: r'HKCU\Software\Wine\WineDbg',
    name: 'ShowCrashDialog',
    type: 'REG_DWORD',
    data: '0',
  ),
  (
    key: r'HKCU\Software\Wine\X11 Driver',
    name: 'EmulateModeset',
    type: 'REG_SZ',
    data: 'Y',
  ),
];

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
  await _prepareBottle(home, name);
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

/// Where [program] runs from: the exe Wine gets, its folder, and the file
/// [exeGraphics] reads (null for a program without a path, like `reg`).
({String exe, String cwd, String? scan}) _programPaths(
  String drive,
  String program,
) {
  if (program.contains('/')) {
    final exe = File(program).resolveSymbolicLinksSync();
    if (winPathProblem(exe) case final problem?) throw BadWindowsPath(problem);
    return (exe: exe, cwd: File(exe).parent.path, scan: exe);
  }
  if (program.toLowerCase().startsWith(r'c:\')) {
    final scan = findCI(drive, program.substring(3).replaceAll(r'\', '/'));
    final folder = File(scan).parent;
    return (
      exe: program,
      cwd: folder.existsSync() ? folder.path : drive,
      scan: scan,
    );
  }
  return (exe: program, cwd: drive, scan: null);
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
  GameFix? fix,
  String? note,
  String? appKey,
  List<String> dllOverrides = const [],
}) async {
  final dir = _existing(home, name);
  final kind = _bottleRuntimeIn(dir);
  final mach9 = kind == RuntimeKind.mach9;
  if (mach9) {
    if (hostPlatform.mach9Block case final block?) {
      throw RuntimeUnavailable(kind, block);
    }
  }
  final rt = runtimeDir(home, kind);
  final prefix = '$dir/prefix';
  final drive = '$prefix/drive_c';
  if (!_ready(prefix)) throw BottleNotReady(name);
  final (:exe, :cwd, :scan) = _programPaths(drive, program);
  final choice = await resolveBackend(
    home,
    dir,
    program,
    scan,
    option: backend,
    config: fix?.backend,
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
  final key = _exeKey(program);
  final more = [
    if (!_ownRuns.contains(key)) ...[
      // ER7: retina before the session on both engines.
      ...await _syncRetina(home, name, dir, rt, settings.retina),
      if (mach9) ...await _syncGamepads(home, name, dir, rt),
    ],
  ];
  // The HUD saved for the program, or else asked for by this launch.
  final hudOn = hud || (settings.programs[key]?.hud ?? false);
  final allSteps = fix?.active ?? const <FixStep>[];
  final steps = _stepsFor(kind, allSteps);
  final skipped = [
    for (final step in allSteps)
      if (!steps.contains(step)) step.name!,
  ]..sort();
  if (skipped.isNotEmpty) more.add('skipped ${skipped.join(', ')}');
  final overrides = [
    for (final step in steps)
      if (step.type == 'dlloverride') step.value!,
  ];
  // Mach9 takes the graphics, the HUD and the DLL overrides as rules (MG5).
  final rules = mach9
      ? _mach9Rules(
          settings,
          key,
          choice,
          optionGiven: backend != null,
          hud: hudOn,
          overrides: [...overrides, ...dllOverrides],
          appKey: appKey,
        )
      : null;
  final log = _newLog(
    dir,
    tag.length > 40 ? tag.substring(0, 40) : tag,
    rt,
    cwd,
    argv,
    backend: '${choice.name} (${choice.origin})',
    note: note,
    rules: rules?.join(' | '),
    more: more,
  );
  final programEnv = settings.programs[key]?.env ?? const <String, String>{};
  final userEnv = {...settings.env, ...programEnv, ...env};
  if (mach9) Directory('$dir/cache/vkd3d').createSync(recursive: true);
  // Backend, then the game's fix, then bottle, program and this launch (M8, F3).
  final launchEnv = {
    if (!mach9) ...backendEnv(home, choice.name, hud: hudOn),
    if (!mach9 && choice.name == 'dxvk')
      ...hostPlatform.dxvkEnv(dir, async: settings.dxvkAsync),
    if (!mach9 && hudOn) ...hostPlatform.perfEnv(dir),
    if (!mach9 && settings.dlss) ..._dlssEnv,
    // ER8: D3DMetal's Metal 4, only where D3DMetal draws.
    if (!mach9 && settings.metal4 && choice.name == 'd3dmetal')
      'D3DM_MTL4': '1',
    if (mach9) 'VKD3D_SHADER_CACHE_PATH': '$dir/cache/vkd3d',
    ...hostPlatform.gpuEnv(settings.gpu),
    for (final step in steps)
      if (step.type == 'env')
        if (fixValue(step.value!) case final value?) step.name!: value,
    ...settings.env,
    ...programEnv,
    ...hostPlatform.syncEnv(settings.sync),
    ...env,
    ...extra,
  };
  if (rules != null) {
    // The user's own rules come after Bodega's, so that theirs win (MG9).
    launchEnv['WINE_COMPATDB'] = [
      ...rules,
      ?userEnv['WINE_COMPATDB'],
    ].join('\n');
  } else if (overrides.isNotEmpty) {
    launchEnv['WINEDLLOVERRIDES'] =
        '${launchEnv['WINEDLLOVERRIDES'] ?? _overrides};${overrides.join(';')}';
  }
  final process = await _start(
    rt,
    prefix,
    log,
    cwd,
    argv,
    detached: true,
    wrapper: hostPlatform.launchWrapper(gamemode: settings.gamemode),
    extra: launchEnv,
    remove: {if (mach9 || !(avx ?? settings.avx)) 'ROSETTA_ADVERTISE_AVX'},
  );
  // The pid is the run's process group too: stopApp and runningApps read it
  // here. The third line, the program's file name, follows a game that
  // relaunches itself (ER4).
  if (appKey != null) {
    File(log.replaceFirst(RegExp(r'\.log$'), '.pid'))
        .writeAsStringSync('${process.pid}\n$appKey\n$key\n');
  }
  return log;
}

/// Bodega's own headless runs, which never wait for the retina values (PE4):
/// the `reg add` that writes them is one.
const _ownRuns = {
  'reg.exe',
  'wineboot.exe',
  'msiexec.exe',
  'regsvr32.exe',
  'extrac32.exe',
  'cmd.exe',
  'winecfg.exe',
};

/// PE4, ER7: `RetinaMode` and `LogPixels` as the bottle's retina [mode] wants them,
/// written before the session boots, since Wine reads them only then (Mach9's
/// `registry.rs`, `session.rs`). A running session keeps its own: stopping it
/// would stop a game. Returns the log header's lines.
Future<List<String>> _syncRetina(
  String home,
  String name,
  String dir,
  String rt,
  String mode,
) async {
  final on = switch (mode) {
    'on' => true,
    'off' => false,
    _ => hostPlatform.mainDisplayHiDpi(),
  };
  final header = 'retina ${on ? 'on' : 'off'} ($mode)';
  final (:retina, :dpi) = _userRegRetina('$dir/prefix/user.reg');
  // Only what this platform writes: Linux has no RetinaMode (ER7).
  final written = hostPlatform.highResRegistry(on);
  final inPlace = written.every(
    (value) => switch (value[1]) {
      'RetinaMode' => retina == (value[3] == 'y'),
      'LogPixels' => dpi == int.parse(value[3]),
      _ => true,
    },
  );
  if (inPlace) return [header];
  if (await _serverRunning(rt, dir)) {
    return [header, 'retina waits for the next session'];
  }
  for (final args in written) {
    final log = await _launchIn(
      home,
      name,
      'reg',
      ['add', args[0], '/v', args[1], '/t', args[2], '/d', args[3], '/f'],
      backend: 'wine',
      label: 'retina',
    );
    final code = await exitOf(log);
    if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
  }
  // The `reg add` booted a session with the old values: end it.
  await _wineserver(rt, '$dir/prefix', '-k');
  await _wineserver(rt, '$dir/prefix', '-w');
  return [header];
}

/// ER1, D7: Mach9's SDL3 pads. Its Wine takes an Xbox pad raw from IOHID,
/// with the wrong controls, unless `DisableHidraw` gives it to SDL (measured
/// on 2026-11-23 with an Xbox One S pad, 045e:02fd). Written before a session
/// boots, as retina is; a running one keeps its own. Returns the log header's
/// lines.
Future<List<String>> _syncGamepads(
  String home,
  String name,
  String dir,
  String rt,
) async {
  final values = _winebusValues('$dir/prefix/system.reg');
  final missing = [
    for (final (value, data) in _mach9Winebus)
      if (values[value.toLowerCase()] != data) (value, data),
  ];
  if (missing.isEmpty) return const [];
  if (await _serverRunning(rt, dir)) {
    return ['pads wait for the next session'];
  }
  for (final (value, data) in missing) {
    final log = await _launchIn(
      home,
      name,
      'reg',
      [
        'add',
        r'HKLM\System\CurrentControlSet\Services\WineBus',
        '/v',
        value,
        '/t',
        'REG_DWORD',
        '/d',
        '$data',
        '/f',
      ],
      backend: 'wine',
      label: 'pads',
    );
    final code = await exitOf(log);
    if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
  }
  // As for retina: the `reg add` booted a session with the old values.
  await _wineserver(rt, '$dir/prefix', '-k');
  await _wineserver(rt, '$dir/prefix', '-w');
  _saveSettings(dir, _with(_settings(dir), gamepads: 3));
  return ['pads sdl3'];
}

/// The `winebus` values a Mach9 bottle needs for SDL3 pads (ER1).
const _mach9Winebus = [
  ('DisableHidraw', 1),
  ('Enable SDL', 1),
  ('DisableInput', 0),
];

/// The dword values under `winebus` in `system.reg`, by lower-cased name.
Map<String, int> _winebusValues(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final values = <String, int>{};
  var inside = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('[')) {
      inside = line.toLowerCase().startsWith(
        r'[system\\controlset001\\services\\winebus]',
      );
    } else if (inside) {
      if (RegExp(r'^"([^"]+)"=dword:([0-9a-fA-F]+)').firstMatch(line)
          case final m?) {
        values[m.group(1)!.toLowerCase()] = int.parse(m.group(2)!, radix: 16);
      }
    }
  }
  return values;
}

/// What `user.reg` holds for retina mode and the system DPI; Wine's defaults,
/// off and 96, where a value is missing (design §2).
({bool retina, int dpi}) _userRegRetina(String path) {
  final file = File(path);
  if (!file.existsSync()) return (retina: false, dpi: 96);
  var retina = false;
  var dpi = 96;
  String? section;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('[')) {
      section = line.substring(1, line.indexOf(']')).toLowerCase();
    } else if (section == r'software\\wine\\mac driver' &&
        line.startsWith('"RetinaMode"=')) {
      retina = line.toLowerCase().contains('"y');
    } else if (section == r'control panel\\desktop' &&
        line.startsWith('"LogPixels"=dword:')) {
      dpi = int.tryParse(line.split(':').last.trim(), radix: 16) ?? 96;
    }
  }
  return (retina: retina, dpi: dpi);
}

/// `wineserver -w`: returns when the bottle's last process is gone, or at
/// once if none runs (R11).
Future<int> waitBottle(String home, String name) async {
  final dir = _existing(home, name);
  final rt = _serverRuntime(home, dir);
  return rt == null ? 0 : _wineserver(rt, '$dir/prefix', '-w');
}

/// `wineserver -k`; its 1 means there was no server, so it counts as 0 (R11).
/// Whatever survives it, or has no server left to end it, ends next (ER3).
Future<int> stopBottle(String home, String name) async {
  final dir = _existing(home, name);
  final rt = _serverRuntime(home, dir);
  final code = rt == null ? 1 : await _wineserver(rt, '$dir/prefix', '-k');
  await _reap('$dir/prefix');
  return code == 1 ? 0 : code;
}

/// The runtime whose wineserver serves the bottle in [dir] (MB3): null for a
/// Mach9 bottle while Mach9 is not installed, since no server of it can run;
/// a bodega bottle without `current` still throws [NoRuntime].
String? _serverRuntime(String home, String dir) {
  final kind = _bottleRuntimeIn(dir);
  try {
    return runtimeDir(home, kind);
  } on RuntimeNotInstalled {
    return null;
  }
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

/// What a run's log can show that the user can act on (R16). Each hint holds
/// the marker that [hintsIn] looks for in a line, and its English text.
enum LogHint {
  /// Wine cannot find FreeType: the runtime lacks its hostlibs.
  freeType(
    'cannot find the FreeType',
    'Wine cannot find FreeType: reinstall the runtime with its hostlibs',
  ),

  /// Wine cannot load GnuTLS: the runtime lacks its hostlibs. The marker
  /// leaves out the F, which Wine writes in either case.
  gnuTls(
    'ailed to load libgnutls',
    'Wine cannot load GnuTLS: reinstall the runtime with its hostlibs',
  ),

  /// A wineserver of another runtime holds the bottle.
  otherServer(
    'version mismatch',
    'a wineserver from another runtime is running: bodega stop <bottle>',
  ),

  /// Wine could not open the program, as when a name in its path breaks
  /// trap 11.
  cannotOpen(
    'wine: failed to open',
    'Wine could not open the program: check its path, where Windows refuses '
        'a name that ends in a dot or a space, or holds <>:"|?* (trap 11)',
  ),

  /// Steam was already open, so the fix of the game did not reach it:
  /// Bodega's own note, [fixNotApplied].
  fixNotApplied(
    _fixNote,
    "Steam was already open, so this game's fix did not reach it. Stop the "
    'bottle and open the game again from Bodega.',
  ),

  /// A .NET program in a Mach9 bottle without Wine Mono.
  monoMissing(
    'Wine Mono is not installed',
    'the program needs Wine Mono: bodega mono install <bottle>',
  ),

  /// Mach9's compatdb dropped a line of `WINE_COMPATDB`.
  rulesIgnored(
    'warning: WINE_COMPATDB line',
    'Mach9 ignored a rule Bodega sent: report it with this log',
  ),

  /// Mach9's loader refused to start outside its signed wine.app.
  loaderNotSigned(
    'the loader must run from the signed wine.app',
    "Mach9's copy is damaged or this macOS cannot run it: bodega runtime "
        'install mach9',
  ),

  /// Wine's `RtlpWaitForCriticalSection` waited 60 s for a lock that no
  /// thread frees: the program seems stuck (ER5).
  stuckLock(
    'wait timed out in thread',
    'the program seems stuck, waiting on a lock: close it, and on the Native '
        'engine try the Rosetta engine',
  );

  const LogHint(this.marker, this.english);

  /// What a line of the log holds when this hint applies.
  final String marker;

  /// For the CLI and logs.
  final String english;
}

/// The hints whose markers [log] holds, once each and in the order of
/// [LogHint] (R16), read as a stream so that a huge log never sits in memory.
Future<List<LogHint>> hintsIn(String log) async {
  final found = <LogHint>{};
  final lines = File(log)
      .openRead()
      .transform(latin1.decoder)
      .transform(const LineSplitter());
  await for (final line in lines) {
    found.addAll(LogHint.values.where((hint) => line.contains(hint.marker)));
  }
  return LogHint.values.where(found.contains).toList();
}

String _existing(String home, String name) {
  final dir = bottleDir(home, name);
  if (!Directory(dir).existsSync()) throw BottleNotFound(name);
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
/// pad through SDL (design §10). 2.30.12, as CrossOver's: with 2.32.10 an Xbox
/// One S pad had up and down swapped in Blur, measured on 2026-11-09.
const _sdl = (
  url:
      'https://github.com/libsdl-org/SDL/releases/download/release-2.30.12/'
      'SDL2-2.30.12.dmg',
  sha256: 'a8fcd488a8062f632bacd7a74dbbb5f585f3b0303ccf08384ac0349eccd8420d',
);

/// Where Wine's winebus looks for SDL2 in a runtime: beside itself, as for
/// FreeType.
const _sdlInRuntime = 'engine/lib/wine/x86_64-unix/libSDL2-2.0.0.dylib';

String _sdlPath(String home) => '${currentRuntime(home)}/$_sdlInRuntime';

/// Whether `current` is a Wine that can take SDL2: one with x86_64 unix
/// modules (MB4).
bool _takesSdl(String home) =>
    hasRuntime(home) &&
    Directory(File(_sdlPath(home)).parent.path).existsSync();

/// Whether the current runtime has SDL2, so that gamepads go through it.
bool hasSdl(String home) =>
    hasRuntime(home) && File(_sdlPath(home)).existsSync();

/// Downloads the pinned SDL2, or takes [dmg], checks its SHA-256, and puts its
/// x86_64 part in the current runtime. Bottles switch to it on their next
/// launch. Returns where it went. Does nothing when `current` has no
/// x86_64 unix modules (MB4).
Future<String> installSdl(String home, {String? dmg}) async {
  if (!hostPlatform.capabilities.sdl) {
    throw NotAvailable('SDL', hostPlatform.displayName);
  }
  final dest = _sdlPath(home);
  // A runtime without x86_64 unix modules has no winebus to give it to.
  if (!_takesSdl(home)) return dest;
  final file = dmg ?? await _download(home, _sdl.url, _sdl.sha256);
  if (await sha256Of(file) != _sdl.sha256) throw ChecksumMismatch(file);
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
    if (slice == null) throw IncompleteArchive(file, 'SDL2.framework (x86_64)');
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
  String? note,
  String? rules,
  List<String> more = const [],
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
      '# argv ${argv.join(' ')}\n'
      '${note == null ? '' : '# note $note\n'}'
      '${[for (final line in more) '# $line\n'].join()}'
      '${rules == null ? '' : '# rules $rules\n'}',
    );
  return log.path;
}

Future<String> _run(String exe, List<String> args, [String? cwd]) async {
  final result = await Process.run(exe, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    throw ProcessFailed(
      '$exe ${args.join(' ')}',
      result.exitCode,
      '${result.stdout}${result.stderr}',
    );
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
  if (_installedRuntime(home, dir) case final rt?) {
    await _wineserver(rt, '$dir/prefix', '-k');
    await _wineserver(rt, '$dir/prefix', '-w');
  }
  // ER3: a process the server no longer reaches would outlive the folder.
  await _reap('$dir/prefix');
  Directory(dir).deleteSync(recursive: true);
}

/// Renames `bottles/<from>` to `bottles/<to>`. The bottle must be stopped: its
/// processes carry the old prefix path. `rename` never follows links, so
/// `dosdevices/z:` stays a link (E4).
Future<void> renameBottle(String home, String from, String to) async {
  final target = bottleDir(home, to);
  final dir = _existing(home, from);
  if (Directory(target).existsSync()) throw BottleExists(to);
  if (_installedRuntime(home, dir) case final rt?
      when await _serverRunning(rt, dir)) {
    throw BottleOpen(from);
  }
  Directory(dir).renameSync(target);
  await _prepareBottle(home, to);
}

/// The bottle's runtime, or null when it is not installed (MB3).
String? _installedRuntime(String home, String dir) {
  try {
    return runtimeDir(home, _bottleRuntimeIn(dir));
  } on NoRuntime {
    return null;
  } on RuntimeNotInstalled {
    return null;
  }
}

/// [hostPlatform]'s preparation of a bottle (gamepads, layers), which only
/// Rosetta's Wine needs: a Mach9 bottle gets none (MB4).
Future<void> _prepareBottle(String home, String name) async {
  if (bottleRuntime(home, name) == RuntimeKind.mach9) return;
  await hostPlatform.prepareBottle(home, name);
}

/// `wineserver -w` returns at once when the bottle has no server, so one still
/// waiting after a second is running (as the app's watch assumes).
Future<bool> _serverRunning(String rt, String dir) async {
  var ended = false;
  final wait = _wineserver(
    rt,
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
