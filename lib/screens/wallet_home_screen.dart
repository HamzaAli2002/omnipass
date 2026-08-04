import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../router/app_router.dart';
import '../state/providers.dart';
import '../widgets/pass_card.dart';

class WalletHomeScreen extends ConsumerWidget {
  const WalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OmniPass Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan to claim a pass',
            onPressed: () => context.push(AppRoutes.scan),
          ),
        ],
      ),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load wallet: $e')),
        data: (passes) {
          if (passes.isEmpty) {
            return _EmptyWallet(onScan: () => context.push(AppRoutes.scan));
          }

          final byType = <PassType, List<Pass>>{};
          for (final p in passes) {
            byType.putIfAbsent(p.type, () => []).add(p);
          }

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final type in PassType.values)
                if (byType.containsKey(type)) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type.label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.category(type)),
                          child: const Text('View all'),
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
            ],
          );
        },
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
            const Icon(Icons.wallet_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No passes yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap a pass link, scan a QR code, or use the scan button above.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan a pass'),
            ),
          ],
        ),
      ),
    );
  }
}
