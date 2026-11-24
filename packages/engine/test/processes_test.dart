import 'dart:io';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

import '_mac.dart';
import 'runtimes_test.dart' show mach9Bottle;

/// The Mac, with each prefix's processes and the orphans given by the test.
class _ProcMac extends TestMac {
  final Map<String, List<WineProcess>> byPrefix = {};
  final List<WineProcess> orphans = [];
  String? orphansHome;

  @override
  List<WineProcess> wineProcesses(String prefix) => [
    for (final process in byPrefix[prefix] ?? const <WineProcess>[])
      if (_alive(process.pid)) process,
  ];

  int? gpu;

  @override
  int? gpuUtilization() => gpu;

  @override
  List<WineProcess> orphanWineProcesses(String home) {
    orphansHome = home;
    return [
      for (final process in orphans)
        if (_alive(process.pid)) process,
    ];
  }
}

// The ER4 tests list `pid`, dart:io's own: alive, as the fake requires.
bool _alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

/// A real process that ignores SIGTERM when [stubborn], so only SIGKILL ends
/// it, standing for a Wine process with [command].
Future<WineProcess> _process(String command, {bool stubborn = false}) async {
  final process = await Process.start('/bin/sh', [
    '-c',
    stubborn ? "trap '' TERM; while :; do sleep 1; done" : 'sleep 60',
  ]);
  return (pid: process.pid, cpu: 0.0, command: command);
}

