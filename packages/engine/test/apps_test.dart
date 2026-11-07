import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'engine_test.dart' show fakeRuntime;

/// A `.lnk` with the shape of the real `Steam.lnk`: a local path in LinkInfo,
/// and its strings in UTF-16.
Uint8List lnk(
  String target, {
  String? workingDir,
  String? args,
  bool unicode = true,
  bool idList = false,
}) {
  final out = BytesBuilder();
  final header = ByteData(76)..setUint32(0, 0x4C, Endian.little);
  var flags = 0x02;
  if (idList) flags |= 0x01;
  if (unicode) flags |= 0x80;
  if (workingDir != null) flags |= 0x10;
  if (args != null) flags |= 0x20;
  header.setUint32(20, flags, Endian.little);
  out.add(header.buffer.asUint8List());
  if (idList) {
    final list = ByteData(2 + 6)..setUint16(0, 6, Endian.little);
    out.add(list.buffer.asUint8List());
  }
  final path = [...latin1.encode(target), 0];
  const infoHeader = 28;
  final info = ByteData(infoHeader)
    ..setUint32(0, infoHeader + path.length, Endian.little)
    ..setUint32(4, infoHeader, Endian.little)
    ..setUint32(16, infoHeader, Endian.little);
  out
    ..add(info.buffer.asUint8List())
    ..add(path);
  for (final text in [workingDir, args]) {
    if (text == null) continue;
    final units = unicode ? text.codeUnits : latin1.encode(text);
    final length = ByteData(2)..setUint16(0, text.length, Endian.little);
    out.add(length.buffer.asUint8List());
    if (unicode) {
      final wide = ByteData(units.length * 2);
      for (final (i, unit) in units.indexed) {
        wide.setUint16(i * 2, unit, Endian.little);
      }
      out.add(wide.buffer.asUint8List());
    } else {
      out.add(units);
    }
  }
  return out.toBytes();
}

/// A PE with these icons in its `.rsrc`: side, and the bytes of the image.
Uint8List pe(List<(int, List<int>)> icons) {
  const address = 0x1000, sectionAt = 64 + 24 + 40;
  final groupBytes = BytesBuilder()
    ..add(
      (ByteData(6)
            ..setUint16(2, 1, Endian.little)
            ..setUint16(4, icons.length, Endian.little))
          .buffer
          .asUint8List(),
    );
  for (final (i, (side, data)) in icons.indexed) {
    final row = ByteData(14)
      ..setUint8(0, side == 256 ? 0 : side)
      ..setUint8(1, side == 256 ? 0 : side)
      ..setUint32(8, data.length, Endian.little)
      ..setUint16(12, i + 1, Endian.little);
    groupBytes.add(row.buffer.asUint8List());
  }
  final g = groupBytes.toBytes();

  final images = <int>[for (final (_, data) in icons) ...data];

  // Root, icons by id, group by id, group's languages, and one language per
  // icon, in the tree a linker writes.
  final tree = BytesBuilder();
  void dir(List<(int, int)> rows) {
    final head = ByteData(16)..setUint16(14, rows.length, Endian.little);
    tree.add(head.buffer.asUint8List());
    for (final (id, to) in rows) {
      final row = ByteData(8)
        ..setUint32(0, id, Endian.little)
        ..setUint32(4, to, Endian.little);
      tree.add(row.buffer.asUint8List());
    }
  }

  const sub = 0x80000000;
  final rootSize = 16 + 8 * 2, iconsSize = 16 + 8 * icons.length;
  final groupSize = 16 + 8, groupLang = 16 + 8, langSize = 16 + 8;
  final atIcons = rootSize, atGroup = atIcons + iconsSize;
  final atGroupLang = atGroup + groupSize;
  final atLangs = atGroupLang + groupLang;
  final atData = atLangs + langSize * icons.length;
  final atGroupData = atData;
  final atIconData = atGroupData + 16;
  final dataStart = atIconData + 16 * icons.length;
  dir([(3, atIcons | sub), (14, atGroup | sub)]);
  dir([
    for (var i = 0; i < icons.length; i++)
      (i + 1, (atLangs + langSize * i) | sub),
  ]);
  dir([(1, atGroupLang | sub)]);
  dir([(1033, atGroupData)]);
  for (var i = 0; i < icons.length; i++) {
    dir([(1033, atIconData + 16 * i)]);
  }
  void entry(int at, int size) {
    final row = ByteData(16)
      ..setUint32(0, address + at, Endian.little)
      ..setUint32(4, size, Endian.little);
    tree.add(row.buffer.asUint8List());
  }

  final imageStart = dataStart + g.length;
  entry(dataStart, g.length);
  var running = imageStart;
  for (final (_, data) in icons) {
    entry(running, data.length);
    running += data.length;
  }
  tree
    ..add(g)
    ..add(images);
  final section = tree.toBytes();

  final out = BytesBuilder();
  final dos = ByteData(64)
    ..setUint8(0, 0x4D)
    ..setUint8(1, 0x5A)
    ..setUint32(60, 64, Endian.little);
  final head = ByteData(24)
    ..setUint8(0, 0x50)
    ..setUint8(1, 0x45)
    ..setUint16(6, 1, Endian.little);
  final row = ByteData(40);
  for (final (i, unit) in '.rsrc'.codeUnits.indexed) {
    row.setUint8(i, unit);
  }
  row
    ..setUint32(12, address, Endian.little)
    ..setUint32(16, section.length, Endian.little)
    ..setUint32(20, sectionAt, Endian.little);
  out
    ..add(dos.buffer.asUint8List())
    ..add(head.buffer.asUint8List())
    ..add(row.buffer.asUint8List())
    ..add(section);
  return out.toBytes();
}

