part of 'backends_bloc.dart';

@freezed
abstract class BackendsState with _$BackendsState {
  const BackendsState._();

  const factory BackendsState({
    @Default(true) bool isLoading,
    @Default([]) List<BackendInfo> backends,
    @Default([]) List<String> bottles,

    /// The ready Native engine bottles, which can run its check (PA4).
    @Default([]) List<String> nativeBottles,

    /// The backend, or the runtime (`mach9`), being installed.
    String? busy,
    @Default(false) bool isDownloading,
    @Default(0) int received,
    int? total,

    /// The Game Porting Toolkit versions offered (I1).
    @Default([]) List<GptkRelease> releases,

    /// The version whose dmg Bodega waits for in Downloads (I2).
    String? gptkWaiting,

    /// What the D3DMetal install is doing (I3), as a code: the card words it
    /// (L6).
    GptkStep? gptkStep,

    /// The D3DMetal install that just ended well, for the page to say so. Its
    /// version is null when the framework does not say, which still counts
    /// as installed (E3).
    ({String? version})? gptkInstalled,

    /// Each runtime kind on this host (MR3).
    @Default([]) List<RuntimeInfo> runtimes,

    /// What the native engine's install is doing, as a code: its card words
    /// it.
    Mach9Step? runtimeStep,

    /// The backend being checked.
    String? checking,
    @Default({}) Map<String, List<ProbeResult>> results,
    AppError? error,
  }) = _BackendsState;

  /// The native engine's entry, when this host lists one that it does not
  /// rule out entirely: a too-old macOS still shows the card, with why (MA5).
  RuntimeInfo? get mach9 {
    for (final runtime in runtimes) {
      if (runtime.kind != RuntimeKind.mach9) continue;
      return switch (runtime.blocked) {
        RuntimeBlock.notThisHost || RuntimeBlock.appleSiliconOnly => null,
        RuntimeBlock.macosTooOld || null => runtime,
      };
    }
    return null;
  }

  /// The native engine is installed and runs here: new bottles may use it.
  bool get nativeUsable => mach9?.usable ?? false;

  double? get fraction {
    final size = total;
    return size == null || size == 0 ? null : received / size;
  }
}
