import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// The Mac without `xattr`, with `sha256sum` where `/usr/bin/shasum` is
/// missing, and with a plain `cp -R` where `cp` has no `-c`, so that the Mac
/// tests also run on Linux.
class TestMac extends MacPlatform {
  const TestMac();

  @override
  Future<void> afterExtract(String dir) async {}

  @override
  (String, List<String>) get sha256Tool => File('/usr/bin/shasum').existsSync()
      ? super.sha256Tool
      : ('sha256sum', const []);

  @override
  Future<void> copyTree(String from, String to) async {
    if (Platform.isMacOS) return super.copyTree(from, to);
    final run = await Process.run('cp', ['-R', from, to]);
    if (run.exitCode != 0) throw 'cp -R $from $to: ${run.stderr}';
  }
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
