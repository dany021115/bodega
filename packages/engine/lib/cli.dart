part of 'engine.dart';

/// What `bodega` prints when its arguments make no verb.
const bodegaUsage = '''
usage: bodega install <engine.tar.gz> <hostlibs.tar.gz>
       bodega runtime list
       bodega runtime install mach9 [Mach9.dmg|Mach9.app] [--mono <wine-mono.msi>]
       bodega runtime check mach9
       bodega create [--runtime bodega|mach9] <bottle>
       bodega mono install <bottle>
       bodega run [--backend <b>] [--hud] <bottle> <program> [args…]
       bodega rules <bottle> [--backend <b>] [--hud] <program>
       bodega wait <bottle>
       bodega stop <bottle>
       bodega rename <bottle> <new-name>
       bodega library <bottle> <key> on|off
       bodega hud <bottle> <key> on|off
       bodega backend list [--runtime mach9]
       bodega backend install <dxmt|dxvk> [tarball]
       bodega backend import d3dmetal <folder>
       bodega backend set <bottle> <backend> [--exe <name.exe>]
       bodega backend test <bottle> <backend>
       bodega sync <bottle> <msync|none>
       bodega option <bottle> gpu auto|discrete
       bodega option <bottle> gamemode on|off
       bodega option <bottle> retina auto|on|off
       bodega option <bottle> metal4 on|off
       bodega native <bottle> <key> [<option> on|off]
       bodega native-move <bottle>
       bodega measure <bottle> [seconds]
       bodega sdl install [file.dmg]
       bodega pads
       bodega catalog list [text]
       bodega catalog show <id>
       bodega catalog install <id> [bottle] [--runtime mach9]
       bodega fix list [text]
       bodega fix show <id|steam-appid>
       bodega fix apply <bottle> <id>
       bodega game show <bottle> <key>
       bodega game use <bottle> <key> on|off
       bodega deps list <bottle>
       bodega deps check <bottle> <key>
       bodega deps install <bottle> <id> <x86|x64|all> [file…]
       bodega apps
       bodega probe <path>
       bodega open [--backend <b>] [--hud] <bottle> [key]
       bodega switch status
       bodega switch emulator <Ryujinx.app>|auto
       bodega switch option fullscreen|headless on|off
       bodega switch add <file|app|folder>…
       bodega switch list
       bodega switch remove <game>
       bodega switch open <game>
       bodega switch stop <game>
       bodega switch keys <file.keys|folder>…
       bodega switch firmware <file|folder>''';

/// A runtime kind named on the command line, or null for an unknown one.
RuntimeKind? _kindNamed(String name) =>
    RuntimeKind.values.where((kind) => kind.name == name).firstOrNull;

/// The arguments of `create` (MC3): `[--runtime <kind>] <bottle>`, or null for
/// a bad usage, an unknown kind included.
({RuntimeKind runtime, String bottle})? parseCreate(List<String> args) =>
    switch (args) {
      [final bottle] when !bottle.startsWith('--') => (
        runtime: RuntimeKind.bodega,
        bottle: bottle,
      ),
      ['--runtime', final name, final bottle] when _kindNamed(name) != null => (
        runtime: _kindNamed(name)!,
        bottle: bottle,
      ),
      _ => null,
    };

/// The arguments of `catalog install` after the id (MC7): `[bottle]
/// [--runtime <kind>]`, in either order, or null for a bad usage.
({String? bottle, RuntimeKind runtime})? parseCatalogInstall(
  List<String> args,
) {
  String? bottle;
  var runtime = RuntimeKind.bodega;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--runtime' && i + 1 < args.length) {
      final kind = _kindNamed(args[++i]);
      if (kind == null) return null;
      runtime = kind;
    } else if (!args[i].startsWith('--') && bottle == null) {
      bottle = args[i];
    } else {
      return null;
    }
  }
  return (bottle: bottle, runtime: runtime);
}

/// The arguments of `runtime install mach9` (MC2): `[Mach9.dmg|Mach9.app]
/// [--mono <msi>]`, in either order, or null for a bad usage.
({String? source, String? mono})? parseRuntimeInstall(List<String> args) {
  String? source, mono;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--mono' && i + 1 < args.length && mono == null) {
      mono = args[++i];
    } else if (!args[i].startsWith('--') && source == null) {
      source = args[i];
    } else {
      return null;
    }
  }
  return (source: source, mono: mono);
}

