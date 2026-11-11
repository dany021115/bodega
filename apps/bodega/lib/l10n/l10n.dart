import 'package:bodega/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:bodega/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  /// The app's text in the active language, non-nullable.
  ///
  /// `AppL10n.of` is nullable because the delegate could be missing. In the app
  /// it cannot be: `main.dart` installs it above every route. So this asserts
  /// once, naming the fix, instead of a `!` at every call site.
  AppL10n get l10n {
    final value = AppL10n.of(this);
    assert(
      value != null,
      'No AppL10n above this widget. A test must pump it through wrapApp or '
      'wrapRouter (test/support/pump.dart).',
    );
    return value!;
  }
}
