import 'dart:async';
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
     bodega backend test <botella> <backend>
     bodega sync <botella> <msync|none>
     bodega option <botella> gpu auto|discrete
     bodega option <botella> gamemode on|off
     bodega sdl install [archivo.dmg]
     bodega catalog list [texto]
     bodega catalog show <id>
     bodega catalog install <id> [botella]
     bodega apps
     bodega open [--backend <b>] [--hud] <botella> [clave]''';

Future<void> main(List<String> args) async {
  final Future<int> Function(String home)? verb = switch (args) {
    ['install', final engine, final hostlibs] => (home) async {
      stdout.writeln(await installRuntime(home, engine, hostlibs));
      return 0;
    },
    ['sdl', 'install', ...final rest] when rest.length < 2 => (home) async {
      stdout.writeln(
        await installSdl(home, dmg: rest.isEmpty ? null : rest.single),
      );
      stdout.writeln('Las botellas usarán SDL2 al volver a abrirlas.');
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
      final since = DateTime.now();
      final log = await runInBottle(
        home,
        run.bottle,
        run.program,
        run.args,
        backend: run.backend,
        hud: run.hud,
      );
      return _follow(home, run.bottle, log, since);
    },
    ['open', ...final rest] when parseOpen(rest) != null => (home) async {
      final open = parseOpen(rest)!;
      final since = DateTime.now();
      final log = await openApp(
        home,
        open.bottle,
        key: open.key,
        backend: open.backend,
        hud: open.hud,
      );
      return _follow(home, open.bottle, log, since);
    },
    ['apps'] => (home) async {
      for (final app in installedApps(home)) {
        stdout.writeln('${app.bottle}  ${app.title}  ${app.key}');
      }
      return 0;
    },
    ['sync', final bottle, final mode] => (home) async {
      if (await setSync(home, bottle, mode)) stdout.writeln('botella detenida');
      return 0;
    },
    ['option', final bottle, 'gpu', final mode]
        when mode == 'auto' || mode == 'discrete' =>
      (home) async {
        setBottleOptions(home, bottle, gpu: mode);
        return 0;
      },
    ['option', final bottle, 'gamemode', final mode]
        when mode == 'on' || mode == 'off' =>
      (home) async {
        setBottleOptions(home, bottle, gamemode: mode == 'on');
        return 0;
      },
    ['catalog', 'list'] => (home) async {
      _list(catalogEntries());
      return 0;
    },
    ['catalog', 'list', final text] => (home) async {
      _list(catalogEntries(text));
      return 0;
    },
    ['catalog', 'show', final id] => (home) async {
      _show(catalogEntry(id));
      return 0;
    },
    ['catalog', 'install', final id, ...final rest] when rest.length < 2 =>
      (home) async {
        final entry = catalogEntry(id);
        final bottle = rest.firstOrNull ?? id;
        stdout.writeln(
          'instalada en: ${await installEntry(home, entry, bottle: bottle, onStep: stdout.writeln)}',
        );
        entry.notes.forEach((note) => stdout.writeln('nota: $note'));
        stdout.writeln('ábrela con: bodega open $bottle');
        return 0;
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
    final issues = await checkHost();
    if (issues.isNotEmpty) {
      throw issues
          .map((i) => '${i.title}: ${i.command ?? i.detail}')
          .join('\n');
    }
    exitCode = await verb(bodegaHome(Platform.environment));
  } catch (e) {
    stderr.writeln('bodega: ${e is FormatException ? e.message : e}');
    exitCode = 1;
  }
}

/// What `run` and `open` share: says what was chosen and waits for the exit.
/// A launcher starts its game while this waits, so Easy Anti-Cheat's failure
/// is looked for during the wait too (I11). ponytail: nothing watches once a
/// launcher that relaunches itself has exited, as Steam does when it updates.
Future<int> _follow(
  String home,
  String bottle,
  String log,
  DateTime since,
) async {
  stdout
    ..writeln(backendOf(log))
    ..writeln('log: $log');
  final told = <String>{};
  void antiCheat() {
    for (final hint in antiCheatHints(home, bottle, since: since)) {
      if (told.add(hint)) stderr.writeln('pista: $hint');
    }
  }

  final watch = Timer.periodic(const Duration(seconds: 5), (_) => antiCheat());
  final code = await exitOf(log);
  watch.cancel();
  antiCheat();
  await _hints(log);
  return code;
}

void _list(List<CatalogEntry> entries) {
  for (final entry in entries) {
    stdout.writeln(
      '${entry.id.padRight(16)}  ${entry.title.padRight(24)}  ${entry.status}',
    );
  }
}

void _show(CatalogEntry entry) {
  stdout
    ..writeln('${entry.title} (${entry.id})')
    ..writeln('estado: ${entry.status}: ${entry.statusNote}')
    ..writeln('backend: ${entry.backend}, sync: ${entry.sync}');
  if (entry.flaky case final flaky?) stdout.writeln('inestable: $flaky');
  for (final note in entry.notes) {
    stdout.writeln('nota: $note');
  }
  for (final issue in entry.knownIssues) {
    stdout.writeln('problema: ${issue.symptom} -> ${issue.fix}');
  }
  stdout.writeln(
    'fuente: ${entry.source['repo']} ${entry.source['commit']}, '
    '${entry.source['path']} (${entry.source['license']}); '
    'verificado: ${entry.source['verified']}',
  );
}

Future<void> _hints(String log) async {
  for (final hint in await hintsIn(log)) {
    stderr.writeln('pista: $hint');
  }
}
