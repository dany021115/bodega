import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:fpdart/fpdart.dart';

abstract class CatalogRepository {
  Future<Either<AppError, List<CatalogApp>>> apps();
}