/// The arguments of `rules` (MC5): `<bottle> [--backend <b>] [--hud]
/// <program>`, or null for a bad usage.
({String bottle, String? backend, bool hud, String program})? parseRules(
  List<String> args,
) {
  if (args.isEmpty || args.first.startsWith('--')) return null;
  final options = _parseOptions(args.sublist(1));
  if (options == null || options.rest.length != 1) return null;
  return (
    bottle: args.first,
    backend: options.backend,
    hud: options.hud,
    program: options.rest.single,
  );
}

/// The CLI's names of the [NativeOption]s (PE11).
const nativeOptionNames = {
  NativeOption.noForceNx: 'no-force-nx',
  NativeOption.largeAddressAware: 'large-address-aware',
  NativeOption.notDpiAware: 'not-dpi-aware',
  NativeOption.cglOpenGl: 'cgl-opengl',
  NativeOption.vulkanWined3d: 'vulkan-wined3d',
  NativeOption.strictCodeTracking: 'strict-code-tracking',
  NativeOption.fullX87Precision: 'full-x87-precision',
};

NativeOption? _nativeOptionNamed(String name) => nativeOptionNames.entries
    .where((entry) => entry.value == name)
    .firstOrNull
    ?.key;

/// One line of `runtime list` (MC1).
String describeRuntime(RuntimeInfo info) {
  final name = info.kind.name;
  if (info.blocked case final block?) {
    return '$name: not available (${block.english})';
  }
  if (!info.installed) return '$name: not installed';
  return switch (info.kind) {
    RuntimeKind.bodega => '$name: installed (${info.id})',
    RuntimeKind.mach9 when info.checked =>
      '$name: installed ${info.version} (${info.id})',
    RuntimeKind.mach9 =>
      '$name: installed ${info.version ?? '(unknown version)'} '
          '(not checked with this Bodega)',
  };
}

/// The runtime verbs of the CLI (MC1, MC2, MC4, MC5, MC6): the work of
/// [args], which writes to [out] and gives the exit code, or null when [args]
/// are none of them or a bad usage. A failure is thrown, for the CLI to print.
Future<int> Function(String home)? runtimeVerb(
  List<String> args,
  StringSink out,
) => switch (args) {
  ['runtime', 'list'] => (home) async {
    listRuntimes(home).map(describeRuntime).forEach(out.writeln);
    return 0;
  },
  ['runtime', 'install', 'mach9', ...final rest]
      when parseRuntimeInstall(rest) != null =>
    (home) async {
      final options = parseRuntimeInstall(rest)!;
      final dir = await installMach9(
        home,
        source: options.source,
        mono: options.mono,
        onStep: (step) => out.writeln(step.english),
      );
      out.writeln(dir);
      return 0;
    },
  // MU5, D7: what is installed and what GitHub has.
  ['runtime', 'check', 'mach9'] => (home) async {
    final latest = await mach9Latest(home);
    final info = listRuntimes(home).where((r) => r.kind == RuntimeKind.mach9);
    final installed = info.firstOrNull?.version;
    out
      ..writeln('installed ${installed ?? 'none'}')
      ..writeln('latest ${latest.version}');
    if (installed != null && !_versionAtLeast(installed, latest.version)) {
      out.writeln('update available');
    }
    return 0;
  },
  ['mono', 'install', final bottle] => (home) async {
    if (bottleRuntime(home, bottle) != RuntimeKind.mach9) {
      out.writeln('not needed: $bottle runs on ${RuntimeKind.bodega.english}');
      return 0;
    }
    final log = await installMono(home, bottle);
    out.writeln(
      log == null ? 'Wine Mono is already installed' : 'Wine Mono installed',
    );
    if (log != null) out.writeln('log: $log');
    return 0;
  },
  ['rules', ...final rest] when parseRules(rest) != null => (home) async {
    final rules = parseRules(rest)!;
    final value = compatdbRules(
      home,
      rules.bottle,
      rules.program,
      backend: rules.backend,
      hud: rules.hud,
    );
    out.writeln(
      value ??
          '${rules.bottle} runs on ${RuntimeKind.bodega.english}, '
              'which takes no rules',
    );
    return 0;
  },
  ['option', final bottle, 'retina', final mode]
      when retinaModes.contains(mode) =>
    (home) async {
      await setRetina(home, bottle, mode);
      return 0;
    },
  ['option', final bottle, 'metal4', final state]
      when state == 'on' || state == 'off' =>
    (home) async {
      setBottleOptions(home, bottle, metal4: state == 'on');
      return 0;
    },
  ['native', final bottle, final key] => (home) async {
    final on = nativeOptions(home, bottle, key);
    for (final MapEntry(key: option, value: name)
        in nativeOptionNames.entries) {
      out.writeln('$name: ${on.contains(option) ? 'on' : 'off'}');
    }
    return 0;
  },
  ['native', final bottle, final key, final name, final state]
      when _nativeOptionNamed(name) != null &&
          (state == 'on' || state == 'off') =>
    (home) async {
      setNativeOption(
        home,
        bottle,
        key,
        _nativeOptionNamed(name)!,
        on: state == 'on',
      );
      out.writeln('$name: $state');
      return 0;
    },
  ['native-move', final bottle] => (home) async {
    final runtimes = await moveToNative(
      home,
      bottle,
      onStep: (step) => out.writeln(switch (step) {
        NativeMoveStep.creating => 'Making the Native engine bottle',
        NativeMoveStep.copying => 'Copying programs, files and settings',
        NativeMoveStep.finishing => 'Deleting the Rosetta bottle',
      }),
    );
    out.writeln('$bottle runs on the Native engine now');
    if (runtimes.isNotEmpty) {
      out.writeln('install again: ${runtimes.join(', ')}');
    }
    return 0;
  },
  ['measure', final bottle, ...final rest] when _measureSeconds(rest) != null =>
    (home) async {
      final seconds = _measureSeconds(rest)!;
      final samples = <BottleSample>[];
      for (var t = 1; t <= seconds; t++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final sample = measureBottle(home, bottle);
        samples.add(sample);
        out.writeln(measureLine('${t}s', sample));
      }
      out.writeln(measureLine('average', averageSample(samples)));
      return 0;
    },
  ['backend', 'list', '--runtime', final name] when _kindNamed(name) != null =>
    (home) async {
      listBackends(home, runtime: _kindNamed(name)!).forEach((name, installed) {
        out.writeln('$name: ${installed ? 'installed' : 'not installed'}');
      });
      return 0;
    },
  _ => null,
};

