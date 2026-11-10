import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/view_mode/view_mode_bloc.dart';
import 'package:bodega/app/presentation/add_app/add_app_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_empty_apps.dart';
import 'package:bodega/app/presentation/bottles/widgets/library_toggle.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/graphics_of.dart';
import 'package:bodega/app/shared/widgets/app_card.dart';
import 'package:bodega/app/shared/widgets/app_menu.dart';
import 'package:bodega/app/shared/widgets/app_row.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/app/shared/widgets/stop_bottle.dart';
import 'package:bodega/app/shared/widgets/view_toggle.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottleDetailPage extends StatelessWidget {
  final String name;

  const BottleDetailPage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // One bloc per bottle, even if the page is reused for another one.
      key: ValueKey(name),
      providers: [
        BlocProvider(
          create: (_) =>
              getIt<BottleDetailBloc>()..add(BottleDetailEvent.load(name)),
        ),
        BlocProvider(
          create: (_) => getIt<GamepadsBloc>()..add(const GamepadsEvent.load()),
        ),
      ],
      child: BottleDetailView(name: name),
    );
  }
}

/// The applications in the center and the bottle's panel at the right. Below
/// [wideFrom] the panel goes under the applications (design §6).
class BottleDetailView extends StatelessWidget {
  static const double wideFrom = 760;
  static const double panelWidth = 380;

  final String name;

  const BottleDetailView({super.key, required this.name});

  void _setInLibrary(BuildContext context, LibraryApp app) {
    context.read<BottleDetailBloc>().add(
      BottleDetailEvent.setInLibrary(app.key, !app.inLibrary),
    );
    context.read<LibraryBloc>().add(const LibraryEvent.load());
  }

  /// Opens the menu beside the menu button that [anchor] is.
  Future<void> _menu(
    BuildContext anchor,
    BottleDetail detail,
    LibraryApp app,
  ) async {
    final action = await showAppMenu(
      anchor,
      inLibrary: app.inLibrary,
      hud: app.hud,
    );
    if (action == null || !anchor.mounted) return;

    switch (action) {
      case AppMenuAction.open:
        anchor.read<LibraryBloc>().add(LibraryEvent.open(detail.name, app.key));
      case AppMenuAction.options:
        showRunOptions(
          anchor,
          bottle: detail.name,
          backends: detail.installedBackends,
          program: app.exe,
          args: app.args,
          title: app.title,
        );
      case AppMenuAction.hud:
        anchor.read<BottleDetailBloc>().add(
          BottleDetailEvent.setHud(app.key, !app.hud),
        );
      case AppMenuAction.library:
        _setInLibrary(anchor, app);
      case AppMenuAction.hide:
        anchor.read<BottleDetailBloc>().add(BottleDetailEvent.hideApp(app.key));
        anchor.read<LibraryBloc>().add(const LibraryEvent.load());
    }
  }

  Widget _app(
    BuildContext context,
    BottleDetail detail,
    LibraryApp app, {
    required bool isGrid,
    required bool running,
  }) {
    void open() => context.read<LibraryBloc>().add(
      LibraryEvent.open(detail.name, app.key),
    );
    final toggle = LibraryToggle(
      inLibrary: app.inLibrary,
      onPressed: () => _setInLibrary(context, app),
    );

    // The builder gives the card or row its own context, to place its menu.
    return Builder(
      builder: (itemContext) {
        void menu(BuildContext button) => _menu(button, detail, app);
        void stop() => confirmStopBottle(itemContext, detail.name);
        final graphics = graphicsOf(itemContext, detail.name, app.exe)?.label;
        return isGrid
            ? AppCard(
                key: ValueKey(app.key),
                app: app,
                running: running,
                onStop: stop,
                onPlay: open,
                footerChip: toggle,
                graphics: graphics,
                onMenu: menu,
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppRow(
                  key: ValueKey(app.key),
                  app: app,
                  running: running,
                  onStop: stop,
                  onPlay: open,
                  footerChip: toggle,
                  graphics: graphics,
                  onMenu: menu,
                ),
              );
      },
    );
  }

