part of 'engine.dart';

/// Linux x86_64: Wine from the package (or the one installed), DXVK in layers
/// copied into each prefix (design §5).
class LinuxPlatform extends HostPlatform {
  /// Null detects MangoHud (see [_hasMangoHud]); true or false forces it.
  /// [bundle] replaces the bundle detection, for tests.
  const LinuxPlatform({this.mangoHud, this.bundle});

  final bool? mangoHud;
  final String? bundle;

  @override
  String get displayName => 'Linux';

  @override
  String get id => 'linux';

  @override
  String get defaultWineDebug => '-all';

  bool get _hasMangoHud =>
      mangoHud ??
      [
        '/usr/share/vulkan/implicit_layer.d/MangoHud.x86_64.json',
        '/etc/vulkan/implicit_layer.d/MangoHud.x86_64.json',
        '${Platform.environment['HOME']}/.local/share/vulkan/implicit_layer.d/MangoHud.x86_64.json',
      ].any((file) => File(file).existsSync());

  @override
  String defaultHome(Map<String, String> env) {
    final data = env['XDG_DATA_HOME'];
    return data != null && data.isNotEmpty
        ? '$data/bodega'
        : '${env['HOME']!}/.local/share/bodega';
  }

  @override
  void prepareHome(String home) {
    final root = Directory(
      bundle ??
          Platform.environment['BODEGA_BUNDLE'] ??
          File(Platform.resolvedExecutable).parent.path,
    ).absolute.path;
    // An AppImage mounts at a new path on every start, so its links would dangle.
    _registerBundled(
      home,
      root,
      copy: Platform.environment['APPIMAGE'] != null,
    );
  }

  @override
  Map<String, String> baseEnv(Map<String, String> parent) {
    // Wine's user is the session's one (R18), found with `id` if the
    // environment does not say.
    final user =
        parent['USER'] ??
        parent['LOGNAME'] ??
        '${Process.runSync('id', ['-un']).stdout}'.trim();
    return {
      for (final key in const [
        'HOME',
        'TMPDIR',
        'LANG',
        'LC_ALL',
        'DISPLAY',
        'WAYLAND_DISPLAY',
        'XAUTHORITY',
        'XDG_RUNTIME_DIR',
        'XDG_SESSION_TYPE',
        'DBUS_SESSION_BUS_ADDRESS',
        'PULSE_SERVER',
        'PULSE_COOKIE',
        'VK_ICD_FILENAMES',
        'VK_DRIVER_FILES',
      ])
        if (parent[key] case final value?) key: value,
      'USER': user,
      'LOGNAME': parent['LOGNAME'] ?? user,
      'PATH': parent['PATH'] ?? '/usr/local/bin:/usr/bin:/bin:/usr/games',
      // Proton's defaults, so DXVK and vkd3d stay quiet as they do under it.
      'DXVK_LOG_LEVEL': 'none',
      'VKD3D_DEBUG': 'none',
      'VKD3D_SHADER_DEBUG': 'none',
    };
  }

  @override
  List<String> get requiredFiles => const [
    'engine/bin/wine',
    'engine/bin/wineserver',
    'engine/lib/wine/x86_64-unix/ntdll.so',
    'engine/lib/wine/x86_64-windows/kernel32.dll',
    'engine/lib/wine/x86_64-windows/ntdll.dll',
    'engine/lib/wine/i386-windows/kernel32.dll',
  ];

  @override
  String tool(String name) => name;

  @override
  (String, List<String>) get sha256Tool => ('sha256sum', const []);

  @override
  Future<void> afterExtract(String dir) async {}

  @override
  Future<List<HostIssue>> checkHost() async {
    final arch = '${(await Process.run('uname', ['-m'])).stdout}'.trim();
    final libs = await _ldconfig();
    return [
      if (arch != 'x86_64')
        (
          title: 'Procesador no soportado',
          detail: 'Bodega necesita un procesador x86_64.',
          command: null,
        ),
      if (libs != null &&
          !(libs.contains('libvulkan.so.1') && _vulkanIcd()))
        (
          title: 'Falta Vulkan',
          detail: 'Los juegos usan Vulkan (DXVK) para dibujar.',
          command: _installCommand(
            'libvulkan1 mesa-vulkan-drivers',
            'vulkan-loader mesa-vulkan-drivers',
            archVulkanPackages(_gpuVendors()),
          ),
        ),
      if (libs != null && !libs.contains('libpulse.so.0'))
        (
          title: 'Falta audio',
          detail:
              'Wine necesita PulseAudio o PipeWire con compatibilidad Pulse.',
          command: _installCommand(
            'libpulse0',
            'pulseaudio-libs',
            'libpulse',
          ),
        ),
    ];
  }

  @override
  HostCapabilities get capabilities => (
    highRes: true,
    avx: false,
    dlss: false,
    d3dmetal: false,
    sdl: false,
    gpu: true,
    gameMode: _onPath('gamemoderun'),
    syncModes: const ['none'],
  );

  // The bundled Wine has no esync or fsync variable, so nothing is set per
  // launch (packaging/linux/README.md).
  @override
  String get defaultSync => 'none';

