import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:engine/probe_data.dart';
import 'package:test/test.dart';

import '_mac.dart';

const fakeWine = r'''#!/bin/sh
case $1 in
--version) echo wine-11.0 ;;
wineboot)
  case $WINEPREFIX in */broken/*) exit 0 ;; esac
  d=$WINEPREFIX/drive_c/windows/syswow64
  mkdir -p "$d" && touch "$d/kernel32.dll" "$WINEPREFIX/system.reg" ;;
reg)
  case "$*" in *FAIL*) exit 3 ;; esac
  echo "$@" >>"$WINEPREFIX/reg.log" ;;
msiexec) echo "$@" >"$WINEPREFIX/msi-args"; . "$3" ;;
tasklist) cat "$WINEPREFIX/tasks" 2>/dev/null ;;
winecfg) echo "$@" >>"$WINEPREFIX/winecfg.log" ;;
*-setup.exe) echo "$@" >"$WINEPREFIX/setup-args"; . "$1" ;;
*) env >"$WINEPREFIX/last-env"; echo "$@"; sleep 5 & exit 7 ;;
esac
''';

const fakeWineserver = r'''#!/bin/sh
case $1 in
-k) { echo k >>"$WINEPREFIX/server.log"; } 2>/dev/null
  rm -f "$WINEPREFIX/hang"; exit 1 ;;
-w) while [ -e "$WINEPREFIX/hang" ]; do sleep 0.1; done ;;
esac
''';

/// A fake runtime packed like the real one (design §6): `<id>.tar.gz` with
/// `./` entries and `hostlibs-<id>.tar.gz` with files only, each next to its
/// `.sha256`.
Future<(String, String)> fakeRuntime(
  String dir,
  String id, {
  bool gnutls = true,
}) async {
  final engine = '$dir/src-$id', libs = '$dir/libs-$id';
  for (final file in requiredFiles.where((f) => !f.endsWith('.dylib'))) {
    File('$engine/$file').createSync(recursive: true);
  }
  File('$engine/engine/bin/wine').writeAsStringSync(fakeWine);
  File('$engine/engine/bin/wineserver').writeAsStringSync(fakeWineserver);
  await Process.run('/bin/chmod', [
    '+x',
    '$engine/engine/bin/wine',
    '$engine/engine/bin/wineserver',
  ]);
  final hostFiles = [
    'hostlibs.txt',
    ...requiredFiles.where(
      (f) => f.endsWith('.dylib') && (gnutls || !f.contains('gnutls')),
    ),
  ];
  for (final file in hostFiles) {
    File('$libs/$file').createSync(recursive: true);
  }
  await Process.run('/usr/bin/tar', [
    '-czf',
    '$dir/$id.tar.gz',
    '-C',
    engine,
    '.',
  ]);
  await Process.run('/usr/bin/tar', [
    '-czf',
    '$dir/hostlibs-$id.tar.gz',
    '-C',
    libs,
    ...hostFiles,
  ]);
  for (final name in ['$id.tar.gz', 'hostlibs-$id.tar.gz']) {
    File('$dir/$name.sha256')
        .writeAsStringSync(await sha256Line(name, dir: dir));
  }
  return ('$dir/$id.tar.gz', '$dir/hostlibs-$id.tar.gz');
}

