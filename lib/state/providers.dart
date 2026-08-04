import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pass.dart';
import '../models/session.dart';
import '../services/deep_link_service.dart';
import '../services/pass_repository.dart';
import '../services/secure_session_store.dart';
import '../services/token_service.dart';

/// --- Service providers (singletons for the app's lifetime) ---

final simulatedBackendProvider = Provider<SimulatedBackend>((ref) {
  return SimulatedBackend();
});

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService(ref.watch(simulatedBackendProvider));
});

final secureSessionStoreProvider = Provider<SecureSessionStore>((ref) {
  return SecureSessionStore();
});

final passRepositoryProvider = Provider<PassRepository>((ref) {
  return PassRepository();
});

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});

/// --- Session state ---
///
/// Holds the currently active [AppSession], if any. This is what every
/// screen checks via [AppSession.canAccessPass] before rendering a secure
/// ticket view — the enforcement point for the scoping rule in 3.2.
class SessionNotifier extends AsyncNotifier<AppSession?> {
  @override
  Future<AppSession?> build() async {
    final store = ref.watch(secureSessionStoreProvider);
    final session = await store.read();
    if (session != null && session.isExpiredAt(DateTime.now().toUtc())) {
      await store.clear();
      return null;
    }
    return session;
  }

  Future<void> setSession(AppSession session) async {
    await ref.read(secureSessionStoreProvider).save(session);
    state = AsyncData(session);
  }

  Future<void> clearSession() async {
    await ref.read(secureSessionStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, AppSession?>(SessionNotifier.new);

/// --- Wallet state ---
///
/// The collected passes. Loaded from local persistence at startup, so the
/// wallet survives a force-kill; updated whenever a pass is newly claimed
/// (via deep link OR in-app scan — both funnel into [addOrUpdatePass]) or
/// marked redeemed.
class WalletNotifier extends AsyncNotifier<List<Pass>> {
  @override
  Future<List<Pass>> build() async {
    return ref.watch(passRepositoryProvider).loadAll();
  }

  Future<void> addOrUpdatePass(Pass pass) async {
    final current = state.value ?? [];
    final withoutExisting = current.where((p) => p.id != pass.id).toList();
    final updated = [...withoutExisting, pass];
    state = AsyncData(updated);
    await ref.read(passRepositoryProvider).saveAll(updated);
  }

  Future<void> markRedeemed(String passId) async {
    final current = state.value ?? [];
    final updated = [
      for (final p in current)
        if (p.id == passId) p.copyWith(redeemed: true) else p,
    ];
    state = AsyncData(updated);
    await ref.read(passRepositoryProvider).saveAll(updated);
  }

  Pass? byId(String passId) {
    return (state.value ?? []).where((p) => p.id == passId).firstOrNull;
  }
}

final walletProvider =
    AsyncNotifierProvider<WalletNotifier, List<Pass>>(WalletNotifier.new);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