  Widget _center(
    BuildContext context,
    BottleDetail detail, {
    required bool isBusy,
  }) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final isGrid = context.select((ViewModeBloc bloc) => bloc.state.isGrid);
    final running = context.select(
      (LibraryBloc bloc) => bloc.state.open.contains(detail.name),
    );
    final inLibrary = detail.apps.where((app) => app.inLibrary).length;
    final canAdd = detail.ready && !isBusy;
    void add() => showAddAppDialog(context, bottle: detail.name);

    final apps = detail.apps.isEmpty
        ? BottleEmptyApps(onAdd: canAdd ? add : null)
        : isGrid
        // The same cells as the library's grid, so the cards are the same.
        ? GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: AppCard.extent(context),
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
            ),
            itemCount: detail.apps.length,
            itemBuilder: (context, index) => _app(
              context,
              detail,
              detail.apps[index],
              isGrid: true,
              running: running,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final app in detail.apps)
                _app(context, detail, app, isGrid: false, running: running),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.bottleDetailTitle, style: styles.screenTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.bottleDetailSummary(
                      l10n.bottleAppCount(detail.apps.length),
                      detail.name,
                      inLibrary,
                    ),
                    style: styles.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ViewToggle(
              isGrid: isGrid,
              onChanged: (value) =>
                  context.read<ViewModeBloc>().add(ViewModeEvent.set(value)),
            ),
            const SizedBox(width: AppSpacing.md),
            GradientButton(
              label: l10n.bottleDetailAddApp,
              icon: Icons.add_rounded,
              onPressed: canAdd ? add : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        apps,
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
        // colored box, so the tiles' ink isn't hidden by it.
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: child,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: DecoratedBox(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = context.select(
      (LibraryBloc bloc) => bloc.state.open.contains(name),
    );
    final hints = context.select(
      (LibraryBloc bloc) => bloc.state.hints[name] ?? const <String>[],
    );

    // Whatever changes the apps (an install, the add-app dialog, a program that
    // makes a shortcut) goes through LibraryBloc: this page follows it.
    return BlocListener<LibraryBloc, LibraryState>(
      listenWhen: (previous, current) => previous.apps != current.apps,
      listener: (context, _) =>
          context.read<BottleDetailBloc>().add(BottleDetailEvent.load(name)),
      child: Scaffold(
        body: BlocConsumer<BottleDetailBloc, BottleDetailState>(
          listenWhen: (previous, current) =>
              previous.deleted != current.deleted ||
              previous.renamedTo != current.renamedTo ||
              (current.error != null && previous.error != current.error),
          listener: (context, state) {
            if (state.deleted) {
              context.read<BottlesBloc>().add(const BottlesEvent.load());
              context.read<LibraryBloc>().add(const LibraryEvent.load());
              RouterManager.go(AppRoute.library, context: context);
            } else if (state.renamedTo case final newName?) {
              context.read<BottlesBloc>().add(const BottlesEvent.load());
              context.read<LibraryBloc>().add(const LibraryEvent.load());
              RouterManager.go(
                AppRoute.bottleDetail,
                params: {'name': newName},
                context: context,
              );
            } else if (state.error case final error?) {
              AppToast.error(context, error.message);
            }
          },
          builder: (context, state) {
            if (state.isLoading) return const CustomLoading();
            final detail = state.detail;
            if (detail == null) {
              return EmptyState(
                icon: Icons.wine_bar_rounded,
                title: context.l10n.bottleDetailOpenFailed,
                message: state.error?.message ?? name,
                actionLabel: context.l10n.navBackToLibrary,
                onAction: () =>
                    RouterManager.go(AppRoute.library, context: context),
              );
            }

            final column = BottleColumn(
              detail: detail,
              isBusy: state.isBusy,
              isOpen: isOpen,
              hints: hints,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < wideFrom) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: _center(context, detail, isBusy: state.isBusy),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _panel(context, column, wide: false),
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
                        child: _center(context, detail, isBusy: state.isBusy),
                      ),
                    ),
                    SizedBox(
                      width: panelWidth,
                      child: _panel(context, column, wide: true),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
