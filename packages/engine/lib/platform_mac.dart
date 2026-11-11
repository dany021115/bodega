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
  }

  /// SDL2 lives inside a runtime, and a runtime is copied only when it is
  /// missing: one installed from a tarball has none, and an older one may have
  /// another version, whose pad controls can be wrong. The bundle's SDL2 goes
  /// into the runtime in use whenever it differs (design §10).
  void _syncSdl(String home, String root) {
    if (!hasRuntime(home)) return;
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
  }

  @override
  Future<GamepadReport?> gamepads() async => null;

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
    avx: true,
    dlss: true,
    d3dmetal: true,
    sdl: true,
    gpu: false,
    gameMode: false,
    syncModes: const ['msync', 'none'],
  );

  @override
  String get defaultSync => 'msync';

  @override
  Map<String, String> syncEnv(String mode) =>
      mode == 'none' ? const {'WINEMSYNC': '0'} : const {};

  @override
  List<String> get backendNames => const ['wine', 'dxmt', 'dxvk', 'd3dmetal'];

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
  /// 32-bit DX12.
  @override
  bool backendFits(String backend, ExeGraphics exe) =>
      exe.directx.isEmpty ||
      switch (backend) {
        'd3dmetal' =>
          exe.bits == 64 && (exe.directx == 'DX11' || exe.directx == 'DX12'),
        'dxmt' || 'dxvk' => exe.directx == 'DX10' || exe.directx == 'DX11',
        _ => true,
      };

  @override
  BackendRole backendRole(String backend) => switch (backend) {
    'd3dmetal' => BackendRole.dx11to12x64,
    'dxmt' || 'dxvk' => BackendRole.dx10to11,
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
        _ => [(64, '11'), (32, '11')],
      };

  @override
  Future<void> prepareBottle(String home, String name) =>
      _ensureGamepads(home, name);

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
  final rt = currentRuntime(home);
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
