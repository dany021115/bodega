import 'package:engine/engine.dart';
import 'package:test/test.dart';

/// The Mac without `xattr`, so that the Mac tests also run on Linux.
class TestMac extends MacPlatform {
  const TestMac();

  @override
  Future<void> afterExtract(String dir) async {}
}

/// Makes the tests of this `main` run as the Mac does.
void useMac() {
  setUp(() => hostPlatform = const TestMac());
  tearDown(() => hostPlatform = HostPlatform.detect());
}
