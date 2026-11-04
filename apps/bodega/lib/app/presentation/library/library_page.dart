import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/library/widgets/library_card.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    context.read<LibraryBloc>().add(const LibraryEvent.load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<LibraryBloc, LibraryState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          if (state.apps.isEmpty) {
            return EmptyState(
              icon: Icons.apps_rounded,
              title: 'Tu biblioteca está vacía',
              message: 'Instala algo desde el Catálogo y aparecerá aquí.',
              actionLabel: 'Ir al Catálogo',
              actionIcon: Icons.storefront_rounded,
              onAction: () =>
                  RouterManager.go(AppRoute.catalog, context: context),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            itemCount: state.apps.length + 1,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Biblioteca',
                  style: AppTextStyle(context).screenTitle,
                );
              }
              final app = state.apps[index - 1];
              return LibraryCard(
                app: app,
                isOpen: state.open.contains(app.bottle),
                hints: state.hints[app.bottle] ?? const [],
              );
            },
          );
        },
      ),
    );
  }
}
