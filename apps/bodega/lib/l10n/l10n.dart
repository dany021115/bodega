import 'package:bodega/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:bodega/l10n/app_localizations.dart';

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
