import 'dart:io';

import 'package:engine/engine.dart';

const _usage = '''
uso: bodega install <engine.tar.gz> <hostlibs.tar.gz>
     bodega create <botella>
     bodega run [--backend <b>] [--hud] <botella> <programa> [args…]
     bodega wait <botella>
     bodega stop <botella>
     bodega backend list
     bodega backend install <dxmt|dxvk> [tarball]
     bodega backend import d3dmetal <carpeta>
     bodega backend set <botella> <backend> [--exe <nombre.exe>]
     bodega backend test <botella> <backend>''';

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
    ['run', ...final rest] when parseRun(rest) != null => (home) async {
      final run = parseRun(rest)!;
      final log = await runInBottle(
        home,
        run.bottle,
        run.program,
        run.args,
        backend: run.backend,
        hud: run.hud,
      );
      stdout.writeln(backendOf(log));
      stdout.writeln('log: $log');
      final code = await exitOf(log);
      await _hints(log);
      return code;
    },
    ['wait', final bottle] => (home) => waitBottle(home, bottle),
    ['stop', final bottle] => (home) => stopBottle(home, bottle),
    ['backend', 'list'] => (home) async {
      listBackends(home).forEach((name, installed) {
        stdout.writeln('$name: ${installed ? 'instalado' : 'no instalado'}');
      });
      return 0;
    },
    ['backend', 'install', final name] => (home) async {
      stdout.writeln(await installBackend(home, name));
      return 0;
    },
    ['backend', 'install', final name, final tarball] => (home) async {
      stdout.writeln(await installBackend(home, name, tarball: tarball));
      return 0;
    },
    ['backend', 'import', 'd3dmetal', final folder] => (home) async {
      stdout
        ..writeln(await importD3DMetal(home, folder))
        ..writeln('compruébalo: bodega backend test <botella> d3dmetal')
        ..writeln(
          'su uso se rige por la licencia de Apple del Game Porting Toolkit',
        );
      return 0;
    },
    ['backend', 'set', final bottle, final backend] => (home) async {
      setBackend(home, bottle, backend);
      return 0;
    },
    ['backend', 'set', final bottle, final backend, '--exe', final exe] =>
      (home) async {
        setBackend(home, bottle, backend, exe: exe);
        return 0;
      },
    ['backend', 'test', final bottle, final backend] => (home) async {
      final results = await backendTest(home, bottle, backend);
      for (final r in results) {
        stdout.writeln(
          '${r.ok ? 'OK   ' : 'FALLA'} D3D${r.d3d} ${r.bits} bits  log: ${r.log}',
        );
      }
      return results.every((r) => r.ok) ? 0 : 1;
    },
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
