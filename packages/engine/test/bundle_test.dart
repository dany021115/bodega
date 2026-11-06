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
    expect(
      File('$dir/backends/dxvk/wine/x64/d3d11.dll').existsSync(),
      isTrue,
    );
    expect(FileSystemEntity.isLinkSync('$dir/backends/dxvk'), isFalse);
  });

  test(
    'a Linux bundle is linked into the home',
    () {
      hostPlatform = LinuxPlatform(bundle: bundle);
      final dir = bodegaHome(env);

      expect(
        File('$dir/runtimes/wine-x/engine/bin/wine').existsSync(),
        isTrue,
      );
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
