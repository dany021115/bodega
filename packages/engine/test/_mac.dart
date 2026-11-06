import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// The Mac without `xattr` and, where `/usr/bin/shasum` is missing, with
/// `sha256sum`, so that the Mac tests also run on Linux.
class TestMac extends MacPlatform {
  const TestMac();

  @override
  Future<void> afterExtract(String dir) async {}

  @override
  (String, List<String>) get sha256Tool => File('/usr/bin/shasum').existsSync()
      ? super.sha256Tool
      : ('sha256sum', const []);
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
