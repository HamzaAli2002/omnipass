import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../models/token.dart';

/// Parses and validates OmniPass tokens.
///
/// IMPORTANT: this is the ONLY place token strings are parsed anywhere in
/// the app. The external deep-link handler (`DeepLinkService`) and the
/// in-app QR scanner (`ScanScreen`) both call [TokenService.parse] and
/// [TokenService.exchange] on this exact class — there is no second,
/// forked parsing path for the scan-in flow (section 3.5 requirement).
///
/// Token wire format (a deliberately JWT-like, compact scheme):
///   base64Url(payloadJson) + "." + hex(HMAC-SHA256(payloadJson, serverSecret))
///
/// The *structural* check (right shape, fields present, correctly typed,
/// not obviously expired) happens instantly and fully offline in [parse].
/// Cryptographic signature verification and replay/revocation checks are
/// modeled as a server responsibility and only happen in [exchange], via
/// [SimulatedBackend] — exactly mirroring how a real backend would own the
/// signing secret and the single-use ledger, which a client must never
/// hold. See README "Token validation model" for the full rationale.
class TokenService {
  final SimulatedBackend backend;
  TokenService(this.backend);

  /// Fast, offline, client-side structural validation. No network call.
  TokenParseResult parse(String rawToken) {
    try {
      final parts = rawToken.split('.');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        return const TokenParseMalformed('Token is not in <payload>.<sig> form');
      }
      final sigHex = parts[1];
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sigHex)) {
        return const TokenParseMalformed('Signature segment is malformed');
      }

      final normalized = base64Url.normalize(parts[0]);
      final decodedBytes = base64Url.decode(normalized);
      final decodedJson = utf8.decode(decodedBytes);
      final map = jsonDecode(decodedJson);
      if (map is! Map<String, Object?>) {
        return const TokenParseMalformed('Payload is not a JSON object');
      }

      final requiredKeys = ['jti', 'pid', 'scp', 'iat', 'exp'];
      for (final k in requiredKeys) {
        if (!map.containsKey(k)) {
          return TokenParseMalformed('Missing claim "$k"');
        }
      }
      if (map['jti'] is! String ||
          map['pid'] is! String ||
          map['scp'] is! String ||
          map['iat'] is! int ||
          map['exp'] is! int) {
        return const TokenParseMalformed('Claim has the wrong type');
      }

      final claims = TokenClaims.fromJson(map);

      if (claims.isExpiredAt(DateTime.now().toUtc())) {
        return const TokenParseExpiredByClaim();
      }

      return TokenParseOk(rawToken, claims);
    } catch (_) {
      // Any decode/parse failure (bad base64, bad JSON, etc.) is a
      // malformed token — never a crash, per section 3.1.
      return const TokenParseMalformed('Could not decode token');
    }
  }

  /// Exchanges a structurally-valid token for a real session. This is the
  /// simulated network call from section 3.2. Real signature verification
  /// and single-use/revocation enforcement happen here, server-side.
  Future<TokenExchangeResult> exchange(TokenParseOk parsed) {
    return backend.redeem(parsed.rawToken, parsed.claims);
  }
}

/// Stands in for a real OmniPass backend. Owns the HMAC signing secret and
/// the single-use redemption ledger — neither of which a client should ever
/// hold in production. Also used by [SimulatedBackend.mintSampleLink] to
/// generate the three demo links the assignment's deliverables call for
/// (valid / expired / bypass-eligible).
class SimulatedBackend {
  // Simulated server secret. In a real system this lives only on the
  // server; the client never sees it and never verifies signatures itself,
  // which is exactly why signature checking is modeled here and not in
  // TokenService.parse. Documented explicitly in the README.
  static const _serverSecretSimulated = 'khizex-omnipass-simulated-server-secret-v1';

  final Set<String> _redeemedTokenIds = {};
  final Set<String> _revokedTokenIds = {};

  Future<TokenExchangeResult> redeem(String rawToken, TokenClaims claims) async {
    await Future<void>.delayed(const Duration(milliseconds: 350)); // simulate latency

    final parts = rawToken.split('.');
    final payloadB64 = parts[0];
    final givenSig = parts[1];
    final expectedSig = _sign(payloadB64);

    if (!_constantTimeEquals(givenSig, expectedSig)) {
      return const ExchangeRejectedInvalidSignature();
    }
    if (claims.isExpiredAt(DateTime.now().toUtc())) {
      return const ExchangeRejectedExpired();
    }
    if (_revokedTokenIds.contains(claims.tokenId)) {
      return const ExchangeRejectedInvalidSignature();
    }
    if (_redeemedTokenIds.contains(claims.tokenId)) {
      return const ExchangeRejectedAlreadyUsed();
    }

    _redeemedTokenIds.add(claims.tokenId); // enforce single-use immediately

    return ExchangeGranted(
      sessionId: 'sess_${claims.tokenId}',
      scope: claims.scope,
      passId: claims.passId,
      sessionExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
    );
  }

  String _sign(String payloadB64) {
    final mac = Hmac(sha256, utf8.encode(_serverSecretSimulated));
    return mac.convert(utf8.encode(payloadB64)).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Mints a correctly-signed demo link for a given pass. Used only to
  /// generate the sample links required in the deliverables (never used by
  /// the app's own runtime parsing/validation path).
  String mintSampleLink({
    required String passId,
    required TokenScope scope,
    required Duration validFor,
    bool preRevoke = false,
  }) {
    final jti = 'jti_${Random.secure().nextInt(1 << 31)}';
    final now = DateTime.now().toUtc();
    final claims = TokenClaims(
      tokenId: jti,
      passId: passId,
      scope: scope,
      issuedAt: now,
      expiresAt: now.add(validFor),
    );
    final payloadB64 = base64Url
        .encode(utf8.encode(jsonEncode(claims.toJson())))
        .replaceAll('=', '');
    final sig = _sign(payloadB64);
    if (preRevoke) _revokedTokenIds.add(jti);
    return 'https://omnipass.app/t/$payloadB64.$sig';
  }
}
