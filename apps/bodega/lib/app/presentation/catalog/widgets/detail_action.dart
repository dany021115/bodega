import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The detail's main button (P3), with where and from what to install (V12).
class DetailAction extends StatefulWidget {
  final CatalogApp app;

  const DetailAction({super.key, required this.app});

  @override
  State<DetailAction> createState() => _DetailActionState();
}

class _DetailActionState extends State<DetailAction> {
  /// Null is a bottle of its own; null [_setup] downloads the installer.
  String? _bottle;
  String? _setup;

  @override
  void initState() {
    super.initState();
    _bottle = context.read<CatalogBloc>().state.targetBottle;
  }

  Future<void> _pickSetup() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Instaladores',
          extensions: ['exe', 'msi', 'EXE', 'MSI'],
        ),
      ],
    );
    if (file != null) setState(() => _setup = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final styles = AppTextStyle(context);
    final install = context.watch<InstallBloc>().state;
    final ready = [
      for (final bottle in context.watch<BottlesBloc>().state.bottles)
        if (bottle.ready) bottle.name,
    ];
    final bottle = ready.contains(_bottle) ? _bottle : null;

    final installed = app.bottle;
    if (installed != null) {
      return FilledButton(
        onPressed: () {
          context.read<LibraryBloc>().add(
            LibraryEvent.open(installed, app.appKey),
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: bottle,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Botella'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Botella nueva')),
              for (final name in ready)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: install.isRunning
                ? null
                : (value) => setState(() => _bottle = value),
          ),
          if (bottle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Instalar en una botella que ya existe cierra lo que tenga '
              'abierto, y la deja con su backend y su sync.',
              style: styles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _setup == null
                      ? 'Instalador: se descarga'
                      : 'Instalador: ${_setup!.split('/').last}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body,
                ),
              ),
              if (_setup != null)
                TextButton(
                  onPressed: () => setState(() => _setup = null),
                  child: const Text('Descargar'),
                ),
              OutlinedButton(
                onPressed: install.isRunning ? null : _pickSetup,
                child: const Text('Elegir archivo…'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: install.isRunning
                  ? null
                  : () => context.read<InstallBloc>().add(
                      InstallEvent.start(app, bottle: bottle, setup: _setup),
                    ),
              child: const Text('Instalar'),
            ),
          ),
          if (install.isRunning) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hay otra instalación en marcha: ${install.app?.title}.',
              style: styles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
