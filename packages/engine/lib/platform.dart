part of 'engine.dart';

/// Something the host lacks before bottles can run (R10), as a code: what is
/// wrong, the device it names ([subject], only for [HostIssueKind.padNoAccess])
/// and the command that installs what is missing, where there is one. A UI
/// words it; [describeHostIssue] gives it in English.
typedef HostIssue = ({HostIssueKind kind, String? subject, String? command});

/// What a [HostIssue] is about.
enum HostIssueKind {
  /// The Mac lacks Rosetta 2, which Wine x86_64 runs on.
  noRosetta,

  /// The processor is not x86_64.
  unsupportedCpu,

  /// No Vulkan loader or driver: DXVK draws with it.
  noVulkan,

  /// No PulseAudio library, which Wine plays sound through.
  noAudio,

  /// Bodega cannot open a gamepad's device, so Wine cannot either. The
  /// subject is the pad's name.
  padNoAccess,

  /// No SDL2: Wine falls back to udev, which knows fewer gamepads.
  noSdl,
}

/// What a backend is for, on the backends screen (G3).
enum BackendRole {
  /// D3DMetal on the Mac.
  dx11to12x64('DirectX 11 and 12, 64 bits only'),

  /// DXMT and DXVK on the Mac.
  dx10to11('DirectX 10 and 11, 32 and 64 bits'),

  /// Wine on the Mac: what the layers do not translate.
  everythingElse(
    'everything: DirectX 9 and older, and what the others cannot run',
  ),

  /// The dxvk layer on Linux, which brings DXVK and vkd3d-proton.
  dx8to12('DirectX 8 to 12 (DXVK and vkd3d-proton)'),

  /// Wine on Linux.
  everythingSlower('everything, slower than dxvk');

  const BackendRole(this.english);

  /// For the CLI and logs.
  final String english;
}

/// What the host offers, so that a UI hides the rest (R11).
typedef HostCapabilities = ({
  bool highRes,
  bool avx,
  bool dlss,
  bool d3dmetal,
  bool sdl,
  bool gpu,
  bool gameMode,
  List<String> syncModes,
  bool switchGames,
});

/// What differs between hosts. The rest of the engine is shared.
abstract class HostPlatform {
  const HostPlatform();

  /// The host this process runs on (R1).
  static HostPlatform detect() => switch (Platform.operatingSystem) {
    'macos' => MacPlatform(),
    'linux' => LinuxPlatform(),
    final other => throw NotAvailable('Bodega', other),
  };

  /// `Mac` or `Linux`, for texts.
  String get displayName;

  /// This machine's memory in MB, for fix values sized to it, or 0 if it can't
  /// be read. It asks the system that really runs, whichever platform a test
  /// pretends to be.
  int get memoryMB => _memoryMB ??= _readMemoryMB();

  /// `mac` or `linux`: what a fix step names in its `platforms`.
  String get id;
  String defaultHome(Map<String, String> env);
  void prepareHome(String home);
  Map<String, String> baseEnv(Map<String, String> parent);
  List<String> get requiredFiles;
  String tool(String name);
  (String, List<String>) get sha256Tool;
  Future<void> afterExtract(String dir);
  Future<List<HostIssue>> checkHost();

  /// The gamepads and what is wrong with them, or null where Bodega sets them
  /// up itself and there is nothing to check (the Mac, design §10).
  Future<GamepadReport?> gamepads();

  /// Switch emulators on this host: found and started on the Mac, not yet on
  /// Linux.
  EmulatorHost get emulators;
  HostCapabilities get capabilities;
  String get defaultSync;
  Map<String, String> syncEnv(String mode);
  List<String> get backendNames;
  Map<String, ({String url, String sha256})> get pinnedBackends;
  ({String dir, String file}) get layerCheck;
  Map<String, String> backendEnv(
    String home,
    String backend, {
    bool hud = false,
  });
  Future<String> autoBackend(String home, String? exePath);

  /// G3: whether [backend] translates what [exe] draws with.
  bool backendFits(String backend, ExeGraphics exe);

  /// G3: what [backend] is for, for the backends screen.
  BackendRole backendRole(String backend);
  String mapBackend(String name);
  List<(int, String)> probeCases(String home, String backend);
  Future<void> prepareBottle(String home, String name);
  List<List<String>> highResRegistry(bool value);
  Map<String, String> gpuEnv(String gpu);
  List<String> launchWrapper({required bool gamemode});
  bool get defaultGamemode;
  String get defaultWineDebug;
  Map<String, String> perfEnv(String bottleDir);
}

/// The host in use. Tests replace it.
HostPlatform hostPlatform = HostPlatform.detect();

/// Read once: the memory does not change while Bodega runs.
int? _memoryMB;

int _readMemoryMB() {
  try {
    if (Platform.isMacOS) {
      final out = Process.runSync('/usr/sbin/sysctl', ['-n', 'hw.memsize']);
      return (int.tryParse('${out.stdout}'.trim()) ?? 0) >> 20;
    }
    final total = RegExp(
      r'^MemTotal:\s+(\d+) kB',
      multiLine: true,
    ).firstMatch(File('/proc/meminfo').readAsStringSync());
    return (int.tryParse(total?.group(1) ?? '') ?? 0) >> 10;
  } on Object {
    return 0;
  }
}
