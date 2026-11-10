import 'package:bodega/domain/entities/app_error.dart';
import 'package:fpdart/fpdart.dart';

abstract class StorageRepository {
  /// Where Bodega keeps its bottles, runtimes and downloads.
  String get dataFolder;

  /// The bytes the installer cache takes.
  Future<Either<AppError, int>> downloadsSize();

  Future<Either<AppError, Unit>> clearDownloads();
}
