import 'dart:async';

import 'package:bodega/domain/entities/app_error.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

/// What a repository's work throws, as a [Left]: the engine throws plain
/// messages and FormatException (design §1), and the network DioException.
Future<Either<AppError, T>> repositoryCall<T>(
  FutureOr<T> Function() call,
) async {
  try {
    return right(await call());
  } on AppError catch (error) {
    return left(error);
  } on String catch (message) {
    return left(AppError.engine(message));
  } on FormatException catch (e) {
    return left(AppError.engine(e.message));
  } on DioException catch (e) {
    return left(
      AppError.network('Error de red: ${e.message ?? e.error ?? e.type}'),
    );
  } on Object catch (e) {
    return left(AppError.unknown('$e'));
  }
}
