import 'package:bodega/l10n/l10n.dart';

/// What [backend] is, under its name on its card. Null for a backend this
/// table does not know: its card already shows the name, so it shows no
/// description rather than the name twice.
String? backendDescriptionText(AppL10n l10n, String backend) =>
    switch (backend) {
      'wine' => l10n.backendDescriptionWine,
      'dxmt' => l10n.backendDescriptionDxmt,
      'dxvk' => l10n.backendDescriptionDxvk,
      'd3dmetal' => l10n.backendDescriptionD3dMetal,
      _ => null,
    };