/// The seconds of `measure`, 60 by default, or null for a bad usage.
int? _measureSeconds(List<String> rest) => switch (rest) {
  [] => 60,
  [final n] => switch (int.tryParse(n)) {
    final seconds? when seconds > 0 => seconds,
    _ => null,
  },
  _ => null,
};

/// One line of `bodega measure` (ER8).
String measureLine(String label, BottleSample sample) => [
  label,
  'cpu ${sample.cpu.toStringAsFixed(1)}%',
  if (sample.top case final top?)
    'top $top ${sample.topCpu.toStringAsFixed(1)}%',
  if (sample.gpu case final gpu?) 'gpu $gpu%',
].join('  ');

/// The mean of [samples]: CPU and GPU averaged, the busiest program the most
/// frequent one (ER8).
BottleSample averageSample(List<BottleSample> samples) {
  if (samples.isEmpty) return (cpu: 0, top: null, topCpu: 0, gpu: null);
  double mean(Iterable<double> values) =>
      values.fold<double>(0, (a, b) => a + b) / samples.length;
  final gpus = [for (final s in samples) ?s.gpu];
  final tops = <String, int>{};
  for (final s in samples) {
    if (s.top case final top?) tops[top] = (tops[top] ?? 0) + 1;
  }
  final top = tops.entries
      .fold<MapEntry<String, int>?>(
        null,
        (best, e) => best == null || e.value > best.value ? e : best,
      )
      ?.key;
  return (
    cpu: mean(samples.map((s) => s.cpu)),
    top: top,
    topCpu: mean(samples.map((s) => s.top == top ? s.topCpu : 0)),
    gpu: gpus.isEmpty
        ? null
        : (gpus.fold<int>(0, (a, b) => a + b) / gpus.length).round(),
  );
}

/// What `bodega probe <path>` prints (AA4): the program's architecture, the
/// newest DirectX it names, and which engine runs it. Null for a file that is
/// no Windows program.
Future<String?> probeProgram(String path) async {
  final arch = programArch(path);
  if (arch == null) return null;
  final directx = await _directxOf(path);
  return [
    '$path: $arch, ${directx.isEmpty ? 'no DirectX' : directx}',
    if (arch == 'arm64' || arch == 'arm64ec')
      'It runs only on the native engine (Mach9).',
  ].join('\n');
}
