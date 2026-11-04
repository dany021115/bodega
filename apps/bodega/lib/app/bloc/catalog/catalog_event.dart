part of 'catalog_bloc.dart';

@freezed
sealed class CatalogEvent with _$CatalogEvent {
  const factory CatalogEvent.load() = CatalogLoadEvent;
  const factory CatalogEvent.search(String query) = CatalogSearchEvent;
}
