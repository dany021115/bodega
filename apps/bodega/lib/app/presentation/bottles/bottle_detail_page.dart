import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_logs_card.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_settings_card.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:file_selector/file_selector.dart';
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

class BottleDetailView extends StatelessWidget {
  final String name;

  const BottleDetailView({super.key, required this.name});

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final confirmed = await confirm(
      context,
      title: 'Borrar la botella $name',
      message:
          'Se cerrará lo que tenga abierto y se borrará su carpeta, con todo '
          'lo que hayas instalado dentro. No se puede deshacer.',
      action: 'Borrar',
    );
    if (confirmed) bloc.add(const BottleDetailEvent.delete());
  }

  Future<void> _stop(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    final confirmed = await confirm(
      context,
      title: 'Parar la botella $name',
      message:
          'Se cerrará todo lo que esté abierto en ella. Lo que no hayas '
          'guardado se perderá.',
      action: 'Parar',
    );
    if (confirmed) bloc.add(LibraryEvent.stop(name));
  }

  Future<void> _run(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    const programs = XTypeGroup(label: 'Programas', extensions: ['exe']);
    final file = await openFile(acceptedTypeGroups: const [programs]);
    if (file != null) bloc.add(LibraryEvent.run(name, file.path));
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final isOpen = context.select(
      (LibraryBloc bloc) => bloc.state.open.contains(name),
    );

    return Scaffold(
      body: BlocConsumer<BottleDetailBloc, BottleDetailState>(
        listener: (context, state) {
          if (state.deleted) {
            RouterManager.go(AppRoute.bottles, context: context);
          } else if (state.error case final error?) {
            AppToast.error(context, error.message);
          }
        },
        listenWhen: (previous, current) =>
            previous.deleted != current.deleted ||
            (current.error != null && previous.error != current.error),
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          final detail = state.detail;
          if (detail == null) {
            return EmptyState(
              icon: Icons.wine_bar_rounded,
              title: 'No se pudo abrir la botella',
              message: state.error?.message ?? name,
              actionLabel: 'Volver a Botellas',
              onAction: () =>
                  RouterManager.go(AppRoute.bottles, context: context),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      RouterManager.go(AppRoute.bottles, context: context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Botellas'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(name, style: styles.screenTitle),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    onPressed: state.isBusy ? null : () => _run(context),
                    child: const Text('Ejecutar un programa'),
                  ),
                  if (isOpen)
                    OutlinedButton(
                      onPressed: state.isBusy ? null : () => _stop(context),
                      child: const Text('Parar'),
                    ),
                  TextButton(
                    onPressed: state.isBusy ? null : () => _delete(context),
                    child: const Text('Borrar botella'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              BottleSettingsCard(detail: detail, isBusy: state.isBusy),
              const SizedBox(height: AppSpacing.md),
              BottleLogsCard(state: state),
            ],
          );
        },
      ),
    );
  }
}
