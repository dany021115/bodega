import 'dart:convert';
import 'dart:io';

import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';

/// A Mac that can run Mach9 ([mach9Block] null), whose only applications
/// folder is [applications] (none by default, so a real Mach9.app on the
/// machine stays out), without `xattr`, and with `sha256sum` where
/// `/usr/bin/shasum` is missing, so these tests also run on Linux.
class Mach9Mac extends engine.MacPlatform {
  const Mach9Mac({this.applications});

  final String? applications;

  @override
  engine.RuntimeBlock? get mach9Block => null;

  // The repository reads a bottle inside `Isolate.run`, where the real host's
  // platform holds: on Linux CI that host admits only `none`, so a bottle
  // made here must not ask for msync (MA11).
  @override
  String get defaultSync => 'none';

  // Not this machine's display: a launch's retina step stays the same (PE3).
  @override
  bool mainDisplayHiDpi() => false;

  // ditto is the Mac's; cp -a keeps links as links on Linux CI too (PE12).
  @override
  Future<void> copyTree(String from, String to) async {
    final result = await Process.run('cp', ['-a', from, to]);
    if (result.exitCode != 0) {
      throw engine.ProcessFailed('cp -a', result.exitCode, '${result.stderr}');
    }
  }

  @override
  List<String> get applicationDirs => [?applications];

  @override
  Future<void> afterExtract(String dir) async {}

  @override
  (String, List<String>) get sha256Tool => File('/usr/bin/shasum').existsSync()
      ? super.sha256Tool
      : ('sha256sum', const []);
}

/// The engine tests' fake Wine: wineboot makes a prefix that counts as
/// ready, `reg` and `winecfg` log their arguments, and `msiexec` sources the
/// MSI it is given, as a shell script.
const _fakeWine = r'''#!/bin/sh
case $1 in
--version) echo wine-11.21 ;;
wineboot)
  d=$WINEPREFIX/drive_c/windows/syswow64
  mkdir -p "$d" && touch "$d/kernel32.dll" "$WINEPREFIX/system.reg" ;;
reg) echo "$@" >>"$WINEPREFIX/reg.log" ;;
winecfg) echo "$@" >>"$WINEPREFIX/winecfg.log" ;;
msiexec) echo "$@" >"$WINEPREFIX/msi-args"; . "$3" ;;
*) exit 7 ;;
esac
''';

const _fakeWineserver = '#!/bin/sh\nexit 0\n';

/// A Mach9 runtime 0.4.0 under `runtimes/mach9`, with every
/// graphics module (MG2), the fake Wine and a fake Mono MSI that makes Mono's
/// folder. Returns its folder.
String fakeMach9Runtime(String home) {
  const version = '0.4.0';
  final dir = '$home/runtimes/mach9-$version';
  for (final sub in [
    'dxgi/wined3d',
    'dxgi/dxmt',
    'd3d9/wined3d',
    'd3d9/mtld3d',
  ]) {
    Directory('$dir/engine/lib/wine/$sub').createSync(recursive: true);
  }
  final wine = File('$dir/engine/bin/wine')
    ..createSync(recursive: true)
    ..writeAsStringSync(_fakeWine);
  final server = File('$dir/engine/bin/wineserver')
    ..writeAsStringSync(_fakeWineserver);
  Process.runSync('/bin/chmod', ['+x', wine.path, server.path]);
  File('$dir/wine-mono-11.3.0-x86.msi').writeAsStringSync(
    r'mkdir -p "$WINEPREFIX/drive_c/windows/mono/mono-2.0"'
    '\n',
  );
  File('$dir/runtime.json').writeAsStringSync(
    jsonEncode({
      'kind': 'mach9',
      'version': version,
      'source': 'app',
      'checked': true,
    }),
  );
  Link('$home/runtimes/mach9').createSync('mach9-$version');
  return dir;
}

/// A bottle whose prefix counts as ready; Mach9 when [mach9] (by its
/// settings), Rosetta otherwise.
String readyBottle(String home, String name, {bool mach9 = false}) {
  final dir = '$home/bottles/$name';
  File('$dir/prefix/drive_c/windows/syswow64/kernel32.dll')
      .createSync(recursive: true);
  File('$dir/prefix/system.reg').createSync();
  Directory('$dir/logs').createSync();
  File('$dir/settings.json')
      .writeAsStringSync(jsonEncode({if (mach9) 'runtime': 'mach9'}));
  return dir;
}

/// Runs each test of this `main` as [host], then puts the detected one back.
void useHost(engine.HostPlatform Function() host) {
  final saved = engine.hostPlatform;
  setUp(() => engine.hostPlatform = host());
  tearDown(() => engine.hostPlatform = saved);
}
