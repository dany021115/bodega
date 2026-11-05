part of 'catalog_bloc.dart';

@freezed
sealed class CatalogEvent with _$CatalogEvent {
  const factory CatalogEvent.load() = CatalogLoadEvent;
  const factory CatalogEvent.search(String query) = CatalogSearchEvent;

  /// From a bottle's `Instalar en esta botella`: the details offer it first.
  const factory CatalogEvent.target(String? bottle) = CatalogTargetEvent;
}
