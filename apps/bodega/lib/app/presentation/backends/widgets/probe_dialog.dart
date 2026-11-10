import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/device/theme/spacing.dart';
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
    return AlertDialog(
      title: Text(l10n.backendsCheckTitle(widget.backend)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.bottles.isEmpty)
            Text(l10n.backendsProbeNoBottle)
          else ...[
            Text(l10n.backendsProbeWarning),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: _bottle,
              decoration: InputDecoration(labelText: l10n.backendsBottle),
              items: [
                for (final bottle in widget.bottles)
                  DropdownMenuItem(value: bottle, child: Text(bottle)),
              ],
              onChanged: (bottle) => setState(() => _bottle = bottle),
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
          onPressed: _bottle == null
              ? null
              : () => Navigator.of(context).pop(_bottle),
          child: Text(l10n.backendsCheck),
        ),
      ],
    );
  }
}
