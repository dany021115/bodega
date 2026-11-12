import 'dart:async';
import 'dart:io';

import 'package:engine/engine.dart';

const _usage = '''
usage: bodega install <engine.tar.gz> <hostlibs.tar.gz>
       bodega create <bottle>
       bodega run [--backend <b>] [--hud] <bottle> <program> [args…]
       bodega wait <bottle>
       bodega stop <bottle>
       bodega rename <bottle> <new-name>
       bodega library <bottle> <key> on|off
       bodega hud <bottle> <key> on|off
       bodega backend list
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
       bodega catalog install <id> [bottle]
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
       bodega switch stop <game>
       bodega switch keys <file.keys|folder>…
       bodega switch firmware <file|folder>''';

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
      stdout.writeln('Bottles will use SDL2 the next time they open.');
      return 0;
    },
    ['pads'] => (home) async {
      final report = await hostPlatform.gamepads();
      if (report == null) {
        stdout.writeln(
          'On ${hostPlatform.displayName}, Bodega sets up gamepads by itself; there is nothing to check.',
        );
        return 0;
      }
      if (report.pads.isEmpty) stdout.writeln('No gamepads connected.');
      for (final pad in report.pads) {
        stdout.writeln(
          '${pad.readable ? 'ok' : 'NO ACCESS'}  ${pad.name} '
          '(${pad.vid}:${pad.pid})  ${pad.node}',
        );
      }
      stdout.writeln('SDL2: ${report.sdl ? 'installed' : 'missing'}');
      for (final issue in report.issues) {
        stdout.writeln('\n${describeHostIssue(issue)}');
        if (issue.command != null) stdout.writeln('  ${issue.command}');
      }
      return report.issues.isEmpty ? 0 : 1;
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
      final app = open.key == null
          ? bottleApps(home, open.bottle).firstOrNull
          : bottleApps(
              home,
              open.bottle,
            ).where((app) => app.key == open.key).firstOrNull;
      final fix = app == null ? null : fixForApp(app.key);
      if (fix != null) {
        stdout.writeln(
          'fix: ${fix.title}, ${_stepsHere(fix)}'
          '${fix.optIn ? ' ($_optIn)' : ''}',
        );
      }
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
      if (await setSync(home, bottle, mode)) stdout.writeln('bottle stopped');
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
    ['fix', 'list'] => (home) async {
      _listFixes(gameFixes());
      return 0;
    },
    ['fix', 'list', final text] => (home) async {
      _listFixes(gameFixes(text));
      return 0;
    },
    ['fix', 'show', final id] => (home) async {
      _showFix(gameFix(id));
      return 0;
    },
    ['catalog', 'install', final id, ...final rest] when rest.length < 2 =>
      (home) async {
        final entry = catalogEntry(id);
        final bottle = rest.firstOrNull ?? id;
        stdout.writeln(
          'installed in: ${await installEntry(home, entry, bottle: bottle, onStep: (step) => stdout.writeln(describeInstallStep(step)))}',
        );
        entry.notes.forEach((note) => stdout.writeln('note: $note'));
        stdout.writeln('open it with: bodega open $bottle');
        return 0;
      },
    ['wait', final bottle] => (home) => waitBottle(home, bottle),
    ['stop', final bottle] => (home) => stopBottle(home, bottle),
    ['rename', final from, final to] => (home) async {
      await renameBottle(home, from, to);
      stdout.writeln('bottle renamed: $to');
      return 0;
    },
    ['library', final bottle, final key, final mode]
        when mode == 'on' || mode == 'off' =>
      (home) async {
        setInLibrary(home, bottle, key, mode == 'on');
        return 0;
      },
    ['hud', final bottle, final key, final mode]
        when mode == 'on' || mode == 'off' =>
      (home) async {
        setAppHud(home, bottle, key, mode == 'on');
        return 0;
      },
    ['backend', 'list'] => (home) async {
      // tool/smoke_linux.sh greps the exact line `dxvk: installed`.
      listBackends(home).forEach((name, installed) {
        stdout.writeln('$name: ${installed ? 'installed' : 'not installed'}');
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
        ..writeln('test it with: bodega backend test <bottle> d3dmetal')
        ..writeln(
          "its use is subject to Apple's license for the Game Porting Toolkit",
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
          '${r.ok ? 'OK  ' : 'FAIL'} D3D${r.d3d} ${r.bits} bits  log: ${r.log}',
        );
      }
      return results.every((r) => r.ok) ? 0 : 1;
    },
    ['switch', ...final rest] => switchVerb(rest, stdout),
    _ => null,
  };
  if (verb == null) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }
  try {
    final issues = needsHost(args) ? await checkHost() : const <HostIssue>[];
    if (issues.isNotEmpty) {
      // Each issue is a failure of its own: every line carries the prefix
      // (E6).
      for (final issue in issues) {
        final text = [describeHostIssue(issue), ?issue.command].join(': ');
        stderr.writeln('bodega: $text');
      }
      exitCode = 1;
      return;
    }
    exitCode = await verb(bodegaHome(Platform.environment));
  } catch (e) {
    stderr.writeln('bodega: $e');
    exitCode = 1;
  }
}

