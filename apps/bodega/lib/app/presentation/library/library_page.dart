import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/presentation/library/widgets/bottle_tag.dart';
import 'package:bodega/app/shared/graphics_of.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/app_menu.dart';
import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/stop_bottle.dart';
import 'package:bodega/app/shared/widgets/view_toggle.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _query = '';
  String? _bottle;

  @override
  void initState() {
    super.initState();
    context.read<LibraryBloc>().add(const LibraryEvent.load());
  }

  /// Opens the menu beside the menu button that [anchor] is.
  Future<void> _menu(BuildContext anchor, LibraryApp app) async {
    final bloc = anchor.read<LibraryBloc>();
    final bottles = getIt<BottleRepository>();
    final action = await showAppMenu(
      anchor,
      inLibrary: app.inLibrary,
      hud: app.hud,
    );
    if (action == null || !anchor.mounted) return;
    // Read now: the menu's awaits below may outlive the item.
    final l10n = anchor.l10n;
    void failed(AppError error) {
      if (anchor.mounted) AppToast.error(anchor, error.localized(l10n));
    }

    switch (action) {
      case AppMenuAction.open:
        bloc.add(LibraryEvent.open(app.bottle, app.key));
      case AppMenuAction.options:
        // The graphics layers installed are a bottle's, not the library's.
        (await bottles.detail(app.bottle)).match(failed, (detail) {
          if (!anchor.mounted) return;
          showRunOptions(
            anchor,
            bottle: app.bottle,
            backends: detail.installedBackends,
            program: app.exe,
            args: app.args,
            title: app.title,
          );
        });
      case AppMenuAction.hud:
        bloc.add(LibraryEvent.setHud(app.bottle, app.key, !app.hud));
      case AppMenuAction.library:
        bloc.add(
          LibraryEvent.setInLibrary(app.bottle, app.key, !app.inLibrary),
        );
      case AppMenuAction.hide:
        final hidden = await bottles.hideApp(app.bottle, app.key);
        hidden.match(failed, (_) => bloc.add(const LibraryEvent.load()));
    }
  }

  Widget _item(
    BuildContext context,
    LibraryState state,
    LibraryApp app, {
    required bool first,
    required bool asRow,
  }) {
    final running = state.open.contains(app.bottle);
    // The hints are of the bottle: they show on its first application.
    final hints = first
        ? state.hints[app.bottle] ?? const <RunHint>[]
        : const <RunHint>[];
    final tag = BottleTag(bottle: app.bottle, hints: hints);
    final bloc = context.read<LibraryBloc>();

    return Builder(
      builder: (anchor) {
        void play() => bloc.add(LibraryEvent.open(app.bottle, app.key));
        void stop() => confirmStopBottle(anchor, app.bottle);
        void menu(BuildContext button) => _menu(button, app);
        final found = graphicsOf(anchor, app.bottle, app.exe);
        final graphics = found == null
            ? null
            : graphicsLabelText(anchor.l10n, found);

        return asRow
            ? AppRow(
                app: app,
                running: running,
                footerChip: tag,
                graphics: graphics,
                onPlay: play,
                onStop: stop,
                onMenu: menu,
              )
            : AppCard(
                app: app,
                running: running,
                footerChip: tag,
                graphics: graphics,
                onPlay: play,
                onStop: stop,
                onMenu: menu,
              );
      },
    );
  }

  Widget _columnHeader(BuildContext context) {
    final style = AppTextStyle(context).caption;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(l10n.libraryColumnApp, style: style)),
          SizedBox(
            width: 140,
            child: Text(l10n.libraryColumnBottle, style: style),
          ),
          SizedBox(
            width: 120,
            child: Text(l10n.libraryColumnStatus, style: style),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    List<LibraryApp> apps,
    List<LibraryApp> visible,
  ) {
    final bottles = apps.map((app) => app.bottle).toSet().toList()..sort();
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final shownBottles = visible.map((app) => app.bottle).toSet().length;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.navLibrary, style: styles.screenTitle),
            Text(
              l10n.libraryCount(visible.length, shownBottles),
              style: styles.bodySecondary,
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                onChanged: (query) => setState(() => _query = query),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.librarySearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            PopupMenuButton<String?>(
              tooltip: l10n.libraryFilterBottle,
              initialValue: _bottle,
              onSelected: (bottle) => setState(() => _bottle = bottle),
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Text(l10n.libraryAllBottles),
                ),
                for (final bottle in bottles)
                  PopupMenuItem<String?>(value: bottle, child: Text(bottle)),
              ],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.smBorder,
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          _bottle ?? l10n.libraryAllBottles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.bodySecondary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
            ),
            BlocBuilder<ViewModeBloc, ViewModeState>(
              builder: (context, mode) => ViewToggle(
                isGrid: mode.isGrid,
                onChanged: (isGrid) =>
                    context.read<ViewModeBloc>().add(ViewModeEvent.set(isGrid)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          final apps = state.libraryApps;
          if (apps.isEmpty) {
            return EmptyState(
              icon: Icons.apps_rounded,
              title: l10n.libraryEmptyTitle,
              message: l10n.libraryEmptyMessage,
              actionLabel: l10n.navNewBottle,
              actionIcon: Icons.add_rounded,
              onAction: () => showNewBottleDialog(context),
            );
          }

          final bottle = apps.any((app) => app.bottle == _bottle)
              ? _bottle
              : null;
          final query = _query.trim().toLowerCase();
          final visible = [
            for (final app in apps)
              if ((bottle == null || app.bottle == bottle) &&
                  app.title.toLowerCase().contains(query))
                app,
          ];
          // The first shown application of each bottle carries its hints.
          final firstOf = <String, LibraryApp>{};
          for (final app in visible) {
            firstOf.putIfAbsent(app.bottle, () => app);
          }
          final wide = ResponsiveBreakpoints.of(context)
              .largerOrEqualTo(DESKTOP);
          final isGrid = context.select(
            (ViewModeBloc bloc) => bloc.state.isGrid,
          );

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, apps, visible),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: l10n.libraryNoResultsTitle,
                          message: l10n.libraryNoResultsMessage,
                        )
                      : isGrid
                      ? GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: AppCard.extent(context),
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                              ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final app = visible[index];
                            return _item(
                              context,
                              state,
                              app,
                              first: identical(firstOf[app.bottle], app),
                              asRow: false,
                            );
                          },
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (wide) ...[
                              _columnHeader(context),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            Expanded(
                              child: ListView.separated(
                                itemCount: visible.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final app = visible[index];
                                  return _item(
                                    context,
                                    state,
                                    app,
                                    first: identical(firstOf[app.bottle], app),
                                    asRow: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
