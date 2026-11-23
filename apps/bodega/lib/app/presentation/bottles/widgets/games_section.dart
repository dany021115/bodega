import 'package:bodega/app/bloc/app_games/app_games_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/report_dialog.dart';
import 'package:bodega/app/presentation/games/widgets/anti_cheat_banner.dart';
import 'package:bodega/app/presentation/games/widgets/game_changes.dart';
import 'package:bodega/app/presentation/games/widgets/game_chips.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// What each app of the bottle gets when it starts (A4): its game's
/// configuration with its switch, or what auto reads in its exe; its page,
/// and its report. It reads the bottle again when [settings] change, since
/// they decide the backend.
class GamesSection extends StatefulWidget {
  final String bottle;

  /// The bottle's settings as the page has them; any value that changes
  /// with them will do.
  final Object? settings;

  const GamesSection({super.key, required this.bottle, this.settings});

  @override
  State<GamesSection> createState() => _GamesSectionState();
}

class _GamesSectionState extends State<GamesSection> {
  void _load() =>
      context.read<AppGamesBloc>().add(AppGamesEvent.load(widget.bottle));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GamesSection old) {
    super.didUpdateWidget(old);
    if (old.bottle != widget.bottle || old.settings != widget.settings) {
      _load();
    }
  }

  Future<void> _report(AppGame game) async {
    final bloc = context.read<AppGamesBloc>();
    final report = await showReportDialog(
      context,
      game.config?.title ?? game.title,
    );
    if (report != null) {
      bloc.add(AppGamesEvent.report(game, report.verdict, report.note));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);

    return BlocListener<AppGamesBloc, AppGamesState>(
      listenWhen: (before, now) => before.reportId != now.reportId,
      listener: (context, state) {
        if (state.report case final url?) launchUrl(url);
      },
      child: BlocBuilder<AppGamesBloc, AppGamesState>(
        builder: (context, state) => CollapsibleSection(
          id: 'games',
          title: l10n.gamesSectionTitle,
          children: [
            Text(l10n.gamesSectionIntro, style: styles.bodySecondary),
            const SizedBox(height: AppSpacing.sm),
            if (state.error case final error?) ...[
              SelectableText(
                error.localized(l10n),
                style: styles.body?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              CopyDetailsButton(error: error),
            ],
            if (!state.isLoading && state.apps.isEmpty)
              Text(l10n.gamesNoApps, style: styles.bodySecondary),
            for (final game in state.apps)
              _GameRow(game: game, onReport: () => _report(game)),
          ],
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  final AppGame game;
  final VoidCallback onReport;

  const _GameRow({required this.game, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final config = game.config;
    final graphics = game.graphics;
    final backend = l10n.gamesBackendFrom(
      game.backend,
      l10n.originOf(game.origin),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(game.title, style: styles.cardTitle),
          Text(
            config == null
                ? l10n.gamesAutomatic
                : l10n.matchOf(game.by!, config.title),
            style: styles.bodySecondary,
          ),
          if (config != null) ...[
            const SizedBox(height: AppSpacing.xs),
            GameChips(game: config),
            if (config.antiCheatVerdict case final verdict?) ...[
              const SizedBox(height: AppSpacing.sm),
              AntiCheatBanner(verdict: verdict, names: config.antiCheat),
            ],
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            graphics == null
                ? backend
                : '$backend · ${graphicsLabelText(l10n, graphics)}',
            style: styles.body,
          ),
          if (game.steps.isNotEmpty || game.requires.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            GameChanges(steps: game.steps, requires: game.requires),
          ],
          if (config != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gamesUseConfig, style: styles.body),
              value: game.on,
              onChanged: (on) => context.read<AppGamesBloc>().add(
                AppGamesEvent.setOn(game.key, on),
              ),
            ),
          if (game.verdict case final verdict?)
            Text(
              l10n.gamesYouSaid(l10n.verdictOf(verdict)),
              style: styles.bodySecondary,
            ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              if (config != null)
                TextButton(
                  onPressed: () => RouterManager.go(
                    AppRoute.gameDetail,
                    params: {'id': config.id},
                    context: context,
                  ),
                  child: Text(l10n.gamesOpenPage),
                ),
              TextButton(onPressed: onReport, child: Text(l10n.gamesReport)),
            ],
          ),
        ],
      ),
    );
  }
}
