import 'dart:io';

import 'package:engine/engine.dart';

const _usage = '''
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>''';

Future<void> main(List<String> args) async {
  final Future<int> Function(String home)? verb = switch (args) {
    ['install', final engine, final hostlibs] => (home) async {
      stdout.writeln(await installRuntime(home, engine, hostlibs));
      return 0;
    },
    ['create', final bottle] => (home) async {
      final logs = Directory('${bottleDir(home, bottle)}/logs');
      final fresh = !logs.existsSync();
      try {
        stdout.writeln('log: ${await createBottle(home, bottle)}');
        return 0;
      } finally {
        // Also when create fails: a new bottle has just its wineboot log.
        if (fresh && logs.existsSync()) {
          for (final file in logs.listSync()) {
            if (file.path.endsWith('.log')) await _hints(file.path);
          }
        }
      }
    },
    ['run', final bottle, final program, ...final rest] => (home) async {
      final log = await runInBottle(home, bottle, program, rest);
      stdout.writeln('log: $log');
      final code = await exitOf(log);
      await _hints(log);
      return code;
    },
    ['wait', final bottle] => (home) => waitBottle(home, bottle),
    ['stop', final bottle] => (home) => stopBottle(home, bottle),
    _ => null,
  };
  if (verb == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final rosetta = await Process.run('/usr/bin/arch', [
      '-x86_64',
      '/usr/bin/true',
    ]);
    if (rosetta.exitCode != 0) {
      throw 'falta Rosetta: '
          'softwareupdate --install-rosetta --agree-to-license';
    }
    exitCode = await verb(bodegaHome(Platform.environment));
  } catch (e) {
    stderr.writeln('bodega: ${e is FormatException ? e.message : e}');
    exitCode = 1;
  }
}

Future<void> _hints(String log) async {
  for (final hint in await hintsIn(log)) {
    stderr.writeln('pista: $hint');
  }
}
