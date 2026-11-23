import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/shared/text/native_text.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/native_option.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Native engine options of [app] (PA2), each saved as it is switched.
Future<void> showNativeOptions(BuildContext context, LibraryApp app) =>
    showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<LibraryBloc>(),
        child: NativeOptionsDialog(app: app),
      ),
    );

class NativeOptionsDialog extends StatefulWidget {
  final LibraryApp app;

  const NativeOptionsDialog({super.key, required this.app});

  @override
  State<NativeOptionsDialog> createState() => _NativeOptionsDialogState();
}

class _NativeOptionsDialogState extends State<NativeOptionsDialog> {
  // ponytail: shown as switched; a failed save shows as the library's error.
  late final Set<NativeOption> _on = {...widget.app.nativeOptions};

  void _set(NativeOption option, bool on) {
    setState(() => on ? _on.add(option) : _on.remove(option));
    context.read<LibraryBloc>().add(
      LibraryEvent.setNativeOption(
        widget.app.bottle,
        widget.app.key,
        option,
        on,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    return AlertDialog(
      title: Text(l10n.nativeOptionsTitle(widget.app.title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final option in NativeOption.values)
              SwitchListTile(
                key: ValueKey('native ${option.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(nativeOptionText(l10n, option), style: styles.body),
                subtitle: Text(
                  nativeOptionHintText(l10n, option),
                  style: styles.caption,
                ),
                value: _on.contains(option),
                onChanged: (on) => _set(option, on),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.nativeOptionsNote, style: styles.caption),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}
