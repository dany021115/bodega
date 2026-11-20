import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/shared/text/dependency_text.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the dialog of what [needs] proposes for one app of [bottle], its
/// recommended items checked (DA5). Every runtime by hand is the section's
/// list (RA6).
Future<void> showNeedsDialog(
  BuildContext context, {
  required String bottle,
  required AppNeeds needs,
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider.value(
    value: context.read<DependenciesBloc>(),
    child: NeedsDialog(bottle: bottle, needs: needs),
  ),
);

/// One line of the dialog: a runtime of [need], or a [setting].
typedef _Option = ({NeedItem item, DependencyNeed? need, SettingNeed? setting});

class NeedsDialog extends StatefulWidget {
  final String bottle;
  final AppNeeds needs;

  const NeedsDialog({super.key, required this.bottle, required this.needs});

  @override
  State<NeedsDialog> createState() => _NeedsDialogState();
}

class _NeedsDialogState extends State<NeedsDialog> {
  late final List<_Option> _options;
  late final Set<NeedItem> _checked;

  @override
  void initState() {
    super.initState();
    final needs = widget.needs;
    _options = [
      for (final need in needs.dependencies)
        if (!need.dependency.installed)
          (
            item: NeedItem.runtime(need.dependency.id, need.dependency.arch),
            need: need,
            setting: null,
          ),
      for (final setting in needs.settings)
        if (setting.state == SettingState.notApplied)
          (item: NeedItem.settings(setting.fix), need: null, setting: setting),
    ];
    // Recommended runtimes and settings start checked; optional ones do not.
    _checked = {
      for (final option in _options)
        if (option.need?.need == Need.recommended || option.setting != null)
          option.item,
    };
  }

  Widget _subtitle(AppL10n l10n, AppTextStyle styles, _Option option) {
    final need = option.setting != null ? Need.recommended : option.need?.need;
    final reason = option.setting != null
        ? l10n.fixReason(option.setting!.fix)
        : l10n.reasonOf(option.need!);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (need != null)
            StatusChip(
              label: l10n.needOf(need),
              color: need == Need.recommended
                  ? AppColor.statusTested
                  : AppColor.statusUntested,
            ),
          Text(reason, style: styles.caption),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final needs = widget.needs;

    return AlertDialog(
      title: Text(l10n.depsDialogFor(needs.title)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_options.isEmpty)
                Text(l10n.depsDialogNone, style: styles.bodySecondary),
              for (final option in _options)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _checked.contains(option.item),
                  onChanged: (value) => setState(
                    () => value == true
                        ? _checked.add(option.item)
                        : _checked.remove(option.item),
                  ),
                  title: Text(
                    option.setting != null
                        ? l10n.settingLine(option.setting!)
                        : l10n.dependencyLine(option.need!.dependency),
                  ),
                  subtitle: _subtitle(l10n, styles, option),
                ),
              if (_options.any((option) => option.item is RuntimeItem)) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.depsWholeBottle, style: styles.caption),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.depsNotNow),
        ),
        FilledButton(
          onPressed: _checked.isEmpty
              ? null
              : () {
                  context.read<DependenciesBloc>().add(
                    DependenciesEvent.install(widget.bottle, [
                      for (final option in _options)
                        if (_checked.contains(option.item)) option.item,
                    ]),
                  );
                  Navigator.of(context).pop();
                },
          child: Text(l10n.commonInstall),
        ),
      ],
    );
  }
}
