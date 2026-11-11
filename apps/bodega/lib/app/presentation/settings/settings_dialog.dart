import 'package:bodega/app/bloc/locale/locale_bloc.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// L4: the app's settings, opened from the sidebar.
Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const SettingsDialog());

/// The language only: a choice applies at once and is kept (L5). There is no
/// theme switch: the light theme is not offered yet.
class SettingsDialog extends StatelessWidget {
  /// The two languages by their own names, not ARB keys: each can be read
  /// whatever language is active.
  static const english = 'English';
  static const spanish = 'Español';

  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final code = context.select((LocaleBloc bloc) => bloc.state.code);

    return AlertDialog(
      title: Text(l10n.navSettings),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.settingsLanguage, style: styles.subsectionTitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            // null is System: the system's ordered list decides.
            RadioGroup<String?>(
              groupValue: code,
              onChanged: (code) =>
                  context.read<LocaleBloc>().add(LocaleEvent.set(code)),
              child: Column(
                children: [
                  for (final (value, name) in [
                    (null, l10n.settingsLanguageSystem),
                    ('en', english),
                    ('es', spanish),
                  ])
                    RadioListTile<String?>(
                      value: value,
                      title: Text(name),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
