part of 'engine.dart';

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

/// The Mac: Wine under Rosetta 2, with MoltenVK, DXMT and D3DMetal.
class MacPlatform extends HostPlatform {
  /// [bundle] replaces the bundle detection, for tests.
  const MacPlatform({this.bundle});

  final String? bundle;

  @override
  String get displayName => 'Mac';

  @override
  String get id => 'mac';

  @override
  String defaultHome(Map<String, String> env) =>
      '${env['HOME']!}/Library/Application Support/Bodega';

  @override
  void prepareHome(String home) {
    final root =
        bundle ??
        Platform.environment['BODEGA_BUNDLE'] ??
        '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/bundle';
    // shortcut: the copy is synchronous and runs once; if a big runtime makes
    // the first start slow, move it to a step with progress.
    _registerBundled(home, root, copy: true, afterCopy: _stripQuarantine);
    _syncSdl(home, root);
    _bundleCurrentWine(home);
  }

  /// Game Mode for the runtime in use, once no Wine process of it runs:
  /// moving its folder under a running session would strand the processes it
  /// starts. Best effort: a failure is tried again at the next start.
  void _bundleCurrentWine(String home) {
    final current = Directory('$home/runtimes/current');
    if (!current.existsSync()) return;
    try {
      final real = current.resolveSymbolicLinksSync();
      if (FileSystemEntity.isLinkSync('$real/engine/lib/wine/x86_64-unix') &&
          File(_winePlistPath('$real/engine')).existsSync()) {
        return;
      }
      final busy = _wineFiles().any(
        (wine) => wine.names.any((name) => name.startsWith('$real/')),
      );
      if (!busy) bundleWineForGameMode('$real/engine');
    } on FileSystemException {
      // Left as it is; the next start tries again.
    } on ProcessException {
      // No ps or lsof: nothing tells whether it runs, so it waits.
    }
  }

  /// SDL2 lives inside a runtime, and a runtime is copied only when it is
  /// missing: one installed from a tarball has none, and an older one may have
  /// another version, whose pad controls can be wrong. The bundle's SDL2 goes
  /// into the runtime in use whenever it differs (design §10).
  void _syncSdl(String home, String root) {
    if (!_takesSdl(home)) return;
    final source = [
      for (final id in _subdirs('$root/runtime'))
        if (File('$root/runtime/$id/$_sdlInRuntime') case final file
            when file.existsSync())
          file,
    ].firstOrNull;
    if (source == null) return;
    final target = File(_sdlPath(home));
    if (target.existsSync() &&
        _sameBytes(source.readAsBytesSync(), target.readAsBytesSync())) {
      return;
    }
    source.copySync('${target.path}.tmp');
    File('${target.path}.tmp').renameSync(target.path);
    _stripQuarantine(target.path);
  }

  @override
  Map<String, String> baseEnv(Map<String, String> parent) => {
    for (final key in const [
      'HOME',
      'USER',
      'LOGNAME',
      'TMPDIR',
      '__CF_USER_TEXT_ENCODING',
    ])
      if (parent[key] case final value?) key: value,
    'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
    'WINEMSYNC': '1',
    'ROSETTA_ADVERTISE_AVX': '1',
    'DOTNET_EnableWriteXorExecute': '0',
    'MVK_CONFIG_LOG_LEVEL': '2',
  };

  /// What an installed runtime must contain (R5): the six files of
  /// `HBK/EngineStore.swift#L637-L646` plus the two host libraries.
  @override
  List<String> get requiredFiles => const [
    'engine/bin/wine',
    'engine/bin/wineserver',
    'engine/lib/wine/x86_64-windows/kernel32.dll',
    'engine/lib/wine/x86_64-windows/ntdll.dll',
    'engine/lib/wine/i386-windows/kernel32.dll',
    'engine/lib/wine/x86_64-unix/ntdll.so',
    'engine/lib/wine/x86_64-unix/libfreetype.6.dylib',
    'engine/lib/wine/x86_64-unix/libgnutls.30.dylib',
  ];

