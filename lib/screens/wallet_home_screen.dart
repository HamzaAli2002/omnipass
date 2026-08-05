import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../router/app_router.dart';
import '../state/providers.dart';
import '../widgets/pass_card.dart';

const _kBg = Color(0xFFF6F7FB);
const _kInk = Color(0xFF6C5CE7);

class WalletHomeScreen extends ConsumerWidget {
  const WalletHomeScreen({super.key});

  ({Color color, IconData icon}) _typeStyle(PassType type) {
    return switch (type) {
      PassType.eventTicket => (
          color: const Color(0xFF6C5CE7),
          icon: Icons.confirmation_number_rounded
        ),
      PassType.smartAccess => (
          color: const Color(0xFF00B894),
          icon: Icons.key_rounded
        ),
      PassType.membership => (
          color: const Color(0xFFE17055),
          icon: Icons.workspace_premium_rounded
        ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load wallet: $e')),
        data: (passes) {
          final byType = <PassType, List<Pass>>{};
          for (final p in passes) {
            byType.putIfAbsent(p.type, () => []).add(p);
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF241E4E), Color(0xFF4A3F9C)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OmniPass',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              passes.isEmpty
                                  ? 'Your wallet is empty'
                                  : '${passes.length} ${passes.length == 1 ? 'pass' : 'passes'} in your wallet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ScanButton(onTap: () => context.push(AppRoutes.scan)),
                    ],
                  ),
                ),
              ),
              if (passes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      _EmptyWallet(onScan: () => context.push(AppRoutes.scan)),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    for (final type in PassType.values)
                      if (byType.containsKey(type)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 18, 18, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_typeStyle(type).icon,
                                      size: 16, color: _typeStyle(type).color),
                                  const SizedBox(width: 6),
                                  Text(
                                    type.label.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: Color(0xFF9098A9),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _kInk,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                ),
                                onPressed: () =>
                                    context.push(AppRoutes.category(type)),
                                child: const Text('View all',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                        for (final pass in byType[type]!)
                          PassCard(
                            pass: pass,
                            onTap: () => context
                                .push(AppRoutes.detail(pass.type, pass.id)),
                          ),
                      ],
                    const SizedBox(height: 24),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.qr_code_scanner_rounded,
              color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyWallet({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _kInk.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wallet_outlined, size: 38, color: _kInk),
            ),
            const SizedBox(height: 20),
            const Text(
              'No passes yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B1F27),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap a pass link, scan a QR code, or use\nthe scan button above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B93A1), height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kInk,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan a pass',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
