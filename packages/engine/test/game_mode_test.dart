import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String engine;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bodega-gamemode');
    engine = '${tmp.path}/engine';
    for (final file in [
      'bin/wine',
      'bin/wineserver',
      'lib/wine/x86_64-unix/wine',
      'lib/wine/x86_64-unix/ntdll.so',
      'lib/wine/x86_64-windows/ntdll.dll',
      'lib/wine/i386-windows/kernel32.dll',
      'share/wine/wine.inf',
    ]) {
      File('$engine/$file')
        ..createSync(recursive: true)
        ..writeAsStringSync(file);
    }
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String read(String path) => File('$engine/$path').readAsStringSync();

  test('the unix folder becomes wine.app, and every old path still reads', () {
    expect(bundleWineForGameMode(engine), isTrue);
    final wine = '$engine/lib/wine';
    // The real folder lives in the bundle, which macOS reads the category of.
    expect(FileSystemEntity.isLinkSync('$wine/x86_64-unix'), isTrue);
    expect(
      FileSystemEntity.typeSync(
        '$wine/wine.app/Contents/MacOS',
        followLinks: false,
      ),
      FileSystemEntityType.directory,
    );
    expect(
      read('lib/wine/wine.app/Contents/MacOS/wine'),
      'lib/wine/x86_64-unix/wine',
    );
    // Bodega's and bin/wine's paths, through the link.
    expect(
      read('lib/wine/x86_64-unix/ntdll.so'),
      'lib/wine/x86_64-unix/ntdll.so',
    );
    // Wine's own, once its dll folder is MacOS.
    const macos = 'lib/wine/wine.app/Contents/MacOS';
    expect(
      read('$macos/x86_64-unix/ntdll.so'),
      'lib/wine/x86_64-unix/ntdll.so',
    );
    expect(
      read('$macos/x86_64-windows/ntdll.dll'),
      'lib/wine/x86_64-windows/ntdll.dll',
    );
    expect(
      read('$macos/i386-windows/kernel32.dll'),
      'lib/wine/i386-windows/kernel32.dll',
    );
    expect(read('$macos/../../bin/wineserver'), 'bin/wineserver');
    expect(read('$macos/../../share/wine/wine.inf'), 'share/wine/wine.inf');
    final plist = read('lib/wine/wine.app/Contents/Info.plist');
    expect(plist, winePlist);
    for (final key in [
      '<key>LSApplicationCategoryType</key><string>public.app-category.games</string>',
      '<key>LSSupportsGameMode</key><true/>',
      '<key>CFBundleExecutable</key><string>wine</string>',
    ]) {
      expect(plist, contains(key));
    }
  });

  test('a second run changes nothing, and puts back a missing piece', () {
    bundleWineForGameMode(engine);
    File('$engine/lib/wine/wine.app/Contents/Info.plist').deleteSync();
    Link('$engine/lib/wine/wine.app/bin').deleteSync();
    expect(bundleWineForGameMode(engine), isTrue);
    expect(read('lib/wine/wine.app/Contents/Info.plist'), winePlist);
    expect(read('lib/wine/wine.app/Contents/MacOS/../../bin/wine'), 'bin/wine');
  });

  test('a move cut short before its link gets the link', () {
    Directory('$engine/lib/wine/wine.app/Contents').createSync(recursive: true);
    Directory('$engine/lib/wine/x86_64-unix')
        .renameSync('$engine/lib/wine/wine.app/Contents/MacOS');
    expect(bundleWineForGameMode(engine), isTrue);
    expect(read('lib/wine/x86_64-unix/wine'), 'lib/wine/x86_64-unix/wine');
  });

  test('a tree with no unix folder, such as a backend, is left alone', () {
    Directory('$engine/lib/wine/x86_64-unix').deleteSync(recursive: true);
    expect(bundleWineForGameMode(engine), isFalse);
    expect(Directory('$engine/lib/wine/wine.app').existsSync(), isFalse);
  });
}
