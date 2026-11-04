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
