import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'runtimes_test.dart' show fakeMach9Runtime, mach9Bottle;

/// The golden strings of design §4.2 and `graphics.md` MG4–MG9.
void main() {
  useMac();
  late String tmp, home;
  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega')
        .resolveSymbolicLinksSync();
    home = bodegaHome({'BODEGA_HOME': '$tmp/home'});
    fakeMach9Runtime(home);
  });
  tearDown(() => Directory(tmp).deleteSync(recursive: true));

  const menu = 'dll_overrides=winemenubuilder.exe=';

  group('MG5 design §4.2', () {
    test('bottle wine', () {
      mach9Bottle(home, 'b', '{"backend": "wine"}');
      expect(
        compatdbRules(home, 'b', 'game.exe'),
        'exe=*;dxgi=wined3d;d3d9=wined3d;$menu',
      );
    });

    test(
      'bottle auto, exception iw5mp.exe=wine, plutonium.exe with the HUD',
      () {
        mach9Bottle(
          home,
          'b',
          '{"programs": {"iw5mp.exe": {"backend": "wine"}}}',
        );
        expect(
          compatdbRules(home, 'b', 'plutonium.exe', hud: true),
          'exe=*;metal_hud=true;$menu\n'
          'exe=iw5mp.exe;dxgi=wined3d;d3d9=wined3d',
        );
      },
    );

    test('same bottle: run --backend mtld3d iw5mp.exe', () {
      mach9Bottle(
        home,
        'b',
        '{"programs": {"iw5mp.exe": {"backend": "wine"}}}',
      );
      expect(
        compatdbRules(home, 'b', 'iw5mp.exe', backend: 'mtld3d'),
        'exe=*;d3d9=mtld3d;$menu\n'
        'exe=iw5mp.exe;d3d9=mtld3d',
      );
    });

    test('the launched program keeps its own exception', () {
      mach9Bottle(
        home,
        'b',
        '{"programs": {"iw5mp.exe": {"backend": "wine"}}}',
      );
      expect(
        compatdbRules(home, 'b', r'C:\Games\IW5MP.EXE'),
        'exe=*;dxgi=wined3d;d3d9=wined3d;$menu\n'
        'exe=iw5mp.exe;dxgi=wined3d;d3d9=wined3d',
      );
    });

    test('--backend auto on any bottle', () {
      mach9Bottle(
        home,
        'b',
        '{"backend": "dxmt", "programs": {"a.exe": {"backend": "wine"}}}',
      );
      expect(compatdbRules(home, 'b', 'a.exe', backend: 'auto'), 'exe=*;$menu');
      expect(
        compatdbRules(home, 'b', 'other.exe', backend: 'auto'),
        'exe=*;$menu',
      );
    });

    test('a bodega bottle has none', () {
      Directory('$home/bottles/x86').createSync(recursive: true);
      expect(compatdbRules(home, 'x86', 'game.exe'), isNull);
    });
  });

  group('MG5 combinations', () {
    const settings =
        '{"backend": "dxmt", "programs": {'
        '"b.exe": {"backend": "mtld3d"}, '
        '"a.exe": {"backend": "wine", "hud": true}, '
        '"c.exe": {"hud": true}, '
        '"d.exe": {"env": {"X": "1"}}}}';

    test('the bottle choice, other programs sorted, HUD lines kept', () {
      mach9Bottle(home, 'b', settings);
      expect(
        compatdbRules(home, 'b', 'game.exe'),
        'exe=*;dxgi=dxmt;$menu\n'
        'exe=a.exe;dxgi=wined3d;d3d9=wined3d;metal_hud=true\n'
        'exe=b.exe;d3d9=mtld3d\n'
        'exe=c.exe;metal_hud=true',
      );
    });

    test("a program's saved HUD goes on exe=*", () {
      mach9Bottle(home, 'b', settings);
      expect(
        compatdbRules(home, 'b', 'c.exe'),
        'exe=*;dxgi=dxmt;metal_hud=true;$menu\n'
        'exe=a.exe;dxgi=wined3d;d3d9=wined3d;metal_hud=true\n'
        'exe=b.exe;d3d9=mtld3d',
      );
    });

    test('an option drops the other exceptions, not their HUD', () {
      mach9Bottle(home, 'b', settings);
      expect(
        compatdbRules(home, 'b', 'b.exe', backend: 'dxmt'),
        'exe=*;dxgi=dxmt;$menu\n'
        'exe=b.exe;dxgi=dxmt\n'
        'exe=a.exe;metal_hud=true\n'
        'exe=c.exe;metal_hud=true',
      );
    });

    test('an option of auto gives no program line', () {
      mach9Bottle(home, 'b', settings);
      expect(
        compatdbRules(home, 'b', 'b.exe', backend: 'auto', hud: true),
        'exe=*;metal_hud=true;$menu\n'
        'exe=a.exe;metal_hud=true\n'
        'exe=c.exe;metal_hud=true',
      );
    });
  });

  group('MG4 the writer', () {
    test('escapes %, ; and control bytes in exe keys', () {
      mach9Bottle(home, 'b');
      setBackend(home, 'b', 'wine', exe: 'a;b%c.exe');
      setBackend(home, 'b', 'mtld3d', exe: 'tab\there.exe');
      final rules = compatdbRules(home, 'b', 'a;b%c.exe')!;
      expect(rules.split('\n'), [
        'exe=*;dxgi=wined3d;d3d9=wined3d;$menu',
        'exe=a%3Bb%25c.exe;dxgi=wined3d;d3d9=wined3d',
        'exe=tab%09here.exe;d3d9=mtld3d',
      ]);
      expect(rules, isNot(endsWith('\n')));
    });
  });

  group('MG9 the user rules', () {
    test('a bottle variable is appended after a newline', () {
      mach9Bottle(
        home,
        'b',
        '{"env": {"WINE_COMPATDB": "exe=a.exe;d3d9=wined3d"}}',
      );
      expect(
        compatdbRules(home, 'b', 'game.exe'),
        'exe=*;$menu\nexe=a.exe;d3d9=wined3d',
      );
    });

    test("the program's variable beats the bottle's", () {
      mach9Bottle(
        home,
        'b',
        '{"env": {"WINE_COMPATDB": "exe=a.exe;d3d9=wined3d"}, '
            '"programs": {"g.exe": {"env": {"WINE_COMPATDB": "exe=g.exe;metal_hud=true"}}}}',
      );
      expect(
        compatdbRules(home, 'b', 'g.exe'),
        'exe=*;$menu\nexe=g.exe;metal_hud=true',
      );
    });
  });

  group('MG3 choices in rules', () {
    test('a Rosetta name is not for Mach9', () {
      mach9Bottle(home, 'b');
      for (final name in ['dxvk', 'dxvk9', 'd3dmetal']) {
        expect(
          () => compatdbRules(home, 'b', 'g.exe', backend: name),
          throwsA(
            isA<BackendNotForRuntime>()
                .having((f) => f.backend, 'backend', name)
                .having((f) => f.runtime, 'runtime', RuntimeKind.mach9),
          ),
          reason: name,
        );
      }
    });

    test('a name the runtime lacks is not installed', () {
      Link('$home/runtimes/mach9').deleteSync();
      fakeMach9Runtime(home, version: '0.5.0', skip: ['d3d9/mtld3d']);
      mach9Bottle(home, 'b');
      expect(
        () => compatdbRules(home, 'b', 'g.exe', backend: 'mtld3d'),
        throwsA(isA<BackendNotInstalled>()),
      );
    });
  });
}
