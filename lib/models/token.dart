import 'package:equatable/equatable.dart';

/// What a valid token grants access to. Per the assignment's scoping
/// requirement, a deep-link token defaults to unlocking exactly one pass
/// (a "guest" grant). Only a token explicitly marked [TokenScope.account]
/// escalates to full account access — see README "Session Scoping".
enum TokenScope {
  singlePass,
  account;

  static TokenScope fromWire(String raw) => switch (raw) {
        'account' => TokenScope.account,
        _ => TokenScope.singlePass,
      };
}

/// The strictly-typed claims decoded from the signed token in a deep link,
/// e.g. https://omnipass.app/t/<signed-token>
///
/// This is never passed around as a raw Map — every field is named and
/// typed, and downstream code (routing, the exchange call, the wallet)
/// only ever consumes a [TokenClaims], never a query-string map.
class TokenClaims extends Equatable {
  final String tokenId; // unique id -> used for single-use/replay checks
  final String passId; // which pass this token unlocks
  final TokenScope scope;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const TokenClaims({
    required this.tokenId,
    required this.passId,
    required this.scope,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  Map<String, Object?> toJson() => {
        'jti': tokenId,
        'pid': passId,
        'scp': scope == TokenScope.account ? 'account' : 'single_pass',
        'iat': issuedAt.millisecondsSinceEpoch,
        'exp': expiresAt.millisecondsSinceEpoch,
      };

  factory TokenClaims.fromJson(Map<String, Object?> json) {
    return TokenClaims(
      tokenId: json['jti'] as String,
      passId: json['pid'] as String,
      scope: TokenScope.fromWire(json['scp'] as String),
      issuedAt:
          DateTime.fromMillisecondsSinceEpoch(json['iat'] as int, isUtc: true),
      expiresAt:
          DateTime.fromMillisecondsSinceEpoch(json['exp'] as int, isUtc: true),
    );
  }

  @override
  List<Object?> get props => [tokenId, passId, scope, issuedAt, expiresAt];
}

/// Outcome of the fast, offline, client-side structural check performed the
/// instant a link is received — before any network call. This is a coarse
/// filter only: it catches garbage links immediately, but real signature
/// verification and replay/revocation checks happen server-side during
/// [TokenExchangeResult] (simulated in [SimulatedBackend]).
sealed class TokenParseResult {
  const TokenParseResult();
}

class TokenParseOk extends TokenParseResult {
  final String rawToken;
  final TokenClaims claims;
  const TokenParseOk(this.rawToken, this.claims);
}

/// The link did not even have the right shape (bad base64, bad JSON, missing
/// fields, malformed signature segment). Rejected immediately, no network call.
class TokenParseMalformed extends TokenParseResult {
  final String reason;
  const TokenParseMalformed(this.reason);
}

/// The token parsed fine but its own claimed expiry has already passed.
/// Caught client-side as a fast-fail — still confirmed server-side too.
class TokenParseExpiredByClaim extends TokenParseResult {
  const TokenParseExpiredByClaim();
}

/// Outcome of exchanging a structurally-valid token for a real session,
/// i.e. the network call in section 3.2. Modeled as a sealed type so every
/// call site is forced to handle each case explicitly (no default-to-crash).
sealed class TokenExchangeResult {
  const TokenExchangeResult();
}

class ExchangeGranted extends TokenExchangeResult {
  final String sessionId;
  final TokenScope scope;
  final String passId;
  final DateTime sessionExpiresAt;
  const ExchangeGranted({
    required this.sessionId,
    required this.scope,
    required this.passId,
    required this.sessionExpiresAt,
  });
}

class ExchangeRejectedInvalidSignature extends TokenExchangeResult {
  const ExchangeRejectedInvalidSignature();
}

class ExchangeRejectedExpired extends TokenExchangeResult {
  const ExchangeRejectedExpired();
}

/// Token was well-formed and signed correctly, but has already been redeemed
/// once (single-use enforcement / anti-replay).
class ExchangeRejectedAlreadyUsed extends TokenExchangeResult {
  const ExchangeRejectedAlreadyUsed();
}

class ExchangeFailedNetwork extends TokenExchangeResult {
  const ExchangeFailedNetwork();
}