void main() {
  late Directory tmp;
  late String home;
  late _ProcMac mac;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bodega-proc');
    home = tmp.path;
    mac = _ProcMac();
    hostPlatform = mac;
  });
  tearDown(() {
    hostPlatform = HostPlatform.detect();
    tmp.deleteSync(recursive: true);
  });

  group('ER2 a Wine process as ps shows it', () {
    test('the program name, whatever the path and the arguments', () {
      expect(programName('FIFA22.exe'), 'fifa22.exe');
      expect(
        programName(r'Z:\Volumes\SSD Daniel\FIFA 22\FIFA22.exe'),
        'fifa22.exe',
      );
      expect(
        programName(r'C:\windows\system32\svchost.exe -k LocalService'),
        'svchost.exe',
      );
      expect(
        programName(r'C:\Program Files (x86)\Steam\steam.exe'),
        'steam.exe',
      );
      expect(programName('/opt/wine/bin/wineserver'), isNull);
    });

    test('the wineserver, by its unix path', () {
      WineProcess p(String command) => (pid: 1, cpu: 0, command: command);
      expect(
        isWineserver(p('/x/engine/lib/wine/../../bin/wineserver')),
        isTrue,
      );
      expect(isWineserver(p('/x/bin/wineserver -w')), isTrue);
      expect(isWineserver(p(r'C:\windows\system32\winedevice.exe')), isFalse);
    });

    test('ps lines, a Windows path with spaces among them', () {
      expect(
        parsePs(
          ' 4361 199.8 FIFA22.exe\n'
          '12903   5.5 /x/bin/wineserver\n'
          r' 7144   0.0 Z:\Volumes\SSD Daniel\FIFA 22\FIFA22.exe'
          '\n\n',
        ),
        [
          (pid: 4361, cpu: 199.8, command: 'FIFA22.exe'),
          (pid: 12903, cpu: 5.5, command: '/x/bin/wineserver'),
          (
            pid: 7144,
            cpu: 0.0,
            command: r'Z:\Volumes\SSD Daniel\FIFA 22\FIFA22.exe',
          ),
        ],
      );
    });
  });

  group('ER3 the reaper', () {
    test('stopping a bottle ends what survives, by TERM or KILL', () async {
      final dir = mach9Bottle(home, 'b');
      final polite = await _process(r'C:\windows\system32\services.exe');
      final stubborn = await _process(
        r'C:\windows\system32\winedevice.exe',
        stubborn: true,
      );
      mac.byPrefix['$dir/prefix'] = [polite, stubborn];
      await stopBottle(home, 'b');
      expect(_alive(polite.pid), isFalse);
      expect(_alive(stubborn.pid), isFalse);
    });

    test('removing a bottle ends them before its folder goes', () async {
      final dir = mach9Bottle(home, 'b');
      final left = await _process(r'C:\windows\system32\winedevice.exe');
      mac.byPrefix['$dir/prefix'] = [left];
      await removeBottle(home, 'b');
      expect(_alive(left.pid), isFalse);
      expect(Directory(dir).existsSync(), isFalse);
    });

    test("a Mac orphan is Bodega's only when it maps a file of its home", () {
      const home = '/Users/u/Library/Application Support/Bodega';
      expect(
        lsofNamesUnder(
          'p26464\nfcwd\nn/\nn$home/runtimes/engine/lib/wine/x86_64-unix/libSDL2-2.0.0.dylib\n',
          home,
        ),
        isTrue,
      );
      expect(
        lsofNamesUnder(
          'p900\nn/Applications/Whisky.app/Contents/Resources/Libraries/Wine/bin/wine64\n'
          'n/Users/u/Library/Containers/com.franke.Whisky/Bottles/X/drive_c\n',
          home,
        ),
        isFalse,
      );
      // A sibling whose name starts the same is not under it.
      expect(lsofNamesUnder('p1\nn${home}-backup/x\n', home), isFalse);
    });

    test('orphans: what the platform finds under the home ends', () async {
      final orphan = await _process(r'C:\windows\system32\winedevice.exe');
      mac.orphans.add(orphan);
      expect(await reapOrphans(home), [orphan]);
      expect(mac.orphansHome, home);
      expect(_alive(orphan.pid), isFalse);
      expect(await reapOrphans(home), isEmpty);
    });
  });

  group('ER4 a game that relaunches itself', () {
    test('it runs while the bottle runs its program', () {
      final dir = mach9Bottle(home, 'b');
      final log = '$dir/logs/run-FIFA22.log';
      File(log).writeAsStringSync('# exit=255\n');
      File('$dir/logs/run-FIFA22.exit').writeAsStringSync('255');
      File('$dir/logs/run-FIFA22.pid')
          .writeAsStringSync('4335\n/volumes/x/fifa22.exe\nfifa22.exe\n');
      mac.byPrefix['$dir/prefix'] = [
        (pid: pid, cpu: 0.0, command: r'Z:\Volumes\X\FIFA22.exe'),
      ];
      expect(appStillRunning(home, 'b', log), isTrue);
      mac.byPrefix['$dir/prefix'] = [
        (pid: pid, cpu: 0.0, command: r'C:\windows\system32\services.exe'),
      ];
      expect(appStillRunning(home, 'b', log), isFalse);
    });

    test("an older Bodega's two-line pid file says it ended", () {
      final dir = mach9Bottle(home, 'b');
      final log = '$dir/logs/run-FIFA22.log';
      File('$dir/logs/run-FIFA22.pid')
          .writeAsStringSync('4335\n/volumes/x/fifa22.exe\n');
      mac.byPrefix['$dir/prefix'] = [
        (pid: pid, cpu: 0.0, command: 'FIFA22.exe'),
      ];
      expect(appStillRunning(home, 'b', log), isFalse);
    });
  });

  group('ER5 a hang', () {
    test('the lock line and a minute near 0% CPU', () {
      final log = File('${tmp.path}/run.log')
        ..writeAsStringSync(
          '00f4:err:sync:RtlpWaitForCriticalSection section 0000000148525EA0 '
          '"?" wait timed out in thread 00f4, blocked by 0000, retrying (60 sec)\n',
        );
      final idle = List.filled(12, 0.1);
      expect(runHung(log.path, idle), isTrue);
      expect(runHung(log.path, idle.sublist(1)), isFalse);
      expect(runHung(log.path, [...idle.sublist(1), 40.0]), isFalse);
      log.writeAsStringSync('nothing stuck\n');
      expect(runHung(log.path, idle), isFalse);
    });

    test("the app's CPU, the sum over its processes", () {
      final dir = mach9Bottle(home, 'b');
      final log = '$dir/logs/run-FIFA22.log';
      File('$dir/logs/run-FIFA22.pid')
          .writeAsStringSync('1\n/volumes/x/fifa22.exe\nfifa22.exe\n');
      expect(appCpu(home, 'b', log), isNull);
      mac.byPrefix['$dir/prefix'] = [
        (pid: pid, cpu: 0.5, command: 'FIFA22.exe'),
        (pid: pid, cpu: 1.0, command: r'Z:\X\FIFA22.exe'),
        (pid: pid, cpu: 9.0, command: r'C:\windows\system32\services.exe'),
      ];
      expect(appCpu(home, 'b', log), 1.5);
    });
  });

  group('ER8 measuring', () {
    test('a sample: CPU, the busiest program, the GPU', () {
      final dir = mach9Bottle(home, 'b');
      mac.gpu = 61;
      mac.byPrefix['$dir/prefix'] = [
        (pid: pid, cpu: 120.0, command: 'FIFA22.exe'),
        (pid: pid, cpu: 30.0, command: 'FIFA22.exe'),
        (pid: pid, cpu: 5.5, command: '/x/bin/wineserver'),
      ];
      final sample = measureBottle(home, 'b');
      expect(sample, (cpu: 155.5, top: 'fifa22.exe', topCpu: 150.0, gpu: 61));
      expect(
        measureLine('1s', sample),
        '1s  cpu 155.5%  top fifa22.exe 150.0%  gpu 61%',
      );
    });

    test('the averages', () {
      final average = averageSample([
        (cpu: 100.0, top: 'a.exe', topCpu: 90.0, gpu: 40),
        (cpu: 200.0, top: 'a.exe', topCpu: 150.0, gpu: 60),
        (cpu: 0.0, top: null, topCpu: 0.0, gpu: null),
      ]);
      expect(average.cpu, 100.0);
      expect(average.top, 'a.exe');
      expect(average.topCpu, 80.0);
      expect(average.gpu, 50);
    });

    test("ioreg's counter", () {
      expect(
        parseGpuUtilization(
          '| "PerformanceStatistics" = {"Device Utilization %"=68,'
          '"Renderer Utilization %"=68}',
        ),
        68,
      );
      expect(parseGpuUtilization('nothing'), isNull);
    });
  });
}
