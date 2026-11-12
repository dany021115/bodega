import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_file_types.dart';
import 'package:bodega/app/shared/widgets/app_menu.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum _From { file, folder }

/// Install firmware: a menu beside the button, to pick the user's own
/// firmware, a file or a folder. The emulator then opens its own installer
/// on it, and the user confirms there: Bodega never opens it.
class InstallFirmwareButton extends StatelessWidget {
  const InstallFirmwareButton({super.key});

  Future<void> _pick(BuildContext button) async {
    final bloc = button.read<SwitchBloc>();
    final l10n = button.l10n;
    final files = firmwareFileTypes();
    final choice = await showMenu<_From>(
      context: button,
      position: menuBeside(button),
      items: [
        PopupMenuItem(value: _From.file, child: Text(l10n.switchFirmwareFile)),
        PopupMenuItem(
          value: _From.folder,
          child: Text(l10n.switchFirmwareFolder),
        ),
      ],
    );
    final path = switch (choice) {
      _From.file => (await openFile(acceptedTypeGroups: [files]))?.path,
      _From.folder => await getDirectoryPath(),
      null => null,
    };
    if (path != null) bloc.add(SwitchEvent.installFirmware(path));
  }

  @override
  Widget build(BuildContext context) => Builder(
    builder: (button) => FilledButton.icon(
      onPressed: () => _pick(button),
      icon: const Icon(Icons.system_update_alt_rounded, size: 18),
      label: Text(context.l10n.switchInstallFirmware),
    ),
  );
}
