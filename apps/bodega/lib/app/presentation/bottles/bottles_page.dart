import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/bottle_card.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottlesPage extends StatefulWidget {
  const BottlesPage({super.key});

  @override
  State<BottlesPage> createState() => _BottlesPageState();
}

class _BottlesPageState extends State<BottlesPage> {
  @override
  void initState() {
    super.initState();
    context.read<BottlesBloc>().add(const BottlesEvent.load());
    context.read<LibraryBloc>().add(const LibraryEvent.load());
  }

  @override
  Widget build(BuildContext context) {
    final open = context.select((LibraryBloc bloc) => bloc.state.open);

    return Scaffold(
      body: BlocConsumer<BottlesBloc, BottlesState>(
        listenWhen: (previous, current) =>
            current.error != null && previous.error != current.error,
        listener: (context, state) =>
            AppToast.error(context, state.error!.message),
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          if (state.bottles.isEmpty) {
            return const EmptyState(
              icon: Icons.wine_bar_rounded,
              title: 'No hay botellas',
              message: 'Se crean al instalar algo desde el Catálogo.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            itemCount: state.bottles.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Botellas',
                  style: AppTextStyle(context).screenTitle,
                );
              }
              final bottle = state.bottles[index - 1];
              return BottleCard(
                bottle: bottle,
                isOpen: open.contains(bottle.name),
              );
            },
          );
        },
      ),
    );
  }
}
