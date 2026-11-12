import 'package:bodega/app/shared/widgets/app_menu.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum SwitchGameAction { open, remove }

/// A Switch game's menu, beside [anchor], the widget of its card's menu
/// button, where every app card's menu opens ([menuBeside]). A game that
/// [running] stays in the list until it ends: its Remove is disabled.
Future<SwitchGameAction?> showSwitchGameMenu(
  BuildContext anchor, {
  required bool running,
}) {
  final l10n = anchor.l10n;

  return showMenu<SwitchGameAction>(
    context: anchor,
    position: menuBeside(anchor),
    items: [
      PopupMenuItem(value: SwitchGameAction.open, child: Text(l10n.commonOpen)),
      PopupMenuItem(
        value: SwitchGameAction.remove,
        enabled: !running,
        child: Text(l10n.switchRemove),
      ),
    ],
  );
}
