import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/presentation/switch/widgets/add_games_button.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_game_menu.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_status_panel.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Switch games (switch-support design §9): the games in the center and the
/// status panel at their right, or below them when the page is narrower than
/// [wideFrom], as on a bottle's page. It reads the app-wide SwitchBloc, which
/// outlives it, and provides none.
class SwitchPage extends StatefulWidget {
  static const double wideFrom = 760;
  static const double panelWidth = 380;

  /// The status panel's box.
  static const panelKey = Key('switchStatusPanel');

  const SwitchPage({super.key});

  @override
  State<SwitchPage> createState() => _SwitchPageState();
}

class _SwitchPageState extends State<SwitchPage> {
  @override
  void initState() {
    super.initState();
    context.read<SwitchBloc>().add(const SwitchEvent.load());
  }

  /// Asks first: stopping a game closes it, and what it has not saved is
  /// lost.
  Future<void> _stop(BuildContext context, SwitchGame game) async {
    final bloc = context.read<SwitchBloc>();
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      title: l10n.switchStopTitle(game.title),
      message: l10n.switchStopConfirm(game.title),
      action: l10n.commonStop,
    );
    if (confirmed) bloc.add(SwitchEvent.stop(game.path));
  }

  /// Opens the menu beside the menu button that [anchor] is.
  Future<void> _menu(
    BuildContext anchor,
    SwitchGame game, {
    required bool running,
  }) async {
    final bloc = anchor.read<SwitchBloc>();
    final action = await showSwitchGameMenu(anchor, running: running);
    switch (action) {
      case SwitchGameAction.open:
        bloc.add(SwitchEvent.open(game.path));
      case SwitchGameAction.remove:
        bloc.add(SwitchEvent.remove(game.path));
      case null:
        return;
    }
  }

  /// A game's card. It plays whatever the panel says: the engine checks what
  /// a launch needs, the emulator for a game file and nothing for a native
  /// game (design §3, §5).
  Widget _card(BuildContext context, SwitchState state, SwitchGame game) {
    final bloc = context.read<SwitchBloc>();
    final running = state.running.containsKey(game.path);

    return AppCard.item(
      key: ValueKey(game.path),
      // A cover pair per game: by its id, or by its path when it has none.
      id: game.titleId ?? game.path,
      title: game.title,
      running: running,
      footerChip: game.native
          ? StatusChip(
              label: context.l10n.switchNative,
              color: AppColor.statusReported,
            )
          : null,
      onPlay: () => bloc.add(SwitchEvent.open(game.path)),
      onStop: () => _stop(context, game),
      onMenu: (button) => _menu(button, game, running: running),
    );
  }

  /// The title and Add games, and under them the games, or the empty state
  /// while there are none.
  Widget _center(BuildContext context, SwitchState state) {
    final l10n = context.l10n;
    // One add at a time, and only once the status gives the extensions.
    final extensions = state.isAdding ? null : state.status?.extensions;
    final header = Row(
      children: [
        Expanded(
          child: Text(l10n.navSwitch, style: AppTextStyle(context).screenTitle),
        ),
        const SizedBox(width: AppSpacing.md),
        AddGamesButton(extensions: extensions),
      ],
    );
    final games = state.games.isEmpty
        ? EmptyState(
            icon: Icons.videogame_asset_rounded,
            title: l10n.switchEmptyTitle,
            message: l10n.switchEmptyMessage,
            action: AddGamesButton(extensions: extensions),
          )
        // The same cells as the library's grid, so the cards are the same.
        : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: AppCard.extent(context),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemCount: state.games.length,
            itemBuilder: (context, index) =>
                _card(context, state, state.games[index]),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.xl),
        games,
      ],
    );
  }

  Widget _panel(BuildContext context, Widget child, {required bool wide}) {
    final colors = Theme.of(context).colorScheme;

    if (wide) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border(left: BorderSide(color: colors.outlineVariant)),
        ),
        // ListTile paints on the nearest Material: this one sits above the
        // colored box, so the switch's ink isn't hidden by it.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: AppRadius.lgBorder,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<SwitchBloc, SwitchState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          final panel = SwitchStatusPanel(
            status: state.status,
            quarantined: [
              for (final game in state.games)
                if (game.native && game.quarantined) game.title,
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < SwitchPage.wideFrom) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: _center(context, state),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: KeyedSubtree(
                        key: SwitchPage.panelKey,
                        child: _panel(context, panel, wide: false),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: _center(context, state),
                    ),
                  ),
                  SizedBox(
                    key: SwitchPage.panelKey,
                    width: SwitchPage.panelWidth,
                    child: _panel(context, panel, wide: true),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
