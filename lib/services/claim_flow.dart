import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/session.dart';
import '../models/token.dart';
import '../router/app_router.dart';
import '../state/providers.dart';
import 'pass_catalog_service.dart';

/// Extracts the raw signed-token string from either an omnipass:// custom
/// scheme link (local-testing fallback) or an https://omnipass.app/t/...
/// universal/app link. Both the [DeepLinkController] and the in-app QR
/// scanner funnel through this before calling [ClaimFlow.claim] — there is
/// exactly one place a token string is pulled out of a URL/QR payload.
String? extractRawToken(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  // https://omnipass.app/t/<token>  -> pathSegments = ['t', '<token>']
  if (segments.length >= 2 && segments.first == 't') {
    return segments[1];
  }
  // omnipass://t/<token> parses with host='t', path='/<token>' on some
  // platforms, or pathSegments=['t','<token>'] on others — handle both.
  if (uri.host == 't' && segments.isNotEmpty) {
    return segments.first;
  }
  return null;
}

/// A [ProviderListenable] reader — matches the generic signature of both
/// `WidgetRef.read` (used inside a `ConsumerStatefulWidget`, e.g.
/// `ScanScreen`) and `Ref.read` (used inside a provider, e.g.
/// `claimFlowProvider`). `WidgetRef` and `Ref` are separate, non-subtype
/// riverpod interfaces, so `ClaimFlow` can't just store a `Ref` field and
/// accept a `WidgetRef` at the call site — it stores this reader function
/// instead, obtained as a tear-off (`ref.read`) from either type.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// The single, shared "claim a pass from a token" pipeline. Both entry
/// points in the assignment — the external deep link (3.1) and the in-app
/// QR scan-in (3.5) — call [claim] with a raw token string and nothing
/// else. Neither path re-implements parsing, exchange, session persistence,
/// or navigation.
class ClaimFlow {
  final ProviderReader read;
  final GoRouter router;
  final PassCatalogService _catalog = PassCatalogService();

  ClaimFlow(this.read, this.router);

  Future<void> claim(String rawToken) async {
    debugPrint('OMNIPASS CLAIM: claim() called with rawToken=$rawToken');
    final tokenService = read(tokenServiceProvider);
    final parsed = tokenService.parse(rawToken);
    debugPrint('OMNIPASS CLAIM: parse result = ${parsed.runtimeType}');

    switch (parsed) {
      case TokenParseMalformed():
        debugPrint('OMNIPASS CLAIM: malformed — ${parsed.reason}');
        router.push(AppRoutes.linkError('malformed'));
        return;
      case TokenParseExpiredByClaim():
        debugPrint('OMNIPASS CLAIM: expired at parse time');
        router.push(AppRoutes.linkError('expired'));
        return;
      case TokenParseOk():
        final result = await tokenService.exchange(parsed);
        debugPrint('OMNIPASS CLAIM: exchange result = ${result.runtimeType}');
        await _handleExchange(
            result, parsed.claims.passId, parsed.claims.tokenId);
    }
  }

  Future<void> _handleExchange(
    TokenExchangeResult result,
    String passId,
    String tokenId,
  ) async {
    switch (result) {
      case ExchangeGranted():
        final pass = _catalog.resolve(result.passId, claimTokenId: tokenId);
        if (pass == null) {
          debugPrint(
              'OMNIPASS CLAIM: granted but unknown passId=${result.passId}');
          router.push(AppRoutes.linkError('unknown-pass'));
          return;
        }

        await read(sessionProvider.notifier).setSession(
          AppSession(
            sessionId: result.sessionId,
            scope: result.scope,
            scopedPassId:
                result.scope == TokenScope.singlePass ? pass.id : null,
            expiresAt: result.sessionExpiresAt,
          ),
        );
        await read(walletProvider.notifier).addOrUpdatePass(pass);

        debugPrint(
            'OMNIPASS CLAIM: navigating to secure ticket for ${pass.id}');
        // Synthesize a correct, poppable back stack: wallet home is the
        // root, then category -> detail -> secure are pushed on top, so
        // back navigation from the deep-linked screen always resolves to
        // the wallet home (section 3.1's back-stack requirement).
        router.go(AppRoutes.wallet);
        router.push(AppRoutes.category(pass.type));
        router.push(AppRoutes.detail(pass.type, pass.id));
        router.push(AppRoutes.secure(pass.type, pass.id));
        debugPrint('OMNIPASS CLAIM: navigation calls issued');

      case ExchangeRejectedInvalidSignature():
        debugPrint('OMNIPASS CLAIM: invalid signature');
        router.push(AppRoutes.linkError('invalid'));
      case ExchangeRejectedExpired():
        debugPrint('OMNIPASS CLAIM: expired at exchange time');
        router.push(AppRoutes.linkError('expired'));
      case ExchangeRejectedAlreadyUsed():
        debugPrint('OMNIPASS CLAIM: already used');
        router.push(AppRoutes.linkError('already-used'));
      case ExchangeFailedNetwork():
        debugPrint('OMNIPASS CLAIM: exchange network failure');
        router.push(AppRoutes.loginFallback(passId: passId));
    }
  }
}