  @override
  Map<String, String> syncEnv(String mode) => const {};

  @override
  List<String> get backendNames => const ['wine', 'dxvk'];

  // The dxvk layer ships in the package: its DXVK and vkd3d-proton DLLs
  // come together, so there is no separate download to pin.
  @override
  Map<String, ({String url, String sha256})> get pinnedBackends => const {};

  @override
  ({String dir, String file}) get layerCheck =>
      (dir: 'x64', file: 'x64/d3d11.dll');

  @override
  Map<String, String> backendEnv(
    String home,
    String backend, {
    bool hud = false,
  }) => {
    // The layer's DLLs sit in the prefix for every launch, so `wine` has to
    // say builtin outright instead of relying on Wine's default order.
    'WINEDLLOVERRIDES':
        '$_overrides;d3d8,d3d9,d3d10core,d3d11,d3d12,d3d12core,dxgi='
        '${backend == 'dxvk' ? 'n,b' : 'b'}',
    // Without MangoHud, DXVK's own HUD stands in, with no log.
    if (hud && backend == 'dxvk' && !_hasMangoHud)
      'DXVK_HUD': 'fps,frametimes,gpuload,memory,compiler',
  };

  @override
  Map<String, String> perfEnv(String bottleDir) {
    if (!_hasMangoHud) return const {};
    // MangoHud does not create the folder it logs to.
    final out = '$bottleDir/logs/perf';
    Directory(out).createSync(recursive: true);
    // shortcut: a comma in the path breaks MANGOHUD_CONFIG, and the CSV is
    // written when the game closes, not while it runs.
    return {
      'MANGOHUD': '1',
      'MANGOHUD_CONFIG':
          'fps,frametime,frame_timing,cpu_stats,gpu_stats,ram,vram,'
          'autostart_log=1,output_folder=$out',
    };
  }

  @override
  Future<String> autoBackend(String home, String? exePath) async =>
      _installed(home, 'dxvk') ? 'dxvk' : 'wine';

  @override
  String mapBackend(String name) =>
      name == 'dxmt' || name == 'd3dmetal' ? 'dxvk' : name;

  @override
  List<(int, String)> probeCases(String home, String backend) =>
      switch (backend) {
        'wine' => [(64, '11')],
        'dxvk' => [(64, '11'), (64, '12'), (32, '11')],
        _ => [(64, '11')],
      };

  @override
  Future<void> prepareBottle(String home, String name) =>
      _ensureLayers(home, name);

  @override
  List<List<String>> highResRegistry(bool value) => [
    [
      r'HKCU\Control Panel\Desktop',
      'LogPixels',
      'REG_DWORD',
      value ? '192' : '96',
    ],
  ];

  @override
  Map<String, String> gpuEnv(String gpu) => gpu != 'discrete'
      ? const {}
      : const {
          'DRI_PRIME': '1',
          '__NV_PRIME_RENDER_OFFLOAD': '1',
          '__GLX_VENDOR_LIBRARY_NAME': 'nvidia',
          '__VK_LAYER_NV_optimus': 'NVIDIA_only',
        };

  @override
  List<String> launchWrapper({required bool gamemode}) =>
      gamemode && capabilities.gameMode ? const ['gamemoderun'] : const [];

  // Harmless without GameMode installed: launchWrapper then adds nothing.
  @override
  bool get defaultGamemode => true;
}

/// Whether [name] is an executable file somewhere on the PATH.
bool _onPath(String name) {
  for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
    final stat = FileStat.statSync('$dir/$name');
    if (stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0) {
      return true;
    }
  }
  return false;
}

/// `ldconfig -p`, or null where ldconfig is not on the PATH; the library
/// checks are then skipped.
Future<String?> _ldconfig() async {
  try {
    return '${(await Process.run('ldconfig', ['-p'])).stdout}';
  } on ProcessException {
    return null;
  }
}

bool _vulkanIcd() => ['/usr/share/vulkan/icd.d', '/etc/vulkan/icd.d'].any(
  (dir) =>
      Directory(dir).existsSync() &&
      Directory(dir).listSync().any((entity) => entity.path.endsWith('.json')),
);

/// The PCI vendor ids (`0x10de`) of the GPUs, from /sys/class/drm.
List<String> _gpuVendors() {
  final drm = Directory('/sys/class/drm');
  if (!drm.existsSync()) return const [];
  return [
    for (final entity in drm.listSync(followLinks: false))
      if (RegExp(r'card\d+$').hasMatch(entity.path) &&
          File('${entity.path}/device/vendor').existsSync())
        File('${entity.path}/device/vendor').readAsStringSync().trim(),
  ];
}

/// The pacman packages that give Vulkan on this hardware: the loader plus the
/// driver of each GPU vendor (`nvidia-utils`, `vulkan-radeon`, `vulkan-intel`).
/// With no known GPU (a VM) it is the software renderer.
String archVulkanPackages(Iterable<String> vendors) {
  const drivers = {
    '0x10de': 'nvidia-utils',
    '0x1002': 'vulkan-radeon',
    '0x8086': 'vulkan-intel',
  };
  final found = {
    for (final vendor in vendors)
      if (drivers[vendor.toLowerCase()] case final driver?) driver,
  };
  return ['vulkan-icd-loader', ...found.isEmpty ? ['vulkan-swrast'] : found]
      .join(' ');
}

