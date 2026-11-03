import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

const fakeWine = r'''#!/bin/sh
case $1 in
--version) echo wine-11.0 ;;
wineboot)
  case $WINEPREFIX in */broken/*) exit 0 ;; esac
  d=$WINEPREFIX/drive_c/windows/syswow64
  mkdir -p "$d" && touch "$d/kernel32.dll" "$WINEPREFIX/system.reg" ;;
*) echo "$@"; sleep 5 & exit 7 ;;
esac
''';

const fakeWineserver = r'''#!/bin/sh
case $1 in -k) exit 1 ;; esac
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
    final sum = await Process.run('/usr/bin/shasum', [
      '-a',
      '256',
      name,
    ], workingDirectory: dir);
    File('$dir/$name.sha256').writeAsStringSync('${sum.stdout}');
  }
  return ('$dir/$id.tar.gz', '$dir/hostlibs-$id.tar.gz');
}

void main() {
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
    for (final name in ['prueba', 'cave-story_2']) {
      expect(bottleDir('/h', name), '/h/bottles/$name');
    }
    for (final name in ['', '.x', '-x', 'a.', 'a b', 'a/b', 'a:b', 'a' * 65]) {
      expect(() => bottleDir('/h', name), throwsFormatException, reason: name);
    }
    expect(winPathProblem('/Users/q/Library/Application Support/B'), isNull);
    expect(winPathProblem('/Users/q/Juegos/Cave Story ñ/Juego.exe'), isNull);
    expect(winPathProblem('/a/./b/../c'), isNull);
    for (final path in ['/a./b', '/a /b', '/a?b', '/a:b', '/<a>', '/a|b']) {
      expect(winPathProblem(path), isNotNull, reason: path);
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
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('"a."'),
        ),
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
    final noRuntime = throwsA(contains('no hay runtime: bodega install'));
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
      throwsA(contains('ya instalado')),
    );

    final (b, bLibs) = await fakeRuntime(tmp, 'engine-b');
    File('$b.sha256').writeAsStringSync('${'0' * 64}  engine-b.tar.gz\n');
    await expectLater(
      installRuntime(home, b, bLibs),
      throwsA(contains('engine-b.tar.gz: FAILED')),
    );
    // A .sha256 that names another file, which does check out.
    File('$bLibs.sha256').copySync('$b.sha256');
    await expectLater(
      installRuntime(home, b, bLibs),
      throwsA(contains('no corresponde a engine-b.tar.gz')),
    );
    File('$b.sha256').deleteSync();
    await expectLater(
      installRuntime(home, b, bLibs),
      throwsA(
        contains('gh release download engine-b -R dany021115/bodega-engine'),
      ),
    );
    expect(runtimes(), ['current', 'engine-a']);

    final (c, cLibs) = await fakeRuntime(tmp, 'engine-c', gnutls: false);
    await expectLater(
      installRuntime(home, c, cLibs),
      throwsA(
        'runtime incompleto: falta '
        'engine/lib/wine/x86_64-unix/libgnutls.30.dylib',
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
      throwsA(allOf(contains('ya existe'), contains('rm -rf'))),
    );
    await expectLater(
      createBottle(home, 'broken'),
      throwsA(contains('$home/bottles/broken/logs/')),
    );
    expect(
      Directory('$home/bottles/broken/logs').listSync().map((e) => e.path),
      contains(endsWith('-wineboot.log')),
    );

    final logs = Directory('$home/bottles/t/logs');
    final before = logs.listSync().length;
    await expectLater(
      runInBottle(home, 't', '$tmp/no/Juego.exe', []),
      throwsA(isA<FileSystemException>()),
    );
    expect(logs.listSync(), hasLength(before));

    Directory('$prefix/drive_c/Juegos').createSync();
    final clock = Stopwatch()..start();
    final run = await runInBottle(home, 't', r'C:\Juegos\Mi Juego.exe', []);
    expect(await exitOf(run), 7);
    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    expect(run, endsWith('-Mi_Juego.log'));
    final text = File(run).readAsStringSync();
    expect(text, contains('# exit=7\n'));
    expect(text, contains('# cwd $prefix/drive_c/Juegos\n'));
    expect(await stopBottle(home, 't'), 0);
    expect(await waitBottle(home, 't'), 0);

    for (final missing in [
      () => runInBottle(home, 'nope', 'notepad', []),
      () => waitBottle(home, 'nope'),
      () => stopBottle(home, 'nope'),
    ]) {
      await expectLater(missing(), throwsA('no existe la botella nope'));
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
        'wine: failed to open "C:\\\\Juegos\\\\x.exe"\n'
        '# exit=53\n',
      );
    final clean = File('$tmp/clean.log')
      ..writeAsStringSync('# runtime engine-x\nok\r\n# exit=0\n');
    final hints = await hintsIn(dirty.path);
    expect(hints, hasLength(4));
    for (final word in ['FreeType', 'GnuTLS', 'bodega stop', 'ruta']) {
      expect(hints, contains(contains(word)), reason: word);
    }
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
        if (Directory('$home/bottles/t').existsSync()) {
          await stopBottle(home, 't');
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
        for (final lib in ['FreeType', 'GnuTLS']) {
          final hint = contains(contains(lib));
          expect(hints, hostlibs ? isNot(hint) : hint, reason: lib);
        }
        expect(await stopBottle(home, 't'), 0);
      });
    },
    skip: runtime == null ? 'BODEGA_TEST_RUNTIME no está definida' : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
