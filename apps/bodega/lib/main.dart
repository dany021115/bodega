import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/helpers/breakpoints.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:toastification/toastification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const BodegaApp());
}

class BodegaApp extends StatefulWidget {
  const BodegaApp({super.key});

  @override
  State<BodegaApp> createState() => _BodegaAppState();
}

class _BodegaAppState extends State<BodegaApp> {
  final SetupBloc _setup = getIt<SetupBloc>()..add(const SetupEvent.check());
  late final GoRouter _router = createRouter(_setup);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _setup),
        BlocProvider.value(value: getIt<CatalogBloc>()),
        BlocProvider.value(value: getIt<InstallBloc>()),
        BlocProvider.value(value: getIt<LibraryBloc>()),
        BlocProvider(create: (_) => getIt<ThemeBloc>()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, theme) {
          return ToastificationWrapper(
            child: MaterialApp.router(
              title: 'Bodega',
              debugShowCheckedModeBanner: false,
              builder: (context, child) => ResponsiveBreakpoints.builder(
                child: child!,
                breakpoints: appBreakpoints,
              ),
              themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
              theme: AppTheme.getLightTheme(),
              darkTheme: AppTheme.getDarkTheme(),
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
