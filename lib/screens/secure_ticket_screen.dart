import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/pass.dart';
import '../state/providers.dart';

/// The deepest screen in the nested stack (Wallet -> Category -> Detail ->
/// Secure Ticket). Renders a scannable code and a live validity indicator
/// that keeps ticking correctly even if the app was backgrounded while this
/// screen was open (section 3.4) — achieved by deriving everything from
/// wall-clock `DateTime.now()` on a periodic rebuild rather than counting
/// down a stored duration, so there's nothing to "lose" on backgrounding.
class SecureTicketScreen extends ConsumerStatefulWidget {
  final PassType type;
  final String passId;
  const SecureTicketScreen({super.key, required this.type, required this.passId});

  @override
  ConsumerState<SecureTicketScreen> createState() => _SecureTicketScreenState();
}

class _SecureTicketScreenState extends ConsumerState<SecureTicketScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resync immediately on resume rather than waiting for the next tick,
    // so the validity indicator never shows stale state after backgrounding.
    if (state == AppLifecycleState.resumed) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _countdownLabel(Pass pass, PassStatus status) {
    if (status == PassStatus.used) return 'Already used';
    if (status == PassStatus.expired) return 'Expired';
    if (status == PassStatus.active) return 'Active now';
    final remaining = pass.validFrom.difference(_now);
    if (remaining.inDays > 0) {
      return 'Starts in ${remaining.inDays}d ${remaining.inHours % 24}h';
    }
    if (remaining.inHours > 0) {
      return 'Starts in ${remaining.inHours}h ${remaining.inMinutes % 60}m';
    }
    return 'Starts in ${remaining.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider).value ?? [];
    final sessionAsync = ref.watch(sessionProvider);
    final matches = wallet.where((p) => p.id == widget.passId);
    final pass = matches.isEmpty ? null : matches.first;

    if (pass == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Secure Ticket')),
        body: const Center(child: Text('Pass not found.')),
      );
    }

    return sessionAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Session error: $e'))),
      data: (session) {
        final authorized = session != null &&
            !session.isExpiredAt(DateTime.now().toUtc()) &&
            session.canAccessPass(pass.id);

        if (!authorized) {
          // Enforcement point: even if someone deep-links directly to this
          // route, the secure view refuses to render without a session
          // scoped to this exact pass (or an account-level session).
          return Scaffold(
            appBar: AppBar(title: const Text('Secure Ticket')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You need to claim this pass again to view its secure ticket.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final status = pass.deriveStatus(_now);
        final scannable = status == PassStatus.active || status == PassStatus.upcoming;

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(pass.title, style: const TextStyle(color: Colors.white)),
          ),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brightness-boost / high-contrast rendering: a pure
                  // white card on a pure black scaffold maximizes on-screen
                  // luminance for real-world gate scanning in low light.
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Opacity(
                      opacity: scannable ? 1.0 : 0.3,
                      child: QrImageView(
                        data: pass.claimTokenId.isNotEmpty
                            ? pass.claimTokenId
                            : pass.id,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: scannable ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _countdownLabel(pass, status),
                      style: TextStyle(
                        color: scannable ? Colors.greenAccent : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(pass.subtitle,
                      style: const TextStyle(color: Colors.white70)),
                  if (!scannable) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'This code is not currently scannable.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