  @override
  String tool(String name) => '/usr/bin/$name';

  @override
  (String, List<String>) get sha256Tool => ('/usr/bin/shasum', ['-a', '256']);

  @override
  Future<void> afterExtract(String dir) async {
    await Process.run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', dir]);
    // A runtime, not a backend: Game Mode before anything runs from it.
    if (Directory('$dir/engine/lib/wine/x86_64-unix').existsSync()) {
      bundleWineForGameMode('$dir/engine');
    }
  }

  @override
  Future<GamepadReport?> gamepads() async => null;

  @override
  EmulatorHost get emulators => const MacEmulators();

  @override
  Future<List<HostIssue>> checkHost() async => [
    if (!(await rosettaInstalled()))
      (
        kind: HostIssueKind.noRosetta,
        subject: null,
        command: 'softwareupdate --install-rosetta --agree-to-license',
      ),
  ];

  @override
  HostCapabilities get capabilities => (
    highRes: true,
    retina: true,
    avx: true,
    dlss: true,
    d3dmetal: true,
    sdl: true,
    gpu: false,
    gameMode: false,
    syncModes: const ['msync', 'none'],
    switchGames: emulators.supported,
    dxvkAsync: true,
  );

  @override
  String get defaultSync => 'msync';

  @override
  Map<String, String> syncEnv(String mode) =>
      mode == 'none' ? const {'WINEMSYNC': '0'} : const {};

  /// The Mac's DXVK is an async build (`v1.10.3-20230507-async`): it reads
  /// `DXVK_ASYNC`, and keeps its shader state cache where
  /// `DXVK_STATE_CACHE_PATH` says, which is the bottle's own `dxvk-cache` as
  /// a Windows path, since DXVK opens it from inside Wine (RE8). The folder is
  /// made here, as DXVK makes none.
  @override
  Map<String, String> dxvkEnv(String dir, {required bool async}) {
    Directory('$dir/dxvk-cache').createSync(recursive: true);
    return {
      'DXVK_STATE_CACHE_PATH': 'Z:${'$dir/dxvk-cache'.replaceAll('/', r'\')}',
      if (async) 'DXVK_ASYNC': '1',
    };
  }

  @override
  List<String> get backendNames => const [
    'wine',
    'dxmt',
    'dxvk',
    'dxvk9',
    'd3dmetal',
  ];

  @override
  Map<String, ({String url, String sha256})> get pinnedBackends => _pinned;

  @override
  ({String dir, String file}) get layerCheck =>
      (dir: 'x86_64-windows', file: 'x86_64-windows/d3d11.dll');

