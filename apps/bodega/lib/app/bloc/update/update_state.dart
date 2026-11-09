part of 'update_bloc.dart';

enum UpdatePhase { available, downloading, installing }

@freezed
abstract class UpdateState with _$UpdateState {
  const UpdateState._();

  const factory UpdateState({
    /// Null while there is no newer version.
    AppUpdate? update,
    @Default(UpdatePhase.available) UpdatePhase phase,
    @Default(0) int received,
    int? total,
    AppError? error,
  }) = _UpdateState;

  bool get isBusy => phase != UpdatePhase.available;

  double? get fraction {
    final size = total;
    return size == null || size == 0 ? null : received / size;
  }
}
