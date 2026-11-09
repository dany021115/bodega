import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

void main() {
  useMac();
  late String tmp, home;

  setUp(() async {
    tmp = Directory.systemTemp
        .createTempSync('bodega-options')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
    await installRuntime(home, engine, hostlibs);
  });

  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  String prefix(String bottle) => '$home/bottles/$bottle/prefix';

  Map<String, String> lastEnv(String bottle) => {
    for (final line in File('${prefix(bottle)}/last-env').readAsLinesSync())
      if (line.indexOf('=') case final at when at > 0)
        line.substring(0, at): line.substring(at + 1),
  };

  Future<void> program(String bottle) async {
    File('${prefix(bottle)}/drive_c/P/a.exe').createSync(recursive: true);
  }

  group('settings', () {
    test('a bottle without these fields has their defaults', () async {
      await createBottle(home, 'b');
      File('$home/bottles/b/settings.json').writeAsStringSync(
        '{"backend": "wine", "sync": "none", "programs": {}}',
      );
      final settings = bottleSettings(home, 'b');
      expect(settings.backend, 'wine');
      expect(settings.highRes, isFalse);
      expect(settings.dlss, isFalse);
      expect(settings.avx, isTrue);
      expect(settings.windows, 'win10');
      expect(settings.env, isEmpty);
    });

    test('an unknown Windows version in the file is an error', () async {
      await createBottle(home, 'b');
      File('$home/bottles/b/settings.json')
          .writeAsStringSync('{"windows": "win95"}');
      expect(() => bottleSettings(home, 'b'), throwsA(contains('win95')));
    });

    test('backend, then bottle, then program, then the launch', () async {
      await createBottle(home, 'b');
      await program('b');
      setBottleOptions(
        home,
        'b',
        dlss: true,
        env: {'A': 'botella', 'B': 'botella', 'C': 'botella'},
      );
      addApp(
        home,
        'b',
        'A',
        'P/a.exe',
        env: {'B': 'programa', 'C': 'programa'},
      );

      await exitOf(await openApp(home, 'b', env: {'C': 'lanzamiento'}));
      final env = lastEnv('b');
      expect(env['A'], 'botella');
      expect(env['B'], 'programa');
      expect(env['C'], 'lanzamiento');
      expect(env['D3DM_ENABLE_METALFX'], '1');
      expect(env['DXMT_ENABLE_NVEXT'], '1');
      expect(env['ROSETTA_ADVERTISE_AVX'], '1');
    });

    test('without AVX the variable goes, not just changes', () async {
      await createBottle(home, 'b');
      await program('b');
      addApp(home, 'b', 'A', 'P/a.exe');

      await exitOf(await openApp(home, 'b', avx: false));
      expect(lastEnv('b'), isNot(contains('ROSETTA_ADVERTISE_AVX')));
      await exitOf(await openApp(home, 'b'));
      expect(lastEnv('b'), contains('ROSETTA_ADVERTISE_AVX'));

      setBottleOptions(home, 'b', avx: false);
      await exitOf(await openApp(home, 'b'));
      expect(lastEnv('b'), isNot(contains('ROSETTA_ADVERTISE_AVX')));
      await exitOf(await runInBottle(home, 'b', r'C:\P\a.exe', [], avx: true));
      expect(lastEnv('b'), contains('ROSETTA_ADVERTISE_AVX'));
    });

    test('a launcher keeps its arguments', () async {
      await createBottle(home, 'b');
      await program('b');
      addApp(home, 'b', 'A', 'P/a.exe', args: ['-uno', 'dos tres']);
      expect(bottleApps(home, 'b').single.args, ['-uno', 'dos tres']);
      final log = await openApp(home, 'b');
      await exitOf(log);
      expect(File(log).readAsStringSync(), contains('-uno dos tres'));
    });
  });

  group('setBottleUser (U1–U4)', () {
    String users(String bottle) => '${prefix(bottle)}/drive_c/users';

    test('names the Windows user and takes the profile with it', () async {
      await createBottle(home, 'b');
      await program('b');
      addApp(home, 'b', 'A', 'P/a.exe');
      Future<String?> launchedAs() async {
        await exitOf(await openApp(home, 'b'));
        return lastEnv('b')['USER'];
      }

      expect(await launchedAs(), hostUser);
      final mac = hostUser;
      File('${users('b')}/$mac/AppData/x').createSync(recursive: true);
      Link('${users('b')}/$mac/Documents').createSync('$tmp/docs');

      expect(await setBottleUser(home, 'b', ' Dany '), isTrue);
      expect(bottleSettings(home, 'b').user, 'Dany');
      expect(await launchedAs(), 'Dany');
      expect(File('${users('b')}/Dany/AppData/x').existsSync(), isTrue);
      expect(Link('${users('b')}/Dany/Documents').targetSync(), '$tmp/docs');
      expect(Directory('${users('b')}/$mac').existsSync(), isFalse);
      expect(
        File('${prefix('b')}/reg.log').readAsStringSync(),
        contains(
          r'reg add HKCU\Environment /v TEMP /t REG_EXPAND_SZ '
          r'/d %USERPROFILE%\AppData\Local\Temp /f',
        ),
      );
      expect(await setBottleUser(home, 'b', 'Dany'), isFalse);

      expect(await setBottleUser(home, 'b', null), isTrue);
      expect(bottleSettings(home, 'b').user, '');
      expect(
        File('$home/bottles/b/settings.json').readAsStringSync(),
        isNot(contains('"user"')),
      );
      expect(File('${users('b')}/$mac/AppData/x').existsSync(), isTrue);
      expect(await launchedAs(), mac);
    });

    test('a name taken, or a bad one, changes nothing', () async {
      await createBottle(home, 'b');
      Directory('${users('b')}/$hostUser').createSync(recursive: true);
      Directory('${users('b')}/Dany').createSync();
      await expectLater(
        setBottleUser(home, 'b', 'Dany'),
        throwsA(contains('ya existe')),
      );
      for (final bad in ['a/b', 'x' * 21, '...', 'a*b', 'a\tb']) {
        await expectLater(
          setBottleUser(home, 'b', bad),
          throwsA(contains('nombre')),
          reason: bad,
        );
      }
      expect(bottleSettings(home, 'b').user, '');
      expect(badUser('Daniel Medina'), isNull);
    });
  });

  group('setHighRes', () {
    List<String> reg(String bottle) {
      final file = File('${prefix(bottle)}/reg.log');
      return [
        for (final line in file.readAsLinesSync())
          if (!line.contains('WineBus')) line,
      ];
    }

    test('writes both values and stops the bottle', () async {
      await createBottle(home, 'b');
      expect(await setHighRes(home, 'b', true), isTrue);
      expect(reg('b'), [
        r'reg add HKCU\Software\Wine\Mac Driver /v RetinaMode /t REG_SZ /d y /f',
        r'reg add HKCU\Control Panel\Desktop /v LogPixels /t REG_DWORD /d 192 /f',
      ]);
      expect(
        File('${prefix('b')}/server.log').readAsStringSync(),
        contains('k'),
      );
      expect(bottleSettings(home, 'b').highRes, isTrue);
    });

    test('the same value again does nothing', () async {
      await createBottle(home, 'b');
      await setHighRes(home, 'b', true);
      File('${prefix('b')}/server.log').deleteSync();
      expect(await setHighRes(home, 'b', true), isFalse);
      expect(reg('b'), hasLength(2));
      expect(File('${prefix('b')}/server.log').existsSync(), isFalse);
    });

    test('turning it off writes the defaults back', () async {
      await createBottle(home, 'b');
      await setHighRes(home, 'b', true);
      await setHighRes(home, 'b', false);
      expect(reg('b').skip(2), [
        r'reg add HKCU\Software\Wine\Mac Driver /v RetinaMode /t REG_SZ /d n /f',
        r'reg add HKCU\Control Panel\Desktop /v LogPixels /t REG_DWORD /d 96 /f',
      ]);
      expect(bottleSettings(home, 'b').highRes, isFalse);
    });
  });

  group('setWindowsVersion', () {
    test('runs winecfg and keeps it', () async {
      await createBottle(home, 'b');
      await setWindowsVersion(home, 'b', 'win7');
      expect(
        File('${prefix('b')}/winecfg.log').readAsStringSync(),
        'winecfg -v win7\n',
      );
      expect(bottleSettings(home, 'b').windows, 'win7');
    });

    test('another one is an error, and changes nothing', () async {
      await createBottle(home, 'b');
      await expectLater(
        setWindowsVersion(home, 'b', 'foo'),
        throwsA(contains('foo')),
      );
      expect(File('${prefix('b')}/winecfg.log').existsSync(), isFalse);
      expect(bottleSettings(home, 'b').windows, 'win10');
    });
  });

  group('installEntry into an existing bottle', () {
    CatalogEntry entry(String id, {String sync = 'none'}) =>
        CatalogEntry.fromJson({
          'id': id,
          'title': id.toUpperCase(),
          'status': 'reported',
          'statusNote': '',
          'installer': {
            'url': 'http://no-se-usa/x.exe',
            'sha256': null,
            'args': <String>[],
            'msi': false,
          },
          'exe': 'Prog/$id.exe',
          'args': <String>[],
          'backend': 'wine',
          'sync': sync,
          'env': <String, String>{},
          'registry': <Map<String, String>>[],
          'notes': <String>[],
          'knownIssues': <Map<String, String>>[],
          'source': <String, String>{},
        });

    File setup(String id) => File('$tmp/$id-setup.exe')
      ..writeAsStringSync(
        'mkdir -p "\$WINEPREFIX/drive_c/Prog"; '
        'touch "\$WINEPREFIX/drive_c/Prog/$id.exe"',
      );

    test('two entries end up in one bottle, which keeps its sync', () async {
      await installEntry(home, entry('a'), bottle: 'b', setup: setup('a').path);
      setBackend(home, 'b', 'dxvk');
      final steps = <String>[];
      await installEntry(
        home,
        entry('c', sync: 'msync'),
        bottle: 'b',
        intoExisting: true,
        setup: setup('c').path,
        onStep: steps.add,
      );

      expect(bottleApps(home, 'b').map((app) => app.id), ['a', 'c']);
      final settings = bottleSettings(home, 'b');
      expect(settings.sync, 'none');
      expect(settings.backend, 'dxvk');
      expect(settings.programs.keys, containsAll(['a.exe', 'c.exe']));
      expect(steps.first, contains('pide msync'));
      expect(steps, isNot(contains(startsWith('Creando'))));
    });

    test('without intoExisting it still refuses one that exists', () async {
      await createBottle(home, 'b');
      await expectLater(
        installEntry(home, entry('a'), bottle: 'b', setup: setup('a').path),
        throwsA(contains('ya existe')),
      );
    });

    test(
      'a bottle that does not exist, or is not ready, is an error',
      () async {
        await expectLater(
          installEntry(
            home,
            entry('a'),
            bottle: 'nada',
            intoExisting: true,
            setup: setup('a').path,
          ),
          throwsA(contains('no existe o no está lista')),
        );
        Directory('$home/bottles/rota').createSync();
        await expectLater(
          installEntry(
            home,
            entry('a'),
            bottle: 'rota',
            intoExisting: true,
            setup: setup('a').path,
          ),
          throwsA(contains('no existe o no está lista')),
        );
      },
    );
  });
}