/// What an opt-in fix adds to its line: it is shown, never applied by itself.
const _optIn = 'opt-in: never applied by itself';

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
  final told = <AntiCheatHint>{};
  void antiCheat() {
    for (final hint in antiCheatHints(home, bottle, since: since)) {
      if (told.add(hint)) {
        stderr.writeln('hint: ${describeAntiCheatHint(hint)}');
      }
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
  // A field the recipe has no data for is null (gog-galaxy's `verified`).
  String source(String field) => entry.source[field] ?? 'no data';
  stdout
    ..writeln('${entry.title} (${entry.id})')
    ..writeln('status: ${entry.status}: ${entry.statusNote}')
    ..writeln('backend: ${entry.backend}, sync: ${entry.sync}');
  if (entry.flaky case final flaky?) stdout.writeln('flaky: $flaky');
  for (final note in entry.notes) {
    stdout.writeln('note: $note');
  }
  for (final issue in entry.knownIssues) {
    stdout.writeln('issue: ${issue.symptom} -> ${issue.fix}');
  }
  stdout.writeln(
    'source: ${source('repo')} ${source('commit')}, '
    '${source('path')} (${source('license')}); '
    'verified: ${source('verified')}',
  );
}

/// How many of [fix]'s steps were verified on this host's platform.
String _stepsHere(GameFix fix) {
  final count = fix.steps.where((step) => step.applies).length;
  final total = fix.steps.length;
  return '$count of $total ${total == 1 ? 'step' : 'steps'} '
      'for ${hostPlatform.displayName}';
}

void _listFixes(List<GameFix> fixes) {
  for (final fix in fixes) {
    stdout.writeln(
      '${fix.id.padRight(34)}  ${fix.steam.toString().padRight(8)}  '
      '${fix.title.padRight(34)}  '
      '${fix.steps.where((step) => step.applies).length}/${fix.steps.length}'
      '${fix.optIn ? '  opt-in' : ''}',
    );
  }
}

void _showFix(GameFix fix) {
  stdout
    ..writeln('${fix.title} (${fix.id}), Steam ${fix.steam}')
    ..writeln(_stepsHere(fix) + (fix.optIn ? '; $_optIn' : ''));
  for (final step in fix.steps) {
    final what = switch (step.type) {
      'env' => 'variable ${step.name}=${step.value}',
      'registry' =>
        'registry ${step.key} ${step.name} (${step.valueType}) = ${step.data}',
      _ => 'dlloverride ${step.value}',
    };
    stdout.writeln(
      '  ${step.applies ? 'applies' : 'does not apply'}  $what  [${step.platforms.join(', ')}]',
    );
  }
  for (final note in fix.notes) {
    stdout.writeln('note: $note');
  }
  for (final issue in fix.knownIssues) {
    stdout.writeln('issue: ${issue.symptom} -> ${issue.fix}');
  }
  final verified = fix.verified;
  stdout.writeln(
    'source: gauthierpiarrette/highball-db ${fixesSourceCommit.substring(0, 7)}, '
    '${fix.source} (CC0-1.0); '
    'verified: ${verified == null ? 'no' : '${verified['date']} on ${verified['chip']}'}',
  );
}

Future<void> _hints(String log) async {
  for (final hint in await hintsIn(log)) {
    stderr.writeln('hint: ${hint.english}');
  }
}
