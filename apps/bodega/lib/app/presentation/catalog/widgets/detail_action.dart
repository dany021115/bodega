import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The detail's main button (P3).
class DetailAction extends StatelessWidget {
  final CatalogApp app;

  const DetailAction({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final install = context.watch<InstallBloc>().state;

    final bottle = app.bottle;
    if (bottle != null) {
      return FilledButton(
        onPressed: () {
          context.read<LibraryBloc>().add(
            LibraryEvent.open(bottle, app.appKey),
          );
          RouterManager.go(AppRoute.library, context: context);
        },
        child: const Text('Abrir'),
      );
    }

    if (app.status == CatalogStatus.blocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FilledButton(onPressed: null, child: Text('Instalar')),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No se puede instalar: está bloqueada, por lo que dice arriba.',
            style: styles.caption,
          ),
        ],
      );
    }

    if (!app.backendInstalled) {
      return FilledButton(
        onPressed: () => RouterManager.go(AppRoute.backends, context: context),
        child: Text('Instalar ${app.backend}'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton(
          onPressed: install.isRunning
              ? null
              : () => context.read<InstallBloc>().add(InstallEvent.start(app)),
          child: const Text('Instalar'),
        ),
        if (install.isRunning) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hay otra instalación en marcha: ${install.app?.title}.',
            style: styles.caption,
          ),
        ],
      ],
    );
  }
}
