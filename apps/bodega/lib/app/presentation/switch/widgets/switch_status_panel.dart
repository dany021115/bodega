import 'package:bodega/app/bloc/switch/switch_bloc.dart';
import 'package:bodega/app/presentation/switch/widgets/install_firmware_button.dart';
import 'package:bodega/app/presentation/switch/widgets/switch_file_types.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a Switch game file needs to open, as Bodega finds it: the emulator,
/// and the keys and firmware the user brings from their own console
/// (switch-support design §9). A native game needs none of them, so the rows
/// say nothing of it, but one in quarantine gets the note the emulator gets.
/// The panel tells what it found and offers the next step: while the
/// emulator is missing, a button that opens its official download page in
/// the browser, as D3DMetal's section opens Apple's; while the keys are, a
/// picker whose files Bodega copies where the emulator reads them; and while
/// the firmware is, a picker whose pick the emulator's own installer takes.
/// Bodega never downloads any of them.
class SwitchStatusPanel extends StatelessWidget {
  /// Where the picker for the emulator's app opens.
  static const applications = '/Applications';

  /// Null until a read of it succeeds: then the panel offers only Check
  /// again, and the notes of [quarantined].
  final SwitchStatus? status;

  /// The titles of the listed native games that macOS keeps in quarantine.
  final List<String> quarantined;

  const SwitchStatusPanel({
    super.key,
    required this.status,
    this.quarantined = const [],
  });

  Future<void> _chooseEmulator(BuildContext context) async {
    final bloc = context.read<SwitchBloc>();
    final apps = emulatorAppTypes();
    final app = await openFile(
      acceptedTypeGroups: [apps],
      initialDirectory: applications,
    );
    if (app != null) bloc.add(SwitchEvent.chooseEmulator(app.path));
  }

  Future<void> _addKeys(BuildContext context) async {
    final bloc = context.read<SwitchBloc>();
    final keys = keysFileTypes();
    final files = await openFiles(acceptedTypeGroups: [keys]);
    if (files.isNotEmpty) {
      bloc.add(SwitchEvent.installKeys([for (final file in files) file.path]));
    }
  }

  /// The emulator, its keys and its firmware: green when found, amber when
  /// missing.
  List<Widget> _rows(AppL10n l10n, SwitchStatus status) {
    final name = status.emulator;
    final install = status.install;
    Widget row(String label, {required bool found}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: StatusChip(
        label: label,
        color: found ? AppColor.statusTested : AppColor.statusFlaky,
      ),
    );

    return [
      row(switch (install) {
        null => l10n.switchEmulatorMissing(name),
        EmulatorInstall(:final app, version: null) =>
          l10n.switchEmulatorFoundNoVersion(name, app),
        EmulatorInstall(:final app, :final version?) =>
          l10n.switchEmulatorFound(name, version, app),
      }, found: install != null),
      row(
        l10n.switchKeys(name, status.keys ? 'found' : 'missing'),
        found: status.keys,
      ),
      row(
        l10n.switchFirmware(name, status.firmware ? 'found' : 'missing'),
        found: status.firmware,
      ),
    ];
  }

  /// What to do if the app called [name] is kept from starting.
  Widget _note(BuildContext context, String name) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColor.statusFlaky,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.l10n.switchQuarantineNote(name),
            style: AppTextStyle(context).bodySecondary,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<SwitchBloc>();
    final status = this.status;
    // The status while no emulator is found, when the panel offers its page.
    final missing = status?.install == null ? status : null;
    // What the user brings, one step at a time: the keys, then the firmware,
    // which the emulator installs only with them.
    final noKeys = status != null && !status.keys;
    final noFirmware =
        status != null &&
        status.keys &&
        status.install != null &&
        !status.firmware;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status != null) ...[
          ..._rows(l10n, status),
          if (status.install?.quarantined ?? false)
            _note(context, status.emulator),
        ],
        for (final title in quarantined) _note(context, title),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (missing != null)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(missing.page)),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(l10n.switchDownloadEmulator(missing.emulator)),
              ),
            if (noKeys)
              FilledButton.icon(
                onPressed: () => _addKeys(context),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: Text(l10n.switchAddKeys),
              ),
            if (noFirmware) const InstallFirmwareButton(),
            // While none is found, or the one in use is the pick: a copy in
            // Applications always comes first (design §2).
            if (status != null && (status.install?.picked ?? true))
              OutlinedButton.icon(
                onPressed: () => _chooseEmulator(context),
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(l10n.switchChooseEmulator(status.emulator)),
              ),
            OutlinedButton.icon(
              onPressed: () => bloc.add(const SwitchEvent.load()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.commonCheckAgain),
            ),
          ],
        ),
        if (missing != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.switchAfterDownload(missing.emulator, missing.appName),
            style: AppTextStyle(context).bodySecondary,
          ),
        ],
        if (status != null && (noKeys || noFirmware)) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            noKeys
                ? l10n.switchKeysHelp(status.emulator)
                : l10n.switchFirmwareHelp(status.emulator),
            style: AppTextStyle(context).bodySecondary,
          ),
        ],
        if (status != null) ...[
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.switchFullScreen,
              style: AppTextStyle(context).body,
            ),
            value: status.fullscreen,
            onChanged: (value) => bloc.add(SwitchEvent.setFullscreen(value)),
          ),
        ],
      ],
    );
  }
}
