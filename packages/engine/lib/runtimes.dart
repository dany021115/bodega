part of 'engine.dart';

/// The Wine a bottle runs on (MR1): Bodega's own x86_64 Wine under Rosetta 2,
/// or Mach9's arm64 Wine. Fixed when the bottle is created (D1).
enum RuntimeKind {
  bodega("Bodega's Wine (x86_64)"),
  mach9('Mach9');

  const RuntimeKind(this.english);

  /// For the CLI and logs.
  final String english;
}

/// Why Mach9 cannot run on this host (MR2).
enum RuntimeBlock {
  notThisHost('Mach9 runs only on a Mac'),
  appleSiliconOnly('Mach9 needs a Mac with Apple silicon'),
  macosTooOld('Mach9 needs macOS 26.4 or later');

  const RuntimeBlock(this.english);

  /// For the CLI and logs.
  final String english;
}

/// One runtime kind as this host sees it (MR1). [id] is the folder its link
/// points at; [version] comes from Mach9's `runtime.json` (null for bodega);
/// [checked] says whether that version is the pinned one; [app] is a
/// `Mach9.app` found in the applications folders.
typedef RuntimeInfo = ({
  RuntimeKind kind,
  bool installed,
  String? id,
  String? version,
  bool checked,
  RuntimeBlock? blocked,
  ({String path, String version})? app,
});

/// The link of each kind under `runtimes/`.
String _runtimeLink(RuntimeKind kind) => switch (kind) {
  RuntimeKind.bodega => 'current',
  RuntimeKind.mach9 => 'mach9',
};

/// One entry per kind the host knows: bodega alone on Linux, then mach9 on
/// the Mac (MR1).
List<RuntimeInfo> listRuntimes(String home) {
  final block = hostPlatform.mach9Block;
  final current = Directory('$home/runtimes/current');
  return [
    (
      kind: RuntimeKind.bodega,
      installed: current.existsSync(),
      id: current.existsSync()
          ? current.resolveSymbolicLinksSync().split('/').last
          : null,
      version: null,
      checked: true,
      blocked: null,
      app: null,
    ),
    if (block != RuntimeBlock.notThisHost) _mach9Info(home, block),
  ];
}