  /// What [wineEnv] gains for [backend] (S4): one layer in front of Wine's own
  /// DLLs per process, with nothing copied into the prefix (design §1).
  @override
  Map<String, String> backendEnv(
    String home,
    String backend, {
    bool hud = false,
  }) => {
    'CX_ACTIVE_GRAPHICS_BACKEND': switch (backend) {
      'wine' => 'wined3d',
      'dxvk9' => 'dxvk',
      _ => backend,
    },
    ...switch (backend) {
      'dxmt' => {'WINEDLLPATH_PREPEND': _layer(home, 'dxmt'), ..._crossProcess},
      'dxvk' => {
        'WINEDLLPATH_PREPEND': _layer(home, 'dxvk'),
        'WINEDLLOVERRIDES': '$_overrides;d3d10core,d3d11=n,b',
      },
      'dxvk9' => {
        // DXVK's d3d9 first, and DXMT behind it for D3D10/11: a launcher
        // such as Plutonium's draws with D3D11 and starts a D3D9 game.
        'WINEDLLPATH_PREPEND': [
          _layer(home, 'dxvk9'),
          if (_installed(home, 'dxmt')) _layer(home, 'dxmt'),
        ].join(':'),
        // Apple GPUs lack features DXVK requires, geometry shaders among
        // them; the layer's patch turns those into warnings (relaxed features).
        'DXVK_RELAX_FEATURES': '1',
        // DXVK logs to stderr, which is the run's log, and not next to the game.
        'DXVK_LOG_PATH': 'none',
        if (_installed(home, 'dxmt')) ..._crossProcess,
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

  /// S3, from what [exeGraphics] finds in the exe.
  @override
  Future<String> autoBackend(String home, String? exePath) async {
    final exe = exePath == null ? null : await exeGraphics(exePath);
    return switch (exe?.directx) {
      'DX12' =>
        exe!.bits == 64 && _installed(home, 'd3dmetal') ? 'd3dmetal' : 'wine',
      'DX11' || 'DX10' =>
        ['dxmt', 'dxvk'].where((b) => _installed(home, b)).firstOrNull ??
            'wine',
      _ => 'wine',
    };
  }

  /// G3: what each layer translates. DXVK-macOS has no d3d9 and D3DMetal no
  /// 32-bit DX12; dxvk9 is DXVK's d3d9 with DXMT behind it for DX10 and 11.
  @override
  bool backendFits(String backend, ExeGraphics exe) =>
      exe.directx.isEmpty ||
      switch (backend) {
        'd3dmetal' =>
          exe.bits == 64 && (exe.directx == 'DX11' || exe.directx == 'DX12'),
        'dxmt' || 'dxvk' => exe.directx == 'DX10' || exe.directx == 'DX11',
        'dxvk9' => exe.directx != 'DX12',
        _ => true,
      };

  @override
  BackendRole backendRole(String backend) => switch (backend) {
    'd3dmetal' => BackendRole.dx11to12x64,
    'dxmt' || 'dxvk' => BackendRole.dx10to11,
    'dxvk9' => BackendRole.dx9to11,
    _ => BackendRole.everythingElse,
  };

  @override
  String mapBackend(String name) => name;

  @override
  List<(int, String)> probeCases(String home, String backend) =>
      switch (backend) {
        'wine' => [(64, '11'), (64, '12')],
        'd3dmetal' => [
          (64, '11'),
          (64, '12'),
          if (_installed(home, 'dxmt')) (32, '11'),
        ],
        'dxvk9' => [
          (32, '9'),
          (64, '9'),
          if (_installed(home, 'dxmt')) (32, '11'),
        ],
        _ => [(64, '11'), (32, '11')],
      };

  @override
  Future<void> prepareBottle(String home, String name) =>
      _ensureGamepads(home, name);

  @override
  bool mainDisplayHiDpi() => _mainDisplayHiDpi();

  @override
  List<List<String>> highResRegistry(bool value) => [
    [
      r'HKCU\Software\Wine\Mac Driver',
      'RetinaMode',
      'REG_SZ',
      value ? 'y' : 'n',
    ],
    [
      r'HKCU\Control Panel\Desktop',
      'LogPixels',
      'REG_DWORD',
      value ? '192' : '96',
    ],
  ];

  @override
  Map<String, String> gpuEnv(String gpu) => const {};

  @override
  List<String> launchWrapper({required bool gamemode}) => const [];

  @override
  bool get defaultGamemode => false;

  @override
  String get defaultWineDebug => 'fixme-all';

  @override
  Map<String, String> perfEnv(String bottleDir) => const {};

  @override
  RuntimeBlock? get mach9Block => (_mach9Block ??= (_readMach9Block(),)).$1;

  @override
  Future<String> signingTeam(String path, {bool deep = false}) async {
    final verify = await Process.run('/usr/bin/codesign', [
      '--verify',
      '--strict',
      if (deep) '--deep',
      path,
    ]);
    if (verify.exitCode != 0) {
      throw RuntimeNotTrusted(path, '${verify.stdout}${verify.stderr}'.trim());
    }
    // -dv writes what it displays to stderr.
    final display = await Process.run('/usr/bin/codesign', ['-dv', path]);
    final team = RegExp(
      r'^TeamIdentifier=(\S+)$',
      multiLine: true,
    ).firstMatch('${display.stdout}${display.stderr}')?.group(1);
    if (display.exitCode != 0 || team == null) {
      throw RuntimeNotTrusted(path, 'no Team ID in its signature');
    }
    return team;
  }

  /// ditto clones on APFS, keeps links and dates, and with `--noqtn` leaves no
  /// quarantine on the copy (D6).
  @override
  Future<void> copyTree(String from, String to) async {
    await _run('/usr/bin/ditto', ['--noqtn', from, to]);
  }

  @override
  List<String> get applicationDirs => [
    '/Applications',
    if (Platform.environment['HOME'] case final home?) '$home/Applications',
  ];

  /// Every Wine process of the prefix has its server folder open, as its
  /// working folder, or mapped (`tmpmap-*`): `lsof -p` shows both, where
  /// `lsof +d` misses a mapped file, as Mach9's processes have it (D1).
  @override
  List<WineProcess> wineProcesses(String prefix) {
    final run = Process.runSync('/usr/bin/stat', ['-f', '%d %i', prefix]);
    final ids = '${run.stdout}'.trim().split(' ');
    if (run.exitCode != 0 || ids.length != 2) return const [];
    final name =
        '/server-${int.parse(ids[0]).toRadixString(16)}'
        '-${int.parse(ids[1]).toRadixString(16)}';
    return [
      for (final (:process, :server, names: _) in _wineFiles())
        if (server.endsWith(name)) process,
    ];
  }

  /// IOKit's own counter, readable without sudo (ER8).
  @override
  int? gpuUtilization() => parseGpuUtilization(
    '${Process.runSync('/usr/sbin/ioreg', ['-r', '-d', '1', '-w', '0', '-c', 'IOAccelerator']).stdout}',
  );

  @override
  List<WineProcess> orphanWineProcesses(String home) {
    final byServer = <String, List<({WineProcess process, bool mine})>>{};
    for (final (:process, :server, :names) in _wineFiles()) {
      (byServer[server] ??= []).add((
        process: process,
        mine: lsofNamesUnder(names.map((n) => 'n$n').join('\n'), home),
      ));
    }
    return [
      for (final members in byServer.values)
        if (!members.any((m) => isWineserver(m.process)))
          for (final (:process, :mine) in members)
            if (mine) process,
    ];
  }
}

/// Each Wine process of this user with its server folder and the files it has
/// open or mapped, from one `ps` and one `lsof` (D1). A Wine process runs an
/// `.exe` or is a wineserver; one with no server folder is left out.
List<({WineProcess process, String server, List<String> names})> _wineFiles() {
  final ps = Process.runSync(
    'ps',
    ['-axo', 'pid=,%cpu=,command='],
    environment: const {'LC_ALL': 'C'},
  );
  final wine = {
    for (final process in parsePs('${ps.stdout}'))
      if (programName(process.command) != null || isWineserver(process))
        process.pid: process,
  };
  if (wine.isEmpty) return const [];
  final run = Process.runSync('/usr/sbin/lsof', [
    '-p',
    wine.keys.join(','),
    '-Fn',
  ]);
  final names = <int, List<String>>{};
  int? pid;
  for (final line in '${run.stdout}'.split('\n')) {
    if (line.startsWith('p')) pid = int.tryParse(line.substring(1));
    if (line.startsWith('n') && pid != null) {
      (names[pid] ??= []).add(line.substring(1));
    }
  }
  final server = RegExp(
    r'^(/private/tmp/\.wine-\d+/server-[0-9a-f]+-[0-9a-f]+)',
  );
  return [
    for (final MapEntry(key: pid, value: files) in names.entries)
      if (wine[pid] case final process?)
        if (files.map(server.firstMatch).nonNulls.firstOrNull case final m?)
          (process: process, server: m.group(1)!, names: files),
  ];
}

/// Whether `lsof -Fn` [output] names a file under [home] (D2).
bool lsofNamesUnder(String output, String home) {
  final root = home.endsWith('/') ? home : '$home/';
  return output
      .split('\n')
      .any(
        (line) => line.startsWith('n') && line.substring(1).startsWith(root),
      );
}

/// [MacPlatform.mach9Block], read once: neither changes while Bodega runs.
(RuntimeBlock?,)? _mach9Block;

RuntimeBlock? _readMach9Block() {
  String ask(String exe, List<String> args) {
    try {
      return '${Process.runSync(exe, args).stdout}'.trim();
    } on ProcessException {
      return '';
    }
  }

  if (ask('/usr/sbin/sysctl', ['-n', 'hw.optional.arm64']) != '1') {
    return RuntimeBlock.appleSiliconOnly;
  }
  final version = ask('/usr/bin/sw_vers', ['-productVersion']);
  return _versionAtLeast(version, mach9Identity.minimumMacos)
      ? null
      : RuntimeBlock.macosTooOld;
}

/// Whether the dotted [version] is [minimum] or later; a version that does
/// not parse is not.
bool _versionAtLeast(String version, String minimum) {
  List<int>? parts(String text) {
    final list = text.split('.').map(int.tryParse).toList();
    return list.contains(null) ? null : list.cast<int>();
  }

  final have = parts(version), want = parts(minimum);
  if (have == null || want == null) return false;
  for (var i = 0; i < want.length || i < have.length; i++) {
    final a = i < have.length ? have[i] : 0, b = i < want.length ? want[i] : 0;
    if (a != b) return a > b;
  }
  return true;
}

/// Copied from the app bundle, the files would be blocked by Gatekeeper.
void _stripQuarantine(String dir) {
  try {
    Process.runSync('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', dir]);
  } on ProcessException {
    // No xattr outside macOS, so nothing to strip.
  }
}

/// How a bottle takes gamepads (design §10). With SDL2 in the runtime, as in
/// CrossOver, Wine's defaults: SDL maps each pad to the Xbox layout, so games
/// get the right controls. Without it Wine ignores an Xbox pad, unless these
/// values make it take it raw from macOS (IOHID); measured with an Xbox One S
/// pad, 045e:02fd, it then shows up, but with its controls wrong in Blur.
/// Version 1 is the raw way and 2 is SDL. It runs once per bottle and per way,
/// and best-effort: a failure is tried again on the next launch. A running
/// bottle sees it after it restarts.
Future<void> _ensureGamepads(String home, String name) async {
  final dir = _existing(home, name);
  final sdl = hasSdl(home);
  final want = sdl ? 2 : 1;
  if (_settings(dir).gamepads == want || !_ready('$dir/prefix')) return;
  for (final (value, data) in [
    ('Enable SDL', sdl ? '1' : '0'),
    ('DisableInput', sdl ? '0' : '1'),
  ]) {
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
        data,
        '/f',
      ],
      backend: 'wine',
      label: 'pads',
    );
    if (await exitOf(log) != 0) return;
  }
  _saveSettings(dir, _with(_settings(dir), gamepads: want));

