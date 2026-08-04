import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/pass.dart';
import '../router/app_router.dart';
import '../state/providers.dart';
import '../widgets/pass_card.dart';

class PassCategoryScreen extends ConsumerWidget {
  final PassType type;
  const PassCategoryScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      body: walletAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (passes) {
          final filtered = passes.where((p) => p.type == type).toList();
          if (filtered.isEmpty) {
            return const Center(child: Text('No passes in this category yet.'));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final pass in filtered)
                PassCard(
                  pass: pass,
                  onTap: () => context.push(AppRoutes.detail(type, pass.id)),
                ),
            ],
          );
        },
      ),
    );
  }
}
