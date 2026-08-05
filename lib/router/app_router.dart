import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../screens/link_error_screen.dart';
import '../screens/login_fallback_screen.dart';
import '../screens/pass_category_screen.dart';
import '../screens/pass_detail_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/secure_ticket_screen.dart';
import '../screens/wallet_home_screen.dart';

/// Route path constants, kept in one place so both the router and the
/// deep-link controller (which needs to *build* these paths after an
/// exchange) agree on the exact shape of the nested stack:
///
///   Wallet -> Pass Category -> Pass Detail -> Secure Ticket View
class AppRoutes {
  static const wallet = '/wallet';
  static String category(PassType t) => '/wallet/category/${t.name}';
  static String detail(PassType t, String passId) =>
      '${category(t)}/pass/$passId';
  static String secure(PassType t, String passId) =>
      '${detail(t, passId)}/secure';
  static const scan = '/scan';

  static String linkError(String reason) =>
      '/link-error?reason=${Uri.encodeComponent(reason)}';
  static String loginFallback({String? passId}) =>
      '/login-fallback${passId != null ? '?passId=$passId' : ''}';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.wallet,
    // go_router automatically tries to match the OS's raw initial route
    // (the exact URI Android/iOS launched the app with) against our
    // declared routes — independently of, and *before*, our own
    // DeepLinkController (built on app_links) gets a chance to handle the
    // same URI. Since `omnipass://t/<token>` and `https://omnipass.app/t/
    // <token>` don't match any declared path, go_router throws
    // "no routes for location" on cold start. This redirect intercepts
    // that shape and sends it to wallet-home instead of erroring; the real
    // navigation (to the secure ticket screen) then happens a moment later
    // when DeepLinkController's own listener processes the same link.
    redirect: (context, state) {
      final uri = state.uri;
      final isRawDeepLink =
          (uri.scheme == 'omnipass' && uri.host == 't') ||
          (uri.scheme == 'https' &&
              uri.host == 'omnipass.app' &&
              uri.path.startsWith('/t/'));
      return isRawDeepLink ? AppRoutes.wallet : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletHomeScreen(),
        routes: [
          GoRoute(
            path: 'category/:type',
            builder: (context, state) {
              final type =
                  PassType.values.byName(state.pathParameters['type']!);
              return PassCategoryScreen(type: type);
            },
            routes: [
              GoRoute(
                path: 'pass/:passId',
                builder: (context, state) {
                  final type =
                      PassType.values.byName(state.pathParameters['type']!);
                  final passId = state.pathParameters['passId']!;
                  return PassDetailScreen(type: type, passId: passId);
                },
                routes: [
                  GoRoute(
                    path: 'secure',
                    builder: (context, state) {
                      final type = PassType.values
                          .byName(state.pathParameters['type']!);
                      final passId = state.pathParameters['passId']!;
                      return SecureTicketScreen(type: type, passId: passId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/link-error',
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'] ?? 'unknown';
          return LinkErrorScreen(reason: reason);
        },
      ),
      GoRoute(
        path: '/login-fallback',
        builder: (context, state) {
          final passId = state.uri.queryParameters['passId'];
          return LoginFallbackScreen(passId: passId);
        },
      ),
    ],
  );
});