part of 'engine.dart';

/// What `bodega` prints when its arguments make no verb.
const bodegaUsage = '''
usage: bodega install <engine.tar.gz> <hostlibs.tar.gz>
       bodega runtime list
       bodega runtime install mach9 [Mach9.dmg|Mach9.app] [--mono <wine-mono.msi>]
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
       bodega sdl install [file.dmg]
       bodega pads
       bodega catalog list [text]
       bodega catalog show <id>
       bodega catalog install <id> [bottle] [--runtime mach9]
       bodega fix list [text]
       bodega fix show <id|steam-appid>
       bodega apps
       bodega open [--backend <b>] [--hud] <bottle> [key]
       bodega switch status
       bodega switch emulator <Ryujinx.app>|auto
       bodega switch option fullscreen|headless on|off
       bodega switch add <file|app|folder>…
       bodega switch list
       bodega switch remove <game>
       bodega switch open <game>
       bodega switch stop <game>''';

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
  ['backend', 'list', '--runtime', final name] when _kindNamed(name) != null =>
    (home) async {
      listBackends(home, runtime: _kindNamed(name)!).forEach((name, installed) {
        out.writeln('$name: ${installed ? 'installed' : 'not installed'}');
      });
      return 0;
    },
  _ => null,
};
