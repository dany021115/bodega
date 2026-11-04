import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';

enum _Action { open, hide }

/// An application in its bottle. A double click or Enter opens it; a single
/// click only selects, so that a game doesn't start by mistake.
class AppTile extends StatefulWidget {
  final LibraryApp app;
  final VoidCallback onOpen;
  final VoidCallback onHide;

  const AppTile({
    super.key,
    required this.app,
    required this.onOpen,
    required this.onHide,
  });

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<PopupMenuEntry<_Action>> _items() => const [
    PopupMenuItem(value: _Action.open, child: Text('Abrir')),
    PopupMenuItem(value: _Action.hide, child: Text('Ocultar')),
  ];

  void _run(_Action? action) {
    switch (action) {
      case _Action.open:
        widget.onOpen();
      case _Action.hide:
        widget.onHide();
      case null:
        break;
    }
  }

  Future<void> _showMenuAt(Offset position) async {
    final action = await showMenu<_Action>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: _items(),
    );
    _run(action);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final app = widget.app;

    // The menu button stays out of the gesture detector: inside, it would wait
    // to see whether a double click is coming before answering.
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            button: true,
            label: app.title,
            hint: 'Doble toque para abrir',
            onTap: widget.onOpen,
            child: FocusableActionDetector(
              focusNode: _focus,
              onShowFocusHighlight: (value) => setState(() => _focused = value),
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    widget.onOpen();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _focus.requestFocus(),
                onDoubleTap: widget.onOpen,
                onSecondaryTapUp: (details) =>
                    _showMenuAt(details.globalPosition),
                child: AnimatedBuilder(
                  animation: _focus,
                  builder: (context, child) => Container(
                    decoration: BoxDecoration(
                      color: _focus.hasFocus
                          ? colors.primaryContainer.withValues(alpha: 0.5)
                          : Colors.transparent,
                      borderRadius: AppRadius.mdBorder,
                      border: Border.all(
                        color: _focused ? colors.primary : Colors.transparent,
                      ),
                    ),
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          id: app.id,
                          title: app.title,
                          iconPath: app.iconPath,
                          size: 64,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          app.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTextStyle(context).caption
                              ?.copyWith(color: colors.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: PopupMenuButton<_Action>(
            tooltip: 'Opciones de ${app.title}',
            iconSize: 16,
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (_) => _items(),
            onSelected: _run,
          ),
        ),
      ],
    );
  }
}
