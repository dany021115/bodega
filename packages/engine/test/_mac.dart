import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// The Mac without `xattr` and, where `/usr/bin/shasum` is missing, with
/// `sha256sum`, so that the Mac tests also run on Linux. Mach9 is available
/// unless [mach9Block] says otherwise; [team] is what every signature names
/// (null: none passes); [applications] is the one applications folder.
class TestMac extends MacPlatform {
  const TestMac({
    this.mach9Block,
    this.team = 'WLKUUJD25W',
    this.applications,
    this.hiDpi = false,
  });

  @override
  final RuntimeBlock? mach9Block;

  final String? team;
  final String? applications;

  /// What [mainDisplayHiDpi] answers, instead of this machine's display.
  final bool hiDpi;

  @override
  bool mainDisplayHiDpi() => hiDpi;

  @override
  Future<void> afterExtract(String dir) async {}

  @override
  (String, List<String>) get sha256Tool => File('/usr/bin/shasum').existsSync()
      ? super.sha256Tool
      : ('sha256sum', const []);

  @override
  Future<String> signingTeam(String path, {bool deep = false}) async =>
      team ?? (throw RuntimeNotTrusted(path, 'not signed'));

  @override
  Future<void> copyTree(String from, String to) async {
    final result = await Process.run('cp', ['-a', from, to]);
    if (result.exitCode != 0) {
      throw ProcessFailed('cp -a', result.exitCode, '${result.stderr}');
    }
  }

  @override
  List<String> get applicationDirs => [?applications];
}

/// What the checksum tool prints for [name] (`<hash>  <name>`), run in [dir].
Future<String> sha256Line(String name, {String? dir}) async {
  final (tool, args) = const TestMac().sha256Tool;
  final run = await Process.run(tool, [...args, name], workingDirectory: dir);
  return '${run.stdout}';
}

/// Makes the tests of this `main` run as the Mac does.
void useMac() {
  setUp(() => hostPlatform = const TestMac());
  tearDown(() => hostPlatform = HostPlatform.detect());
}
