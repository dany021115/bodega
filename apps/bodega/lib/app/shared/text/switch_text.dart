import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/l10n/l10n.dart';

/// A [SwitchNotice] in the user's language: the toast when an add ends, or
/// when a game's run ends badly, on whatever page shows (switch-support
/// design §6).
///
/// One case per notice and no default, so a notice added to [SwitchNotice]
/// fails the build here until it has its words.
String switchNoticeText(AppL10n l10n, SwitchNotice notice) => switch (notice) {
  SwitchAddedNotice(:final added, :final known) => l10n.switchAdded(
    added,
    known,
  ),
  SwitchExitedNotice(:final title, :final code) => l10n.switchExited(
    title,
    code,
  ),
};
