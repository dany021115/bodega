import 'dart:async';

import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/backends/backends_page.dart';
import 'package:bodega/app/presentation/bottles/bottle_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_detail_page.dart';
import 'package:bodega/app/presentation/catalog/catalog_page.dart';
import 'package:bodega/app/presentation/library/library_page.dart';
import 'package:bodega/app/presentation/setup/setup_page.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/main_shell.dart';
import 'package:bodega/app/shared/widgets/shell_body.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/router/observer.dart';
import 'package:bodega/device/router/transitions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

enum AppRoute {
  splash,
  setup,
  library,
  catalog,
  catalogDetail,
  bottles,
  bottleDetail,
  backends,
}

/// Without the host requirements or the runtime there is only `/setup`; with
/// them, `/setup` leads to the library. While the first check runs, the splash waits.
String? setupRedirect(SetupState setup, String location) {
  final splash = RouterManager.path(AppRoute.splash);
  final setupPage = RouterManager.path(AppRoute.setup);
  final waiting = location == splash || location == setupPage;

  if (setup.isChecking) return waiting ? null : splash;
  if (!setup.isReady) return location == setupPage ? null : setupPage;
  return waiting ? RouterManager.path(AppRoute.library) : null;
}

GoRouter createRouter(SetupBloc setup) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouterManager.path(AppRoute.splash),
    observers: [StackObserver<void>()],
    refreshListenable: _StreamRefresh(setup.stream),
    redirect: (context, state) =>
        setupRedirect(setup.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: RouterManager.path(AppRoute.splash),
        name: AppRoute.splash.name,
        builder: (context, state) => const Scaffold(body: CustomLoading()),
      ),
      GoRoute(
        path: RouterManager.path(AppRoute.setup),
        name: AppRoute.setup.name,
        pageBuilder: (context, state) => PageTransitions.fadeTransition(
          child: const SetupPage(),
          state: state,
        ),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        pageBuilder: (context, state, child) => PageTransitions.fadeTransition(
          child: MainShell(child: ShellBody(child: child)),
          state: state,
        ),
        routes: [
          _section(AppRoute.library, const LibraryPage()),
          _section(
            AppRoute.catalog,
            const CatalogPage(),
            routes: [
              GoRoute(
                path: ':id',
                name: AppRoute.catalogDetail.name,
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: CatalogDetailPage(id: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          // Siblings, not parent and child: a parent's redirect would also
          // apply to every bottle, and send them all to the library.
          GoRoute(
            path: RouterManager.path(AppRoute.bottles),
            name: AppRoute.bottles.name,
            redirect: (context, state) => RouterManager.path(AppRoute.library),
          ),
          GoRoute(
            path: '${RouterManager.path(AppRoute.bottles)}/:name',
            name: AppRoute.bottleDetail.name,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: BottleDetailPage(name: state.pathParameters['name']!),
            ),
          ),
          _section(AppRoute.backends, const BackendsPage()),
        ],
      ),
    ],
  );
}

GoRoute _section(
  AppRoute route,
  Widget page, {
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: RouterManager.path(route),
  name: route.name,
  routes: routes,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: page),
);

class _StreamRefresh extends ChangeNotifier {
  late final StreamSubscription<Object?> _subscription;

  _StreamRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
