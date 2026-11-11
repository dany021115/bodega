import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  late String home;
  // Each fake run's process group, killed in tearDown if a test left it alive.
  final groups = <int>[];

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('bodega');
    home = dir.resolveSymbolicLinksSync();
    Directory('$home/bottles/demo/logs').createSync(recursive: true);
  });

  tearDown(() {
    for (final group in groups) {
      Process.runSync('kill', ['-KILL', '--', '-$group']);
    }
    groups.clear();
    Directory(home).deleteSync(recursive: true);
  });

  /// A fake app run: a `sh` leader with a `sleep` child, detached, with the
  /// `.pid` file the launch would write. Returns its log path.
  Future<String> fakeRun(String key, String stamp) async {
    final log = '$home/bottles/demo/logs/$stamp-$key.log';
    File(log).writeAsStringSync('');
    final process = await Process.start('/bin/sh', [
      '-c',
      'sleep 60; :',
      'bodega',
      log,
    ], mode: ProcessStartMode.detached);
    groups.add(
      int.parse(
        (Process.runSync('ps', ['-o', 'pgid=', '-p', '${process.pid}']).stdout
                as String)
            .trim(),
      ),
    );
    File(log.replaceFirst(RegExp(r'\.log$'), '.pid'))
        .writeAsStringSync('${process.pid}\n$key\n');
    return log;
  }

  int pidOf(String log) => int.parse(
    File(log.replaceFirst(RegExp(r'\.log$'), '.pid')).readAsLinesSync().first,
  );

  bool alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

  test(
    'stopApp ends only its run and runningApps lists the live one',
    () async {
      final logA = await fakeRun('app-a', '2026-01-01T00-00-00');
      final logB = await fakeRun('app-b', '2026-01-01T00-00-01');

      expect(
        runningApps(home, 'demo').map((app) => app.key),
        unorderedEquals(['app-a', 'app-b']),
      );

      await stopApp(logA);

      expect(alive(pidOf(logA)), isFalse, reason: 'the stopped run is gone');
      expect(runningApps(home, 'demo').map((app) => app.log), [
        logB,
      ], reason: 'only the other run is listed');
      expect(alive(pidOf(logB)), isTrue, reason: 'the other run stays alive');
    },
  );
}
