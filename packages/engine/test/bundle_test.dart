import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void _write(String path, String text) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(text);
}

List<String> _names(String dir) =>
    Directory(dir).listSync().map((entity) => entity.path).toList()..sort();

void main() {
  late String tmp, bundle, home;
  late Map<String, String> env;

  setUp(() {
    tmp = Directory.systemTemp
        .createTempSync('bodega-bundle')
        .resolveSymbolicLinksSync();
    bundle = '$tmp/bundle';
    home = '$tmp/home';
    env = {'BODEGA_HOME': home, 'HOME': tmp};
    _write('$bundle/runtime/wine-x/engine/bin/wine', 'wine');
    _write('$bundle/backends/dxvk/wine/x64/d3d11.dll', 'dll');
  });

  tearDown(() {
    hostPlatform = HostPlatform.detect();
    Directory(tmp).deleteSync(recursive: true);
  });

  test('a Mac bundle is copied into the home, not linked', () {
    hostPlatform = MacPlatform(bundle: bundle);
    final dir = bodegaHome(env);

    expect(File('$dir/runtimes/wine-x/engine/bin/wine').existsSync(), isTrue);
    expect(FileSystemEntity.isLinkSync('$dir/runtimes/wine-x'), isFalse);
    expect(
      Directory('$dir/runtimes/current').resolveSymbolicLinksSync(),
      Directory('$dir/runtimes/wine-x').resolveSymbolicLinksSync(),
    );
    expect(File('$dir/backends/dxvk/wine/x64/d3d11.dll').existsSync(), isTrue);
    expect(FileSystemEntity.isLinkSync('$dir/backends/dxvk'), isFalse);
  });

  test(
    'a Linux bundle is linked into the home',
    () {
      hostPlatform = LinuxPlatform(bundle: bundle);
      final dir = bodegaHome(env);

      expect(File('$dir/runtimes/wine-x/engine/bin/wine').existsSync(), isTrue);
      expect(FileSystemEntity.isLinkSync('$dir/runtimes/wine-x'), isTrue);
      expect(
        File('$dir/backends/dxvk/wine/x64/d3d11.dll').existsSync(),
        isTrue,
      );
    },
    skip: Platform.environment.containsKey('APPIMAGE')
        ? 'APPIMAGE is set, so the bundle is copied'
        : false,
  );

  test('a missing bundle leaves runtimes empty and does not throw', () {
    hostPlatform = MacPlatform(bundle: '$tmp/nope');
    final dir = bodegaHome(env);

    expect(_names('$dir/runtimes'), isEmpty);
  });

  test('an update keeps the bottles, D3DMetal and the runtime in use (A5)', () {
    hostPlatform = MacPlatform(bundle: bundle);
    final dir = bodegaHome(env);
    _write('$dir/bottles/juegos/settings.json', '{"backend": "d3dmetal"}');
    _write('$dir/bottles/juegos/prefix/drive_c/Juego/partida.sav', 'nivel 9');
    _write('$dir/backends/d3dmetal/external/libd3dshared.dylib', 'mio');
    final before = {
      for (final file in Directory(dir).listSync(recursive: true))
        if (file is File) file.path: file.readAsStringSync(),
    };

    // The next version brings another Wine, a newer dxvk and dxmt.
    final next = '$tmp/next';
    _write('$next/runtime/wine-y/engine/bin/wine', 'wine nuevo');
    _write('$next/backends/dxvk/wine/x64/d3d11.dll', 'dll nueva');
    _write('$next/backends/dxmt/wine/x64/d3d11.dll', 'dxmt');
    hostPlatform = MacPlatform(bundle: next);
    bodegaHome(env);

    for (final MapEntry(:key, :value) in before.entries) {
      expect(File(key).readAsStringSync(), value, reason: key);
    }
    expect(
      Directory('$dir/runtimes/current').resolveSymbolicLinksSync(),
      Directory('$dir/runtimes/wine-x').resolveSymbolicLinksSync(),
    );
    expect(File('$dir/runtimes/wine-y/engine/bin/wine').existsSync(), isTrue);
    expect(File('$dir/backends/dxmt/wine/x64/d3d11.dll').existsSync(), isTrue);
  });

  test("the bundle's SDL2 goes into the runtime in use when it differs", () {
    const sdl = 'engine/lib/wine/x86_64-unix/libSDL2-2.0.0.dylib';
    _write('$bundle/runtime/wine-x/$sdl', 'sdl 2.30.12');
    hostPlatform = MacPlatform(bundle: bundle);
    final dir = bodegaHome(env);
    final installed = File('$dir/runtimes/current/$sdl');
    expect(installed.readAsStringSync(), 'sdl 2.30.12');

    // A runtime from a tarball has none, an older one another version.
    installed.deleteSync();
    bodegaHome(env);
    expect(installed.readAsStringSync(), 'sdl 2.30.12');
    installed.writeAsStringSync('sdl 2.32.10');
    bodegaHome(env);
    expect(installed.readAsStringSync(), 'sdl 2.30.12');

    final before = installed.lastModifiedSync();
    bodegaHome(env);
    expect(installed.lastModifiedSync(), before);
  });

  test('sha256Of', () async {
    _write('$tmp/abc', 'abc');
    expect(
      await sha256Of('$tmp/abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('a second bodegaHome changes nothing', () {
    hostPlatform = MacPlatform(bundle: bundle);
    final first = bodegaHome(env);
    final runtimes = _names('$first/runtimes');
    final backends = _names('$first/backends');

    final second = bodegaHome(env);

    expect(second, first);
    expect(_names('$second/runtimes'), runtimes);
    expect(_names('$second/backends'), backends);
    expect(
      File('$second/runtimes/wine-x/engine/bin/wine').existsSync(),
      isTrue,
    );
  });
}
