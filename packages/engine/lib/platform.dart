part of 'engine.dart';

/// Something the host lacks before bottles can run (R10).
typedef HostIssue = ({String title, String detail, String? command});

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
});

/// What differs between hosts. The rest of the engine is shared.
abstract class HostPlatform {
  const HostPlatform();

  /// The host this process runs on (R1).
  static HostPlatform detect() => switch (Platform.operatingSystem) {
    'macos' => MacPlatform(),
    'linux' => LinuxPlatform(),
    final other => throw 'sistema no soportado: $other',
  };

  /// `Mac` or `Linux`, for texts.
  String get displayName;
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
