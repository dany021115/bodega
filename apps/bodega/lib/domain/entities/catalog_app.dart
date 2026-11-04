import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_app.freezed.dart';

enum CatalogStatus { tested, reported, untested, blocked }

@freezed
abstract class KnownIssue with _$KnownIssue {
  const factory KnownIssue({required String symptom, required String fix}) =
      _KnownIssue;
}

@freezed
abstract class CatalogApp with _$CatalogApp {
  const CatalogApp._();

  const factory CatalogApp({
    required String id,
    required String title,
    required CatalogStatus status,
    required String statusNote,
    String? flaky,
    required String backend,
    required bool backendInstalled,
    required String sync,
    required String host,
    required bool hasChecksum,
    @Default([]) List<String> notes,
    @Default([]) List<KnownIssue> knownIssues,
    @Default({}) Map<String, String> source,

    /// The bottle it is installed in.
    String? bottle,
  }) = _CatalogApp;

  bool get isInstalled => bottle != null;
}
