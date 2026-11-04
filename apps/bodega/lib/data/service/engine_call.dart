import 'dart:async';

import 'package:bodega/domain/entities/app_error.dart';
import 'package:fpdart/fpdart.dart';

/// The engine throws plain messages; repositories return them as [EngineError].
Future<Either<AppError, T>> engineCall<T>(FutureOr<T> Function() call) async {
  try {
    return right(await call());
  } on String catch (message) {
    return left(AppError.engine(message));
  } on FormatException catch (e) {
    return left(AppError.engine(e.message));
  } on Object catch (e) {
    return left(AppError.unknown('$e'));
  }
}
