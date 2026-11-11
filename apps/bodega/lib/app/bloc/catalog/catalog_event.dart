part of 'catalog_bloc.dart';

@freezed
sealed class CatalogEvent with _$CatalogEvent {
  const factory CatalogEvent.load() = CatalogLoadEvent;
  const factory CatalogEvent.search(String query) = CatalogSearchEvent;

  /// From a bottle's add-app dialog, whose Install opens a catalog app's
  /// details: they offer that bottle first.
  const factory CatalogEvent.target(String? bottle) = CatalogTargetEvent;
}
