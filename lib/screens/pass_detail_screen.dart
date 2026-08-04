import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../router/app_router.dart';
import '../state/providers.dart';

class PassDetailScreen extends ConsumerWidget {
  final PassType type;
  final String passId;
  const PassDetailScreen({super.key, required this.type, required this.passId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value ?? [];
    final sessionAsync = ref.watch(sessionProvider);
    final pass = wallet.where((p) => p.id == passId).firstOrNull;

    if (pass == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pass')),
        body: const Center(child: Text('This pass is no longer in your wallet.')),
      );
    }

    final status = pass.deriveStatus(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(pass.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pass.subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '${_fmt(pass.validFrom)} — ${_fmt(pass.validTo)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text('Status: ${status.label}'),
            const Spacer(),
            sessionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Text('Session error: $e'),
              data: (session) {
                final canAccess = session != null &&
                    !session.isExpiredAt(DateTime.now().toUtc()) &&
                    session.canAccessPass(pass.id);
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.qr_code),
                    label: Text(canAccess
                        ? 'Open Secure Ticket'
                        : 'Sign in to view secure ticket'),
                    onPressed: () {
                      if (canAccess) {
                        context.push(AppRoutes.secure(type, passId));
                      } else {
                        context.push(AppRoutes.loginFallback(passId: passId));
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