void main() {
  useMac();
  late String tmp, home;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-apps')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
  });

  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  String bottle(String name) {
    final drive = '$home/bottles/$name/prefix/drive_c';
    Directory(drive).createSync(recursive: true);
    return drive;
  }

  File touch(String path) => File(path)..createSync(recursive: true);

  void legacy(String name, Map<String, Object> app) =>
      File('$home/bottles/$name/app.json').writeAsStringSync(jsonEncode(app));

  const steamApp = {
    'id': 'steam',
    'title': 'Steam',
    'exe': 'Program Files (x86)/Steam/steam.exe',
    'args': <String>[],
    'installedAt': '2026-11-03T19:30:01Z',
  };

  group('apps.json', () {
    test('a bottle from before lists its application', () {
      bottle('steam');
      legacy('steam', steamApp);
      final apps = bottleApps(home, 'steam');
      expect(apps.single.title, 'Steam');
      expect(apps.single.id, 'steam');
      expect(apps.single.key, 'program files (x86)/steam/steam.exe');
      expect(File('$home/bottles/steam/app.json').existsSync(), isTrue);
    });

    test('adding another keeps both, and app.json goes', () {
      final drive = bottle('steam');
      legacy('steam', steamApp);
      touch('$drive/Juego/j.exe');
      addApp(home, 'steam', 'Juego', 'Juego/j.exe');
      expect(bottleApps(home, 'steam').map((a) => a.title), ['Steam', 'Juego']);
      expect(File('$home/bottles/steam/app.json').existsSync(), isFalse);
      expect(File('$home/bottles/steam/apps.json').existsSync(), isTrue);
    });

    test('a broken one is an error with its path', () {
      bottle('a');
      File('$home/bottles/a/apps.json').writeAsStringSync('{roto');
      expect(() => bottleApps(home, 'a'), throwsA(contains('apps.json')));
      File('$home/bottles/a/apps.json').writeAsStringSync('{"apps": [{}]}');
      expect(() => bottleApps(home, 'a'), throwsA(contains('no es válido')));
    });
  });

  test('appKey', () {
    expect(appKey(r'C:\Program Files\X\A.EXE'), 'program files/x/a.exe');
    expect(appKey('Program Files/X/a.exe'), 'program files/x/a.exe');
    expect(appKey('/Users/q/Juegos/A.exe'), '/users/q/juegos/a.exe');
  });

  group('readLnk', () {
    Lnk? read(Uint8List bytes) {
      final file = File('$tmp/x.lnk')..writeAsBytesSync(bytes);
      return readLnk(file.path);
    }

    test('the shape of the real Steam.lnk', () {
      final link = read(
        lnk(
          r'C:\Program Files (x86)\Steam\steam.exe',
          workingDir: r'C:\Program Files (x86)\Steam',
          idList: true,
        ),
      )!;
      expect(link.target, r'C:\Program Files (x86)\Steam\steam.exe');
      expect(link.workingDir, r'C:\Program Files (x86)\Steam');
      expect(link.args, '');
    });

    test('arguments, in UTF-16 and in ANSI', () {
      expect(
        read(lnk(r'C:\a.exe', args: '-uno "dos tres"'))!.args,
        '-uno "dos tres"',
      );
      expect(
        read(lnk(r'C:\a.exe', args: '-uno', unicode: false))!.args,
        '-uno',
      );
    });

    test('anything else is null, not an error', () {
      final good = lnk(r'C:\a.exe', args: '-uno');
      expect(read(Uint8List(0)), isNull);
      expect(
        read(
          Uint8List.fromList(utf8.encode('no soy un acceso directo, y largo')),
        ),
        isNull,
      );
      expect(read(good.sublist(0, 40)), isNull);
      expect(read(good.sublist(0, good.length - 3)), isNull);
      expect(readLnk('$tmp/no-existe.lnk'), isNull);
    });
  });

  group('bottleApps', () {
    void shortcut(String path, String target, {String? args}) =>
        touch(path).writeAsBytesSync(lnk(target, args: args));

    test('three shortcuts to one exe are one application', () {
      final drive = bottle('b');
      touch('$drive/Prog/a.exe');
      const target = r'C:\Prog\a.exe';
      shortcut('$drive/users/Public/Desktop/A.lnk', target);
      shortcut(
        '$drive/users/q/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/A/A.lnk',
        target,
      );
      shortcut(
        '$drive/ProgramData/Microsoft/Windows/Start Menu/Programs/A.lnk',
        target,
      );
      final app = bottleApps(home, 'b').single;
      expect(app.title, 'A');
      expect(app.id, 'detected');
      expect(app.exe, 'Prog/a.exe');
    });

    test('one to a registered exe does not repeat it, and that one wins', () {
      final drive = bottle('b');
      touch('$drive/Prog/a.exe');
      addApp(home, 'b', 'Mi nombre', 'Prog/a.exe');
      shortcut('$drive/users/Public/Desktop/Otro nombre.lnk', r'C:\PROG\A.EXE');
      expect(bottleApps(home, 'b').single.title, 'Mi nombre');
    });

    test('registered first, then detected by title, with their arguments', () {
      final drive = bottle('b');
      for (final name in ['z', 'y', 'x']) {
        touch('$drive/Prog/$name.exe');
      }
      addApp(home, 'b', 'Zeta', 'Prog/z.exe');
      shortcut(
        '$drive/users/Public/Desktop/Beta.lnk',
        r'C:\Prog\y.exe',
        args: '-uno "dos tres"',
      );
      shortcut('$drive/users/Public/Desktop/alfa.lnk', r'C:\Prog\x.exe');
      final apps = bottleApps(home, 'b');
      expect(apps.map((a) => a.title), ['Zeta', 'alfa', 'Beta']);
      expect(apps.last.args, ['-uno', 'dos tres']);
    });

    test('what is not an application stays out', () {
      final drive = bottle('b');
      touch('$drive/Prog/unins000.exe');
      touch('$drive/Prog/Uninstall.exe');
      touch('$drive/Prog/manual.pdf');
      const desktop = 'users/Public/Desktop';
      shortcut('$drive/$desktop/Quitar.lnk', r'C:\Prog\unins000.exe');
      shortcut('$drive/$desktop/Quitar2.lnk', r'C:\Prog\Uninstall.exe');
      shortcut('$drive/$desktop/Manual.lnk', r'C:\Prog\manual.pdf');
      shortcut('$drive/$desktop/Ya no.lnk', r'C:\Prog\borrado.exe');
      shortcut('$drive/$desktop/Fuera.lnk', r'Z:\Users\q\a.exe');
      touch('$drive/$desktop/roto.lnk').writeAsStringSync('nada');
      touch('$drive/$desktop/notas.txt');
      expect(bottleApps(home, 'b'), isEmpty);
    });

    test('links are not followed, as in a real bottle', () {
      final drive = bottle('b');
      touch('$drive/Prog/a.exe');
      // users/<user>/Documents and such point to the Mac's own folders.
      final mac = Directory('$tmp/mac')..createSync();
      shortcut('${mac.path}/Trampa.lnk', r'C:\Prog\a.exe');
      Directory('$drive/users/q').createSync(recursive: true);
      Link('$drive/users/q/Desktop').createSync(mac.path);
      const programs = 'ProgramData/Microsoft/Windows/Start Menu/Programs';
      Directory('$drive/$programs').createSync(recursive: true);
      Link('$drive/$programs/enlace').createSync(mac.path);
      Link('$drive/users/otro').createSync(mac.path);
      expect(bottleApps(home, 'b'), isEmpty);
    });

    test('a bottle without a prefix has none', () {
      Directory('$home/bottles/rota').createSync();
      expect(bottleApps(home, 'rota'), isEmpty);
    });
  });

  group('steam games', () {
    String manifest(String id, String name, int flags) =>
        '"AppState"\n{\n\t"appid"\t\t"$id"\n\t"name"\t\t"$name"\n'
        '\t"StateFlags"\t\t"$flags"\n\t"LauncherPath"\t\t"C:\\\\x"\n}\n';

    String steam(String name) {
      final drive = bottle(name);
      touch('$drive/Program Files (x86)/Steam/steam.exe');
      return '$drive/Program Files (x86)/Steam/steamapps';
    }

    test('an installed game shows; the redistributables do not', () {
      final apps = steam('s');
      touch('$apps/appmanifest_1625450.acf')
          .writeAsStringSync(manifest('1625450', 'Muck', 4));
      touch('$apps/appmanifest_228980.acf').writeAsStringSync(
        manifest('228980', 'Steamworks Common Redistributables', 4),
      );
      touch('$apps/libraryfolders.vdf').writeAsStringSync('"appid" "1"');
      final game = bottleApps(home, 's').single;
      expect(game.key, 'steam:1625450');
      expect(game.title, 'Muck');
      expect(game.exe, 'Program Files (x86)/Steam/steam.exe');
      expect(game.args, ['-applaunch', '1625450']);
    });

    test('one half installed does not show', () {
      final apps = steam('s');
      touch('$apps/appmanifest_1.acf')
          .writeAsStringSync(manifest('1', 'A medias', 2));
      touch('$apps/appmanifest_2.acf')
          .writeAsStringSync(manifest('2', 'Actualizando', 6));
      touch('$apps/appmanifest_3.acf').writeAsStringSync('basura');
      expect(bottleApps(home, 's').single.title, 'Actualizando');
    });

    test('without Steam there are none', () {
      final drive = bottle('s');
      touch('$drive/Program Files (x86)/Steam/steamapps/appmanifest_1.acf')
          .writeAsStringSync(manifest('1', 'X', 4));
      expect(bottleApps(home, 's'), isEmpty);
    });
  });

  group('with a runtime', () {
    setUp(() async {
      final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
      await installRuntime(home, engine, hostlibs);
    });

    test('addApp admits several, and refuses the same exe', () async {
      await createBottle(home, 'b');
      final drive = '$home/bottles/b/prefix/drive_c';
      touch('$drive/P/a.exe');
      touch('$drive/P/b.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      addApp(home, 'b', 'B', 'P/b.exe');
      expect(bottleApps(home, 'b').map((a) => a.title), ['A', 'B']);
      expect(
        () => addApp(home, 'b', 'Otra', 'p/A.EXE'),
        throwsA(contains('ya tiene')),
      );
      expect(
        () => addApp(home, 'b', 'Nada', 'P/c.exe'),
        throwsA(contains('no existe')),
      );
    });

    test('openApp opens the one asked, and by default the first', () async {
      await createBottle(home, 'b');
      final drive = '$home/bottles/b/prefix/drive_c';
      touch('$drive/P/a.exe');
      touch('$drive/P/b.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      addApp(home, 'b', 'B', 'P/b.exe');

      final first = await openApp(home, 'b');
      await exitOf(first);
      expect(File(first).readAsStringSync(), contains(r'C:\P\a.exe'));

      final second = await openApp(home, 'b', key: 'p/b.exe');
      await exitOf(second);
      expect(File(second).readAsStringSync(), contains(r'C:\P\b.exe'));

      await expectLater(
        openApp(home, 'b', key: 'p/c.exe'),
        throwsA(contains('p/c.exe')),
      );
    });

    test('openApp on a Steam game passes through Steam', () async {
      await createBottle(home, 'b');
      final drive = '$home/bottles/b/prefix/drive_c';
      touch('$drive/Program Files (x86)/Steam/steam.exe');
      touch('$drive/Program Files (x86)/Steam/steamapps/appmanifest_9.acf')
          .writeAsStringSync('"appid" "9"\n"name" "Juego"\n"StateFlags" "4"');
      final log = await openApp(home, 'b', key: 'steam:9');
      await exitOf(log);
      final text = File(log).readAsStringSync();
      expect(text, contains(r'Steam\steam.exe'));
      expect(text, contains('-applaunch'));
      expect(text, contains('9'));
    });

    test('a bottle from before still opens the same, with no key', () async {
      await createBottle(home, 'steam');
      touch(
        '$home/bottles/steam/prefix/drive_c/Program Files (x86)/Steam/steam.exe',
      );
      legacy('steam', steamApp);
      final log = await openApp(home, 'steam');
      await exitOf(log);
      expect(File(log).readAsStringSync(), contains(r'Steam\steam.exe'));
    });

    group('gamepads', () {
      List<String> regLogs(String name) => [
        for (final log in bottleLogs(home, name))
          if (log.name.endsWith('-mandos.log')) log.path,
      ];

      test('a new bottle takes them straight from macOS', () async {
        await createBottle(home, 'b');
        final logs = regLogs('b');
        expect(logs, hasLength(2));
        final text = logs.map((log) => File(log).readAsStringSync()).join();
        expect(
          text,
          contains(r'HKLM\System\CurrentControlSet\Services\WineBus'),
        );
        expect(text, contains('Enable SDL'));
        expect(text, contains('DisableInput'));
        expect(bottleSettings(home, 'b').gamepads, 1);
      });

      test('a bottle from before gets it once, on its next launch', () async {
        await createBottle(home, 'b');
        File('$home/bottles/b/settings.json').deleteSync();
        for (final log in regLogs('b')) {
          File(log).deleteSync();
        }
        touch('$home/bottles/b/prefix/drive_c/P/a.exe');
        addApp(home, 'b', 'A', 'P/a.exe');

        await exitOf(await openApp(home, 'b'));
        expect(regLogs('b'), hasLength(2));
        await exitOf(await runInBottle(home, 'b', 'cmd', ['/c', 'exit']));
        await exitOf(await openApp(home, 'b'));
        expect(regLogs('b'), hasLength(2));
      });

      test('with SDL2 in the runtime, the bottle goes back to SDL', () async {
        await createBottle(home, 'b');
        expect(bottleSettings(home, 'b').gamepads, 1);
        final sdl = File(
          '$home/runtimes/current/engine/lib/wine/x86_64-unix/'
          'libSDL2-2.0.0.dylib',
        )..createSync(recursive: true);
        expect(hasSdl(home), isTrue);

        await exitOf(await runInBottle(home, 'b', 'cmd', ['/c', 'exit']));
        final reg = File('$home/bottles/b/prefix/reg.log')
            .readAsLinesSync()
            .where((l) => l.contains('WineBus'))
            .toList();
        expect(reg.skip(2), [
          allOf(contains('Enable SDL'), endsWith('/d 1 /f')),
          allOf(contains('DisableInput'), endsWith('/d 0 /f')),
        ]);
        expect(bottleSettings(home, 'b').gamepads, 2);

        // Once is enough; and without SDL it goes back to the raw way.
        await exitOf(await runInBottle(home, 'b', 'cmd', ['/c', 'exit']));
        expect(regLogs('b'), hasLength(4));
        sdl.deleteSync();
        await exitOf(await runInBottle(home, 'b', 'cmd', ['/c', 'exit']));
        expect(bottleSettings(home, 'b').gamepads, 1);
      });

      test('the bottle keeps it when other settings change', () async {
        await createBottle(home, 'b');
        setBackend(home, 'b', 'wine');
        await setSync(home, 'b', 'none');
        expect(bottleSettings(home, 'b').gamepads, 1);
      });
    });

    test('an empty bottle says what to do', () async {
      await createBottle(home, 'b');
      await expectLater(
        openApp(home, 'b'),
        throwsA(contains('no tiene una aplicación')),
      );
    });
  });

  group('hideApp', () {
    test('a detected one stays hidden, and adding it shows it again', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      touch('$drive/users/Public/Desktop/A.lnk')
          .writeAsBytesSync(lnk(r'C:\P\a.exe'));
      hideApp(home, 'b', 'p/a.exe');
      expect(bottleApps(home, 'b'), isEmpty);
      hideApp(home, 'b', 'p/a.exe');
      expect(
        jsonDecode(
          File('$home/bottles/b/apps.json').readAsStringSync(),
        )['hidden'],
        ['p/a.exe'],
      );
      addApp(home, 'b', 'A', 'P/a.exe');
      expect(bottleApps(home, 'b').single.id, 'custom');
    });

    test('a registered one does not come back through its shortcut', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      touch('$drive/users/Public/Desktop/A.lnk')
          .writeAsBytesSync(lnk(r'C:\P\a.exe'));
      addApp(home, 'b', 'A', 'P/a.exe');
      hideApp(home, 'b', 'p/a.exe');
      expect(bottleApps(home, 'b'), isEmpty);
    });

    test('a Steam game too', () {
      final drive = bottle('b');
      touch('$drive/Program Files (x86)/Steam/steam.exe');
      touch('$drive/Program Files (x86)/Steam/steamapps/appmanifest_9.acf')
          .writeAsStringSync('"appid" "9"\n"name" "J"\n"StateFlags" "4"');
      expect(bottleApps(home, 'b').single.key, 'steam:9');
      hideApp(home, 'b', 'steam:9');
      expect(bottleApps(home, 'b'), isEmpty);
    });
  });

  group('setInLibrary', () {
    test('every app is in the library until it is taken out', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      expect(bottleApps(home, 'b').single.inLibrary, isTrue);

      setInLibrary(home, 'b', 'p/a.exe', false);
      expect(bottleApps(home, 'b').single.inLibrary, isFalse);
      expect(
        jsonDecode(
          File('$home/bottles/b/apps.json').readAsStringSync(),
        )['offLibrary'],
        ['p/a.exe'],
      );

      setInLibrary(home, 'b', 'p/a.exe', true);
      expect(bottleApps(home, 'b').single.inLibrary, isTrue);
      expect(
        jsonDecode(
          File('$home/bottles/b/apps.json').readAsStringSync(),
        )['offLibrary'],
        isEmpty,
      );
    });

    test('a detected one can be taken out too', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      touch('$drive/users/Public/Desktop/A.lnk')
          .writeAsBytesSync(lnk(r'C:\P\a.exe'));
      setInLibrary(home, 'b', 'p/a.exe', false);
      expect(bottleApps(home, 'b').single.inLibrary, isFalse);
    });

    test('a bottle from before apps.json reads as all in', () {
      bottle('steam');
      legacy('steam', steamApp);
      expect(bottleApps(home, 'steam').single.inLibrary, isTrue);

      setInLibrary(home, 'steam', 'program files (x86)/steam/steam.exe', false);
      expect(bottleApps(home, 'steam').single.inLibrary, isFalse);
      expect(File('$home/bottles/steam/app.json').existsSync(), isFalse);
    });

    test('an app the bottle does not have is an error', () {
      bottle('b');
      expect(
        () => setInLibrary(home, 'b', 'p/nada.exe', false),
        throwsA(contains('no tiene la aplicación')),
      );
    });

    test('hideApp takes the app out of the off list', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      setInLibrary(home, 'b', 'p/a.exe', false);
      hideApp(home, 'b', 'p/a.exe');
      expect(
        jsonDecode(
          File('$home/bottles/b/apps.json').readAsStringSync(),
        )['offLibrary'],
        isEmpty,
      );
    });
  });

  group('setAppHud', () {
    test('an app has no HUD until it is turned on', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      expect(bottleApps(home, 'b').single.hud, isFalse);
    });

    test('on and off are kept in the bottle settings', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      addApp(home, 'b', 'A', 'P/a.exe');
      setAppHud(home, 'b', 'p/a.exe', true);
      expect(bottleApps(home, 'b').single.hud, isTrue);
      expect(
        jsonDecode(
          File('$home/bottles/b/settings.json').readAsStringSync(),
        )['programs'],
        {
          'a.exe': {'hud': true},
        },
      );

      setAppHud(home, 'b', 'p/a.exe', false);
      expect(bottleApps(home, 'b').single.hud, isFalse);
    });

    test('a detected app keeps it too', () {
      final drive = bottle('b');
      touch('$drive/P/a.exe');
      touch('$drive/users/Public/Desktop/A.lnk')
          .writeAsBytesSync(lnk(r'C:\P\a.exe'));
      setAppHud(home, 'b', 'p/a.exe', true);
      expect(bottleApps(home, 'b').single.hud, isTrue);
    });

    test('an app the bottle does not have is an error', () {
      bottle('b');
      expect(
        () => setAppHud(home, 'b', 'p/nada.exe', true),
        throwsA(contains('no tiene la aplicación')),
      );
    });

    group('a launch', () {
      setUp(() async {
        final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
        await installRuntime(home, engine, hostlibs);
      });

      test('gets the HUD its program has, and not once it is off', () async {
        await createBottle(home, 'b');
        touch('$home/bottles/b/prefix/drive_c/P/a.exe');
        addApp(home, 'b', 'A', 'P/a.exe');
        final env = File('$home/bottles/b/prefix/last-env');

        setAppHud(home, 'b', 'p/a.exe', true);
        await exitOf(await openApp(home, 'b'));
        expect(env.readAsStringSync(), contains('MTL_HUD_ENABLED=1'));

        setAppHud(home, 'b', 'p/a.exe', false);
        await exitOf(await openApp(home, 'b'));
        expect(env.readAsStringSync(), isNot(contains('MTL_HUD_ENABLED')));
      });
    });
  });

  group('renameBottle', () {
    setUp(() async {
      final (engine, hostlibs) = await fakeRuntime(tmp, 'engine');
      await installRuntime(home, engine, hostlibs);
      await createBottle(home, 'b');
    });

    test('moves the folder, and a z: link stays a link', () async {
      final dosdevices = '$home/bottles/b/prefix/dosdevices';
      Directory(dosdevices).createSync();
      Link('$dosdevices/z:').createSync('/');
      await renameBottle(home, 'b', 'c');
      expect(Directory('$home/bottles/b').existsSync(), isFalse);
      expect(File('$home/bottles/c/prefix/system.reg').existsSync(), isTrue);
      final z = '$home/bottles/c/prefix/dosdevices/z:';
      expect(
        FileSystemEntity.typeSync(z, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(Link(z).targetSync(), '/');
    });

    test(
      'refuses a name that exists, an invalid one or a missing bottle',
      () async {
        await createBottle(home, 'c');
        await expectLater(
          renameBottle(home, 'b', 'c'),
          throwsA(contains('ya existe la botella c')),
        );
        await expectLater(
          renameBottle(home, 'b', 'a b'),
          throwsA(isA<FormatException>()),
        );
        await expectLater(
          renameBottle(home, 'nada', 'x'),
          throwsA(contains('no existe la botella nada')),
        );
        expect(Directory('$home/bottles/b').existsSync(), isTrue);
      },
    );

    test('refuses an open bottle, and leaves it where it is', () async {
      final hang = File('$home/bottles/b/prefix/hang')..writeAsStringSync('');
      await expectLater(
        renameBottle(home, 'b', 'c'),
        throwsA(contains('está abierta')),
      );
      hang.deleteSync();
      expect(Directory('$home/bottles/b').existsSync(), isTrue);
    });
  });

  group('appIcon', () {
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];
    final dib = [40, 0, 0, 0, 32, 0, 0, 0, 64, 0, 0, 0, 9, 9];

    InstalledApp app(String drive, List<int> bytes) {
      touch('$drive/P/a.exe').writeAsBytesSync(bytes);
      addApp(home, 'b', 'A', 'P/a.exe');
      return bottleApps(home, 'b').single;
    }

    test('takes the largest icon, whether PNG or DIB', () {
      final drive = bottle('b');
      final path = appIcon(
        home,
        app(drive, pe([(32, dib), (256, png), (48, dib)])),
      )!;
      final ico = File(path).readAsBytesSync();
      expect(path, endsWith('.ico'));
      expect(ico.sublist(0, 6), [0, 0, 1, 0, 1, 0]);
      expect(ico[6], 0, reason: '0 means 256 in an .ico');
      expect(ico.sublist(22), png);
      final head = ByteData.sublistView(ico);
      expect(head.getUint32(14, Endian.little), png.length);
      expect(head.getUint32(18, Endian.little), 22);
    });

    test('a DIB alone also comes out', () {
      final drive = bottle('b');
      final ico = File(appIcon(home, app(drive, pe([(32, dib)])))!)
          .readAsBytesSync();
      expect(ico[6], 32);
      expect(ico.sublist(22), dib);
    });

    test('no .rsrc, not a PE, or missing: null, not an error', () {
      final drive = bottle('b');
      expect(
        appIcon(
          home,
          app(
            drive,
            Uint8List(200)
              ..[0] = 0x4D
              ..[1] = 0x5A,
          ),
        ),
        isNull,
      );
      touch('$drive/P/n.exe').writeAsStringSync('no soy un exe');
      addApp(home, 'b', 'N', 'P/n.exe');
      expect(appIcon(home, bottleApps(home, 'b').last), isNull);
      File('$drive/P/n.exe').deleteSync();
      expect(
        appIcon(home, (
          bottle: 'b',
          key: 'p/n.exe',
          id: 'custom',
          title: 'N',
          exe: 'P/n.exe',
          args: const <String>[],
          inLibrary: true,
        )),
        isNull,
      );
    });

    test('a truncated one is null too', () {
      final drive = bottle('b');
      final whole = pe([(256, png)]);
      expect(
        appIcon(home, app(drive, whole.sublist(0, whole.length - 8))),
        isNull,
      );
    });

    test('the second time it uses the cache, until the exe changes', () {
      final drive = bottle('b');
      final item = app(drive, pe([(32, dib)]));
      final exe = File('$drive/P/a.exe')..setLastModifiedSync(DateTime(2020));
      final path = appIcon(home, item)!;
      File(path).writeAsStringSync('marca');
      expect(appIcon(home, item), path);
      expect(File(path).readAsStringSync(), 'marca');

      exe.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
      appIcon(home, item);
      expect(File(path).readAsStringSync(), isNot('marca'));
    });

    test('an exe without an icon is remembered', () {
      final drive = bottle('b');
      final item = app(drive, Uint8List(10));
      File('$drive/P/a.exe').setLastModifiedSync(DateTime(2020));
      expect(appIcon(home, item), isNull);
      expect(
        Directory('$home/bottles/b/icons').listSync().single.statSync().size,
        0,
      );
      expect(appIcon(home, item), isNull);
    });

    test('a Steam game uses what Steam keeps', () {
      final drive = bottle('b');
      final cache = '$drive/Program Files (x86)/Steam/appcache/librarycache/9';
      const game = (
        bottle: 'b',
        key: 'steam:9',
        id: 'steam-game',
        title: 'J',
        exe: 'x',
        args: <String>[],
        inLibrary: true,
      );
      expect(appIcon(home, game), isNull);
      touch('$cache/header.jpg');
      expect(appIcon(home, game), isNull);
      touch('$cache/logo.png');
      expect(appIcon(home, game), endsWith('logo.png'));
      final hash = 'a123e3d10527fbdf3fea7ea235e11b41da3754dc.jpg';
      touch('$cache/$hash');
      expect(appIcon(home, game), endsWith(hash));
    });
  });

  group('x86Slice', () {
    Uint8List fat(List<(int, List<int>)> parts, {bool wide = false}) {
      final entry = wide ? 32 : 20;
      final head = 8 + entry * parts.length;
      final out = BytesBuilder();
      final header = ByteData(head)
        ..setUint32(0, wide ? 0xcafebabf : 0xcafebabe)
        ..setUint32(4, parts.length);
      var offset = head;
      for (final (i, (cpu, data)) in parts.indexed) {
        final at = 8 + entry * i;
        header.setUint32(at, cpu);
        if (wide) {
          header
            ..setUint64(at + 8, offset)
            ..setUint64(at + 16, data.length);
        } else {
          header
            ..setUint32(at + 8, offset)
            ..setUint32(at + 12, data.length);
        }
        offset += data.length;
      }
      out.add(header.buffer.asUint8List());
      for (final (_, data) in parts) {
        out.add(data);
      }
      return out.toBytes();
    }

    const x86 = 0x01000007, arm = 0x0100000c;

    test('takes the x86_64 part of a universal binary', () {
      expect(
        x86Slice(
          fat([
            (arm, [1, 1]),
            (x86, [2, 3, 4]),
          ]),
        ),
        [2, 3, 4],
      );
      expect(
        x86Slice(
          fat([
            (x86, [5]),
          ], wide: true),
        ),
        [5],
      );
    });

    test('a thin one is itself if x86_64', () {
      final thin = Uint8List(16);
      ByteData.sublistView(thin)
        ..setUint32(0, 0xfeedfacf, Endian.little)
        ..setUint32(4, x86, Endian.little);
      expect(x86Slice(thin), thin);
      ByteData.sublistView(thin).setUint32(4, arm, Endian.little);
      expect(x86Slice(thin), isNull);
    });

    test('anything else is null', () {
      expect(
        x86Slice(
          fat([
            (arm, [1]),
          ]),
        ),
        isNull,
      );
      expect(x86Slice(Uint8List(4)), isNull);
      final cut = fat([
        (x86, [1, 2, 3]),
      ]);
      expect(x86Slice(cut.sublist(0, cut.length - 1)), isNull);
    });
  });

  test('parseOpen takes an optional key', () {
    expect(parseOpen(['steam'])?.key, isNull);
    expect(parseOpen(['steam', 'steam:9'])?.key, 'steam:9');
    expect(parseOpen(['--hud', 'steam', 'x'])?.hud, isTrue);
    expect(parseOpen(['a', 'b', 'c']), isNull);
    expect(parseOpen([]), isNull);
  });
}
