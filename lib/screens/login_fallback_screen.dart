import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Section 3.2's "clear recovery screen" for a failed exchange. In this
/// demo there's no real account backend to sign into, so this screen
/// documents the fallback UX (a manual login form would live here) rather
/// than implementing full account auth, which is out of scope for the
/// assignment's deep-link architecture focus.
class LoginFallbackScreen extends StatelessWidget {
  final String? passId;
  const LoginFallbackScreen({super.key, this.passId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In Required')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'We couldn\'t automatically grant access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                passId != null
                    ? 'Sign in to your account to view pass "$passId", or request a fresh link.'
                    : 'Sign in to your account, or request a fresh link.',
                textAlign: TextAlign.center,
              ),
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
