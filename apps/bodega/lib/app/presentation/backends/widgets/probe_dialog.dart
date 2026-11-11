import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Asks which bottle runs the check, warning that it closes what is open in it.
/// The bottle's name, or null if it was cancelled.
Future<String?> chooseProbeBottle(
  BuildContext context,
  String backend,
  List<String> bottles,
) => showDialog<String>(
  context: context,
  builder: (_) => ProbeDialog(backend: backend, bottles: bottles),
);

class ProbeDialog extends StatefulWidget {
  final String backend;
  final List<String> bottles;

  const ProbeDialog({super.key, required this.backend, required this.bottles});

  @override
  State<ProbeDialog> createState() => _ProbeDialogState();
}

class _ProbeDialogState extends State<ProbeDialog> {
  late String? _bottle = widget.bottles.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottle = _bottle;
    return AlertDialog(
      title: Text(l10n.probeTitle(widget.backend)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.bottles.isEmpty)
            Text(l10n.probeNoBottle)
          else ...[
            // It names the bottle chosen below, and follows the choice.
            if (bottle != null) Text(l10n.bottleStopConfirm(bottle)),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: bottle,
              decoration: InputDecoration(labelText: l10n.commonBottle),
              items: [
                for (final name in widget.bottles)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: (chosen) => setState(() => _bottle = chosen),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: bottle == null
              ? null
              : () => Navigator.of(context).pop(bottle),
          child: Text(l10n.backendCheck),
        ),
      ],
    );
  }
}
