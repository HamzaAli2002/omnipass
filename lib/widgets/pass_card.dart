import 'package:flutter/material.dart';
import '../models/pass.dart';

class PassCard extends StatelessWidget {
  final Pass pass;
  final VoidCallback onTap;

  const PassCard({super.key, required this.pass, required this.onTap});

  Color _statusColor(PassStatus status, ColorScheme scheme) {
    return switch (status) {
      PassStatus.active => Colors.green,
      PassStatus.upcoming => scheme.primary,
      PassStatus.expired => Colors.grey,
      PassStatus.used => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = pass.deriveStatus(DateTime.now());
    final isDimmed = status == PassStatus.expired || status == PassStatus.used;
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: isDimmed ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor(status, scheme),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pass.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pass.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status, scheme).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: _statusColor(status, scheme),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
