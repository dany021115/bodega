import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_file_types.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _Add { files, folder }

/// Add games (switch-support SA16): a menu under the button, to pick game
/// files and native apps, or a folder that Bodega looks through. The engine
/// tells which of them are Switch games.
class AddGamesButton extends StatelessWidget {
  /// The extensions of the game files the emulator opens, from the status.
  /// Null, while there is no status or an add runs, disables the button.
  final List<String>? extensions;

  const AddGamesButton({super.key, required this.extensions});

  /// Under [button]: from its left edge, or from its right edge when that is
  /// closer to the window's.
  static RelativeRect _under(BuildContext button) {
    final box = button.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    return RelativeRect.fromRect(
      rect.shift(Offset(0, rect.height)),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _add(BuildContext button, List<String> extensions) async {
    final bloc = button.read<SwitchBloc>();
    final l10n = button.l10n;
    final games = gameFileTypes(extensions);
    final choice = await showMenu<_Add>(
      context: button,
      position: _under(button),
      items: [
        PopupMenuItem(value: _Add.files, child: Text(l10n.switchAddFiles)),
        PopupMenuItem(value: _Add.folder, child: Text(l10n.switchAddFolder)),
      ],
    );
    switch (choice) {
      case _Add.files:
        final files = await openFiles(acceptedTypeGroups: [games]);
        if (files.isNotEmpty) {
          bloc.add(SwitchEvent.addFiles([for (final file in files) file.path]));
        }
      case _Add.folder:
        final folder = await getDirectoryPath();
        if (folder != null) bloc.add(SwitchEvent.addFolder(folder));
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final extensions = this.extensions;

    return GradientButton(
      label: context.l10n.switchAddGames,
      icon: Icons.add_rounded,
      onPressed: extensions == null ? null : () => _add(context, extensions),
    );
  }
}