/// The install command for this distro, read from ID and ID_LIKE in
/// /etc/os-release, or null if it is not Debian-like, Fedora or Arch.
String? _installCommand(String apt, String dnf, String pacman) {
  final file = File('/etc/os-release');
  if (!file.existsSync()) return null;
  final ids = file
      .readAsLinesSync()
      .where((line) => line.startsWith('ID=') || line.startsWith('ID_LIKE='))
      .map((line) => line.substring(line.indexOf('=') + 1).replaceAll('"', ''))
      .join(' ')
      .split(' ');
  if (ids.any((id) => id == 'debian' || id == 'ubuntu')) {
    return 'sudo apt install $apt';
  }
  if (ids.contains('fedora')) return 'sudo dnf install $dnf';
  if (ids.contains('arch')) return 'sudo pacman -S $pacman';
  return null;
}

/// The names of the subdirectories of [dir], or none if it is missing.
List<String> _subdirs(String dir) => !Directory(dir).existsSync()
    ? []
    : [
        for (final entity in Directory(dir).listSync())
          if (entity is Directory) entity.path.split('/').last,
      ];

/// Registers what ships in [root] (R5): `runtime/<id>` becomes `runtimes/<id>`
/// and `backends/<name>` becomes `backends/<name>`, as links, or as copies with
/// [copy]. [afterCopy] runs on each copied folder.
void _registerBundled(
  String home,
  String root, {
  bool copy = false,
  void Function(String dest)? afterCopy,
}) {
  if (!Directory('$root/runtime').existsSync()) return;
  final runtimes = _subdirs('$root/runtime')..sort();
  for (final id in runtimes) {
    _register(
      '$root/runtime/$id',
      '$home/runtimes/$id',
      copy: copy,
      afterCopy: afterCopy,
    );
  }
  // shortcut: current moves only when it is missing or dangling, so a runtime
  // the user installed stays; an update that keeps the old Wine installed
  // keeps it as current too, until it is repointed by hand.
  if (runtimes.isNotEmpty &&
      !Directory('$home/runtimes/current').existsSync()) {
    _point('$home/runtimes/current', runtimes.last);
  }
  final backends = _subdirs('$root/backends');
  if (backends.isNotEmpty) {
    Directory('$home/backends').createSync(recursive: true);
  }
  for (final name in backends) {
    _register(
      '$root/backends/$name',
      '$home/backends/$name',
      copy: copy,
      afterCopy: afterCopy,
    );
  }
}

/// A link (or copy) at [dest] to [source]. A dangling link left by a moved
/// bundle is replaced.
void _register(
  String source,
  String dest, {
  bool copy = false,
  void Function(String dest)? afterCopy,
}) {
  if (Directory(dest).existsSync()) return;
  if (FileSystemEntity.isLinkSync(dest)) Link(dest).deleteSync();
  if (copy) {
    // Copied aside and renamed, so an interrupted copy is never taken as done.
    final tmp = Directory('$dest.tmp');
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    final cp = Process.runSync('cp', ['-a', source, tmp.path]);
    if (cp.exitCode != 0) throw 'no se pudo copiar $source: ${cp.stderr}';
    // Before the rename, so a start cut short never leaves a copy that
    // looks complete but still carries the quarantine.
    afterCopy?.call(tmp.path);
    tmp.renameSync(dest);
  } else {
    Link(dest).createSync(source);
  }
}

/// Points the link [link] at [target] in one step, as installRuntime does, so
/// that a dangling link is replaced too.
void _point(String link, String target) {
  final tmp = Link('$link.tmp');
  if (tmp.existsSync()) tmp.deleteSync();
  (tmp..createSync(target)).renameSync(link);
}

/// Copies the dxvk layer's DLLs into the prefix, once per layer version (R7).
/// The mark is the layer's VERSION file, or its resolved path if it has none.
Future<void> _ensureLayers(String home, String name) async {
  if (!_installed(home, 'dxvk')) return;
  final dir = _existing(home, name);
  final prefix = '$dir/prefix';
  if (!_ready(prefix)) return;
  final layer = _layer(home, 'dxvk');
  final version = File('$home/backends/dxvk/VERSION');
  final mark = version.existsSync()
      ? version.readAsStringSync().trim()
      : Directory(layer).resolveSymbolicLinksSync();
  final stamp = File('$prefix/.bodega-dxvk');
  final noted = stamp.existsSync() ? stamp.readAsStringSync() : null;
  if (noted == mark) return;
  for (final (source, target) in [('x64', 'system32'), ('x32', 'syswow64')]) {
    if (!Directory('$layer/$source').existsSync()) continue;
    for (final dll in Directory('$layer/$source').listSync()) {
      if (dll is File && dll.path.endsWith('.dll')) {
        final file = dll.path.split('/').last;
        dll.copySync('$prefix/drive_c/windows/$target/$file');
      }
    }
  }
  stamp.writeAsStringSync(mark);
}
