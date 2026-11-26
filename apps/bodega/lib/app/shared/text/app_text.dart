import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';

/// What an app row says about its program: its architecture when it matters,
/// then what its exe draws with (G2). A program built for Windows on ARM runs
/// only on the Native engine, and a row on the Rosetta engine says so before a
/// launch fails (AA1).
String? programFactsText(AppL10n l10n, LibraryApp app, String? graphics) {
  final facts = [
    if (app.arm64) app.nativeEngine ? l10n.appArm64 : l10n.appArm64NeedsNative,
    ?graphics,
  ];
  return facts.isEmpty ? null : facts.join(' · ');
}
