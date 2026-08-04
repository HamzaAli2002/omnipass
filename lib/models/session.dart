import 'package:equatable/equatable.dart';
import 'token.dart';

/// The session granted after a successful token exchange. This — never the
/// raw token — is what gets persisted in secure storage long-term.
class AppSession extends Equatable {
  final String sessionId;
  final TokenScope scope;

  /// Populated when [scope] is [TokenScope.singlePass]: the one pass this
  /// guest session is allowed to view/act on. Null for account-scoped
  /// sessions, which is exactly why account-level tokens must be issued
  /// deliberately, not as the default — see README.
  final String? scopedPassId;

  final DateTime expiresAt;

  const AppSession({
    required this.sessionId,
    required this.scope,
    required this.expiresAt,
    this.scopedPassId,
  });

  bool get isAccountLevel => scope == TokenScope.account;

  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  /// Authorization check used everywhere the app decides whether the current
  /// session may open a given pass's secure view. Centralizing this in one
  /// place is what prevents a single-pass grant from silently turning into
  /// full-wallet access.
  bool canAccessPass(String passId) {
    if (isAccountLevel) return true;
    return scopedPassId == passId;
  }

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'scope': scope == TokenScope.account ? 'account' : 'single_pass',
        'scopedPassId': scopedPassId,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AppSession.fromJson(Map<String, Object?> json) => AppSession(
        sessionId: json['sessionId'] as String,
        scope: TokenScope.fromWire(json['scope'] as String),
        scopedPassId: json['scopedPassId'] as String?,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  @override
  List<Object?> get props => [sessionId, scope, scopedPassId, expiresAt];
}