  // Those runs started Wine's services, the gamepad one among them, before the
  // values existed, and it keeps what it read for as long as the session
  // lasts. Measured: Blur opened right after had no pad until the bottle was
  // reopened. So let that session end; something else keeping it up only
  // costs this wait, and then it sees them after it restarts.
  final rt = runtimeDir(home, _bottleRuntimeIn(dir));
  final wait = await Process.start(
    '$rt/engine/bin/wineserver',
    ['-w'],
    environment: wineEnv('$dir/prefix', Platform.environment),
    includeParentEnvironment: false,
  );
  await wait.exitCode.timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      wait.kill();
      return -1;
    },
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Mach9.app's rule (`retina.rs`): the main display's current mode has more
/// pixels than points. CoreGraphics' C API through `dart:ffi`; false without
/// a display or the library (PE3).
bool _mainDisplayHiDpi() {
  try {
    final cg = DynamicLibrary.open(
      '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics',
    );
    final display = cg.lookupFunction<Uint32 Function(), int Function()>(
      'CGMainDisplayID',
    )();
    final mode = cg
        .lookupFunction<
          Pointer<Void> Function(Uint32),
          Pointer<Void> Function(int)
        >('CGDisplayCopyDisplayMode')(display);
    if (mode == nullptr) return false;
    int size(String function) =>
        cg.lookupFunction<
          Size Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >(function)(mode);
    try {
      return size('CGDisplayModeGetPixelWidth') > size('CGDisplayModeGetWidth');
    } finally {
      cg.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('CGDisplayModeRelease')(mode);
    }
  } on Object {
    return false;
  }
}

