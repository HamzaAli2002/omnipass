# OmniPass — The Deep Link Wallet

Khizex Mobile Engineering Internship — Week 4 Build Challenge
Stack: **Flutter (Dart, strict null-safety)** — `go_router`, `flutter_riverpod`,
`flutter_secure_storage`, `app_links`, `mobile_scanner`, `qr_flutter`.

## 1. Setup

This repo ships the `lib/` source, `pubspec.yaml`, and the native-config
*snippets* you need to add — it does not ship generated `android/`/`ios/`
platform folders (those are machine/SDK-specific scaffolding, not
hand-written source). Generate them once, then layer the snippets on top:

```
flutter create --project-name omnipass --org app.omnipass .
flutter pub get
```

Then:
1. Open `android/app/src/main/AndroidManifest.xml` and add the intent-filter
   block from `android_snippets/AndroidManifest_intent_filter.xml` inside
   your launcher `<activity>`.
2. In Xcode (or directly in `ios/Runner/Runner.entitlements` and
   `ios/Runner/Info.plist`), apply `ios_snippets/associated_domains_setup.txt`.
3. `flutter run`

To generate the three sample links required in the deliverables:

```
dart run bin/generate_sample_links.dart
```

This prints a valid link, an expired link, and a bypass-demo link, each
signed against the same (simulated) server secret the app itself verifies
against — so pasting any of them into a browser or a notes app and tapping
them will actually exercise the real flow described below.

To test locally before `omnipass.app` is a real, verified domain, use the
`omnipass://t/<token>` scheme instead of `https://omnipass.app/t/<token>` —
both are wired to the identical parsing/exchange path (see `extractRawToken`
in `lib/services/claim_flow.dart`).

## 2. Deep-link configuration

- **Android**: `android_snippets/AndroidManifest_intent_filter.xml` — an
  `autoVerify="true"` intent-filter for `https://omnipass.app/t/*`, plus the
  `omnipass://t/` custom-scheme fallback. `launchMode="singleTask"` is set
  deliberately: without it, tapping a link while the app is backgrounded
  would spawn a second Activity instance instead of resuming the existing
  one, which would silently break "warm resume" (the app would lose
  whatever screen state existed before backgrounding, per 3.1b). Real
  verification requires hosting `assetlinks.json` — see the file for the
  exact JSON and fingerprint command.
- **iOS**: `ios_snippets/associated_domains_setup.txt` — the
  `applinks:omnipass.app` Associated Domains entitlement, the
  `CFBundleURLTypes` custom-scheme fallback, and the
  `apple-app-site-association` file needed for real verification.

Both platforms route into the same Dart-side handler
(`lib/services/deep_link_service.dart`, built on the `app_links` package),
which is what actually gives us the three entry scenarios:

| Scenario | Mechanism |
|---|---|
| Cold start | `DeepLinkService.getInitialLink()`, checked once at boot before the first frame settles |
| Warm resume | OS delivers the link on `DeepLinkService.linkStream` after `singleTask` brings the existing Activity back to the foreground |
| Already foregrounded | Same `linkStream`, fired while the app is already the frontmost app (or from an in-app share/QR handoff) |

The app deliberately treats "warm resume" and "already foregrounded"
identically once a URI is in hand — the OS has already done the work of
distinguishing the two; from the app's perspective both are just "a URI
arrived while the process was alive," handled by the same stream listener.

## 3. Navigation stack — Wallet → Category → Detail → Secure Ticket

Deep-linked navigation is synthesized by `ClaimFlow._handleExchange` in
`lib/services/claim_flow.dart`:

```dart
router.go(AppRoutes.wallet);              // reset stack, wallet is now root
router.push(AppRoutes.category(pass.type));
router.push(AppRoutes.detail(pass.type, pass.id));
router.push(AppRoutes.secure(pass.type, pass.id));
```

`go()` resets the stack so wallet-home is always the root; the three
`push()` calls build a real, poppable back stack on top of it. Back
navigation from the secure ticket view always lands somewhere sensible
(pass detail → category → wallet home), never a crash or a dead end,
because it's a genuine `go_router` stack rather than a single replaced
route.

## 4. Token model & the shared validation path (no forked logic)

A link looks like `https://omnipass.app/t/<payload>.<signature>` — a
deliberately JWT-like, compact scheme: `<payload>` is base64url(JSON claims:
`jti`, `pid`, `scp`, `iat`, `exp`), `<signature>` is a hex HMAC-SHA256 over
the payload.

**`TokenService.parse`** (`lib/services/token_service.dart`) is fully
offline and synchronous: right shape, decodable JSON, all required claims
present and correctly typed, not obviously expired. It rejects garbage
instantly, with zero network calls — this is what "reject obviously
malformed links immediately" (3.2) means in practice.

**`TokenService.exchange`** simulates the network call: it hands the token
to `SimulatedBackend.redeem`, which owns the HMAC secret and an in-memory
single-use ledger (`_redeemedTokenIds`) and revocation list
(`_revokedTokenIds`). This is where actual signature verification and
replay/revocation enforcement happen — deliberately modeled as a *server*
responsibility, because a real client should never hold the signing secret
or be trusted to self-report "I haven't used this yet."

