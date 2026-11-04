import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.storefront_rounded,
        title: 'Catálogo',
        message: 'Esta sección llega en el siguiente hito.',
      ),
    );
  }
}
