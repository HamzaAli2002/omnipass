// Run with: dart run bin/generate_sample_links.dart
//   -> mints the 3 required deliverable links (valid / expired / bypass demo)
//
// Or, to mint a link for ANY pass in the catalog (so the wallet list can
// actually grow past 3 entries during testing):
//   dart run bin/generate_sample_links.dart <passId>
// e.g. dart run bin/generate_sample_links.dart evt-jazz-night
//
// Valid passIds (see lib/services/pass_catalog_service.dart):
//   evt-synthwave-2026, evt-jazz-night, evt-tech-conf,
//   access-hq-floor4, access-garage-b2,
//   member-studio-gold, member-library-plus
//
// These use SimulatedBackend directly (the same signing logic the app's
// SimulatedBackend.redeem verifies against) — never a separate/fake signer.
import '../lib/models/token.dart';
import '../lib/services/token_service.dart';

void main(List<String> args) {
  final backend = SimulatedBackend();

  if (args.isNotEmpty) {
    final passId = args[0];
    final link = backend.mintSampleLink(
      passId: passId,
      scope: TokenScope.singlePass,
      validFor: const Duration(hours: 6),
    );
    print('--- Link for "$passId" ---');
    print(link);
    print('');
    print('(If this passId is not in the catalog, the app will show');
    print('"Pass not found" — check pass_catalog_service.dart for the list.)');
    return;
  }

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
  print('');
  print('Tip: to add MORE distinct passes to your wallet (not just these');
  print('3), run: dart run bin/generate_sample_links.dart <passId>');
  print('e.g.:    dart run bin/generate_sample_links.dart evt-jazz-night');
}
