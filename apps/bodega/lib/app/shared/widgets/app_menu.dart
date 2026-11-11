import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum AppMenuAction { open, options, hud, library, hide }

/// The widest a popup menu gets.
const double _menuWidth = 280;

/// The menu every app card and row shares. It opens beside [anchor], the
/// widget of its menu button: at its right, or at its left when there is no
/// room (so it always shows in the same place for the same button).
Future<AppMenuAction?> showAppMenu(
  BuildContext anchor, {
  required bool inLibrary,
  required bool hud,
}) {
  final button = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final rect =
      button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
  final width = overlay.size.width;
  final toRight = width - rect.right >= _menuWidth || rect.left < _menuWidth;
  final l10n = anchor.l10n;

  return showMenu<AppMenuAction>(
    context: anchor,
    // The popup grows from `left` when it is smaller than `right`, and from
    // the right edge otherwise.
    position: toRight
        ? RelativeRect.fromLTRB(rect.right, rect.top, width, 0)
        : RelativeRect.fromLTRB(width, rect.top, width - rect.left, 0),
    items: [
      PopupMenuItem(value: AppMenuAction.open, child: Text(l10n.commonOpen)),
      PopupMenuItem(
        value: AppMenuAction.options,
        child: Text(l10n.bottleRunWithOptions),
      ),
      // A switch that is saved for this app: the item's tap flips it.
      PopupMenuItem(
        value: AppMenuAction.hud,
        child: Row(
          children: [
            Expanded(child: Text(l10n.appMenuHud)),
            IgnorePointer(
              child: Switch(value: hud, onChanged: (_) {}),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: AppMenuAction.library,
        child: Text(inLibrary ? l10n.libraryRemove : l10n.libraryAdd),
      ),
      PopupMenuItem(value: AppMenuAction.hide, child: Text(l10n.appMenuHide)),
    ],
  );
}