RuntimeInfo _mach9Info(String home, RuntimeBlock? block) {
  final link = Directory('$home/runtimes/mach9');
  final installed = link.existsSync();
  final dir = installed ? link.resolveSymbolicLinksSync() : null;
  String? version;
  if (dir != null) {
    try {
      final json = jsonDecode(
        File('$dir/runtime.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      version = json['version'] as String?;
    } on Object {
      version = null;
    }
  }
  return (
    kind: RuntimeKind.mach9,
    installed: installed,
    id: dir?.split('/').last,
    version: version,
    checked: version == mach9Release.version,
    blocked: block,
    app: findMach9App(),
  );
}

/// The resolved folder of [kind] (MR10): bodega throws [NoRuntime] as
/// [currentRuntime] does, mach9 [RuntimeNotInstalled] when its link is missing
/// or dangling.
String runtimeDir(String home, RuntimeKind kind) {
  if (kind == RuntimeKind.bodega) return currentRuntime(home);
  // Directory follows the link, so a dangling one counts as none.
  final link = Directory('$home/runtimes/${_runtimeLink(kind)}');
  if (!link.existsSync()) throw RuntimeNotInstalled(kind);
  return link.resolveSymbolicLinksSync();
}

/// The kind a bottle really runs on (MB2, D2): the PE machine of its
/// `system32/kernel32.dll` (0xAA64 mach9; 0x8664 or 0x14C bodega), or else
/// what settings.json stores. Reads files only, so it is safe inside
/// `Isolate.run`.
RuntimeKind bottleRuntime(String home, String name) =>
    _bottleRuntimeIn(_existing(home, name));

RuntimeKind _bottleRuntimeIn(String dir) {
  final kernel32 = '$dir/prefix/drive_c/windows/system32/kernel32.dll';
  // Never through a link: a prefix holds links to the host (dosdevices).
  if (FileSystemEntity.typeSync(kernel32, followLinks: false) ==
      FileSystemEntityType.file) {
    switch (_peMachine(kernel32)) {
      case 0xAA64:
        return RuntimeKind.mach9;
      case 0x8664 || 0x14C:
        return RuntimeKind.bodega;
    }
  }
  return _storedRuntime(dir);
}

/// The `runtime` of settings.json: a missing file or key is bodega, an
/// unknown value [CorruptData] (MB1). Without [hostPlatform], so that
/// [bottleRuntime] works in another isolate.
RuntimeKind _storedRuntime(String dir) {
  final file = File('$dir/settings.json');
  if (!file.existsSync()) return RuntimeKind.bodega;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _runtimeNamed(json['runtime'] as String?);
  } on Object catch (e) {
    throw CorruptData(file.path, '$e');
  }
}

RuntimeKind _runtimeNamed(String? value) => value == null
    ? RuntimeKind.bodega
    : RuntimeKind.values.where((kind) => kind.name == value).firstOrNull ??
          (throw BadChoice(ChoiceKind.runtime, value));

/// The graphics names a bottle of [kind] offers (MG1), besides `auto`.
List<String> backendNamesFor(RuntimeKind kind) => switch (kind) {
  RuntimeKind.bodega => backendNames,
  RuntimeKind.mach9 => const ['wine', 'dxmt', 'mtld3d'],
};

/// Whether each Mach9 name has its modules in the installed runtime (MG2).
Map<String, bool> _mach9Backends(String home) {
  final link = Directory('$home/runtimes/mach9');
  final root = link.existsSync()
      ? '${link.resolveSymbolicLinksSync()}/engine/lib/wine'
      : null;
  bool has(String path) =>
      root != null &&
      FileSystemEntity.typeSync('$root/$path') != FileSystemEntityType.notFound;
  return {
    'wine': has('dxgi/wined3d') && has('d3d9/wined3d'),
    'dxmt': has('dxgi/dxmt'),
    'mtld3d': has('d3d9/mtld3d'),
  };
}

/// G3 per kind: on Mach9 only `wine` misfits, with a DX12 exe (MG2).
bool backendFitsFor(RuntimeKind kind, String backend, ExeGraphics exe) =>
    switch (kind) {
      RuntimeKind.bodega => hostPlatform.backendFits(backend, exe),
      RuntimeKind.mach9 =>
        exe.directx.isEmpty || !(backend == 'wine' && exe.directx == 'DX12'),
    };

/// A catalog entry's backend for a bottle of [kind] (MB9): on Mach9 `wine`
/// stays and everything else is `auto`.
String mapBackendFor(RuntimeKind kind, String name) => switch (kind) {
  RuntimeKind.bodega => hostPlatform.mapBackend(name),
  RuntimeKind.mach9 => name == 'wine' ? 'wine' : 'auto',
};

/// The `WINE_COMPATDB` value of one launch of [program] in a Mach9 bottle,
/// or null for a bodega one (MG5, design §4.2): what `_launchIn` sends for the
/// same [backend] option and [hud], without a fix's overrides. The bottle's
/// and the program's own `WINE_COMPATDB` follow Bodega's lines (MG9).
String? compatdbRules(
  String home,
  String name,
  String program, {
  String? backend,
  bool hud = false,
  String? appKey,
}) {
  final dir = _existing(home, name);
  if (_bottleRuntimeIn(dir) != RuntimeKind.mach9) return null;
  final settings = _settings(dir);
  final key = _exeKey(program);
  final rules = _mach9Rules(
    settings,
    key,
    _mach9Choice(home, settings, key, backend),
    optionGiven: backend != null,
    hud: hud || (settings.programs[key]?.hud ?? false),
    appKey: appKey,
  );
  final user = {...settings.env, ...?settings.programs[key]?.env};
  return [...rules, ?user['WINE_COMPATDB']].join('\n');
}

/// The DLL override that keeps Wine's menu builder off in every Mach9 process.
const _mach9MenuOverride = 'winemenubuilder.exe=';

/// The fields a Mach9 graphics name sets (design §4.1): each sets only the
/// DirectX family it names, `wine` both; `auto` (or null) none.
List<(String, String)> _mach9Fields(String? backend) => switch (backend) {
  'mtld3d' => const [('d3d9', 'mtld3d')],
  'dxmt' => const [('dxgi', 'dxmt')],
  'wine' => const [('dxgi', 'wined3d'), ('d3d9', 'wined3d')],
  _ => const [],
};

/// S2 on Mach9, without a scan (MG3): the launch option, the program's
/// exception, the bottle, then `auto`, which leaves the choice to Mach9. A
/// name of the other kind is [BackendNotForRuntime]; one whose modules the
/// runtime lacks [BackendNotInstalled].
({String name, String origin}) _mach9Choice(
  String home,
  BottleSettings settings,
  String key,
  String? option,
) {
  if (option != null) _checkChoiceFor(RuntimeKind.mach9, option);
  final exception = settings.programs[key]?.backend;
  final bottle = settings.backend == 'auto' ? null : settings.backend;
  final (name, origin) = option == 'auto'
      ? ('auto', 'auto')
      : option != null
      ? (option, 'option')
      : exception != null
      ? (exception, 'exe')
      : bottle != null
      ? (bottle, 'bottle')
      : ('auto', 'auto');
  if (name != 'auto') {
    _checkChoiceFor(RuntimeKind.mach9, name);
    if (!(_mach9Backends(home)[name] ?? false)) {
      throw BackendNotInstalled(name);
    }
  }
  return (name: name, origin: origin);
}

/// Lines 1–3 of design §4.2 for one launch of the program [key]: `exe=*`
/// always; the program's own line when the choice came from a launch option
/// or its exception; then one line per other program with an exception
/// (unless [optionGiven]) or a saved HUD. [overrides] are DLL override
/// values, each split on `;` (MG8).
List<String> _mach9Rules(
  BottleSettings settings,
  String key,
  ({String name, String origin}) choice, {
  required bool optionGiven,
  required bool hud,
  List<String> overrides = const [],
  String? appKey,
}) {
  final fields = _mach9Fields(choice.name);
  // PE8: a Steam game's own line names its app id, not the store client.
  final steam = appKey != null && appKey.startsWith('steam:');
  final own = [
    if (choice.origin == 'option' || choice.origin == 'exe') ...fields,
    if (steam && hud) ('metal_hud', 'true'),
    // PE7: the app's native options, on its own line only.
    for (final option in settings.native[appKey] ?? const <String>[])
      (
        NativeOption.values.byName(option).field,
        NativeOption.values.byName(option).value,
      ),
  ];
  return [
    _compatdbLine([
      ('exe', '*'),
      ...fields,
      if (hud && !steam) ('metal_hud', 'true'),
      ('dll_overrides', _mach9MenuOverride),
      for (final value in overrides)
        for (final element in value.split(';'))
          if (element.isNotEmpty) ('dll_overrides', element),
    ]),
    if (own.isNotEmpty) _compatdbLine([('exe', steam ? appKey : key), ...own]),
    for (final other in settings.programs.keys.toList()..sort())
      if (other != key)
        if ([
              if (!optionGiven)
                ..._mach9Fields(settings.programs[other]!.backend),
              if (settings.programs[other]!.hud) ('metal_hud', 'true'),
            ]
            case final extra when extra.isNotEmpty)
          _compatdbLine([('exe', other), ...extra]),
  ];
}

/// One line of `WINE_COMPATDB` (MG4): `name=value` fields joined by `;`, in
/// compatdb's `Key::ALL` order (design §3; fields of one key keep theirs),
/// with `%`, `;` and control bytes of each value escaped as `%XX`.
String _compatdbLine(List<(String, String)> fields) {
  for (final (name, _) in fields) {
    if (!_compatdbKeys.contains(name))
      throw StateError('no compatdb key $name');
  }
  return [
    for (final key in _compatdbKeys)
      for (final (name, value) in fields)
        if (name == key) '$name=${_compatdbEscape(value)}',
  ].join(';');
}

/// compatdb's `Key::ALL` at Mach9 v0.4.0 (`compatdb/core/src/key.rs`).
const _compatdbKeys = [
  'exe',
  'company',
  'product',
  'original_filename',
  'dxgi',
  'd3d9',
  'wined3d',
  'opengl',
  'dpi_aware',
  'large_address_aware',
  'gcmouse',
  'force_nx',
  'metal_hud',
  'vulkan_capture',
  'metal_capture',
  'dll_overrides',
  'arguments_override',
  'arguments',
  'debug_channels',
  'env',
];

String _compatdbEscape(String value) {
  final out = StringBuffer();
  for (final unit in value.codeUnits) {
    if (unit == 0x25 || unit == 0x3B || unit < 0x20 || unit == 0x7F) {
      out.write('%${unit.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// The Mach9 probe cases per name (design §4.1, MG10).
List<(int, String)> _mach9ProbeCases(String backend) => switch (backend) {
  'mtld3d' => const [(32, '9'), (64, '9')],
  'dxmt' => const [(32, '11'), (64, '11'), (64, '12')],
  _ => const [(32, '9'), (64, '9'), (64, '11')],
};

/// A compatdb setting a Mach9 bottle sends on one app's own rule, from
/// `builtin.rs`'s documented fixes (PE7, P7). Off sends nothing, so Mach9's
/// own default holds.
enum NativeOption {
  /// No-execute as Wine does it: launchers and configurators built with the
  /// ATL of Visual Studio 2003 crash on their first window without it.
  noForceNx('force_nx', 'false'),

  /// The 4 GB address space for a 32-bit game, which otherwise shares 2 GB
  /// with Wine and the Direct3D layers under FEX.
  largeAddressAware('large_address_aware', 'true'),

  /// Windows' scaling off, for interfaces drawn in fixed pixels.
  notDpiAware('dpi_aware', 'false'),

  /// macOS's own OpenGL instead of EGL, when a game gets no OpenGL at all.
  cglOpenGl('opengl', 'cgl'),

  /// wined3d draws with Vulkan instead of OpenGL.
  vulkanWined3d('wined3d', 'vulkan');

  const NativeOption(this.field, this.value);

  /// compatdb's key and the value this option sends.
  final String field;
  final String value;
}
