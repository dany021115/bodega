import 'package:bodega/app/bloc/language/language_bloc.dart';
import 'package:bodega/app/bloc/preferences/preferences_bloc.dart';
import 'package:bodega/app/shared/error_text.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<PreferencesBloc>()..add(const PreferencesEvent.load()),
    child: const PreferencesView(),
  );
}

/// The screen without its bloc, which the page provides.
class PreferencesView extends StatelessWidget {
  const PreferencesView({super.key});

  /// Language names go in their own language, never translated.
  static const _languages = {'en': 'English', 'es': 'Español'};

  Future<void> _clear(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<PreferencesBloc>();
    final ok = await confirm(
      context,
      title: l10n.preferencesClearTitle,
      message: l10n.preferencesClearMessage,
      action: l10n.preferencesClear,
    );
    if (ok) bloc.add(const PreferencesEvent.clear());
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final language = context.select((LanguageBloc bloc) => bloc.state.code);
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      body: BlocBuilder<PreferencesBloc, PreferencesState>(
        builder: (context, state) {
          final bytes = state.cacheBytes;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Text(l10n.preferencesTitle, style: styles.screenTitle),
              if (state.error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                SelectableText(
                  error.text(l10n),
                  style: styles.body?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.preferencesDataFolder, style: styles.subsectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(state.dataFolder, style: styles.mono),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: state.dataFolder.isEmpty
                        ? null
                        : () => launchUrl(Uri.directory(state.dataFolder)),
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(
                      isMac
                          ? l10n.preferencesOpenFinder
                          : l10n.preferencesOpenFolder,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.preferencesCache, style: styles.subsectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bytes == null
                          ? '…'
                          : l10n.preferencesCacheSize(
                              (bytes / (1024 * 1024)).toStringAsFixed(1),
                            ),
                      style: styles.body,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: state.isClearing || bytes == null || bytes == 0
                        ? null
                        : () => _clear(context),
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: Text(l10n.preferencesClear),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.preferencesLanguage, style: styles.subsectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<String?>(
                  value: language,
                  onChanged: (code) =>
                      context.read<LanguageBloc>().add(LanguageEvent.set(code)),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.preferencesLanguageSystem),
                    ),
                    for (final MapEntry(:key, :value) in _languages.entries)
                      DropdownMenuItem(value: key, child: Text(value)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