**Section 3.5's "no duplicated/forked parsing path" requirement**: both the
external deep link handler (`DeepLinkController` → `ClaimFlow.claim`) and
the in-app QR scanner (`ScanScreen._onDetect` → the exact same
`ClaimFlow.claim`) call into this one pipeline. `extractRawToken()` is also
shared — the QR scanner accepts a scanned URL and normalizes it through the
identical function the deep-link handler uses, rather than writing a second
"parse this some other way" path.

## 5. Session scoping — how the login-bypass is *not* over-granting

`AppSession` (`lib/models/session.dart`) carries a `TokenScope`:

- `TokenScope.singlePass` (the default): the session's `scopedPassId` is set
  to exactly the pass the token encoded. `AppSession.canAccessPass(id)`
  returns `true` only for that one id. This is what a claim/share link
  should issue — someone who receives a forwarded link only ever unlocks
  the one pass it names, never the sender's whole wallet.
- `TokenScope.account`: only used if a token's `scp` claim is explicitly
  `"account"` — reserved for a genuine account-recovery/sign-in link, not
  the default event-ticket/access-pass claim flow. `canAccessPass` returns
  `true` for any pass in that case.

Every screen that renders a secure ticket (`SecureTicketScreen`) re-checks
`session.canAccessPass(passId)` at render time — not just at claim time —
so even a direct/manual navigation to a secure-ticket route can't bypass
the scoping check.

## 6. Handling a leaked/forwarded link

Because tokens are **single-use** (enforced server-side in
`SimulatedBackend._redeemedTokenIds`), the failure mode for a forwarded
link is: whoever taps it *first* claims the pass and its scoped session;
everyone after that gets `ExchangeRejectedAlreadyUsed` → the link-error
screen ("This link was already used"). The token is also **time-bound**
(`exp` claim, checked both client-side for a fast fail and server-side for
the authoritative check), so a leaked link has a bounded window even before
anyone uses it. And because the resulting session is scoped to exactly one
pass (see §5), even a successful early claim by the wrong person never
exposes anything beyond that single pass.

## 7. Storage

- **Session/credential data** (`SecureSessionStore`,
  `lib/services/secure_session_store.dart`): platform secure storage only —
  Keychain via `IOSOptions` on iOS, `encryptedSharedPreferences: true` on
  Android. Never `SharedPreferences` directly for this data. The *raw*
  claim token is discarded immediately after a successful exchange — only
  the derived session (scope + scoped pass id + expiry) is persisted, so
  disk access alone can't be used to replay the original claim link.
- **Pass metadata** (`PassRepository`, `lib/services/pass_repository.dart`):
  event name/dates/status — non-sensitive on its own, so `SharedPreferences`
  is an appropriate local cache here. This is what makes the wallet survive
  a force-kill (verified manually: claim a pass → force-kill from the app
  switcher → relaunch → pass is still listed with correct status, since
  status is derived live from `validFrom`/`validTo`/`redeemed`, never
  cached as a stale label).
- No raw token or session secret is ever passed to `print`/logging in the
  claim/exchange path.

## 8. Error handling

All parse/exchange outcomes are modeled as Dart sealed classes
(`TokenParseResult`, `TokenExchangeResult` in `lib/models/token.dart`), so
`ClaimFlow._handleExchange`'s `switch` is exhaustive — there's no
"forgot to handle a case" path that falls through to a crash or a blank
screen. Each rejection reason routes to a distinct, human-readable message
on `LinkErrorScreen`; a failed exchange (simulated network error) routes to
`LoginFallbackScreen` instead of a stuck spinner.

## 9. Demo script (cold / warm / foregrounded)

1. **Cold start**: force-kill the app entirely, then tap a generated link
   (e.g. from Notes or Messages) → app launches directly into the secure
   ticket view for that pass.
2. **Warm resume**: open the app, background it (home button/gesture,
   don't kill it), tap a different link → app foregrounds straight into
   that pass's secure ticket view, and pressing back still returns to
   whatever screen you were on before backgrounding once you pop past the
   deep-linked stack's own root.
3. **Already foregrounded**: with the app open on the wallet home, use the
   in-app scan button to scan a QR code encoding a link → navigates
   immediately, no backgrounding involved.

## 10. What's simulated vs. real

- Real: Universal/App Link config (manifest + entitlements + verification
  files), the full client-side parsing/typing layer, secure storage
  integration, the nested `go_router` stack, wallet persistence, the QR
  scan-in flow with real camera permission handling.
- Simulated (and documented as such in code, not silently faked): the
  backend that signs tokens and enforces single-use/revocation
  (`SimulatedBackend`), and the pass-metadata lookup
  (`PassCatalogService`). Swapping these for real HTTP calls to an actual
  OmniPass backend would not require changing any of the parsing, routing,
  session-scoping, or storage code above them.
