part of 'install_bloc.dart';

enum InstallPhase { idle, downloading, installing, done, failed }

@freezed
abstract class InstallState with _$InstallState {
  const InstallState._();

  const factory InstallState({
    @Default(InstallPhase.idle) InstallPhase phase,
    CatalogApp? app,

    /// Where it goes: its own bottle, named as the app, or an existing one.
    String? bottle,
    @Default(0) int received,
    int? total,
    ProgressStep? step,
    AppError? error,
    @Default(false) bool bottleLeft,
  }) = _InstallState;

  bool get isRunning =>
      phase == InstallPhase.downloading || phase == InstallPhase.installing;

  double? get fraction {
    final size = total;
    return size == null || size == 0 ? null : received / size;
  }
}
