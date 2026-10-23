import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_failure.dart';
import 'auth_controller.dart';
import 'session.dart';

/// Shown while the session is restored or the profile loads, and when the
/// profile could not be loaded.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final error = profile.error;
    // Watched so the sign-out controller stays alive while its request runs.
    ref.watch(authControllerProvider(AuthForm.signOut));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: error == null || profile.isLoading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AuthFailure.messageFor(error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(currentProfileProvider),
                        child: const Text('Tekrar dene'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(
                              authControllerProvider(AuthForm.signOut).notifier,
                            )
                            .signOut(),
                        child: const Text('Çıkış yap'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
