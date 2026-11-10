import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The bottle's name is also its folder name.
final RegExp _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

/// Asks for a bottle name: to rename one or to name a copy. Returns the name,
/// or null if it was cancelled.
Future<String?> showBottleNameDialog(
  BuildContext context, {
  required String title,
  required String action,
  required String initial,
  required List<String> taken,
}) => showDialog<String>(
  context: context,
  builder: (_) => BottleNameDialog(
    title: title,
    action: action,
    initial: initial,
    taken: taken,
  ),
);

class BottleNameDialog extends StatefulWidget {
  final String title;
  final String action;
  final String initial;

  /// Names already used; compared without case, like the engine's folders.
  final List<String> taken;

  const BottleNameDialog({
    super.key,
    required this.title,
    required this.action,
    required this.initial,
    required this.taken,
  });

  @override
  State<BottleNameDialog> createState() => _BottleNameDialogState();
}

class _BottleNameDialogState extends State<BottleNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final valid = _validName.hasMatch(name);
    final taken = widget.taken.any(
      (bottle) => bottle.toLowerCase() == name.toLowerCase(),
    );
    final canSave = valid && !taken;
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.bottlesName,
            errorText: name.isEmpty
                ? null
                : !valid
                ? l10n.bottlesNameInvalid
                : taken
                ? l10n.bottlesNameTaken
                : null,
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
          child: Text(widget.action),
        ),
      ],
    );
  }
}
