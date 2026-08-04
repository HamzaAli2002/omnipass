import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'claim_flow.dart';
import 'deep_link_service.dart';

/// Ties [DeepLinkService]'s three arrival modes to [ClaimFlow.claim]:
///
///  - cold start:   [start] checks [DeepLinkService.getInitialLink] once,
///                   at app boot, before the first frame settles.
///  - warm resume & already-foregrounded: both arrive on
///                   [DeepLinkService.linkStream] — from the app's
///                   perspective they're handled identically, which is
///                   correct: the OS has already done the work of
///                   distinguishing "was backgrounded" vs "was open"; all
///                   this app needs to do is navigate to the right screen
///                   once it has the URI, exactly the same way regardless
///                   of which of the two it was.
class DeepLinkController {
  final DeepLinkService _linkService;
  final ClaimFlow _claimFlow;
  StreamSubscription<Uri>? _sub;

  DeepLinkController({
    required DeepLinkService linkService,
    required ClaimFlow claimFlow,
  })  : _linkService = linkService,
        _claimFlow = claimFlow;

  Future<void> start() async {
    // Cold start: app was fully terminated and this link launched it.
    final initial = await _linkService.getInitialLink();
    if (initial != null) {
      await _handle(initial);
    }

    // Warm resume + already-foregrounded: process is alive, OS delivers
    // the link directly.
    _sub = _linkService.linkStream.listen(_handle);
  }

  Future<void> _handle(Uri uri) async {
    final rawToken = extractRawToken(uri);
    if (rawToken == null) {
      // A link hit our scheme/domain but didn't match the expected
      // /t/<token> shape at all — still rejected safely, never a crash.
      _claimFlow.router.push('/link-error?reason=malformed');
      return;
    }
    await _claimFlow.claim(rawToken);
  }

  void dispose() {
    _sub?.cancel();
  }
}

/// Provider wiring: built once the router exists, since ClaimFlow needs it
/// for navigation.
final claimFlowProvider = Provider.family<ClaimFlow, GoRouter>((ref, router) {
  return ClaimFlow(ref.read, router);
});
