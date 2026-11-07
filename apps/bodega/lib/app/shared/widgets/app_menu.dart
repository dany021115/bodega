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

  return showMenu<AppMenuAction>(
    context: anchor,
    // The popup grows from `left` when it is smaller than `right`, and from
    // the right edge otherwise.
    position: toRight
        ? RelativeRect.fromLTRB(rect.right, rect.top, width, 0)
        : RelativeRect.fromLTRB(width, rect.top, width - rect.left, 0),
    items: [
      const PopupMenuItem(value: AppMenuAction.open, child: Text('Abrir')),
      const PopupMenuItem(
        value: AppMenuAction.options,
        child: Text('Ejecutar con opciones…'),
      ),
      // A switch that is saved for this app: the item's tap flips it.
      PopupMenuItem(
        value: AppMenuAction.hud,
        child: Row(
          children: [
            const Expanded(child: Text('HUD de rendimiento')),
            IgnorePointer(
              child: Switch(value: hud, onChanged: (_) {}),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: AppMenuAction.library,
        child: Text(
          inLibrary ? 'Quitar de la biblioteca' : 'Agregar a la biblioteca',
        ),
      ),
      const PopupMenuItem(
        value: AppMenuAction.hide,
        child: Text('Quitar de la botella'),
      ),
    ],
  );
}
