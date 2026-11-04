import 'package:bodega/app/bloc/add_app/add_app_bloc.dart';
import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _programs = XTypeGroup(label: 'Programas', extensions: ['exe']);

Future<void> showAddAppDialog(BuildContext context) => showDialog<void>(
  context: context,
  // An installer may be running: only the dialog's own buttons close it.
  barrierDismissible: false,
  builder: (_) => BlocProvider(
    create: (_) => getIt<AddAppBloc>()..add(const AddAppEvent.load()),
    child: const AddAppDialog(),
  ),
);

class AddAppDialog extends StatefulWidget {
  const AddAppDialog({super.key});

  @override
  State<AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickExe(BuildContext context) async {
    final bloc = context.read<AddAppBloc>();
    final file = await openFile(acceptedTypeGroups: const [_programs]);
    if (file != null) bloc.add(AddAppEvent.exeChosen(file.path));
  }

  Future<void> _pickInstalled(BuildContext context, String? driveC) async {
    final bloc = context.read<AddAppBloc>();
    final file = await openFile(
      initialDirectory: driveC,
      acceptedTypeGroups: const [_programs],
    );
    if (file != null) bloc.add(AddAppEvent.installedChosen(file.path));
  }

  void _finish(BuildContext context, String title) {
    context.read<BottlesBloc>().add(const BottlesEvent.load());
    context.read<LibraryBloc>().add(const LibraryEvent.load());
    AppToast.success(context, '$title ya está en tu Biblioteca');
    // Close the dialog first: this context goes with it.
    Navigator.of(context).pop();
    RouterManager.go(AppRoute.library);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddAppBloc, AddAppState>(
      listener: (context, state) {
        if (state.step == AddAppStep.done) {
          _finish(context, state.title.trim());
        } else if (_title.text != state.title) {
          _title.text = state.title;
        }
      },
      builder: (context, state) {
        final styles = AppTextStyle(context);

        return AlertDialog(
          title: const Text('Agregar otra aplicación'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  switch (state.step) {
                    AddAppStep.form || AddAppStep.done => _form(context, state),
                    AddAppStep.creating => _waiting(
                      'Creando la botella. La primera vez puede tardar unos '
                      'minutos.',
                      styles,
                    ),
                    AddAppStep.installing => _waiting(
                      'El instalador se abre en su propia ventana. Termínalo '
                      'allí y se seguirá aquí.',
                      styles,
                    ),
                    AddAppStep.pickInstalled => Text(
                      'Instalador terminado. Elige el programa instalado: '
                      'suele estar en Program Files.',
                      style: styles.body,
                    ),
                  },
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
          actions: [
            if (state.step == AddAppStep.form ||
                state.step == AddAppStep.pickInstalled)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            if (state.step == AddAppStep.form)
              FilledButton(
                onPressed: state.canSubmit
                    ? () => context.read<AddAppBloc>().add(
                        const AddAppEvent.submit(),
                      )
                    : null,
                child: const Text('Agregar'),
              ),
            if (state.step == AddAppStep.installing)
              TextButton(
                onPressed: () => context.read<AddAppBloc>().add(
                  const AddAppEvent.installerDone(),
                ),
                child: const Text('El instalador ya terminó'),
              ),
            if (state.step == AddAppStep.pickInstalled)
              FilledButton(
                onPressed: () => _pickInstalled(context, state.driveC),
                child: const Text('Elegir el programa…'),
              ),
          ],
        );
      },
    );
  }

  Widget _waiting(String message, AppTextStyle styles) => Row(
    children: [
      const CustomLoading(size: 20),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(message, style: styles.body)),
    ],
  );

  Widget _form(BuildContext context, AddAppState state) {
    final bloc = context.read<AddAppBloc>();
    final styles = AppTextStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.exe?.split('/').last ?? 'Ningún programa elegido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.body,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            OutlinedButton(
              onPressed: () => _pickExe(context),
              child: const Text('Elegir .exe…'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Título'),
          onChanged: (title) => bloc.add(AddAppEvent.titleChanged(title)),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String?>(
          key: ValueKey(state.bottles.length),
          initialValue: state.bottle,
          decoration: const InputDecoration(labelText: 'Botella'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Botella nueva')),
            for (final bottle in state.bottles)
              DropdownMenuItem(value: bottle, child: Text(bottle)),
          ],
          onChanged: (bottle) => bloc.add(AddAppEvent.bottleChosen(bottle)),
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Es un instalador', style: styles.body),
          value: state.isInstaller,
          onChanged: (value) =>
              bloc.add(AddAppEvent.installerToggled(value ?? false)),
        ),
      ],
    );
  }
}
