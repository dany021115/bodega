import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_app.freezed.dart';

enum CatalogStatus { tested, reported, untested, blocked }

/// An app of the catalog, as data: its prose (status note, why it is
/// unstable, notes and known issues) is worded in app/ by [id] (design §7).
@freezed
abstract class CatalogApp with _$CatalogApp {
  const CatalogApp._();

  const factory CatalogApp({
    required String id,
    required String title,
    required CatalogStatus status,

    /// The catalog marks it unstable; its prose says why.
    @Default(false) bool flaky,
    required String backend,
    required bool backendInstalled,
    required String sync,
    required String host,
    required bool hasChecksum,

    /// Where its recipe comes from, by field: null for one with no data.
    @Default({}) Map<String, String?> source,

    /// The bottle it is installed in, and its key there.
    String? bottle,
    String? appKey,

    /// Its key once installed, wherever it goes.
    @Default('') String installKey,
  }) = _CatalogApp;

  bool get isInstalled => bottle != null;
}
