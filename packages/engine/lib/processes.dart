part of 'engine.dart';

/// One process of a Wine prefix (D1), as `ps` shows it: Wine renames a
/// Windows process after its program (`FIFA22.exe`,
/// `Z:\Volumes\X\FIFA22.exe`), and the wineserver keeps its unix path.
typedef WineProcess = ({int pid, double cpu, String command});

/// The program file name of a Wine process's [command], lower-cased, or null
/// when it runs no `.exe`: `fifa22.exe` from `FIFA22.exe`,
/// `Z:\Volumes\X\FIFA22.exe` or `C:\a b\FIFA22.exe -k x`.
String? programName(String command) => RegExp(
  r'([^\\/]+?\.exe)(?=\s|$)',
  caseSensitive: false,
).firstMatch(command)?.group(1)?.toLowerCase();

/// Whether [process] is a wineserver: its command ends in `/wineserver`,
/// maybe with options.
bool isWineserver(WineProcess process) =>
    RegExp(r'(^|/)wineserver(\s|$)').hasMatch(process.command);

/// `ps -o pid=,%cpu=,command=` lines as [WineProcess]es; others are skipped.
List<WineProcess> parsePs(String output) => [
  for (final line in output.split('\n'))
    if (RegExp(r'^\s*(\d+)\s+([\d.]+)\s+(.+?)\s*$').firstMatch(line)
        case final m?)
      (
        pid: int.parse(m.group(1)!),
        cpu: double.parse(m.group(2)!),
        command: m.group(3)!,
      ),
];

/// [pids] as `ps` sees them now, in the C locale so `%cpu` has a dot.
List<WineProcess> _psOf(Iterable<int> pids) {
  if (pids.isEmpty) return const [];
  final run = Process.runSync(
    'ps',
    ['-o', 'pid=,%cpu=,command=', '-p', pids.join(',')],
    environment: const {'LC_ALL': 'C'},
  );
  return parsePs('${run.stdout}');
}

/// The processes of [bottle]'s prefix, its wineserver included (ER2).
List<WineProcess> bottleProcesses(String home, String bottle) =>
    hostPlatform.wineProcesses('${_existing(home, bottle)}/prefix');

/// Ends what is left of the prefix [prefix] after `wineserver -k` (ER3):
/// SIGTERM, up to 3 s, then SIGKILL. Returns what it ended.
Future<List<WineProcess>> _reap(String prefix) =>
    _end(hostPlatform.wineProcesses(prefix));

/// Ends the Wine processes Bodega's bottles left behind, whose wineserver is
/// gone (ER3, D2), and returns them. A process that maps nothing under [home]
/// is someone else's (Whisky's, CrossOver's, Mach9.app's) and stays.
Future<List<WineProcess>> reapOrphans(String home) =>
    _end(hostPlatform.orphanWineProcesses(home));

Future<List<WineProcess>> _end(List<WineProcess> processes) async {
  if (processes.isEmpty) return const [];
  for (final process in processes) {
    Process.killPid(process.pid, ProcessSignal.sigterm);
  }
  for (var i = 0; i < 12 && processes.any((p) => _alive(p.pid)); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  for (final process in processes) {
    if (_alive(process.pid))
      Process.killPid(process.pid, ProcessSignal.sigkill);
  }
  return processes;
}

/// Whether the app of the run [log] still runs in [bottle] after its first
/// process exited (ER4): a process of the bottle runs the program the `.pid`
/// file's third line names. A two-line `.pid` (older Bodega) says no.
bool appStillRunning(String home, String bottle, String log) =>
    _appProcesses(home, bottle, log).isNotEmpty;

/// The program the run [log] started, lower-cased: the third line of its
/// `.pid` file, or null for an older two-line one (ER4).
String? _runProgram(String log) {
  final pid = File(log.replaceFirst(RegExp(r'\.log$'), '.pid'));
  if (!pid.existsSync()) return null;
  final lines = pid.readAsLinesSync();
  return lines.length < 3 || lines[2].isEmpty ? null : lines[2];
}

List<WineProcess> _appProcesses(String home, String bottle, String log) {
  final name = _runProgram(log);
  if (name == null) return const [];
  return [
    for (final process in bottleProcesses(home, bottle))
      if (programName(process.command) == name) process,
  ];
}

/// The CPU of the app of the run [log] in [bottle], in `ps`'s percent: the
/// sum over its processes, or null when none runs (ER5).
double? appCpu(String home, String bottle, String log) {
  final processes = _appProcesses(home, bottle, log);
  if (processes.isEmpty) return null;
  return processes.fold<double>(0, (sum, process) => sum + process.cpu);
}

/// Whether the run of [log] looks hung (ER5, D4): its log holds Wine's lock
/// timeout ([LogHint.stuckLock]), and the last 12 of [samples], its CPU
/// taken every 5 s, average under 2%: a minute that did nothing.
bool runHung(String log, List<double> samples) {
  if (samples.length < 12) return false;
  final last = samples.sublist(samples.length - 12);
  if (last.fold<double>(0, (sum, cpu) => sum + cpu) / 12 >= 2) return false;
  final file = File(log);
  return file.existsSync() &&
      latin1.decode(file.readAsBytesSync()).contains(LogHint.stuckLock.marker);
}

/// One sample of `bodega measure` (ER8): the bottle's CPU, its busiest
/// program and that one's CPU, and the GPU's utilization in percent where
/// the host tells it.
typedef BottleSample = ({double cpu, String? top, double topCpu, int? gpu});

BottleSample measureBottle(String home, String bottle) {
  final byName = <String, double>{};
  var cpu = 0.0;
  for (final process in bottleProcesses(home, bottle)) {
    cpu += process.cpu;
    final name =
        programName(process.command) ??
        (isWineserver(process) ? 'wineserver' : process.command);
    byName[name] = (byName[name] ?? 0) + process.cpu;
  }
  final top = byName.entries.fold<MapEntry<String, double>?>(
    null,
    (best, entry) => best == null || entry.value > best.value ? entry : best,
  );
  return (
    cpu: cpu,
    top: top?.key,
    topCpu: top?.value ?? 0,
    gpu: hostPlatform.gpuUtilization(),
  );
}

/// `"Device Utilization %"=N` from `ioreg -r -d 1 -w 0 -c IOAccelerator`.
int? parseGpuUtilization(String ioreg) => int.tryParse(
  RegExp(r'"Device Utilization %"=(\d+)').firstMatch(ioreg)?.group(1) ?? '',
);
