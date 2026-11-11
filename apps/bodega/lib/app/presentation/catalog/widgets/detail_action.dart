import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/l10n/l10n.dart';
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
    // In the active language, so built here, and before the await.
    final installers = XTypeGroup(
      label: context.l10n.catalogInstallersFileType,
      extensions: const ['exe', 'msi', 'EXE', 'MSI'],
    );
    final file = await openFile(acceptedTypeGroups: [installers]);
    if (file != null) setState(() => _setup = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        child: Text(l10n.commonOpen),
      );
    }

    if (app.status == CatalogStatus.blocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton(onPressed: null, child: Text(l10n.commonInstall)),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.catalogBlockedNote, style: styles.caption),
        ],
      );
    }

    if (!app.backendInstalled) {
      return FilledButton(
        onPressed: () => RouterManager.go(AppRoute.backends, context: context),
        child: Text(l10n.catalogInstallBackend(app.backend)),
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
            decoration: InputDecoration(labelText: l10n.commonBottle),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.catalogNewBottle)),
              for (final name in ready)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: install.isRunning
                ? null
                : (value) => setState(() => _bottle = value),
          ),
          if (bottle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.catalogExistingBottleNote, style: styles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _setup == null
                      ? l10n.catalogInstallerDownloaded
                      : l10n.catalogInstallerFile(_setup!.split('/').last),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.body,
                ),
              ),
              if (_setup != null)
                TextButton(
                  onPressed: () => setState(() => _setup = null),
                  child: Text(l10n.catalogDownloadInstaller),
                ),
              OutlinedButton(
                onPressed: install.isRunning ? null : _pickSetup,
                child: Text(l10n.commonChooseFile),
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
              child: Text(l10n.commonInstall),
            ),
          ),
          if (install.isRunning) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              // A running install always has its app.
              l10n.catalogInstallRunning(install.app?.title ?? ''),
              style: styles.caption,
            ),
          ],
        ],
      ),
    );
  }
}
