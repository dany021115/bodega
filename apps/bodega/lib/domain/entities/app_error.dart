import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_error.freezed.dart';

/// Lives in domain, not in data as in TeeShot, so that repository interfaces
/// don't import the data layer.
@freezed
sealed class AppError with _$AppError {
  const factory AppError.engine(String message) = EngineError;
  const factory AppError.network(String message) = NetworkError;
  const factory AppError.unknown(String message) = UnknownError;
}
