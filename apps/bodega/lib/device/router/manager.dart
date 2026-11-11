import 'package:bodega/app/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouterManager {
  static final Map<AppRoute, String Function(Map<String, String>)>
  _routeBuilders = {
    AppRoute.splash: (_) => '/',
    AppRoute.setup: (_) => '/setup',
    AppRoute.library: (_) => '/library',
    AppRoute.switchGames: (_) => '/switch',
    AppRoute.catalog: (_) => '/catalog',
    AppRoute.catalogDetail: (p) => '/catalog/${p['id']}',
    AppRoute.bottles: (_) => '/bottles',
    AppRoute.bottleDetail: (p) => '/bottles/${p['name']}',
    AppRoute.backends: (_) => '/backends',
  };

  static String path(AppRoute route, {Map<String, String> params = const {}}) =>
      _routeBuilders[route]!(params);

  static void go(
    AppRoute route, {
    Map<String, String> params = const {},
    BuildContext? context,
  }) {
    final ctx = context ?? rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.go(path(route, params: params));
  }

  static void push(
    AppRoute route, {
    Map<String, String> params = const {},
    BuildContext? context,
  }) {
    final ctx = context ?? rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.push(path(route, params: params));
  }
}
