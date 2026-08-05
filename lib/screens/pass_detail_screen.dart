import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../router/app_router.dart';
import '../state/providers.dart';

const _kBg = Color(0xFFF6F7FB);
const _kInk = Color(0xFF6C5CE7);

class PassDetailScreen extends ConsumerWidget {
  final PassType type;
  final String passId;
  const PassDetailScreen({super.key, required this.type, required this.passId});

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

  ({Color color, Color bg}) _statusStyle(PassStatus status) {
    return switch (status) {
      PassStatus.active => (
          color: const Color(0xFF00B894),
          bg: const Color(0xFFE7FBF5)
        ),
      PassStatus.upcoming => (
          color: const Color(0xFF6C5CE7),
          bg: const Color(0xFFEFECFD)
        ),
      PassStatus.expired => (
          color: const Color(0xFF8395A7),
          bg: const Color(0xFFEEF1F4)
        ),
      PassStatus.used => (
          color: const Color(0xFF8395A7),
          bg: const Color(0xFFEEF1F4)
        ),
    };
  }

  String _fmtDate(DateTime d) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).value ?? [];
    final sessionAsync = ref.watch(sessionProvider);
    final matches = wallet.where((p) => p.id == passId);
    final pass = matches.isEmpty ? null : matches.first;

    if (pass == null) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(backgroundColor: _kBg, title: const Text('Pass')),
        body:
            const Center(child: Text('This pass is no longer in your wallet.')),
      );
    }

    final status = pass.deriveStatus(DateTime.now());
    final ts = _typeStyle(pass.type);
    final ss = _statusStyle(status);

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ts.color.withOpacity(0.85),
                    ts.color,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(ts.icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pass.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pass.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoCard(
                    icon: Icons.calendar_today_rounded,
                    label: 'Valid from',
                    value: _fmtDate(pass.validFrom),
                    color: ts.color,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.event_busy_rounded,
                    label: 'Valid to',
                    value: _fmtDate(pass.validTo),
                    color: ts.color,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.info_outline_rounded,
                    label: 'Status',
                    value: status.label,
                    color: ss.color,
                    valueColor: ss.color,
                    valueBg: ss.bg,
                  ),
                  const SizedBox(height: 28),
                  sessionAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Session error: $e'),
                    data: (session) {
                      final canAccess = session != null &&
                          !session.isExpiredAt(DateTime.now().toUtc()) &&
                          session.canAccessPass(pass.id);
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                canAccess ? ts.color : const Color(0xFF8395A7),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: Icon(
                            canAccess
                                ? Icons.qr_code_2_rounded
                                : Icons.lock_outline_rounded,
                            size: 22,
                          ),
                          label: Text(
                            canAccess
                                ? 'Open Secure Ticket'
                                : 'Sign in to view secure ticket',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: () {
                            if (canAccess) {
                              context.push(AppRoutes.secure(type, passId));
                            } else {
                              context.push(
                                  AppRoutes.loginFallback(passId: passId));
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color? valueColor;
  final Color? valueBg;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueColor,
    this.valueBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9098A9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              valueBg != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: valueBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: valueColor,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B1F27),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
