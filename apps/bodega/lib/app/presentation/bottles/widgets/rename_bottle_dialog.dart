import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The bottle's name is also its folder name.
final RegExp _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

/// The new name, or null if it was cancelled.
Future<String?> showRenameBottleDialog(BuildContext context, String current) =>
    showDialog<String>(
      context: context,
      builder: (_) => RenameBottleDialog(current: current),
    );

class RenameBottleDialog extends StatefulWidget {
  final String current;

  const RenameBottleDialog({super.key, required this.current});

  @override
  State<RenameBottleDialog> createState() => _RenameBottleDialogState();
}

class _RenameBottleDialogState extends State<RenameBottleDialog> {
  late final _name = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final valid = _validName.hasMatch(name);
    final changed = name != widget.current;
    final canSave = valid && changed;
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.bottlesRenameTitle),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.bottlesName,
            errorText: name.isEmpty || valid ? null : l10n.bottlesNameInvalid,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: canSave ? (_) => Navigator.of(context).pop(name) : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.of(context).pop(name) : null,
          child: Text(l10n.bottlesRename),
        ),
      ],
    );
  }
}
