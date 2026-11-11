import 'package:bodega/app/shared/text/problem_text.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// U5: the name chosen, '' for the host's, or null if it was cancelled.
Future<String?> showWindowsUserDialog(
  BuildContext context, {
  required String current,
  required String macUser,
  required UserNameProblem? Function(String user) problem,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      WindowsUserDialog(current: current, macUser: macUser, problem: problem),
);

class WindowsUserDialog extends StatefulWidget {
  /// The bottle's own name, or '' when it uses [macUser].
  final String current;
  final String macUser;

  /// Why a name cannot be used (U3), or null.
  final UserNameProblem? Function(String user) problem;

  const WindowsUserDialog({
    super.key,
    required this.current,
    required this.macUser,
    required this.problem,
  });

  @override
  State<WindowsUserDialog> createState() => _WindowsUserDialogState();
}

class _WindowsUserDialogState extends State<WindowsUserDialog> {
  late final _shown = widget.current.isEmpty ? widget.macUser : widget.current;
  late final _name = TextEditingController(text: _shown);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final name = _name.text.trim();
    final why = name.isEmpty ? null : widget.problem(name);
    final canSave = name.isNotEmpty && why == null && name != _shown;

    return AlertDialog(
      title: Text(l10n.bottleWindowsUser),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.windowsUserHelp(l10n.bottleChangeCloses),
              style: styles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.commonName,
                errorText: why == null ? null : userNameProblemText(l10n, why),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: canSave
                  ? (_) => Navigator.of(context).pop(name)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.windowsUserUseHost(widget.macUser)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: canSave ? () => Navigator.of(context).pop(name) : null,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