/// Where [bundleWineForGameMode] writes the bundle's `Info.plist`.
String _winePlistPath(String engine) =>
    '$engine/lib/wine/wine.app/Contents/Info.plist';

/// What makes macOS give Game Mode to a game of the Rosetta engine, as Mach9's
/// own `wine.app` does for the Native one: the games category.
const winePlist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.dany021115.bodega.wine</string>
<key>CFBundleName</key><string>wine</string>
<key>CFBundleExecutable</key><string>wine</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
<key>LSSupportsGameMode</key><true/>
<key>GCSupportsGameMode</key><true/>
<key>LSUIElement</key><true/>
</dict></plist>
''';

/// Puts the Rosetta engine's unix folder in a `wine.app` so that macOS gives
/// its games Game Mode (measured on 2026-11-24 with a game in full screen).
///
/// macOS reads an app's category from the bundle of the path a process was
/// started by, never through a link. Wine starts each process as
/// `<ntdll.so's real folder>/wine` (`dlls/ntdll/unix/loader.c`, init_paths),
/// so the real `lib/wine/x86_64-unix` becomes `lib/wine/wine.app/Contents/
/// MacOS`, and links keep every path that Wine and Bodega use:
/// - `lib/wine/x86_64-unix`, the old place, for `bin/wine` and Bodega;
/// - in `MacOS`, `x86_64-unix` (itself), `x86_64-windows` and `i386-windows`,
///   where Wine looks once its dll folder is `MacOS`;
/// - `wine.app/bin` and `wine.app/share`, Wine's `../../bin` and
///   `../../share` from there.
///
/// Idempotent. Returns false for a tree without that folder.
bool bundleWineForGameMode(String engine) {
  final wine = '$engine/lib/wine';
  final unix = '$wine/x86_64-unix';
  final macos = '$wine/wine.app/Contents/MacOS';
  if (!FileSystemEntity.isLinkSync(unix)) {
    if (Directory(unix).existsSync()) {
      if (Directory(macos).existsSync()) return false;
      Directory('$wine/wine.app/Contents').createSync(recursive: true);
      Directory(unix).renameSync(macos);
    } else if (!Directory(macos).existsSync()) {
      return false;
    }
    try {
      Link(unix).createSync('wine.app/Contents/MacOS');
    } on FileSystemException {
      if (!Directory(unix).existsSync()) Directory(macos).renameSync(unix);
      rethrow;
    }
  }
  for (final (path, target) in [
    ('$macos/x86_64-unix', '.'),
    ('$macos/x86_64-windows', '../../../x86_64-windows'),
    ('$macos/i386-windows', '../../../i386-windows'),
    ('$wine/wine.app/bin', '../../../bin'),
    if (Directory('$engine/share').existsSync())
      ('$wine/wine.app/share', '../../../share'),
  ]) {
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      Link(path).createSync(target);
    }
  }
  final plist = File(_winePlistPath(engine));
  if (!plist.existsSync() || plist.readAsStringSync() != winePlist) {
    plist.writeAsStringSync(winePlist);
  }
  return true;
}
