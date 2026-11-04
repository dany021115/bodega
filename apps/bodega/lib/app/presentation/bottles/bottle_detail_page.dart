import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/app_tile.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_column.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottleDetailPage extends StatelessWidget {
  final String name;

  const BottleDetailPage({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<BottleDetailBloc>()..add(BottleDetailEvent.load(name)),
      child: BottleDetailView(name: name),
    );
  }
}

/// Applications in the center and a column at the right, which goes below them
/// when there is no room. It depends on the room left by the sidebar, not on
/// the window (design §6).
class BottleDetailView extends StatelessWidget {
  static const double wideFrom = 760;
  static const double columnWidth = 270;

  final String name;

  const BottleDetailView({super.key, required this.name});

  Widget _header(
    BuildContext context,
    BottleDetail detail,
    bool isOpen,
    List<String> hints,
  ) {
    final styles = AppTextStyle(context);
    final (label, color) = !detail.ready
        ? ('Incompleta', AppColor.statusFlaky)
        : isOpen
        ? ('Abierta', AppColor.statusTested)
        : ('Cerrada', AppColor.statusUntested);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.screenTitle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              StatusChip(label: label, color: color),
            ],
          ),
          for (final hint in hints) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(hint, style: styles.bodySecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _apps(BuildContext context, BottleDetail detail, {required bool fit}) {
    if (detail.apps.isEmpty) {
      return EmptyState(
        icon: Icons.apps_rounded,
        title: 'Esta botella no tiene aplicaciones',
        message: 'Instala algo desde el catálogo.',
        actionLabel: 'Instalar',
        actionIcon: Icons.storefront_rounded,
        onAction: () => RouterManager.go(AppRoute.catalog, context: context),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      shrinkWrap: fit,
      physics: fit ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 130,
        mainAxisExtent: 124,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: detail.apps.length,
      itemBuilder: (context, index) {
        final app = detail.apps[index];
        return AppTile(
          key: ValueKey(app.key),
          app: app,
          onOpen: () =>
              context.read<LibraryBloc>().add(LibraryEvent.open(name, app.key)),
          onHide: () {
            context.read<BottleDetailBloc>().add(
              BottleDetailEvent.hideApp(app.key),
            );
            context.read<LibraryBloc>().add(const LibraryEvent.load());
          },
        );
      },
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

    return Scaffold(
      body: BlocConsumer<BottleDetailBloc, BottleDetailState>(
        listenWhen: (previous, current) =>
            previous.deleted != current.deleted ||
            (current.error != null && previous.error != current.error),
        listener: (context, state) {
          if (state.deleted) {
            context.read<BottlesBloc>().add(const BottlesEvent.load());
            context.read<LibraryBloc>().add(const LibraryEvent.load());
            RouterManager.go(AppRoute.library, context: context);
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
              title: 'No se pudo abrir la botella',
              message: state.error?.message ?? name,
              actionLabel: 'Volver a Biblioteca',
              onAction: () =>
                  RouterManager.go(AppRoute.library, context: context),
            );
          }

          final column = BottleColumn(
            detail: detail,
            isBusy: state.isBusy,
            isOpen: isOpen,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < wideFrom) {
                return ListView(
                  children: [
                    _header(context, detail, isOpen, hints),
                    if (detail.apps.isEmpty)
                      SizedBox(
                        height: 280,
                        child: _apps(context, detail, fit: true),
                      )
                    else
                      _apps(context, detail, fit: true),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: column,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context, detail, isOpen, hints),
                        Expanded(child: _apps(context, detail, fit: false)),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: columnWidth,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: column,
                    ),
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
