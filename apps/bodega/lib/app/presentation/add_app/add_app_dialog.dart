import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/add_app/widgets/installer_choice.dart';
import 'package:bodega/app/presentation/add_app/widgets/popular_app_card.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The file picker's filter, in the active language: each handler builds it
/// before its await.
XTypeGroup _programs(AppL10n l10n) =>
    XTypeGroup(label: l10n.commonProgramsFileType, extensions: ['exe', 'EXE']);

Future<void> showAddAppDialog(BuildContext context, {required String bottle}) =>
    showDialog<void>(
      context: context,
      // An installer may be running: only the dialog's own buttons close it.
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => getIt<AddAppBloc>()..add(AddAppEvent.load(bottle)),
        child: const AddAppDialog(),
      ),
    );

enum _Tab { popular, file }

class AddAppDialog extends StatefulWidget {
  const AddAppDialog({super.key});

  @override
  State<AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  final _title = TextEditingController();
  _Tab _tab = _Tab.file;

  @override
  void initState() {
    super.initState();
    // The bottle may be opened before the catalog was ever visited.
    context.read<CatalogBloc>().add(const CatalogEvent.load());
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickExe(BuildContext context) async {
    final bloc = context.read<AddAppBloc>();
    final programs = _programs(context.l10n);
    final file = await openFile(acceptedTypeGroups: [programs]);
    if (file != null) bloc.add(AddAppEvent.exeChosen(file.path));
  }

  Future<void> _pickInstalled(BuildContext context, String? driveC) async {
    final bloc = context.read<AddAppBloc>();
    final programs = _programs(context.l10n);
    final file = await openFile(
      initialDirectory: driveC,
      acceptedTypeGroups: [programs],
    );
    if (file != null) bloc.add(AddAppEvent.installedChosen(file.path));
  }

  void _install(BuildContext context, CatalogApp app) {
    final bottle = context.read<AddAppBloc>().state.bottle;
    context.read<CatalogBloc>().add(CatalogEvent.target(bottle));
    Navigator.of(context).pop();
    RouterManager.go(AppRoute.catalogDetail, params: {'id': app.id});
  }

  void _finish(BuildContext context, AddAppState state) {
    context.read<BottlesBloc>().add(const BottlesEvent.load());
    context.read<LibraryBloc>().add(const LibraryEvent.load());
    final l10n = context.l10n;
    final title = state.title.trim();
    AppToast.success(
      context,
      state.addToLibrary
          ? l10n.addAppAddedToLibrary(title)
          : l10n.addAppAddedToBottle(title),
    );
    // Stays in the bottle: no navigation.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddAppBloc, AddAppState>(
      listener: (context, state) {
        if (state.step == AddAppStep.done) {
          _finish(context, state);
        } else if (_title.text != state.title) {
          _title.text = state.title;
        }
      },
      builder: (context, state) {
        final styles = AppTextStyle(context);
        final busy = state.step == AddAppStep.installing;
        // An installer in progress is shown on its own tab.
        final onFile = state.step != AddAppStep.form || _tab == _Tab.file;

        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, state, styles, busy),
                  const SizedBox(height: AppSpacing.lg),
                  _tabs(context, state, onFile),
                  const SizedBox(height: AppSpacing.lg),
                  // The error scrolls with the body: a long one must not push
                  // the footer out of a small window.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          onFile
                              ? _fileBody(context, state)
                              : _popularBody(context),
                          if (state.error case final error?) ...[
                            const SizedBox(height: AppSpacing.md),
                            SelectableText(
                              error.message,
                              style: styles.body?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _footer(context, state, onFile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(
    BuildContext context,
    AddAppState state,
    AppTextStyle styles,
    bool busy,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.addAppTitle(state.bottle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(context.l10n.addAppSubtitle, style: styles.caption),
          ],
        ),
      ),
      IconButton(
        tooltip: context.l10n.commonClose,
        icon: const Icon(Icons.close_rounded),
        onPressed: busy ? null : () => Navigator.of(context).pop(),
      ),
    ],
  );

  Widget _tabs(BuildContext context, AddAppState state, bool onFile) {
    // Tabs stay put while an installer or its program choice is pending.
    final locked = state.step != AddAppStep.form;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.smBorder,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(
                icon: Icons.file_present_rounded,
                label: context.l10n.addAppTabFile,
                selected: onFile,
                onTap: locked ? null : () => setState(() => _tab = _Tab.file),
              ),
              _Segment(
                icon: Icons.grid_view_rounded,
                label: context.l10n.addAppTabOthers,
                selected: !onFile,
                onTap: locked
                    ? null
                    : () => setState(() => _tab = _Tab.popular),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popularBody(BuildContext context) {
    return BlocBuilder<CatalogBloc, CatalogState>(
      builder: (context, state) {
        if (state.isLoading) return const CustomLoading();
        final apps = state.apps;
        if (apps.isEmpty) {
          return SelectableText(
            state.error?.message ?? context.l10n.addAppCatalogEmpty,
            style: AppTextStyle(context).body,
          );
        }
        return Column(
          children: [
            for (var i = 0; i < apps.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: PopularAppCard(
                          app: apps[i],
                          onInstall: () => _install(context, apps[i]),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: i + 1 < apps.length
                            ? PopularAppCard(
                                app: apps[i + 1],
                                onInstall: () => _install(context, apps[i + 1]),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fileBody(BuildContext context, AddAppState state) {
    final l10n = context.l10n;
    final bloc = context.read<AddAppBloc>();
    final styles = AppTextStyle(context);

    switch (state.step) {
      case AddAppStep.installing:
        return Row(
          children: [
            const CustomLoading(size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.addAppInstallerRunning, style: styles.body),
              ),
            ),
          ],
        );
      case AddAppStep.pickInstalled:
        return Text(l10n.addAppInstallerFinished, style: styles.body);
      case AddAppStep.form || AddAppStep.done:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: InstallerChoice(
                    icon: Icons.download_rounded,
                    title: l10n.addAppIsInstaller,
                    description: l10n.addAppIsInstallerHint,
                    selected: state.isInstaller,
                    onTap: () =>
                        bloc.add(const AddAppEvent.installerToggled(true)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InstallerChoice(
                    icon: Icons.play_circle_outline_rounded,
                    title: l10n.addAppIsProgram,
                    description: l10n.addAppIsProgramHint,
                    selected: !state.isInstaller,
                    onTap: () =>
                        bloc.add(const AddAppEvent.installerToggled(false)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.addAppProgram, style: styles.caption),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.exe?.split('/').last ?? l10n.addAppNoProgram,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: styles.body,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _pickExe(context),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(l10n.addAppChooseExe),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.addAppTitleField),
              onChanged: (title) => bloc.add(AddAppEvent.titleChanged(title)),
            ),
          ],
        );
    }
  }

  Widget _footer(BuildContext context, AddAppState state, bool onFile) {
    final l10n = context.l10n;
    final bloc = context.read<AddAppBloc>();
    final styles = AppTextStyle(context);
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l10n.commonCancel),
    );

    final actions = switch (state.step) {
      AddAppStep.installing => [
        TextButton(
          onPressed: () => bloc.add(const AddAppEvent.installerDone()),
          child: Text(l10n.addAppInstallerDone),
        ),
      ],
      AddAppStep.pickInstalled => [
        cancel,
        GradientButton(
          label: l10n.addAppChooseProgram,
          onPressed: () => _pickInstalled(context, state.driveC),
        ),
      ],
      AddAppStep.form => [
        cancel,
        if (onFile)
          GradientButton(
            label: l10n.addAppAdd,
            onPressed: state.canSubmit
                ? () => bloc.add(const AddAppEvent.submit())
                : null,
          ),
      ],
      AddAppStep.done => const <Widget>[],
    };

    // A Wrap, so the buttons go under the switch when there is no room.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpacing.sm,
      children: [
        SizedBox(
          width: 320,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.libraryAdd, style: styles.body),
            subtitle: Text(l10n.addAppLibraryHint, style: styles.caption),
            value: state.addToLibrary,
            onChanged: (value) =>
                bloc.add(AddAppEvent.addToLibraryToggled(value)),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, action) in actions.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ],
    );
  }
}

/// One half of the tab control; the selected one is in the brand gradient.
class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.smBorder,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? AppGradient.brand : null,
            borderRadius: AppRadius.smBorder,
          ),
          child: InkWell(
            borderRadius: AppRadius.smBorder,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTextStyle(context).body?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
