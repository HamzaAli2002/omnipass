# OmniPass — The Deep Link Wallet

> **Khizex Mobile Engineering Internship · Week 4 Build Challenge**
> A Flutter application that handles cryptographically signed, single-use deep links for secure pass claiming — event tickets, access passes, and more.

**Stack:** Flutter (Dart, strict null-safety) · `go_router` · `flutter_riverpod` · `flutter_secure_storage` · `app_links` · `mobile_scanner` · `qr_flutter`

---

## What This Is

OmniPass is a mobile wallet for time-bound, single-use passes distributed via deep links or QR codes. A link looks like:

```
https://omnipass.app/t/<payload>.<signature>
```

Where `<payload>` is `base64url(JSON claims)` and `<signature>` is an HMAC-SHA256 hex digest — a compact, JWT-inspired scheme. Tapping or scanning the link claims the pass and navigates the user directly into a secure ticket view, handling all three OS entry scenarios: cold start, warm resume, and already foregrounded.

---

## Architecture Highlights

### Token Pipeline (No Forked Logic)
Both the deep link handler and the in-app QR scanner feed into the exact same `ClaimFlow.claim()` pipeline. `extractRawToken()` is shared — there is no second parsing path for QR-scanned URLs.

```
Deep link  ─┐
             ├─→ extractRawToken() → TokenService.parse() → TokenService.exchange() → ClaimFlow._handleExchange()
QR scan    ─┘
```

### Two-Phase Validation
- **`TokenService.parse`** — fully offline, synchronous. Validates shape, decodes JSON, checks required claims, rejects obviously expired tokens. Zero network calls.
- **`TokenService.exchange`** — simulates the server call. `SimulatedBackend` owns the HMAC secret, a single-use ledger (`_redeemedTokenIds`), and a revocation list. Signature verification and replay protection are deliberately server-side responsibilities.

### Session Scoping
`AppSession` carries a `TokenScope`:
- `TokenScope.singlePass` — `canAccessPass(id)` returns `true` only for the one pass the token named. A forwarded link never unlocks the sender's whole wallet.
- `TokenScope.account` — reserved for account-recovery links; grants wallet-wide access.

`SecureTicketScreen` re-checks `session.canAccessPass(passId)` at render time — not just at claim time — so direct/manual navigation cannot bypass scoping.

### Deep Link Entry Scenarios

| Scenario | Mechanism |
|---|---|
| Cold start | `DeepLinkService.getInitialLink()`, checked once at boot |
| Warm resume | `DeepLinkService.linkStream` after `singleTask` Activity resume |
| Already foregrounded | Same `linkStream`, fired while app is frontmost |

### Navigation Stack (Synthesized on Claim)
```dart
router.go(AppRoutes.wallet);                          // reset, wallet is root
router.push(AppRoutes.category(pass.type));
router.push(AppRoutes.detail(pass.type, pass.id));
router.push(AppRoutes.secure(pass.type, pass.id));
```
Back navigation always lands somewhere sensible — never a dead end or crash.

### Storage Strategy
| Data | Store | Reason |
|---|---|---|
| Session / credentials | `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) | Sensitive |
| Pass metadata | `SharedPreferences` | Non-sensitive local cache |
| Raw claim token | **Discarded after exchange** | Never persisted to disk |

### Error Handling
All parse/exchange outcomes are Dart sealed classes (`TokenParseResult`, `TokenExchangeResult`). The `switch` in `ClaimFlow._handleExchange` is exhaustive — no silent fall-through to a blank screen. Each rejection reason maps to a distinct message on `LinkErrorScreen`.

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── session.dart         # AppSession, TokenScope, canAccessPass()
│   └── token.dart           # Sealed result types for parse & exchange
├── services/
│   ├── claim_flow.dart      # Orchestrates the full claim pipeline
│   ├── deep_link_service.dart
│   ├── token_service.dart   # parse() + exchange()
│   ├── secure_session_store.dart
│   └── pass_repository.dart
├── router/
│   └── app_router.dart      # go_router config + AppRoutes
└── screens/
    ├── wallet_screen.dart
    ├── category_screen.dart
    ├── detail_screen.dart
    ├── secure_ticket_screen.dart
    ├── scan_screen.dart
    ├── link_error_screen.dart
    └── login_fallback_screen.dart

android_snippets/
└── AndroidManifest_intent_filter.xml   # autoVerify intent-filter + custom scheme

ios_snippets/
└── associated_domains_setup.txt        # Entitlement + Info.plist + AASA file

bin/
└── generate_sample_links.dart          # Prints valid / expired / bypass-demo links
```

---

## Setup

This repo ships `lib/`, `pubspec.yaml`, and native config snippets. Platform folders (`android/`, `ios/`) are machine-generated scaffolding — generate them once, then layer the snippets on top:

```bash
flutter create --project-name omnipass --org app.omnipass .
flutter pub get
```

**Android:** Add the intent-filter block from `android_snippets/AndroidManifest_intent_filter.xml` inside your launcher `<activity>` in `android/app/src/main/AndroidManifest.xml`.

**iOS:** Apply `ios_snippets/associated_domains_setup.txt` to `Runner.entitlements` and `Info.plist` in Xcode (or directly).

```bash
flutter run
```

### Generate Sample Links

```bash
dart run bin/generate_sample_links.dart
```

Prints three links signed against the same simulated server secret the app verifies — a valid link, an expired link, and a bypass-demo link. Paste any into Notes or Messages and tap to exercise the real claim flow.

### Local Testing (Before Domain Verification)

Use the custom scheme instead of the universal link:
```
omnipass://t/<token>   # instead of https://omnipass.app/t/<token>
```
Both routes through the identical `extractRawToken` → `ClaimFlow` path.

---

## Demo Script

**Cold start:** Force-kill the app → tap a generated link from Notes → app launches directly into the secure ticket view.

**Warm resume:** Open the app → background it → tap a different link → app foregrounds straight into that pass's secure ticket, back stack intact.

**Already foregrounded:** With the app open on wallet home, use the in-app scan button to scan a QR encoding a link → navigates immediately.

---

## Security Model

A leaked or forwarded link is handled by layered controls:

- **Single-use enforcement** (server-side): the first tap claims the pass; every subsequent tap gets `ExchangeRejectedAlreadyUsed`.
- **Time-bound expiry**: the `exp` claim is checked client-side (fast fail) and server-side (authoritative).
- **Scope isolation**: a successful claim by the wrong person still exposes only the one named pass, never the whole wallet.
- **No raw token on disk**: only the derived session is persisted post-exchange.

---

## What's Simulated vs. Real

| Real | Simulated |
|---|---|
| Universal/App Link config (manifest, entitlements, AASA) | `SimulatedBackend` (HMAC signing, single-use ledger, revocation) |
| Full client-side parsing and type layer | `PassCatalogService` (pass metadata lookup) |
| Secure storage integration | — |
| Nested `go_router` stack with back navigation | — |
| Wallet persistence across force-kills | — |
| QR scan with real camera permission handling | — |

Swapping `SimulatedBackend` for real HTTP calls requires no changes to parsing, routing, session-scoping, or storage code.

---

## Dependencies

| Package | Purpose |
|---|---|
| `go_router` | Declarative routing + synthesized back stacks |
| `flutter_riverpod` | State management |
| `flutter_secure_storage` | Keychain / EncryptedSharedPreferences |
| `app_links` | Universal links + custom scheme handling |
| `mobile_scanner` | QR code scanning |
| `qr_flutter` | QR code generation |

---

## License

MIT
