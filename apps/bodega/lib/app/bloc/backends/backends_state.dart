part of 'backends_bloc.dart';

@freezed
abstract class BackendsState with _$BackendsState {
  const BackendsState._();

  const factory BackendsState({
    @Default(true) bool isLoading,
    @Default([]) List<BackendInfo> backends,
    @Default([]) List<String> bottles,

    /// The backend being installed.
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

    /// The backend being checked.
    String? checking,
    @Default({}) Map<String, List<ProbeResult>> results,
    AppError? error,
  }) = _BackendsState;

  double? get fraction {
    final size = total;
    return size == null || size == 0 ? null : received / size;
  }
}
