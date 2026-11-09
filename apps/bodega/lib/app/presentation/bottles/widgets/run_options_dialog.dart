import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/run_options/run_options_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/shared/graphics_of.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// [program] and [args] fill it in when it comes from an application.
Future<void> showRunOptions(
  BuildContext context, {
  required String bottle,
  required List<String> backends,
  String program = '',
  List<String> args = const [],
  String title = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => BlocProvider(
    create: (_) => getIt<RunOptionsBloc>()
      ..add(
        RunOptionsEvent.start(
          bottle: bottle,
          program: program,
          args: [for (final arg in args) arg.contains(' ') ? '"$arg"' : arg]
              .join(' '),
          title: title,
        ),
      ),
    child: RunOptionsDialog(backends: backends),
  ),
);

class RunOptionsDialog extends StatefulWidget {
  final List<String> backends;

  const RunOptionsDialog({super.key, required this.backends});

  @override
  State<RunOptionsDialog> createState() => _RunOptionsDialogState();
}

class _RunOptionsDialogState extends State<RunOptionsDialog> {
  final _program = TextEditingController();
  final _args = TextEditingController();
  final _env = TextEditingController();
  final _title = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_program, _args, _env, _title]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _change(RunOptionsState Function(RunOptionsState) edit) {
    final bloc = context.read<RunOptionsBloc>();
    bloc.add(RunOptionsEvent.changed(edit(bloc.state)));
  }

  Future<void> _pick() async {
    const programs = XTypeGroup(label: 'Programas', extensions: ['exe', 'EXE']);
    final file = await openFile(acceptedTypeGroups: const [programs]);
    if (file == null) return;
    _program.text = file.path;
    _change((state) => state.copyWith(program: file.path));
  }

  /// G4: why the chosen backend does not suit the program, if it does not.
  String? _misfit(BuildContext context, RunOptionsState state) {
    final backend = state.backend;
    if (backend == null || backend == 'auto') return null;
    final name = state.program.split(RegExp(r'[\\/]')).last;
    return graphicsOf(
      context,
      state.bottle,
      state.program,
    )?.warning(state.title.isEmpty ? name : state.title, backend);
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return BlocConsumer<RunOptionsBloc, RunOptionsState>(
      listenWhen: (previous, current) =>
          (previous.log != current.log && current.log != null) ||
          previous.program != current.program && _program.text.isEmpty,
      listener: (context, state) {
        if (state.log case final log?) {
          context.read<LibraryBloc>().add(
            LibraryEvent.track(state.bottle, log),
          );
          Navigator.of(context).pop();
          return;
        }
        // The first state brings what came from an application.
        _program.text = state.program;
        _args.text = state.args;
        _title.text = state.title;
      },
      builder: (context, state) {
        final caps = context.read<SetupBloc>().state.capabilities;
        return AlertDialog(
          title: const Text('Ejecutar con opciones'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _program,
                          decoration: const InputDecoration(
                            labelText: 'Programa',
                          ),
                          onChanged: (value) =>
                              _change((s) => s.copyWith(program: value)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: state.isRunning ? null : _pick,
                        child: const Text('Elegir…'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _args,
                    decoration: const InputDecoration(labelText: 'Argumentos'),
                    onChanged: (value) =>
                        _change((s) => s.copyWith(args: value)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _env,
                    minLines: 2,
                    maxLines: 5,
                    style: styles.mono,
                    decoration: const InputDecoration(
                      labelText: 'Variables de entorno',
                      hintText:
                          'NOMBRE=valor, una por línea. WINEDEBUG va aquí.',
                    ),
                    onChanged: (value) =>
                        _change((s) => s.copyWith(env: value)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String?>(
                    initialValue: state.backend,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gráficos'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Como la botella'),
                      ),
                      for (final backend in widget.backends)
                        DropdownMenuItem(value: backend, child: Text(backend)),
                    ],
                    onChanged: (value) =>
                        _change((s) => s.copyWith(backend: value)),
                  ),
                  if (_misfit(context, state) case final warning?)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        warning,
                        style: styles.caption?.copyWith(
                          color: AppColor.statusFlaky,
                        ),
                      ),
                    ),
                  if (caps.avx)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Anunciar AVX', style: styles.body),
                      subtitle: Text(
                        'Apágalo si un juego se cierra al empezar.',
                        style: styles.caption,
                      ),
                      value: state.avx,
                      onChanged: (value) =>
                          _change((s) => s.copyWith(avx: value)),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Guardar como lanzador', style: styles.body),
                    subtitle: Text(
                      'Queda en la botella, con estos argumentos y variables.',
                      style: styles.caption,
                    ),
                    value: state.save,
                    onChanged: (value) =>
                        _change((s) => s.copyWith(save: value)),
                  ),
                  if (state.save)
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Título'),
                      onChanged: (value) =>
                          _change((s) => s.copyWith(title: value)),
                    ),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: state.isRunning || state.program.trim().isEmpty
                  ? null
                  : () => context.read<RunOptionsBloc>().add(
                      const RunOptionsEvent.submit(),
                    ),
              child: state.isRunning
                  ? const CustomLoading(size: 18)
                  : const Text('Ejecutar'),
            ),
          ],
        );
      },
    );
  }
}
