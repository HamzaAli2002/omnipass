import 'package:flutter/material.dart';
import '../models/pass.dart';

class PassCard extends StatelessWidget {
  final Pass pass;
  final VoidCallback onTap;

  const PassCard({super.key, required this.pass, required this.onTap});

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

  @override
  Widget build(BuildContext context) {
    final status = pass.deriveStatus(DateTime.now());
    final isDimmed = status == PassStatus.expired || status == PassStatus.used;
    final typeStyle = _typeStyle(pass.type);
    final statusStyle = _statusStyle(status);

    return Opacity(
      opacity: isDimmed ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: typeStyle.color.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: typeStyle.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                        Icon(typeStyle.icon, color: typeStyle.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pass.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Color(0xFF1B1F27),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pass.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8B93A1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusStyle.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(
                            color: statusStyle.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey.shade400, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
