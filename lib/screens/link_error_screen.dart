import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

class LinkErrorScreen extends StatelessWidget {
  final String reason;
  const LinkErrorScreen({super.key, required this.reason});

  ({String title, String message, IconData icon}) _content() {
    return switch (reason) {
      'expired' => (
          title: 'This link has expired',
          message:
              'The pass link you opened is no longer valid. Request a new link from the issuer.',
          icon: Icons.timer_off_outlined,
        ),
      'already-used' => (
          title: 'This link was already used',
          message:
              'Pass links are single-use. If this wasn\'t you, request a new link.',
          icon: Icons.block_outlined,
        ),
      'invalid' => (
          title: 'This link isn\'t valid',
          message:
              'We couldn\'t verify this pass link. It may have been tampered with.',
          icon: Icons.gpp_bad_outlined,
        ),
      'unknown-pass' => (
          title: 'Pass not found',
          message: 'This link points to a pass we don\'t recognize.',
          icon: Icons.help_outline,
        ),
      _ => (
          title: 'This link isn\'t valid',
          message: 'The link is malformed and couldn\'t be read.',
          icon: Icons.link_off,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _content();
    return Scaffold(
      appBar: AppBar(title: const Text('Link Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.icon, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(c.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(c.message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.wallet),
                child: const Text('Back to Wallet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
