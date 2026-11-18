part of 'dependencies_bloc.dart';

/// What the job is doing: one item at a time.
enum DependencyPhase { idle, downloading, installing, applying }

@freezed
abstract class DependenciesState with _$DependenciesState {
  const DependenciesState._();

  const factory DependenciesState({
    /// What each bottle read has: its runtimes and its apps' needs.
    @Default(<String, BottleDependencies>{})
    Map<String, BottleDependencies> bottles,
    @Default(DependencyPhase.idle) DependencyPhase phase,

    /// The bottle of the job, and the item it is doing.
    String? bottle,
    NeedItem? item,
    @Default(0) int received,
    int? total,

    /// The last failure, with the bottle and the item it belongs to: a
    /// runtime's failure offers a file of the user's (DA7).
    AppError? error,
    String? failedBottle,
    NeedItem? failed,

    /// A proposal waiting for its dialog, for [offerBottle].
    AppNeeds? offer,
    String? offerBottle,
  }) = _DependenciesState;

  bool get isBusy => phase != DependencyPhase.idle;

  double? get fraction {
    final size = total;
    return size == null || size == 0 ? null : received / size;
  }
}