void main() {
  useMac();
  late String tmp;
  setUp(() {
    final dir = Directory.systemTemp.createTempSync('bodega');
    tmp = dir.resolveSymbolicLinksSync();
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  test('wineEnv is hermetic', () {
    const kept = {
      'HOME': '/Users/q',
      'USER': 'q',
      'LOGNAME': 'q',
      'TMPDIR': '/var/folders/x/T/',
      '__CF_USER_TEXT_ENCODING': '0x1F5:0x0:0x8',
    };
    final parent = {
      ...kept,
      'WINEARCH': 'win32',
      'DYLD_LIBRARY_PATH': '/opt/homebrew/lib',
      'WINEDLLPATH': '/x',
      'CX_ROOT': '/cx',
      'LANG': 'es_ES.UTF-8',
      'WINEDEBUG': '+all',
      'PATH': '/opt/homebrew/bin',
    };
    final env = {
      ...kept,
      'PATH': '/usr/bin:/bin:/usr/sbin:/sbin',
      'WINEPREFIX': '/b/bottles/t/prefix',
      'WINEMSYNC': '1',
      'WINEDLLOVERRIDES': 'winemenubuilder.exe=d',
      'ROSETTA_ADVERTISE_AVX': '1',
      'DOTNET_EnableWriteXorExecute': '0',
      'MVK_CONFIG_LOG_LEVEL': '2',
      'WINEDEBUG': 'fixme-all',
    };
    expect(wineEnv('/b/bottles/t/prefix', parent), env);
    final debug = {...parent, 'BODEGA_WINEDEBUG': '+loaddll'};
    expect(wineEnv('/b/bottles/t/prefix', debug), {
      ...env,
      'WINEDEBUG': '+loaddll',
    });
  });

  test('names and windows paths', () {
    for (final name in ['sample', 'cave-story_2']) {
      expect(bottleDir('/h', name), '/h/bottles/$name');
    }
    for (final name in ['', '.x', '-x', 'a.', 'a b', 'a/b', 'a:b', 'a' * 65]) {
      expect(
        () => bottleDir('/h', name),
        throwsA(isA<BadBottleName>().having((f) => f.name, 'name', name)),
        reason: name,
      );
    }
    expect(winPathProblem('/Users/q/Library/Application Support/B'), isNull);
    expect(winPathProblem('/Users/q/Games/Cave Story ø/Game.exe'), isNull);
    expect(winPathProblem('/a/./b/../c'), isNull);
    for (final (path, part) in [
      ('/a./b', 'a.'),
      ('/a /b', 'a '),
      ('/a?b', 'a?b'),
      ('/a:b', 'a:b'),
      ('/<a>', '<a>'),
      ('/a|b', 'a|b'),
    ]) {
      expect(winPathProblem(path), (part: part, path: path), reason: path);
    }

    Directory('$tmp/real').createSync();
    Link('$tmp/link').createSync('real');
    final home = bodegaHome({'BODEGA_HOME': '$tmp/link/b', 'HOME': '/no'});
    expect(home, '$tmp/real/b');
    expect(Directory('$home/runtimes').existsSync(), isTrue);
    expect(Directory('$home/bottles').existsSync(), isTrue);
    expect(bodegaHome({'BODEGA_HOME': '$tmp/link/../real/./c'}), '$tmp/real/c');
    expect(
      () => bodegaHome({'BODEGA_HOME': '$tmp/a./b'}),
      throwsA(
        isA<BadWindowsPath>().having((f) => f.problem, 'problem', (
          part: 'a.',
          path: '$tmp/a./b',
        )),
      ),
    );
    expect(Directory('$tmp/a.').existsSync(), isFalse);
  });

  test('installRuntime', () async {
    final home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    List<String> runtimes() => [
      for (final e in Directory('$home/runtimes').listSync())
        e.path.split('/').last,
    ]..sort();
    final noRuntime = throwsA(isA<NoRuntime>());
    expect(() => currentRuntime(home), noRuntime);

    final (a, aLibs) = await fakeRuntime(tmp, 'engine-a');
    final rtA = await installRuntime(home, a, aLibs);
    expect(rtA, '$home/runtimes/engine-a');
    expect(
      File('$rtA/engine/lib/wine/x86_64-unix/libgnutls.30.dylib').existsSync(),
      isTrue,
    );
    expect(currentRuntime(home), rtA);

    File('$a.sha256').deleteSync();
    await expectLater(
      installRuntime(home, a, aLibs),
      throwsA(isA<AlreadyInstalled>().having((f) => f.path, 'path', rtA)),
    );

    final (b, bLibs) = await fakeRuntime(tmp, 'engine-b');
    final mismatch = throwsA(
      isA<ChecksumMismatch>().having((f) => f.file, 'file', b),
    );
    File('$b.sha256').writeAsStringSync('${'0' * 64}  engine-b.tar.gz\n');
    await expectLater(installRuntime(home, b, bLibs), mismatch);
    // A .sha256 that names another file, which does check out.
    File('$bLibs.sha256').copySync('$b.sha256');
    await expectLater(installRuntime(home, b, bLibs), mismatch);
    File('$b.sha256').deleteSync();
    await expectLater(
      installRuntime(home, b, bLibs),
      throwsA(
        isA<ChecksumMissing>().having((f) => f.file, 'file', '$b.sha256'),
      ),
    );
    expect(runtimes(), ['current', 'engine-a']);

    final (c, cLibs) = await fakeRuntime(tmp, 'engine-c', gnutls: false);
    await expectLater(
      installRuntime(home, c, cLibs),
      throwsA(
        isA<IncompleteArchive>()
            .having((f) => f.archive, 'archive', 'engine-c')
            .having(
              (f) => f.missing,
              'missing',
              'engine/lib/wine/x86_64-unix/libgnutls.30.dylib',
            ),
      ),
    );
    expect(runtimes(), ['current', 'engine-a']);

    await fakeRuntime(tmp, 'engine-b');
    final rtB = await installRuntime(home, b, bLibs);
    expect(rtB, '$home/runtimes/engine-b');
    expect(currentRuntime(home), rtB);

    Directory(rtB).deleteSync(recursive: true);
    expect(() => currentRuntime(home), noRuntime);
  });

  test('fake runtime cycle', () async {
    final home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine-f');
    await installRuntime(home, engine, hostlibs);

    final prefix = '$home/bottles/t/prefix';
    final log = await createBottle(home, 't');
    expect(File(log).readAsStringSync(), contains('# exit=0\n'));
    expect(
      File('$prefix/drive_c/windows/syswow64/kernel32.dll').existsSync(),
      isTrue,
    );
    await expectLater(
      createBottle(home, 't'),
      throwsA(isA<BottleExists>().having((f) => f.bottle, 'bottle', 't')),
    );
    await expectLater(
      createBottle(home, 'broken'),
      throwsA(
        isA<BottleSetupFailed>()
            .having((f) => f.timedOut, 'timedOut', isFalse)
            .having(
              (f) => f.log,
              'log',
              startsWith('$home/bottles/broken/logs/'),
            ),
      ),
    );
    expect(
      Directory('$home/bottles/broken/logs').listSync().map((e) => e.path),
      contains(endsWith('-wineboot.log')),
    );

    final logs = Directory('$home/bottles/t/logs');
    final before = logs.listSync().length;
    await expectLater(
      runInBottle(home, 't', '$tmp/no/Game.exe', []),
      throwsA(isA<FileSystemException>()),
    );
    final odd = File('$tmp/odd:/game.exe')..createSync(recursive: true);
    await expectLater(
      runInBottle(home, 't', odd.path, []),
      throwsA(
        isA<BadWindowsPath>().having((f) => f.problem, 'problem', (
          part: 'odd:',
          path: odd.path,
        )),
      ),
    );
    expect(logs.listSync(), hasLength(before));

    Directory('$prefix/drive_c/Games').createSync();
    final clock = Stopwatch()..start();
    final run = await runInBottle(home, 't', r'C:\Games\My Game.exe', []);
    expect(await exitOf(run), 7);
    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    expect(run, endsWith('-My_Game.log'));
    final text = File(run).readAsStringSync();
    expect(text, contains('# exit=7\n'));
    expect(text, contains('# cwd $prefix/drive_c/Games\n'));
    expect(text, contains('# backend wine (auto)\n'));
    expect(backendOf(run), 'backend wine (auto)');
    expect(File(log).readAsStringSync(), isNot(contains('# backend')));

    setBackend(home, 't', 'wine', exe: 'My Game.exe');
    final byExe = await runInBottle(home, 't', r'C:\Games\My Game.exe', []);
    await exitOf(byExe);
    expect(backendOf(byExe), 'backend wine (exe)');
    expect(
      File('$prefix/last-env').readAsStringSync(),
      contains('WINEMSYNC=1\n'),
    );
    final noDxmt = throwsA(
      isA<BackendNotInstalled>().having((f) => f.backend, 'backend', 'dxmt'),
    );
    await expectLater(
      runInBottle(home, 't', 'notepad', [], backend: 'dxmt'),
      noDxmt,
    );
    await expectLater(backendTest(home, 't', 'dxmt'), noDxmt);
    final probes = await backendTest(home, 't', 'wine');
    expect(probes.map((p) => (p.bits, p.d3d)), [(64, '11'), (64, '12')]);
    expect(probes.every((p) => !p.ok), isTrue, reason: 'fake wine exits 7');
    expect(
      File('$home/backends/probe/probe-64.exe').lengthSync(),
      greaterThan(0),
    );
    expect(await stopBottle(home, 't'), 0);
    expect(await waitBottle(home, 't'), 0);

    for (final missing in [
      () => runInBottle(home, 'nope', 'notepad', []),
      () => waitBottle(home, 'nope'),
      () => stopBottle(home, 'nope'),
    ]) {
      await expectLater(
        missing(),
        throwsA(
          isA<BottleNotFound>().having((f) => f.bottle, 'bottle', 'nope'),
        ),
      );
    }
  });

  test('hints', () async {
    final dirty = File('$tmp/dirty.log')
      ..writeAsStringSync(
        '# runtime engine-x\n'
        'Wine cannot find the FreeType font library.\n'
        '0024:err:winediag:gnutls_process_attach failed to load libgnutls, '
        'no support for encryption\n'
        'wine client error:0: version mismatch 812/815.\r\n'
        'wine: failed to open "C:\\\\Games\\\\x.exe"\n'
        // A marker twice is still one hint.
        'Wine cannot find the FreeType font library.\n'
        '# exit=53\n',
      );
    final clean = File('$tmp/clean.log')
      ..writeAsStringSync('# runtime engine-x\nok\r\n# exit=0\n');
    expect(await hintsIn(dirty.path), [
      LogHint.freeType,
      LogHint.gnuTls,
      LogHint.otherServer,
      LogHint.cannotOpen,
    ]);
    expect(await hintsIn(clean.path), isEmpty);
  });

  final runtime = Platform.environment['BODEGA_TEST_RUNTIME'];
  group(
    'real runtime',
    () {
      late String home;
      setUpAll(() {
        final dir = Directory.systemTemp.createTempSync('bodega-real');
        home = bodegaHome({'BODEGA_HOME': dir.path});
        final target = Directory(runtime!).absolute.path;
        Link('$home/runtimes/current').createSync(target);
      });
      tearDownAll(() async {
        for (final bottle in ['t', 'probe']) {
          if (Directory('$home/bottles/$bottle').existsSync()) {
            await stopBottle(home, bottle);
          }
        }
        Directory(home).deleteSync(recursive: true);
      });

      test('cycle', () async {
        final rt = currentRuntime(home);
        final version = await Process.run(
          '$rt/engine/bin/wine',
          ['--version'],
          environment: wineEnv('$home/bottles/t/prefix', Platform.environment),
          includeParentEnvironment: false,
        );
        expect('${version.stdout}', startsWith('wine-'));

        final clock = Stopwatch()..start();
        final logs = [await createBottle(home, 't')];
        print('create: ${clock.elapsed}');

        Future<int> run(String program, List<String> args) async {
          logs.add(await runInBottle(home, 't', program, args));
          return exitOf(logs.last);
        }

        expect(await run('cmd', ['/c', 'echo', 'ok']), 0);
        final lines = File(logs.last).readAsLinesSync(encoding: latin1);
        expect(lines.map((line) => line.trim()), contains('ok'));
        expect(await run('cmd', ['/c', 'exit', '7']), 7);
        await run('rundll32', ['dwrite.dll,BodegaProbe']);
        await run('rundll32', ['bcrypt.dll,BodegaProbe']);

        final hints = [for (final log in logs) ...await hintsIn(log)];
        final hostlibs = File(
          '$rt/engine/lib/wine/x86_64-unix/libgnutls.30.dylib',
        ).existsSync();
        for (final lib in [LogHint.freeType, LogHint.gnuTls]) {
          final hint = contains(lib);
          expect(hints, hostlibs ? isNot(hint) : hint, reason: lib.name);
        }
        expect(await stopBottle(home, 't'), 0);
      });

      // The probe stands in for an installer: it exits at once, so this checks
      // the flow, not a real installer (T9).
      test('installEntry', () async {
        final setup = File('$home/setup.exe')
          ..writeAsBytesSync(base64.decode(probe64Base64));
        final entry = CatalogEntry.fromJson({
          'id': 'probe',
          'title': 'Probe',
          'status': 'reported',
          'statusNote': '',
          'installer': {
            'url': 'file://${setup.path}',
            'sha256': null,
            'args': ['11'],
            'msi': false,
          },
          'exe': 'windows/system32/notepad.exe',
          'args': <String>[],
          'backend': 'wine',
          'sync': 'none',
          'env': {'BODEGA_PROBE': '1'},
          'registry': [
            {
              'key': r'HKCU\Software\Bodega',
              'name': 'Probe',
              'type': 'REG_SZ',
              'data': 'ok',
            },
          ],
          'notes': <String>[],
          'knownIssues': <Map<String, String>>[],
          'source': <String, String>{},
        });
        final clock = Stopwatch()..start();
        final dir = await installEntry(home, entry);
        print('install: ${clock.elapsed}');
        expect(installedApps(home).single.bottle, 'probe');

        final query = await runInBottle(home, 'probe', 'reg', [
          'query',
          r'HKCU\Software\Bodega',
          '/v',
          'Probe',
        ]);
        expect(await exitOf(query), 0);
        expect(File(query).readAsStringSync(encoding: latin1), contains('ok'));

        final set = await runInBottle(home, 'probe', 'cmd', ['/c', 'set']);
        expect(await exitOf(set), 0);
        final lines = File(set).readAsLinesSync(encoding: latin1);
        expect(lines.map((line) => line.trim()), contains('WINEMSYNC=0'));
        final logs = Directory('$dir/logs').listSync().map((e) => e.path);
        expect(logs, contains(endsWith('-probe-setup.log')));
        expect(await stopBottle(home, 'probe'), 0);
      });
    },
    skip: runtime == null ? 'BODEGA_TEST_RUNTIME is not set' : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
