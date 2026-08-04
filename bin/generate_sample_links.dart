// Run with: dart run bin/generate_sample_links.dart
//
// Produces the three sample links called for in the deliverables:
//   1. A valid pass link (fresh, single-pass scope)
//   2. An expired/invalid token
//   3. A pass requiring the auth-bypass path from a logged-out state
//      (a fresh single-pass-scope token — the same mechanism as #1,
//      demoed by force-clearing the session first; see README "Demo script").
//
// These use SimulatedBackend directly (the same signing logic the app's
// SimulatedBackend.redeem verifies against) — never a separate/fake signer.
import '../lib/models/token.dart';
import '../lib/services/token_service.dart';

void main() {
  final backend = SimulatedBackend();

  final valid = backend.mintSampleLink(
    passId: 'evt-synthwave-2026',
    scope: TokenScope.singlePass,
    validFor: const Duration(hours: 6),
  );

  final expired = backend.mintSampleLink(
    passId: 'access-hq-floor4',
    scope: TokenScope.singlePass,
    validFor: const Duration(seconds: -1), // already expired at mint time
  );

  final bypassDemo = backend.mintSampleLink(
    passId: 'member-studio-gold',
    scope: TokenScope.singlePass,
    validFor: const Duration(hours: 6),
  );

  print('--- Valid pass link ---');
  print(valid);
  print('');
  print('--- Expired/invalid token link ---');
  print(expired);
  print('');
  print('--- Auth-bypass demo link (logged-out user) ---');
  print(bypassDemo);
  print('');
  print('Note: each backend instance keeps its own redemption ledger, so');
  print('these three are only meaningful within a single run of the app');
  print('(a fresh app install/state). Re-run this script to mint new ones.');
}
