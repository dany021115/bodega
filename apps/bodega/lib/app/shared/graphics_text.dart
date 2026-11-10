import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/l10n/app_localizations.dart';

/// `DX9 · 32 bits`, or `32 bits` (G2).
String graphicsLabel(AppLocalizations l10n, ExeGraphics g) => g.directx.isEmpty
    ? l10n.graphicsBits(g.bits)
    : l10n.graphicsDirectxBits(g.directx, g.bits);

/// G4: why [backend] does not suit [title], or null if it does.
String? graphicsWarning(
  AppLocalizations l10n,
  ExeGraphics g,
  String title,
  String backend,
) => g.misfits.contains(backend)
    ? l10n.graphicsWarning(title, g.bits, g.directx.substring(2), backend)
    : null;
